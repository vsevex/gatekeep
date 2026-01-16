# Mock Gatekeep Server

A simple mock server that simulates the Gatekeep queue system with dummy users for testing purposes.

## Features

- **Pre-populated queues**: Each event starts with 50 dummy users already in the queue
- **Automatic admission**: Admits users at a configurable rate (default: 2 users/second)
- **Realistic positions**: New users join at the end of the queue with realistic positions
- **Position updates**: Positions decrease automatically as users ahead are admitted
- **Admission tokens**: Generates mock admission tokens when users are admitted
- **Full API compatibility**: Implements the same endpoints as the real server

## Usage

### Run the mock server

```bash
# From the backend directory
make run-mock

# Or directly
go run ./cmd/mock-server
```

The server will start on `http://localhost:8080`

### Configuration

You can modify the configuration in `main.go`:

- `initialQueueSize`: Number of dummy users to pre-populate (default: 50)
- `releaseRate`: Users admitted per second (default: 2)
- `port`: Server port (default: 8080)

## API Endpoints

### POST /queue/join

Join a queue for an event. If the event doesn't exist, it will be created with dummy users.

**Request:**

```json
{
  "event_id": "test-event-123",
  "device_id": "device-123",
  "user_id": "user-123", // optional
  "priority_bucket": "normal" // optional
}
```

**Response:**

```json
{
  "queue_id": "uuid-here",
  "position": 51,
  "estimated_wait_seconds": 1530,
  "status": "waiting",
  "enqueued_at": "2024-01-15T10:00:00Z",
  "last_heartbeat": "2024-01-15T10:00:00Z",
  "total_in_queue": 51
}
```

### GET /queue/status

Get the current status of a queue entry.

**Request:**

```plain
GET /queue/status?queue_id=uuid-here
```

**Response:**

```json
{
  "queue_id": "uuid-here",
  "position": 45, // Decreases over time
  "estimated_wait_seconds": 1350,
  "status": "waiting",
  "enqueued_at": "2024-01-15T10:00:00Z",
  "last_heartbeat": "2024-01-15T10:05:00Z",
  "total_in_queue": 45
}
```

When admitted:

```json
{
  "queue_id": "uuid-here",
  "position": 0,
  "estimated_wait_seconds": 0,
  "status": "admitted",
  "admission_token": {
    "token": "mock_token_...",
    "event_id": "test-event-123",
    "device_id": "device-123",
    "user_id": "user-123",
    "issued_at": "2024-01-15T10:25:00Z",
    "expires_at": "2024-01-15T11:25:00Z",
    "queue_id": "uuid-here"
  }
}
```

### POST /queue/heartbeat

Send a heartbeat to keep the queue position alive.

**Request:**

```json
{
  "queue_id": "uuid-here"
}
```

**Response:** Same as GET /queue/status

## Testing Flow

1. **Start the mock server**: `make run-mock`
2. **Configure your Flutter app** to use `http://localhost:8080` as the base URL
3. **Join a queue** with any event ID
4. **Watch your position decrease** as dummy users ahead are admitted
5. **Get admitted** when your position reaches 0

## Example Timeline

With default settings (50 initial users, 2 users/second):

- **0:00** - Join queue, position: 51
- **0:25** - Position: ~1 (25 seconds \* 2 users/sec = 50 users admitted)
- **0:26** - Position: 0, Status: "admitted" ✅

## Notes

- The mock server is **in-memory only** - restarting clears all queues
- Each event gets its own independent queue
- Positions update automatically as users are admitted
- No Redis or external dependencies required
- Perfect for testing the Flutter SDK's waiting room UI
