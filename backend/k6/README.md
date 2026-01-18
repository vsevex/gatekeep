# k6 Load Testing

This directory contains k6 load testing scripts for the Gatekeep backend service.

## Prerequisites

Install k6 from [https://k6.io/docs/getting-started/installation/](https://k6.io/docs/getting-started/installation/)

### Quick Install

- **macOS**: `brew install k6`
- **Windows**: `choco install k6`
- **Linux**: See [k6 installation guide](https://k6.io/docs/getting-started/installation/)

## Test Scripts

### load-test.js

Comprehensive load test that simulates realistic user behavior:

- Gradual ramp-up to 4,000 concurrent users
- Queue join operations
- Status polling (3-7 checks per user)
- Heartbeat operations
- Full test duration: ~10 minutes

**Usage:**

```bash
# Run with default settings (localhost:8080)
k6 run k6/load-test.js

# Run with custom base URL
k6 run -e BASE_URL=http://staging.example.com:8080 k6/load-test.js

# Run with custom event ID
k6 run -e EVENT_ID=my-event-123 k6/load-test.js

# Run with custom admin API key
k6 run -e ADMIN_API_KEY=your-admin-key k6/load-test.js
```

**Using Make:**

```bash
make k6-load
```

### stress-test.js

Stress test with rapid ramp-up to 4,000 users:

- Fast ramp-up (10 seconds to 4k users)
- Focus on join operations
- Tests system under sudden load
- Full test duration: ~3 minutes

**Usage:**

```bash
k6 run k6/stress-test.js
```

**Using Make:**

```bash
make k6-stress
```

## Test Scenarios

### Load Test Flow

1. **Setup**: Configures event with unlimited queue size and release rate
2. **Join Queue**: Each virtual user joins the queue with unique user/device IDs
3. **Status Polling**: Users poll their queue status 3-7 times (simulating waiting)
4. **Heartbeat**: Users send heartbeat to keep their position active
5. **Admission**: Users check for admission tokens when released
6. **Teardown**: Disables event configuration

### Metrics Tracked

- `http_req_duration`: Request duration percentiles
- `http_req_failed`: Request failure rate
- `queue_join_success`: Queue join success rate
- `queue_status_success`: Status check success rate
- `queue_heartbeat_success`: Heartbeat success rate
- `queue_join_duration`: Join operation duration
- `queue_status_duration`: Status check duration
- `queue_heartbeat_duration`: Heartbeat duration

## Thresholds

### Load Test Thresholds

- 95% of requests under 500ms
- 99% of requests under 1s
- Less than 1% error rate
- 95% join success rate
- 98% status check success rate

### Stress Test Thresholds

- 95% of requests under 1s
- 99% of requests under 2s
- Less than 5% error rate
- 90% join success rate

## Environment Variables

| Variable | Default | Description |

|----------|---------|-------------|
| `BASE_URL` | `http://localhost:8080` | Base URL of the Gatekeep service |
| `EVENT_ID` | `test-event-001` | Event ID to use for testing |
| `ADMIN_API_KEY` | `staging-admin-api-key-12345` | Admin API key for configuration |

## Running Tests

### Local Testing

#### Before Running Tests

1. **Start Redis**: Ensure Redis is running and accessible

   ```bash
   redis-server
   ```

2. **Start Gatekeep Server**: Run the server in staging mode

   ```bash
   cd backend
   make run-staging
   ```

3. **Verify Health**: Check that the service is healthy

   ```bash
   curl http://localhost:8080/health
   ```

#### Run Load Test (Local)

```bash
# Using k6 directly
k6 run k6/load-test.js

# Using Make (from backend directory)
make k6-load

# With custom URL
k6 run -e BASE_URL=http://localhost:8080 k6/load-test.js
```

#### Run Stress Test (Local)

```bash
# Using k6 directly
k6 run k6/stress-test.js

# Using Make
make k6-stress
```

### Remote Staging Server Testing

#### Run Load Test Against Remote Server

```bash
# Using the script (recommended)
cd backend/k6
chmod +x run-remote-test.sh
export BASE_URL=https://your-staging-worker.workers.dev
./run-remote-test.sh

# Using Make
cd backend
make k6-load-remote BASE_URL=https://your-staging-worker.workers.dev

# Using k6 directly
k6 run \
  -e BASE_URL=https://your-staging-worker.workers.dev \
  -e EVENT_ID=staging-test-001 \
  -e ADMIN_API_KEY=your-admin-key \
  k6/load-test-remote.js
```

#### Customize Remote Test

```bash
# With custom event ID and admin key
export BASE_URL=https://staging.example.com
export EVENT_ID=my-custom-event
export ADMIN_API_KEY=my-admin-key
./run-remote-test.sh
```

## Output

k6 will output real-time metrics during the test and a summary at the end:

```plain
     ✓ join status is 200
     ✓ join response has queue_id
     ✓ join response has position
     ✓ status check is 200
     ✓ status response has position

     checks.........................: 95.00% ✓ 38000  ✗ 2000
     data_received..................: 12 MB  200 kB/s
     data_sent......................: 8.5 MB 142 kB/s
     http_req_duration..............: avg=245ms min=12ms med=180ms max=2.1s p(90)=450ms p(95)=520ms
     http_req_failed................: 0.50%  ✓ 2000  ✗ 380000
     http_reqs......................: 400000 6666.666667/s
     iteration_duration.............: avg=3.2s min=0.5s med=2.8s max=15s p(90)=5.1s p(95)=6.2s
     iterations.....................: 40000  666.666667/s
     queue_join_duration............: avg=180ms min=10ms med=150ms max=1.8s p(90)=350ms p(95)=420ms
     queue_join_success.............: 95.00% ✓ 38000  ✗ 2000
     queue_status_duration..........: avg=45ms min=5ms med=35ms max=800ms p(90)=80ms p(95)=120ms
     queue_status_success...........: 98.50% ✓ 197000  ✗ 3000
     vus............................: 4000   min=0      max=4000
     vus_max........................: 4000   min=4000   max=4000
```

## Interpreting Results

- **http_req_duration**: Should be under thresholds (p95 < 500ms for load test)
- **http_req_failed**: Should be < 1% for load test, < 5% for stress test
- **queue_join_success**: Should be > 95% for load test
- **queue_status_success**: Should be > 98% for load test

## Troubleshooting

### Connection Refused

- Ensure the Gatekeep server is running
- Check that the BASE_URL is correct
- Verify the port is accessible

### Redis Connection Errors

- Ensure Redis is running
- Check REDIS_ADDR in server configuration
- Verify Redis is accessible from the server

### High Error Rates

- Check server logs for errors
- Verify Redis has sufficient memory
- Check system resources (CPU, memory)
- Review rate limiting settings

### Slow Response Times

- Check Redis performance
- Monitor server CPU and memory
- Review network latency
- Check for bottlenecks in queue operations

## Advanced Usage

### Custom Test Scenarios

You can modify the test scripts to:

- Change ramp-up patterns
- Adjust user behavior
- Add custom metrics
- Test specific endpoints

### Distributed Testing

For larger scale tests, use k6 Cloud:

```bash
k6 cloud k6/load-test.js
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
- name: Run k6 load test
  run: |
    cd backend
    make k6-load
```

## Performance Targets

Based on the system design:

- **Single instance**: ~10k requests/second (queue operations)
- **Token generation**: ~50k/second per instance
- **Release processing**: Limited by Redis throughput (~100k ops/sec per Redis node)

The 4k user load test validates:

- System can handle 4,000 concurrent users
- Response times remain acceptable
- Error rates stay low
- Redis operations scale properly
