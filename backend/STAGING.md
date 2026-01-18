# Staging Environment Setup

This guide explains how to set up and run the Gatekeep backend in staging mode for load testing.

## Prerequisites

1. **Redis**: Redis server must be running

   ```bash
   # Check if Redis is running
   redis-cli ping
   # Should return: PONG
   ```

2. **Go**: Go 1.21+ installed

   ```bash
   go version
   ```

3. **k6**: For load testing (optional, but required for load tests)

   ```bash
   k6 version
   ```

## Staging Configuration

### Environment Variables

Create a `.env.staging` file in the `backend` directory with the following:

```bash
PORT=8080
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=
TOKEN_SECRET=staging-secret-key-must-be-at-least-32-characters-long-for-security
ADMIN_API_KEY=staging-admin-api-key-12345
LOG_LEVEL=info
METRICS_PORT=9090
```

**Important Notes:**

- `TOKEN_SECRET` must be at least 32 characters long
- `REDIS_ADDR` should point to your Redis instance
- `ADMIN_API_KEY` is used for admin endpoints (used by k6 tests)

### Auto-Generate Configuration

The Makefile can auto-generate the `.env.staging` file:

```bash
cd backend
make staging
# This will create .env.staging if it doesn't exist
```

## Running in Staging Mode

### Method 1: Using Make

```bash
cd backend
make run-staging
```

### Method 2: Manual

```bash
cd backend
export $(cat .env.staging | grep -v '^#' | xargs)
go run ./cmd/server
```

### Method 3: Direct Environment Variables

```bash
cd backend
export PORT=8080
export REDIS_ADDR=localhost:6379
export TOKEN_SECRET=staging-secret-key-must-be-at-least-32-characters-long-for-security
export ADMIN_API_KEY=staging-admin-api-key-12345
export LOG_LEVEL=info
export METRICS_PORT=9090
go run ./cmd/server
```

## Verifying Staging Setup

1. **Check Health Endpoint**

   ```bash
   curl http://localhost:8080/health
   # Expected: OK
   ```

2. **Check Metrics Endpoint**

   ```bash
   curl http://localhost:8080/metrics
   # Should return Prometheus metrics
   ```

3. **Check Admin Endpoint** (requires API key)

   ```bash
   curl -H "X-Admin-API-Key: staging-admin-api-key-12345" \
        http://localhost:8080/admin/metrics
   # Should return JSON metrics
   ```

## Running Load Tests

Once the server is running in staging mode, you can run k6 load tests:

```bash
# From backend directory
make k6-load        # Comprehensive load test (4k users, ~10 min)
make k6-stress      # Stress test (4k users, rapid ramp-up, ~3 min)
```

See [k6/README.md](k6/README.md) for detailed information about load testing.

## Staging vs Production

### Differences

| Aspect | Staging | Production |

|--------|---------|------------|
| Log Level | `info` | `warn` or `error` |
| Token Secret | Simple/known | Strong, secret |
| Admin API Key | Known/test | Secure, rotated |
| Redis | Local/dev instance | Production cluster |
| Metrics | Local access | Protected access |

### Security Notes

⚠️ **Warning**: The staging configuration uses simple secrets. Never use staging secrets in production!

- Staging secrets are for testing only
- Production should use strong, randomly generated secrets
- Admin API keys should be rotated regularly
- Redis passwords should be used in production

## Troubleshooting

### Server Won't Start

1. **Check Redis Connection**

   ```bash
   redis-cli -h localhost -p 6379 ping
   ```

2. **Check Port Availability**

   ```bash
   # Check if port 8080 is in use
   lsof -i :8080  # macOS/Linux
   netstat -ano | findstr :8080  # Windows
   ```

3. **Check Environment Variables**

   ```bash
   # Verify all required variables are set
   env | grep -E 'PORT|REDIS|TOKEN|ADMIN'
   ```

### Redis Connection Errors

- Ensure Redis is running: `redis-cli ping`
- Check `REDIS_ADDR` matches your Redis instance
- If using password, set `REDIS_PASSWORD`
- Check firewall/network rules

### Configuration Validation Errors

- `TOKEN_SECRET` must be at least 32 characters
- `PORT` and `METRICS_PORT` must be different
- Ports must be between 1 and 65535
- All required variables must be set

## Next Steps

1. ✅ Set up staging environment
2. ✅ Start server in staging mode
3. ✅ Verify health endpoints
4. ✅ Run load tests with k6
5. ✅ Monitor metrics and performance
6. ✅ Review test results

For load testing details, see [k6/README.md](k6/README.md).
