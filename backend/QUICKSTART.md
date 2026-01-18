# Quick Start: Staging & Load Testing

Quick guide to get the Gatekeep backend running in staging and run k6 load tests with 4k users.

## 1. Prerequisites Check

```bash
# Check Redis
redis-cli ping
# Should return: PONG

# Check Go
go version

# Check k6 (install if needed)
k6 version
# If not installed: brew install k6 (macOS) or choco install k6 (Windows)
```

## 2. Setup Staging Environment

```bash
cd backend

# Auto-create .env.staging (if it doesn't exist)
make staging
# This will create the file and try to start the server
# Press Ctrl+C to stop, then continue
```

Or manually create `backend/.env.staging`:

```bash
PORT=8080
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=
TOKEN_SECRET=staging-secret-key-must-be-at-least-32-characters-long-for-security
ADMIN_API_KEY=staging-admin-api-key-12345
LOG_LEVEL=info
METRICS_PORT=9090
```

## 3. Start Server in Staging Mode

```bash
# In one terminal
cd backend
make run-staging
```

Wait for: `HTTP server listening on port 8080`

## 4. Verify Server is Running

```bash
# In another terminal
curl http://localhost:8080/health
# Should return: OK
```

## 5. Run k6 Load Test (4k Users)

```bash
# In another terminal
cd backend
make k6-load
```

This will:

- Ramp up to 4,000 concurrent users over ~4 minutes
- Run for 5 minutes at 4k users
- Test queue joins, status checks, and heartbeats
- Output real-time metrics and final summary

## 6. Alternative: Stress Test

For a faster stress test with rapid ramp-up:

```bash
cd backend
make k6-stress
```

## Expected Results

### Load Test Metrics

- **Duration**: ~10 minutes total
- **Peak Users**: 4,000 concurrent
- **Success Rate**: >95% for joins, >98% for status checks
- **Response Time**: p95 < 500ms, p99 < 1s
- **Error Rate**: <1%

### What to Monitor

1. **Server Logs**: Watch for errors or warnings
2. **Redis Memory**: Monitor Redis memory usage
3. **Response Times**: Should stay under thresholds
4. **Error Rates**: Should remain low

## Troubleshooting

### Server won't start

- Check Redis: `redis-cli ping`
- Check port 8080: `lsof -i :8080` (macOS/Linux) or `netstat -ano | findstr :8080` (Windows)

### k6 not found

- Install: `brew install k6` (macOS) or `choco install k6` (Windows)
- Or download from: [https://k6.io/docs/getting-started/installation/]

### High error rates

- Check server logs
- Verify Redis is running and has memory
- Check system resources (CPU, memory)

## Next Steps

- Review detailed documentation: [STAGING.md](STAGING.md)
- Learn about k6 tests: [k6/README.md](k6/README.md)
- Check API documentation in main [README.md](../README.md)
