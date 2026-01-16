# Gatekeep: Production-Grade Virtual Waiting Room System

A distributed admission control system for managing access to limited resources, designed for correctness, safety, and operability under extreme load. Suitable for ticket sales, product launches, beta access, API rate limiting, and any scenario requiring controlled admission.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Components](#components)
- [API Specification](#api-specification)
- [Redis Data Model](#redis-data-model)
- [Flutter SDK](#flutter-sdk)
- [Security & Abuse Prevention](#security--abuse-prevention)
- [Operational Guide](#operational-guide)
- [Failure Modes & Mitigations](#failure-modes--mitigations)
- [Deployment](#deployment)

## Overview

Gatekeep is a stateless admission control service that sits between clients and backend systems. It manages user queues, issues time-limited admission tokens, and releases users at a controlled rate to prevent resource exhaustion and backend overload.

### Use Cases

- **Ticket Sales**: High-demand event ticket releases
- **Product Launches**: Limited edition product drops
- **Beta Access**: Controlled rollout of new features
- **API Throttling**: Fair access to rate-limited APIs
- **Resource Protection**: Any scenario with limited capacity and high demand

### Core Principles

- **Stateless where possible**: Service instances are horizontally scalable
- **Token-based admission**: Offline-verifiable tokens eliminate network calls for backend validation
- **Resource safety**: Time-limited access windows with automatic release on timeout
- **Fairness**: FIFO queue with configurable priority buckets
- **Operability**: Comprehensive metrics, structured logs, and admin controls

### Traffic Flow

```plain
Flutter App → Go Admission Service → Backend
                      ↓
                    Redis
```

## Architecture

### Service Boundaries

**Go Admission Service**:

- Queue management (join, position tracking, heartbeat)
- Token issuance and validation
- Release rate control
- Resource capacity coordination

**Backend** (unchanged)

- Token verification (offline, no network calls)
- Resource allocation and business logic processing

**Redis**:

- Queue state (FIFO lists, sorted sets for priority)
- Token metadata and TTL tracking
- Release counters and rate limiting
- Event configuration

### Design Decisions

1. **Stateless service**: All state in Redis enables horizontal scaling
2. **Signed tokens**: HMAC-based tokens verifiable without Redis lookup
3. **Time-bound admission**: Tokens expire aggressively; inventory auto-releases
4. **Heartbeat mechanism**: Detects abandoned sessions and reclaims positions
5. **Priority buckets**: Sorted sets enable multiple queue tiers (presale, partners, general)

## Components

### Backend Service (Go)

**Queue Manager**:

- Maintains FIFO queue per event
- Supports priority buckets via Redis sorted sets
- Tracks position, enqueue time, last heartbeat
- Handles queue joins with idempotency

**Token Service**:

- Generates HMAC-signed admission tokens
- Binds tokens to event_id, user_id/device_id, timestamp
- Enforces short TTL (default: 5 minutes)
- Provides offline verification signature

**Release Controller**:

- Configurable release rate (users/second)
- Manual controls: pause, boost, drain
- Capacity-aware: respects available resource count
- Throughput-aware: adapts to backend processing completion rate

**Admin API**:

- Real-time queue metrics
- Release rate adjustment
- Pause/resume controls
- Event-level enable/disable

### Flutter SDK

**Queue Client**:

- Idempotent join operations
- Position polling with exponential backoff
- Token persistence and restoration
- Network failure handling with retry logic

**UI Components**:

- Waiting room screen with position/ETA
- State machine: Joining → Waiting → Admitted → Expired/Error
- Graceful degradation on network loss

## API Specification

### Base URL

```plain
https://gatekeep.example.com/v1
```

### Authentication

Admin endpoints require API key:

```plain
Authorization: Bearer <admin-api-key>
```

Client endpoints use device/user identification:

```plain
X-Device-ID: <uuid>
X-User-ID: <optional-user-id>
```

### Endpoints

#### POST /queue/join

Join the queue for a resource (event, product, feature, etc.).

**Request:**

```json
{
  "event_id": "evt_123",
  "device_id": "dev_abc123",
  "user_id": "usr_xyz789", // optional
  "priority_bucket": "general", // optional: "presale", "partner", "general"
  "metadata": {} // optional: custom key-value pairs for analytics
}
```

**Response:**

```json
{
  "queue_id": "q_abc123",
  "position": 1523,
  "estimated_wait_seconds": 180,
  "status": "waiting"
}
```

**Status Codes:**

- `200 OK`: Successfully joined queue
- `400 Bad Request`: Invalid event_id or missing device_id
- `409 Conflict`: Already in queue (returns current position)
- `503 Service Unavailable`: Queue disabled or Redis unavailable

**Idempotency:**

- Same `device_id` + `event_id` returns existing position
- `queue_id` is stable across retries
- Duplicate joins within 5 seconds are treated as single join

**Rate Limiting:**

- Per device_id: 5 join attempts per minute
- Per IP: 20 join attempts per minute
- Returns `429 Too Many Requests` when exceeded

#### GET /queue/status

Get current queue position and status.

**Request:**

```plain
GET /queue/status?queue_id=q_abc123
```

**Response:**

```json
{
  "queue_id": "q_abc123",
  "position": 892,
  "estimated_wait_seconds": 95,
  "status": "waiting",
  "enqueued_at": "2024-01-15T10:23:45Z",
  "last_heartbeat": "2024-01-15T10:28:12Z"
}
```

**Status Codes:**

- `200 OK`: Queue position retrieved
- `404 Not Found`: Queue ID not found (expired or invalid)
- `410 Gone`: User was admitted but token expired

#### POST /queue/heartbeat

Keep queue position alive. Prevents timeout-based removal.

**Request:**

```json
{
  "queue_id": "q_abc123"
}
```

**Response:**

```json
{
  "queue_id": "q_abc123",
  "position": 892,
  "status": "waiting",
  "next_heartbeat_seconds": 30
}
```

**Status Codes:**

- `200 OK`: Heartbeat accepted
- `404 Not Found`: Queue ID expired or invalid
- `410 Gone`: Already admitted or expired

**Behavior:**

- Extends TTL on queue entry
- Returns updated position
- If admitted, returns admission token

#### POST /admission/verify

Verify an admission token (used by backend).

**Request:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "event_id": "evt_123"
}
```

**Response:**

```json
{
  "valid": true,
  "event_id": "evt_123",
  "device_id": "dev_abc123",
  "user_id": "usr_xyz789",
  "issued_at": "2024-01-15T10:30:00Z",
  "expires_at": "2024-01-15T10:35:00Z"
}
```

**Status Codes:**

- `200 OK`: Token verified (valid may be false)
- `400 Bad Request`: Malformed token

**Note:** This endpoint can be called by backend, but tokens are designed for offline verification via HMAC signature. See [Backend Integration](#backend-integration) for verification libraries.

#### POST /admin/release

Manually release users from queue (admin only).

**Request:**

```json
{
  "event_id": "evt_123",
  "count": 100, // optional: release N users
  "rate_per_second": 10 // optional: override release rate
}
```

**Response:**

```json
{
  "released": 100,
  "remaining_in_queue": 1423,
  "current_release_rate": 10
}
```

#### POST /admin/pause

Pause or resume queue releases (admin only).

**Request:**

```json
{
  "event_id": "evt_123",
  "paused": true
}
```

**Response:**

```json
{
  "event_id": "evt_123",
  "paused": true,
  "queue_length": 1523
}
```

#### POST /admin/config

Update resource configuration (admin only).

**Request:**

```json
{
  "event_id": "evt_123",
  "enabled": true,
  "release_rate_per_second": 5,
  "max_queue_size": 10000,
  "admission_token_ttl_seconds": 300,
  "heartbeat_timeout_seconds": 60,
  "max_capacity": 5000, // optional: max concurrent admissions
  "bypass_queue": false, // optional: emergency bypass
  "webhook_url": "https://backend.example.com/webhooks/admission" // optional
}
```

**Response:**

```json
{
  "event_id": "evt_123",
  "config": {
    "enabled": true,
    "release_rate_per_second": 5,
    "max_queue_size": 10000,
    "admission_token_ttl_seconds": 300,
    "heartbeat_timeout_seconds": 60
  }
}
```

#### GET /admin/metrics

Get real-time queue metrics (admin only).

**Request:**

```plain
GET /admin/metrics?event_id=evt_123
```

**Response:**

```json
{
  "event_id": "evt_123",
  "queue_length": 1523,
  "average_wait_seconds": 180,
  "release_rate_per_second": 5,
  "admissions_last_hour": 1800,
  "abandoned_sessions": 45,
  "paused": false
}
```

## Redis Data Model

### Queue Structures

**FIFO Queue (per event)**:

```plain
Key: queue:event:{event_id}
Type: LIST
Value: queue_id (FIFO order)
TTL: None (managed by release process)
```

**Priority Queue (per event, per bucket)**:

```plain
Key: queue:event:{event_id}:priority:{bucket}
Type: ZSET (sorted set)
Score: enqueue_timestamp (microseconds)
Member: queue_id
TTL: None
```

**Queue Entry Metadata**:

```plain
Key: queue:entry:{queue_id}
Type: HASH
Fields:
  - event_id: string
  - device_id: string
  - user_id: string (optional)
  - position: integer
  - enqueued_at: timestamp (ISO 8601)
  - last_heartbeat: timestamp (ISO 8601)
  - priority_bucket: string
TTL: 3600 seconds (1 hour, extended on heartbeat)
```

**Admission Tokens**:

```plain
Key: admission:token:{token_hash}
Type: HASH
Fields:
  - event_id: string
  - device_id: string
  - user_id: string (optional)
  - issued_at: timestamp
  - expires_at: timestamp
  - queue_id: string (for tracking)
TTL: admission_token_ttl_seconds (default: 300)
```

**Release State (per event)**:

```plain
Key: release:event:{event_id}
Type: HASH
Fields:
  - paused: boolean
  - rate_per_second: integer
  - last_release_at: timestamp
  - total_released: integer
TTL: None
```

**Event Configuration**:

```plain
Key: config:event:{event_id}
Type: HASH
Fields:
  - enabled: boolean
  - release_rate_per_second: integer
  - max_queue_size: integer
  - admission_token_ttl_seconds: integer
  - heartbeat_timeout_seconds: integer
TTL: None
```

### Operations

**Join Queue:**

1. Check `config:event:{event_id}` for enabled/max_size
2. Generate `queue_id` (UUID)
3. Add to `queue:event:{event_id}` (LIST) or `queue:event:{event_id}:priority:{bucket}` (ZSET)
4. Create `queue:entry:{queue_id}` (HASH) with metadata
5. Calculate position from LIST length or ZSET rank

**Release Users:**

1. Read `release:event:{event_id}` for rate/paused state
2. Check capacity limits (if configured)
3. Pop from queue (LPOP from LIST or ZRANGE from ZSET)
4. Generate admission token
5. Store token in `admission:token:{token_hash}`
6. Update `release:event:{event_id}` counters
7. Delete `queue:entry:{queue_id}`
8. Trigger webhook (if configured)

**Heartbeat:**

1. Check `queue:entry:{queue_id}` exists
2. Update `last_heartbeat` field
3. Extend TTL to `heartbeat_timeout_seconds * 2`

### TTL Strategy

- **Queue entries**: 1 hour default, extended on heartbeat
- **Admission tokens**: 5 minutes (aggressive expiry for resource safety)
- **Release state**: No TTL (persistent until event ends)
- **Event config**: No TTL (persistent configuration)

## Flutter Dev Kit

### Package Structure

```plain
app/
├── lib/
│   ├── gatekeep.dart
│   ├── models/
│   │   ├── queue_status.dart
│   │   ├── admission_token.dart
│   │   └── queue_error.dart
│   ├── client/
│   │   └── queue_client.dart
│   └── ui/
│       └── waiting_room_screen.dart
└── pubspec.yaml
```

### API Design

```dart
class QueueClient {
  static Future<void> initialize({
    required String baseUrl,
    required String deviceId,
    String? userId,
    Map<String, String>? headers,
  });

  Future<QueueStatus> joinEvent({
    required String eventId,
    String? priorityBucket,
  });

  Stream<QueueStatus> listenStatus({
    required String queueId,
    Duration pollInterval = const Duration(seconds: 5),
  });

  Future<AdmissionToken?> onAdmitted({
    required String queueId,
  });

  Future<void> sendHeartbeat({
    required String queueId,
  });

  Future<AdmissionToken?> restoreToken({
    required String eventId,
  });
}

class QueueStatus {
  final String queueId;
  final int position;
  final int estimatedWaitSeconds;
  final QueueState state;
  final DateTime? enqueuedAt;
  final AdmissionToken? admissionToken; // null until admitted
}

enum QueueState {
  joining,
  waiting,
  admitted,
  expired,
  error,
}

class AdmissionToken {
  final String token;
  final String eventId;
  final DateTime expiresAt;

  // Persist to secure storage
  Future<void> save();

  // Verify token is still valid
  bool isValid();
}
```

### Usage Example

```dart
import 'package:gatekeep_flutter/gatekeep_flutter.dart';

// Initialize
await QueueClient.initialize(
  baseUrl: 'https://gatekeep.example.com/v1',
  deviceId: await getDeviceId(),
  userId: currentUser?.id,
);

// Join queue
final status = await QueueClient.instance.joinEvent(
  eventId: 'evt_123',
  priorityBucket: 'general',
);

// Listen for updates
QueueClient.instance.listenStatus(
  queueId: status.queueId,
).listen((status) {
  if (status.state == QueueState.admitted) {
    // Navigate to protected resource
    navigateToProtectedResource(status.admissionToken!);
  } else if (status.state == QueueState.waiting) {
    // Update UI with position
    updateWaitingRoom(status.position, status.estimatedWaitSeconds);
  }
});

// Send periodic heartbeat
Timer.periodic(Duration(seconds: 30), (timer) {
  QueueClient.instance.sendHeartbeat(queueId: status.queueId);
});
```

### UI States

**Joining**:

- Show loading indicator
- Disable retry for idempotency

**Waiting**:

- Display position: "You are #1,523 in line"
- Show ETA: "Estimated wait: 3 minutes"
- Progress indicator (approximate)
- Heartbeat status indicator

**Admitted**:

- Show success message
- Auto-navigate to protected resource
- Display token expiry countdown
- Store token securely for app resume scenarios

**Expired**:

- Show error message
- Offer retry button
- Explain token expiry

**Error**:

- Show error message
- Retry with exponential backoff
- Network status indicator

### Resilience Features

1. **Token Persistence**: Save admission tokens to secure storage (flutter_secure_storage)
2. **App Resume**: Restore queue position or token on app restart
3. **Network Loss**: Queue status cached; retry on reconnect
4. **Clock Skew**: Token validation uses server time from API responses
5. **Idempotent Joins**: Same device_id + event_id returns existing position

## Backend Integration

### Token Verification

Tokens use HMAC-SHA256 signatures and can be verified offline without network calls. The backend must share the `GATEKEEP_TOKEN_SECRET` with the Go service.

**Go Verification Example:**

```go
func VerifyAdmissionToken(token, eventID, secretKey string) (map[string]interface{}, error) {
    parts := strings.Split(token, ".")
    if len(parts) != 3 {
        return nil, fmt.Errorf("invalid token format")
    }

    header, payload, signature := parts[0], parts[1], parts[2]

    mac := hmac.New(sha256.New, []byte(secretKey))
    mac.Write([]byte(header + "." + payload))
    expectedSig := base64.URLEncoding.EncodeToString(mac.Sum(nil))

    if !hmac.Equal([]byte(signature), []byte(expectedSig)) {
        return nil, fmt.Errorf("invalid signature")
    }

    payloadBytes, err := base64.URLEncoding.DecodeString(payload)
    if err != nil {
        return nil, err
    }

    var data map[string]interface{}
    if err := json.Unmarshal(payloadBytes, &data); err != nil {
        return nil, err
    }

    if data["event_id"].(string) != eventID {
        return nil, fmt.Errorf("event_id mismatch")
    }

    expiresAt := int64(data["expires_at"].(float64))
    if time.Now().Unix() > expiresAt {
        return nil, fmt.Errorf("token expired")
    }

    return data, nil
}
```

### Webhook Integration

If `webhook_url` is configured, the service will POST admission events:

```json
{
  "event": "admission_granted",
  "event_id": "evt_123",
  "device_id": "dev_abc123",
  "user_id": "usr_xyz789",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "issued_at": "2024-01-15T10:30:00Z",
  "expires_at": "2024-01-15T10:35:00Z",
  "queue_id": "q_abc123"
}
```

Webhook retries: 3 attempts with exponential backoff (1s, 2s, 4s). Failures are logged but do not block admission.

## Security & Abuse Prevention

### Token Security

**HMAC Signature**:

```plain
token = base64(header.payload.signature)
signature = HMAC-SHA256(secret_key, header.payload)
```

**Token Payload**:

```json
{
  "event_id": "evt_123",
  "device_id": "dev_abc123",
  "user_id": "usr_xyz789",
  "issued_at": 1705312200,
  "expires_at": 1705312500,
  "nonce": "random_uuid"
}
```

### Abuse Prevention

1. **Rate Limiting**

   - Per device_id: 5 join attempts per minute
   - Per IP: 100 requests per minute (configurable per endpoint)
   - Per user_id: 10 join attempts per minute (if provided)
   - Redis-based sliding window with atomic operations
   - Returns `429 Too Many Requests` with `Retry-After` header

2. **Device Binding**

   - Tokens bound to device_id (immutable)
   - Token reuse detection (nonce tracking in Redis)
   - Multiple device detection (admin alert when same user_id from >3 devices)
   - Device fingerprinting via User-Agent + IP correlation

3. **Bot Resistance**

   - CAPTCHA on suspicious patterns (future: integration point documented)
   - Heartbeat requirement (abandoned sessions removed after timeout)
   - Unusual position jump detection (alerts on >50% position improvement)
   - Request pattern analysis (rapid polling detection)

4. **Token Replay Protection**

   - Single-use tokens (optional, via Redis check with `admission:used:{token_hash}`)
   - Short TTL (5 minutes default, configurable)
   - Nonce tracking per device_id (prevents token regeneration attacks)
   - Token rotation on each admission grant

5. **Queue Manipulation Prevention**
   - Position calculated server-side only
   - No client-controlled queue parameters
   - Admin API requires separate authentication
   - Audit log for all admin actions

## Operational Guide

### Metrics

**Queue Metrics**:

- `queue_length{event_id}`: Current queue size
- `queue_wait_time_seconds{event_id}`: Average wait time
- `queue_join_rate{event_id}`: Joins per second
- `queue_abandon_rate{event_id}`: Abandoned sessions per hour

**Release Metrics**:

- `release_rate{event_id}`: Users released per second
- `admissions_total{event_id}`: Total admissions
- `admission_token_expiry_rate{event_id}`: Expired tokens per hour

**System Metrics**:

- `redis_operation_duration_seconds`: Redis latency
- `api_request_duration_seconds{endpoint}`: API latency
- `api_requests_total{endpoint,status}`: Request counts
- `rate_limit_hits_total{type}`: Rate limit violations
- `webhook_delivery_total{status}`: Webhook delivery success/failure
- `concurrent_admissions{event_id}`: Active admission tokens

### Logging

**Structured Logs (JSON)**:

```json
{
  "timestamp": "2024-01-15T10:23:45Z",
  "level": "info",
  "service": "gatekeep",
  "event": "queue_join",
  "queue_id": "q_abc123",
  "event_id": "evt_123",
  "device_id": "dev_abc123",
  "position": 1523,
  "duration_ms": 45
}
```

**Log Levels**:

- `ERROR`: Redis failures, token generation failures, critical errors
- `WARN`: Rate limit hits, suspicious patterns, config issues
- `INFO`: Queue joins, releases, token issuances
- `DEBUG`: Heartbeats, position updates, internal state

### Admin Controls

**Release Rate Tuning**:

- Start conservative (2-5 users/second)
- Monitor checkout completion rate
- Increase gradually if backend handles load
- Use boost for catch-up after pause

**Pause Scenarios**:

- Backend degradation detected
- Inventory issue discovered
- Security incident
- Manual intervention needed

**Bypass Mechanism**:

- Feature flag: `bypass_queue:true` in event config
- All joins return immediate admission token
- Useful for testing or emergency override

### Shadow Mode

Run queue logic without enforcing admission:

1. Queue users normally
2. Issue tokens normally
3. Backend accepts all requests (ignores tokens)
4. Compare queue behavior vs. actual traffic
5. Validate ETA accuracy and release rate tuning

### Multi-Tenant Support

Gatekeep supports multiple tenants via event_id namespacing. Each tenant's events are isolated:

- Queue data: `queue:event:{tenant_id}:{event_id}`
- Config: `config:event:{tenant_id}:{event_id}`
- Metrics: Tagged with `tenant_id` label

Admin API supports tenant-scoped operations via `X-Tenant-ID` header (optional, defaults to default tenant).

## Failure Modes & Mitigations

### Redis Failure

**Symptoms:**

- Queue joins fail
- Position updates fail
- Token generation fails

**Mitigation:**

- Return `503 Service Unavailable` immediately
- Do not queue users if Redis is down (prevents data loss)
- Circuit breaker: fail fast after 3 consecutive errors
- Fallback: Bypass queue (admin config) if Redis unavailable > 5 minutes

### Clock Skew

**Symptoms:**

- Tokens appear expired prematurely
- Tokens appear valid after expiry

**Mitigation:**

- Use Redis time for token issuance (single source of truth)
- Include `issued_at` in token payload
- Backend validates against server time, not client time
- Allow 30-second clock skew tolerance

### Token Replay

**Symptoms:**

- Same token used multiple times
- Inventory oversold

**Mitigation:**

- Short TTL (5 minutes)
- Optional: Single-use tracking in Redis
- Backend checks token expiry before processing
- Inventory lock on token presentation

### Queue Position Jump

**Symptoms:**

- User sees position decrease unexpectedly
- Fairness violation

**Mitigation:**

- Position calculated from Redis LIST/ZSET (source of truth)
- Heartbeat extends TTL (prevents premature removal)
- Abandoned sessions removed only after timeout
- Log position changes for audit

### Backend Overload

**Symptoms:**

- Backend slow to respond
- Checkout failures increase

**Mitigation:**

- Pause releases immediately (admin API)
- Reduce release rate
- Monitor checkout completion rate
- Resume when backend recovers

### Network Partition

**Symptoms:**

- Flutter app cannot reach Go service
- Queue status unavailable

**Mitigation:**

- Cache last known position locally
- Retry with exponential backoff
- Show "Reconnecting..." UI
- Restore token from secure storage if admitted

### Resource Capacity Mismatch

**Symptoms:**

- More tokens issued than resources available
- Overselling or resource exhaustion

**Mitigation:**

- Token TTL shorter than processing window
- Resource lock on token presentation (Backend responsibility)
- Release rate respects available capacity (admin config: `max_capacity`)
- Monitor admission:capacity ratio
- Backend should reject requests when at capacity, even with valid token

### Concurrent Release Race Conditions

**Symptoms:**

- Multiple service instances releasing same user
- Duplicate tokens issued
- Position calculation errors

**Mitigation:**

- Redis atomic operations (LPOP, ZPOPMIN) prevent duplicate releases
- Token generation uses Redis INCR for nonce uniqueness
- Position calculated from Redis LIST/ZSET length (single source of truth)
- Distributed locks for release controller (optional, for strict ordering)

### Token Expiry During Processing

**Symptoms:**

- User admitted but token expires before backend processing completes
- User loses access mid-operation

**Mitigation:**

- Token TTL should exceed expected processing time (configurable)
- Backend should complete operation within token lifetime
- Consider token refresh mechanism for long-running operations (future)
- Monitor token expiry rate vs. processing completion rate

## Deployment

### Prerequisites

- Go 1.21+
- Redis 7.0+ (cluster mode supported)
- Flutter 3.2+ (for SDK)

### Environment Variables

```bash
# Service
GATEKEEP_PORT=8080
GATEKEEP_REDIS_ADDR=redis://localhost:6379
GATEKEEP_REDIS_PASSWORD=secret
GATEKEEP_TOKEN_SECRET=hmac-secret-key-32-bytes-min

# Admin
GATEKEEP_ADMIN_API_KEY=admin-secret-key

# Observability
GATEKEEP_LOG_LEVEL=info
GATEKEEP_METRICS_PORT=9090
```

### Health Checks

```plain
GET /health
Response: {"status": "healthy", "redis": "connected"}
```

### Scaling

- **Horizontal**: Deploy multiple Go service instances behind load balancer
- **Stateless**: No session affinity required
- **Redis**: Use Redis Cluster for high availability
- **Monitoring**: Prometheus metrics endpoint at `/metrics`

### Rollout Strategy

1. **Shadow Mode**: Enable queue logic, backend ignores tokens
2. **Small Event**: Test with low-traffic resource
3. **Gradual Rollout**: Enable for 10% → 50% → 100% of resources
4. **Feature Flags**: Event-level enable/disable via admin API
5. **Canary Deployment**: Route 1% of traffic to new service version

### Capacity Planning

**Redis Capacity:**

- Queue entry: ~500 bytes per user
- 1M users in queue ≈ 500MB Redis memory
- Plan for 2x peak queue size for buffer

**Go Service Capacity:**

- Single instance handles ~10k requests/second (queue operations)
- Token generation: ~50k/second per instance
- Release processing: Limited by Redis throughput (~100k ops/sec per Redis node)

**Scaling Guidelines:**

- Add Go instances for request throughput (stateless, no affinity needed)
- Add Redis nodes for queue size (use Redis Cluster for >100M queue entries)
- Monitor Redis memory usage and queue TTL cleanup

### Testing Strategy

**Unit Tests:**

- Token generation and verification
- Queue position calculation
- Rate limiting logic
- Idempotency guarantees

**Integration Tests:**

- Redis failure scenarios
- Concurrent release operations
- Token expiry handling
- Webhook delivery

**Load Tests:**

- 100k concurrent queue joins
- 10k releases/second
- Redis failover scenarios
- Network partition recovery

**Chaos Engineering:**

- Random Redis node failures
- Network latency injection
- Clock skew simulation
- Service instance crashes

### Disaster Recovery

**Backup Strategy:**

- Redis persistence: AOF + RDB snapshots
- Event configs: Version controlled in Git (infrastructure as code)
- Token secrets: Rotated quarterly, stored in secret manager

**Recovery Procedures:**

1. **Redis Complete Failure:**

   - Restore from latest RDB snapshot
   - Queue positions may be lost (users rejoin)
   - Tokens invalidated (users re-queue)
   - Enable bypass mode if recovery > 5 minutes

2. **Service Outage:**

   - Deploy new instances (stateless, fast recovery)
   - Existing tokens remain valid (offline verification)
   - Queue state preserved in Redis

3. **Data Corruption:**
   - Restore from backup
   - Validate queue integrity (admin tool)
   - Reconcile admission tokens with backend state

### Performance Benchmarks

**Expected Performance (single Go instance, single Redis node):**

- Queue join: <50ms p99
- Status check: <20ms p99
- Token generation: <5ms p99
- Release operation: <100ms p99 (includes token generation)

**Redis Operations:**

- LPOP: <1ms
- ZRANGE: <5ms (for 10k queue)
- HGETALL: <2ms
- HSET: <1ms

**Scalability Limits:**

- Max queue size: 10M users (tested), 100M users (theoretical with Redis Cluster)
- Max release rate: 1k/second per Redis node
- Max concurrent admissions: Limited by token TTL and backend capacity

---

## License

Proprietary - Internal Use Only

## Client Support

### Flutter (Mobile)

Full SDK support as documented in [Flutter Dev Kit](#flutter-dev-kit).

### Web Clients

Web clients can use the same REST API. Recommended patterns:

- Use WebSockets or Server-Sent Events for real-time position updates (future)
- Implement exponential backoff for polling (5s → 10s → 30s)
- Store tokens in `localStorage` (less secure than mobile secure storage)
- Consider device fingerprinting for device_id generation

### Native Mobile (iOS/Android)

Native clients can use REST API directly. Follow same patterns as Flutter SDK:

- Idempotent joins
- Periodic heartbeats
- Token persistence
- Network retry logic

## Analytics & Audit Trail

All operations are logged with structured JSON:

- Queue joins: `queue_id`, `event_id`, `device_id`, `user_id`, `position`
- Token issuances: `token_hash`, `event_id`, `device_id`, `expires_at`
- Admin actions: `admin_id`, `action`, `event_id`, `parameters`
- Rate limit hits: `type`, `identifier`, `count`

Logs are suitable for:

- Security auditing
- Performance analysis
- Abuse detection
- Business intelligence

## Support

For operational issues, contact the Platform Engineering team.
For security concerns, follow the security incident response process.
For integration questions, see [Backend Integration](#backend-integration).
