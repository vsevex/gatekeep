# Cloudflare Integration for Gatekeep

Integration guide for deploying Gatekeep behind Cloudflare Workers and leveraging Cloudflare's edge network for DDoS protection, caching, and performance optimization.

## Overview

Cloudflare integration provides:

- **DDoS Protection**: Automatic mitigation at the edge
- **Bot Management**: Advanced bot detection and blocking
- **Rate Limiting**: Edge-level rate limiting before requests reach origin
- **Caching**: Cache queue status responses to reduce backend load
- **Performance**: Reduced latency via edge routing
- **Analytics**: Cloudflare Analytics for traffic insights

## Architecture

```plain
User → Cloudflare Edge → Cloudflare Workers → Go Service → Redis
                          ↓
                    (Caching, Rate Limiting, Bot Detection)
```

### Components

1. **Cloudflare Workers**: Edge compute for request handling
2. **Cloudflare Rate Limiting**: Edge-level rate limiting
3. **Cloudflare Bot Management**: Bot detection and mitigation
4. **Cloudflare Cache**: Response caching for status endpoints
5. **Cloudflare Analytics**: Traffic and security analytics

## Prerequisites

- Cloudflare account with Workers plan
- Wrangler CLI installed: `npm install -g wrangler`
- Cloudflare API token with Workers permissions
- Domain configured in Cloudflare (optional, for custom domain)

## Setup

### Step 1: Install Wrangler

```bash
npm install -g wrangler
```

### Step 2: Authenticate

```bash
wrangler login
```

### Step 3: Initialize Workers Project

```bash
mkdir gatekeep-workers
cd gatekeep-workers
wrangler init
```

### Step 4: Project Structure

```plain
gatekeep-workers/
├── src/
│   ├── index.ts          # Main worker entry
│   ├── queue.ts          # Queue operations
│   ├── cache.ts          # Caching logic
│   └── rate-limit.ts     # Rate limiting
├── wrangler.toml         # Workers configuration
└── package.json
```

## Implementation

### Worker Entry Point (`src/index.ts`)

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Route requests
    if (url.pathname.startsWith("/v1/queue/join")) {
      return handleQueueJoin(request, env);
    }

    if (url.pathname.startsWith("/v1/queue/status")) {
      return handleQueueStatus(request, env);
    }

    if (url.pathname.startsWith("/v1/queue/heartbeat")) {
      return handleHeartbeat(request, env);
    }

    // Admin endpoints bypass cache and go directly to origin
    if (url.pathname.startsWith("/v1/admin/")) {
      return forwardToOrigin(request, env);
    }

    // Default: forward to origin
    return forwardToOrigin(request, env);
  },
};

async function forwardToOrigin(request: Request, env: Env): Promise<Response> {
  const originUrl = new URL(request.url);
  originUrl.hostname = env.ORIGIN_HOST;

  const originRequest = new Request(originUrl, {
    method: request.method,
    headers: request.headers,
    body: request.body,
  });

  return fetch(originRequest);
}
```

### Queue Join Handler (`src/queue.ts`)

```typescript
export async function handleQueueJoin(
  request: Request,
  env: Env
): Promise<Response> {
  // Check rate limit at edge
  const rateLimitKey = getRateLimitKey(request);
  const rateLimit = await checkRateLimit(rateLimitKey, env);

  if (!rateLimit.allowed) {
    return new Response(JSON.stringify({ error: "Rate limit exceeded" }), {
      status: 429,
      headers: {
        "Content-Type": "application/json",
        "Retry-After": rateLimit.retryAfter.toString(),
      },
    });
  }

  // Bot detection
  if (await isBot(request, env)) {
    return new Response(JSON.stringify({ error: "Bot detected" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Forward to origin
  return forwardToOrigin(request, env);
}

function getRateLimitKey(request: Request): string {
  const deviceId = request.headers.get("X-Device-ID") || "";
  const ip = request.headers.get("CF-Connecting-IP") || "";
  return `rate_limit:${deviceId}:${ip}`;
}

async function checkRateLimit(
  key: string,
  env: Env
): Promise<{ allowed: boolean; retryAfter: number }> {
  // Use Cloudflare KV or Durable Objects for rate limiting
  // Or use Cloudflare Rate Limiting API
  const count = await env.RATE_LIMIT_KV.get(key);
  const limit = 5; // 5 requests per minute
  const window = 60; // 60 seconds

  if (count && parseInt(count) >= limit) {
    return { allowed: false, retryAfter: window };
  }

  // Increment counter
  await env.RATE_LIMIT_KV.put(key, (parseInt(count || "0") + 1).toString(), {
    expirationTtl: window,
  });

  return { allowed: true, retryAfter: 0 };
}

async function isBot(request: Request, env: Env): Promise<boolean> {
  // Use Cloudflare Bot Management
  const cf = request.cf;
  if (cf && cf.botManagement) {
    return cf.botManagement.score < 30; // Threshold for bot detection
  }

  // Fallback: Check User-Agent
  const ua = request.headers.get("User-Agent") || "";
  const botPatterns = ["bot", "crawler", "spider", "scraper"];
  return botPatterns.some((pattern) => ua.toLowerCase().includes(pattern));
}
```

### Status Caching (`src/cache.ts`)

```typescript
export async function handleQueueStatus(
  request: Request,
  env: Env
): Promise<Response> {
  const url = new URL(request.url);
  const queueId = url.searchParams.get("queue_id");

  if (!queueId) {
    return new Response(JSON.stringify({ error: "Missing queue_id" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Check cache
  const cacheKey = `queue_status:${queueId}`;
  const cached = await env.CACHE.get(cacheKey, { type: "json" });

  if (cached) {
    return new Response(JSON.stringify(cached), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=5",
        "X-Cache": "HIT",
      },
    });
  }

  // Fetch from origin
  const response = await forwardToOrigin(request, env);

  if (response.ok) {
    const data = await response.json();

    // Cache for 5 seconds
    await env.CACHE.put(cacheKey, JSON.stringify(data), {
      expirationTtl: 5,
    });

    // Return with cache headers
    return new Response(JSON.stringify(data), {
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=5",
        "X-Cache": "MISS",
      },
    });
  }

  return response;
}
```

### Configuration (`wrangler.toml`)

```toml
name = "gatekeep-worker"
main = "src/index.ts"
compatibility_date = "2024-01-15"

[env.production]
vars = { ORIGIN_HOST = "gatekeep.example.com" }

[[env.production.kv_namespaces]]
binding = "RATE_LIMIT_KV"
id = "your-kv-namespace-id"

[[env.production.kv_namespaces]]
binding = "CACHE"
id = "your-cache-kv-namespace-id"

[env.production.r2_buckets]
binding = "LOGS"
bucket_name = "gatekeep-logs"
```

## Cloudflare Rate Limiting

### Setup Rate Limiting Rules

1. **Navigate to**: Cloudflare Dashboard → Security → WAF → Rate Limiting Rules

2. **Create Rule**:

   - **Rule Name**: Gatekeep Queue Join Rate Limit
   - **Match**: `http.request.uri.path eq "/v1/queue/join"`
   - **Action**: Block
   - **Rate**: 5 requests per minute per IP
   - **Action**: Block for 60 seconds

3. **Create Rule for Status Checks**:
   - **Rule Name**: Gatekeep Status Rate Limit
   - **Match**: `http.request.uri.path eq "/v1/queue/status"`
   - **Action**: Challenge
   - **Rate**: 100 requests per minute per IP

### Rate Limiting Configuration

```javascript
// In Cloudflare Dashboard or via API
{
  "match": "http.request.uri.path eq \"/v1/queue/join\"",
  "action": {
    "mode": "simulate", // Start with simulate
    "timeout": 60,
    "response": {
      "status_code": 429,
      "content_type": "application/json",
      "body": "{\"error\":\"Rate limit exceeded\"}"
    }
  },
  "rate": {
    "threshold": 5,
    "period": 60
  }
}
```

## Cloudflare Bot Management

### Enable Bot Management

1. **Navigate to**: Cloudflare Dashboard → Security → Bots

2. **Enable Bot Fight Mode** (Free) or **Bot Management** (Paid)

3. **Configure Rules**:
   - Block known bots
   - Challenge suspicious requests
   - Allow verified bots

### Bot Detection in Workers

```typescript
interface BotManagement {
  score: number; // 0-100, lower = more likely bot
  verifiedBot: boolean;
  staticResource: boolean;
}

async function handleBotDetection(request: Request): Promise<boolean> {
  const cf = request.cf;

  if (!cf || !cf.botManagement) {
    return false; // No bot management data
  }

  const botMgmt = cf.botManagement as BotManagement;

  // Block if score is too low
  if (botMgmt.score < 30) {
    return true; // Is bot
  }

  // Allow verified bots (search engines, etc.)
  if (botMgmt.verifiedBot) {
    return false; // Not a malicious bot
  }

  return false;
}
```

## Caching Strategy

### Cache Rules

1. **Queue Status**: Cache for 5 seconds

   - High read frequency
   - Position updates frequently
   - Short TTL prevents stale data

2. **Queue Join**: No cache

   - Write operation
   - Must reach origin

3. **Heartbeat**: No cache

   - Write operation
   - Must reach origin

4. **Admin Endpoints**: No cache
   - Sensitive operations
   - Must reach origin

### Cache Invalidation

```typescript
export async function invalidateCache(
  queueId: string,
  env: Env
): Promise<void> {
  const cacheKey = `queue_status:${queueId}`;
  await env.CACHE.delete(cacheKey);
}

// Call from origin when position changes
// Or use Cloudflare Cache Purge API
```

## DDoS Protection

### Automatic Protection

Cloudflare automatically provides DDoS protection for:

- Layer 3/4 attacks (network layer)
- Layer 7 attacks (application layer)
- Volumetric attacks

### Custom Rules

Create custom WAF rules for additional protection:

```javascript
// Block requests with suspicious patterns
{
  "expression": "http.request.uri.path eq \"/v1/queue/join\" and http.request.headers[\"User-Agent\"] eq \"\"",
  "action": "block"
}
```

## Analytics

### Cloudflare Analytics

Monitor:

- Request volume
- Bot traffic
- Rate limit hits
- Cache hit ratio
- Error rates
- Geographic distribution

### Custom Analytics

```typescript
export async function logAnalytics(
  event: string,
  data: Record<string, any>,
  env: Env
): Promise<void> {
  // Send to Cloudflare Analytics or external service
  await fetch("https://api.cloudflare.com/client/v4/analytics", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.CF_API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      event,
      data,
      timestamp: Date.now(),
    }),
  });
}
```

## Deployment

### Deploy Workers

```bash
# Deploy to production
wrangler deploy --env production

# Deploy to staging
wrangler deploy --env staging
```

### Update Configuration

```bash
# Update environment variables
wrangler secret put ORIGIN_HOST

# Update KV namespaces
wrangler kv:namespace create RATE_LIMIT_KV
wrangler kv:namespace create CACHE
```

## Monitoring

### Workers Analytics

- **Requests**: Total requests per minute
- **Errors**: Error rate and types
- **CPU Time**: Execution time
- **Subrequests**: Outbound requests

### Alerts

Set up alerts for:

- High error rate (>1%)
- High CPU time (>50ms p99)
- Rate limit hits (>1000/minute)
- Bot traffic spikes

## Performance Optimization

### Edge Caching

- Cache queue status for 5 seconds
- Reduce origin load by ~80%
- Improve response time by ~200ms

### Request Batching

```typescript
// Batch multiple status checks
export async function batchStatusCheck(
  queueIds: string[],
  env: Env
): Promise<Response> {
  // Check cache for all
  const results = await Promise.all(
    queueIds.map((id) => env.CACHE.get(`queue_status:${id}`, { type: "json" }))
  );

  // Fetch missing from origin in batch
  const missing = queueIds.filter((_, i) => !results[i]);
  if (missing.length > 0) {
    // Batch request to origin
  }

  return new Response(JSON.stringify(results));
}
```

## Security Considerations

### API Key Protection

- Store origin API keys in Workers Secrets
- Never expose in client-side code
- Rotate keys regularly

### Request Validation

```typescript
export function validateRequest(request: Request): boolean {
  // Validate required headers
  const deviceId = request.headers.get("X-Device-ID");
  if (!deviceId || deviceId.length < 10) {
    return false;
  }

  // Validate request body
  if (request.method === "POST") {
    const contentType = request.headers.get("Content-Type");
    if (contentType !== "application/json") {
      return false;
    }
  }

  return true;
}
```

## Cost Optimization

### Workers Pricing

- **Free Plan**: 100k requests/day
- **Paid Plan**: $5/month + $0.50 per million requests

### Optimization Tips

1. **Cache aggressively**: Reduce origin requests
2. **Use KV for rate limiting**: Cheaper than Durable Objects
3. **Batch operations**: Reduce subrequests
4. **Monitor usage**: Set up billing alerts

## Troubleshooting

### Common Issues

1. **Cache Not Working**

   - Check KV namespace binding
   - Verify cache TTL
   - Check cache headers

2. **Rate Limiting Too Aggressive**

   - Adjust rate limit rules
   - Check IP reputation
   - Review bot management settings

3. **Origin Timeout**
   - Increase timeout in Workers
   - Check origin health
   - Review request size

### Debug Mode

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (env.DEBUG) {
      console.log("Request:", {
        url: request.url,
        method: request.method,
        headers: Object.fromEntries(request.headers),
      });
    }

    // ... rest of handler
  },
};
```

## Testing

### Local Testing

```bash
# Run locally
wrangler dev

# Test endpoints
curl http://localhost:8787/v1/queue/status?queue_id=test
```

### Integration Testing

1. Deploy to staging
2. Run test suite
3. Verify caching
4. Test rate limiting
5. Check bot detection

## Best Practices

1. **Start with Simulate Mode**: Test rate limiting before blocking
2. **Monitor Cache Hit Ratio**: Aim for >70%
3. **Set Appropriate TTLs**: Balance freshness vs. load
4. **Use KV for Rate Limiting**: More cost-effective than Durable Objects
5. **Enable Bot Management**: Protect against automated attacks
6. **Monitor Analytics**: Track performance and security metrics

## Migration Guide

### From Direct Origin Access

1. Deploy Workers to staging
2. Update DNS to point to Workers (or use subdomain)
3. Test all endpoints
4. Monitor metrics
5. Switch production traffic
6. Monitor for issues

### Rollback Plan

1. Update DNS to point directly to origin
2. Disable Workers
3. Investigate issues
4. Fix and redeploy

## Support

- **Cloudflare Workers Docs**: [https://developers.cloudflare.com/workers/]
- **Cloudflare Rate Limiting**: [https://developers.cloudflare.com/waf/rate-limiting-rules/]
- **Cloudflare Bot Management**: [https://developers.cloudflare.com/bots/]

## License

Proprietary - Internal Use Only
