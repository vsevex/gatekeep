# Gatekeep Implementation Plan

Step-by-step implementation guide with testing strategy for building the admission control system.

## Implementation Phases

1. [Phase 1: Foundation](#phase-1-foundation)
2. [Phase 2: Core Queue Logic](#phase-2-core-queue-logic)
3. [Phase 3: Token System](#phase-3-token-system)
4. [Phase 4: Release Controller](#phase-4-release-controller)
5. [Phase 5: Admin API](#phase-5-admin-api)
6. [Phase 6: Flutter SDK](#phase-6-flutter-sdk)
7. [Phase 7: Production Hardening](#phase-7-production-hardening)
8. [Phase 8: Cloudflare Integration](#phase-8-cloudflare-integration)

---

## Phase 1: Foundation

### Step 1.1: Project Setup

**Tasks:**

- [x] Initialize Go module: `go mod init gatekeep`
- [x] Set up project structure:

  ```plain
  backend/
  ├── cmd/
  │   └── server/
  │       └── main.go
  ├── internal/
  │   ├── config/
  │   ├── redis/
  │   ├── queue/
  │   ├── token/
  │   ├── api/
  │   └── metrics/
  ├── pkg/
  │   └── errors/
  └── go.mod
  ```

- [x] Add dependencies: `go get github.com/redis/go-redis/v9`, `go get github.com/gorilla/mux`
- [x] Create `.env.example` with required environment variables
- [x] Set up Makefile with common commands

**Tests:**

- [x] Test project structure compiles
- [x] Test environment variable loading
- [x] Test Redis connection initialization

**Acceptance Criteria:**

- Project compiles without errors
- Environment variables load correctly
- Redis connection can be established

---

### Step 1.2: Configuration Management

**Tasks:**

- [x] Create `internal/config/config.go`:
  - Load from environment variables
  - Validate required settings
  - Default values for optional settings
- [x] Configuration struct:

  ```go
  type Config struct {
    Port              int
    RedisAddr         string
    RedisPassword     string
    TokenSecret       string
    AdminAPIKey       string
    LogLevel          string
    MetricsPort       int
  }
  ```

**Tests:**

- [x] Test config loading from environment
- [x] Test validation of required fields
- [x] Test default values
- [x] Test invalid configuration handling

**Acceptance Criteria:**

- Config loads from environment variables
- Missing required fields return clear errors
- Default values work correctly

---

### Step 1.3: Redis Client Setup

**Tasks:**

- [x] Create `internal/redis/client.go`:
  - Connection pool configuration
  - Health check function
  - Context timeout handling
- [x] Implement connection retry logic
- [x] Add connection metrics

**Tests:**

- [x] Test successful connection
- [x] Test connection failure handling
- [x] Test connection retry logic
- [x] Test health check function
- [x] Test context timeout

**Acceptance Criteria:**

- Redis client connects successfully
- Failures are handled gracefully
- Health checks work correctly

---

## Phase 2: Core Queue Logic

### Step 2.1: Queue Data Structures

**Tasks:**

- [x] Create `internal/queue/models.go`:
- [x] Create Redis key generation helpers
- [x] Define queue operation interfaces

**Tests:**

- [x] Test QueueEntry serialization/deserialization
- [x] Test Redis key generation
- [x] Test data structure validation

**Acceptance Criteria:**

- Data structures are well-defined
- Redis keys are generated correctly
- Validation works

---

### Step 2.2: Queue Join Operation

**Tasks:**

- [x] Implement `JoinQueue()` in `internal/queue/join.go`:
  - Check event configuration (enabled, max_size)
  - Generate queue_id (UUID)
  - Check for existing queue entry (idempotency)
  - Add to Redis LIST or ZSET (priority)
  - Create queue entry metadata
  - Calculate position
- [x] Handle priority buckets
- [x] Implement rate limiting check

**Tests:**

- [x] Test successful queue join
- [x] Test idempotent join (same device_id + event_id)
- [x] Test queue disabled scenario
- [x] Test max queue size limit
- [x] Test priority bucket handling
- [x] Test rate limiting
- [x] Test concurrent joins (race conditions)
- [x] Test Redis failure handling

**Acceptance Criteria:**

- Users can join queue successfully
- Idempotency works correctly
- Rate limiting prevents abuse
- Concurrent operations are safe

---

### Step 2.3: Queue Status Retrieval

**Tasks:**

- [x] Implement `GetQueueStatus()` in `internal/queue/status.go`:
  - Retrieve queue entry from Redis
  - Calculate current position from LIST/ZSET
  - Calculate estimated wait time
  - Return status
- [x] Handle expired queue entries
- [x] Handle admitted users

**Tests:**

- [x] Test status retrieval for waiting user
- [x] Test status for non-existent queue_id
- [x] Test position calculation accuracy
- [x] Test ETA calculation
- [x] Test expired entry handling
- [x] Test admitted user status

**Acceptance Criteria:**

- Status retrieval works correctly
- Position is accurate
- ETA is reasonable
- Edge cases handled

---

### Step 2.4: Heartbeat Mechanism

**Tasks:**

- [x] Implement `SendHeartbeat()` in `internal/queue/heartbeat.go`:
  - Verify queue entry exists
  - Update last_heartbeat timestamp
  - Extend TTL
  - Return updated position
  - Return admission token if admitted
- [x] Implement cleanup job for abandoned sessions

**Tests:**

- [x] Test successful heartbeat
- [x] Test heartbeat extends TTL
- [x] Test heartbeat for non-existent queue_id
- [x] Test heartbeat returns token when admitted
- [x] Test abandoned session cleanup
- [x] Test concurrent heartbeats

**Acceptance Criteria:**

- Heartbeats keep queue entries alive
- TTL is extended correctly
- Abandoned sessions are cleaned up
- Admitted users receive tokens

---

## Phase 3: Token System

### Step 3.1: Token Generation

**Tasks:**

- [x] Create `internal/token/generator.go`:
  - HMAC-SHA256 signature
  - Base64 URL encoding
  - Token payload structure
  - Nonce generation
- [x] Implement `GenerateToken()`:
  - Create header (algorithm, type)
  - Create payload (event_id, device_id, user_id, timestamps, nonce)
  - Sign with HMAC
  - Encode to base64url
  - Store in Redis with TTL

**Tests:**

- [x] Test token generation
- [x] Test token format (header.payload.signature)
- [x] Test HMAC signature correctness
- [x] Test token stored in Redis
- [x] Test TTL on token storage
- [x] Test nonce uniqueness
- [x] Test concurrent token generation

**Acceptance Criteria:**

- Tokens are generated correctly
- Signatures are valid
- Tokens are stored with TTL
- Nonces are unique

---

### Step 3.2: Token Verification

**Tasks:**

- [x] Implement `VerifyToken()` in `internal/token/verifier.go`:
  - Parse token (split by '.')
  - Verify HMAC signature
  - Decode payload
  - Validate event_id
  - Check expiry
  - Optional: Check Redis for single-use
- [x] Create verification library examples (Go, Python, Node.js)

**Tests:**

- [x] Test valid token verification
- [x] Test invalid signature
- [x] Test expired token
- [x] Test wrong event_id
- [x] Test malformed token
- [x] Test single-use token check (if implemented)
- [x] Test verification library examples

**Acceptance Criteria:**

- Valid tokens verify correctly
- Invalid tokens are rejected
- Expiry checking works
- Verification libraries work

---

### Step 3.3: Token Metadata Management

**Tasks:**

- [x] Implement token lookup in Redis
- [x] Implement token expiry tracking
- [x] Add metrics for token operations
- [x] Implement token revocation (admin)

**Tests:**

- [x] Test token lookup
- [x] Test token expiry tracking
- [x] Test token revocation
- [x] Test metrics collection

**Acceptance Criteria:**

- Token metadata is accessible
- Expiry is tracked
- Revocation works
- Metrics are collected

---

## Phase 4: Release Controller

### Step 4.1: Release Rate Control

**Tasks:**

- [x] Create `internal/release/controller.go`:
  - Configurable release rate (users/second)
  - Rate limiting logic
  - Time-based release scheduling
- [x] Implement `ReleaseUsers()`:
  - Check release state (paused, rate)
  - Pop from queue (LPOP or ZPOPMIN)
  - Generate admission token
  - Update release counters
  - Trigger webhook (if configured)
- [x] Implement release scheduler (goroutine)

**Tests:**

- [x] Test release at configured rate
- [x] Test pause/resume
- [x] Test rate adjustment
- [x] Test queue exhaustion
- [x] Test priority bucket release order
- [x] Test concurrent releases
- [x] Test webhook triggering

**Acceptance Criteria:**

- Release rate is controlled accurately
- Pause/resume works
- Priority order is maintained
- Webhooks are triggered

---

### Step 4.2: Capacity Management

**Tasks:**

- [x] Implement capacity checking
- [x] Respect max_capacity configuration
- [x] Track concurrent admissions
- [x] Implement capacity-based release throttling

**Tests:**

- [x] Test capacity limit enforcement
- [x] Test capacity tracking
- [x] Test release throttling at capacity
- [x] Test capacity recovery

**Acceptance Criteria:**

- Capacity limits are enforced
- Tracking is accurate
- Throttling works correctly

---

### Step 4.3: Release State Management

**Tasks:**

- [x] Implement release state storage in Redis
- [x] Implement pause/resume functionality
- [x] Implement release rate override
- [x] Add release metrics

**Tests:**

- [x] Test release state persistence
- [x] Test pause functionality
- [x] Test resume functionality
- [x] Test rate override
- [x] Test metrics collection

**Acceptance Criteria:**

- Release state persists correctly
- Pause/resume works
- Metrics are accurate

---

## Phase 5: Admin API

### Step 5.1: Admin Authentication

**Tasks:**

- [x] Create `internal/api/middleware.go`:
  - Admin API key validation
  - Request logging
  - Rate limiting for admin endpoints
- [x] Implement authentication middleware

**Tests:**

- [x] Test valid API key
- [x] Test invalid API key
- [x] Test missing API key
- [x] Test rate limiting

**Acceptance Criteria:**

- Admin endpoints are protected
- Authentication works correctly
- Rate limiting prevents abuse

---

### Step 5.2: Admin Endpoints

**Tasks:**

- [x] Implement `POST /admin/release`
- [x] Implement `POST /admin/pause`
- [x] Implement `POST /admin/config`
- [x] Implement `GET /admin/metrics`
- [x] Add request/response validation
- [x] Add error handling

**Tests:**

- [x] Test release endpoint
- [x] Test pause endpoint
- [x] Test config endpoint
- [x] Test metrics endpoint
- [x] Test invalid requests
- [x] Test authorization

**Acceptance Criteria:**

- All admin endpoints work
- Validation is correct
- Errors are handled properly

---

### Step 5.3: Metrics Collection

**Tasks:**

- [x] Implement Prometheus metrics:
  - Queue length
  - Wait time
  - Release rate
  - Admission count
  - API request duration
  - Redis operation duration
- [x] Create `/metrics` endpoint
- [x] Add metric labels for event_id

**Tests:**

- [x] Test metrics collection
- [x] Test metrics endpoint
- [x] Test metric labels
- [x] Test metric accuracy

**Acceptance Criteria:**

- Metrics are collected correctly
- Metrics endpoint works
- Labels are applied correctly

---

## Phase 6: Flutter SDK

### Step 6.1: SDK Project Setup

**Tasks:**

- [ ] Initialize Flutter package: `flutter create --template=package gatekeep_flutter`
- [ ] Set up project structure:

  ```yaml
  app/
  ├── lib/
  │   ├── gatekeep.dart
  │   ├── models/
  │   ├── client/
  │   └── ui/
  ├── test/
  └── pubspec.yaml
  ```

- [ ] Add dependencies: `http`, `flutter_secure_storage`
- [ ] Create package exports

**Tests:**

- [ ] Test package structure
- [ ] Test dependencies resolve
- [ ] Test exports work

**Acceptance Criteria:**

- Package structure is correct
- Dependencies are available
- Exports work

---

### Step 6.2: Queue Client Implementation

**Tasks:**

- [ ] Implement `QueueClient` class:
  - `initialize()` method
  - `joinEvent()` method
  - `listenStatus()` method (polling)
  - `sendHeartbeat()` method
  - `onAdmitted()` method
  - `restoreToken()` method
- [ ] Implement HTTP client with retry logic
- [ ] Implement exponential backoff
- [ ] Implement token persistence

**Tests:**

- [ ] Test client initialization
- [ ] Test queue join
- [ ] Test status polling
- [ ] Test heartbeat
- [ ] Test token persistence
- [ ] Test retry logic
- [ ] Test network failure handling

**Acceptance Criteria:**

- Client methods work correctly
- Retry logic functions
- Token persistence works
- Network failures handled

---

### Step 6.3: UI Components

**Tasks:**

- [ ] Create `WaitingRoomScreen` widget
- [ ] Implement state machine UI:
  - Joining state
  - Waiting state
  - Admitted state
  - Expired state
  - Error state
- [ ] Add position display
- [ ] Add ETA display
- [ ] Add progress indicator

**Tests:**

- [ ] Test UI state transitions
- [ ] Test position display
- [ ] Test ETA display
- [ ] Test error handling UI
- [ ] Test widget rendering

**Acceptance Criteria:**

- UI states work correctly
- Display is accurate
- Error states are handled
- Widgets render properly

---

### Step 6.4: SDK Integration Example

**Tasks:**

- [ ] Create example Flutter app
- [ ] Demonstrate SDK usage
- [ ] Show error handling
- [ ] Show token restoration

**Tests:**

- [ ] Test example app compiles
- [ ] Test example app runs
- [ ] Test integration flow

**Acceptance Criteria:**

- Example app works
- Integration is clear
- Error handling demonstrated

---

## Phase 7: Production Hardening

### Step 7.1: Error Handling

**Tasks:**

- [ ] Implement structured error types
- [ ] Add error context
- [ ] Implement error recovery
- [ ] Add error metrics
- [ ] Improve error messages

**Tests:**

- [ ] Test error types
- [ ] Test error context
- [ ] Test error recovery
- [ ] Test error metrics

**Acceptance Criteria:**

- Errors are well-structured
- Recovery works
- Metrics are collected

---

### Step 7.2: Observability

**Tasks:**

- [ ] Implement structured logging (JSON)
- [ ] Add log levels
- [ ] Add request ID tracking
- [ ] Implement distributed tracing (optional)
- [ ] Add performance logging

**Tests:**

- [ ] Test log format
- [ ] Test log levels
- [ ] Test request ID propagation
- [ ] Test performance logging

**Acceptance Criteria:**

- Logs are structured
- Levels work correctly
- Request tracking works

---

### Step 7.3: Rate Limiting

**Tasks:**

- [ ] Implement per-device rate limiting
- [ ] Implement per-IP rate limiting
- [ ] Implement per-user rate limiting
- [ ] Add rate limit headers
- [ ] Add rate limit metrics

**Tests:**

- [ ] Test device rate limiting
- [ ] Test IP rate limiting
- [ ] Test user rate limiting
- [ ] Test rate limit headers
- [ ] Test rate limit metrics

**Acceptance Criteria:**

- Rate limiting works
- Headers are correct
- Metrics are accurate

---

### Step 7.4: Health Checks

**Tasks:**

- [ ] Implement `/health` endpoint
- [ ] Check Redis connectivity
- [ ] Check service status
- [ ] Add health check metrics

**Tests:**

- [ ] Test health check endpoint
- [ ] Test Redis connectivity check
- [ ] Test service status
- [ ] Test health metrics

**Acceptance Criteria:**

- Health checks work
- Redis status is accurate
- Service status is correct

---

### Step 7.5: Load Testing

**Tasks:**

- [ ] Create load test scenarios:
  - 10k concurrent joins
  - 1k releases/second
  - 100k status checks
- [ ] Run load tests
- [ ] Identify bottlenecks
- [ ] Optimize performance

**Tests:**

- [ ] Test concurrent joins
- [ ] Test release throughput
- [ ] Test status check load
- [ ] Test Redis performance

**Acceptance Criteria:**

- System handles expected load
- Bottlenecks identified
- Performance is acceptable

---

## Phase 8: Cloudflare Integration

### Step 8.1: Cloudflare Workers Setup

**Tasks:**

- [ ] Review [Cloudflare Integration README](CLOUDFLARE.md)
- [ ] Set up Cloudflare Workers project
- [ ] Configure Wrangler
- [ ] Set up environment variables

**Tests:**

- [ ] Test Workers deployment
- [ ] Test environment variables
- [ ] Test basic routing

**Acceptance Criteria:**

- Workers deploy successfully
- Configuration works
- Routing functions

---

### Step 8.2: Queue Join Proxy

**Tasks:**

- [ ] Implement queue join proxy in Workers
- [ ] Add DDoS protection
- [ ] Add bot detection
- [ ] Add rate limiting at edge
- [ ] Forward to Go service

**Tests:**

- [ ] Test proxy functionality
- [ ] Test DDoS protection
- [ ] Test bot detection
- [ ] Test rate limiting
- [ ] Test forwarding

**Acceptance Criteria:**

- Proxy works correctly
- Protection is effective
- Forwarding is reliable

---

### Step 8.3: Status Polling Optimization

**Tasks:**

- [ ] Implement caching in Workers
- [ ] Add cache invalidation
- [ ] Optimize status endpoint
- [ ] Reduce backend load

**Tests:**

- [ ] Test caching
- [ ] Test cache invalidation
- [ ] Test optimization
- [ ] Test load reduction

**Acceptance Criteria:**

- Caching works
- Invalidation is correct
- Load is reduced

---

### Step 8.4: WebSocket Support (Optional)

**Tasks:**

- [ ] Implement WebSocket in Workers
- [ ] Connect to Go service
- [ ] Push status updates
- [ ] Handle reconnections

**Tests:**

- [ ] Test WebSocket connection
- [ ] Test status updates
- [ ] Test reconnection
- [ ] Test error handling

**Acceptance Criteria:**

- WebSocket works
- Updates are pushed
- Reconnection works

---

## Testing Strategy

### Unit Tests

- **Coverage Target**: 80%+
- **Focus Areas**:
  - Queue operations
  - Token generation/verification
  - Release controller
  - Rate limiting
  - Error handling

### Integration Tests

- **Test Scenarios**:
  - Full queue flow (join → wait → admit)
  - Token lifecycle
  - Release controller
  - Admin operations
  - Redis failure scenarios

### End-to-End Tests

- **Test Scenarios**:
  - Flutter app → Go service → Redis
  - Multiple concurrent users
  - Network failures
  - Token expiry
  - Admin operations

### Load Tests

- **Scenarios**:
  - 100k concurrent queue joins
  - 10k releases/second
  - 1M status checks
  - Redis failover

### Chaos Tests

- **Scenarios**:
  - Redis node failure
  - Network partition
  - Service crash
  - Clock skew

---

## Deployment Checklist

### Pre-Deployment

- [ ] All tests passing
- [ ] Load tests completed
- [ ] Documentation updated
- [ ] Monitoring configured
- [ ] Alerts configured
- [ ] Runbooks created

### Deployment

- [ ] Deploy to staging
- [ ] Run smoke tests
- [ ] Deploy to production (canary)
- [ ] Monitor metrics
- [ ] Gradual rollout
- [ ] Full deployment

### Post-Deployment

- [ ] Verify metrics
- [ ] Check logs
- [ ] Monitor performance
- [ ] Gather feedback
- [ ] Document issues

---

## Rollback Plan

1. **Immediate Rollback**: Disable queue via feature flag
2. **Service Rollback**: Deploy previous version
3. **Redis Rollback**: Restore from backup (if needed)
4. **Communication**: Notify stakeholders

---

## Success Metrics

- **Functionality**: All features working
- **Performance**: <50ms p99 for queue operations
- **Reliability**: 99.9% uptime
- **Security**: No security vulnerabilities
- **Observability**: All metrics collected
- **Documentation**: Complete and accurate

---

## Timeline Estimate

- **Phase 1**: 1 week
- **Phase 2**: 2 weeks
- **Phase 3**: 1 week
- **Phase 4**: 2 weeks
- **Phase 5**: 1 week
- **Phase 6**: 2 weeks
- **Phase 7**: 2 weeks
- **Phase 8**: 1 week

**Total**: ~12 weeks (3 months)

---

## Next Steps

1. Review this implementation plan
2. Set up development environment
3. Begin Phase 1
4. Set up CI/CD pipeline
5. Schedule regular reviews
