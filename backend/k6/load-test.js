import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const joinSuccessRate = new Rate('queue_join_success');
const statusCheckRate = new Rate('queue_status_success');
const heartbeatSuccessRate = new Rate('queue_heartbeat_success');
const joinDuration = new Trend('queue_join_duration');
const statusCheckDuration = new Trend('queue_status_duration');
const heartbeatDuration = new Trend('queue_heartbeat_duration');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 1000 },   // Ramp up to 1k users
    { duration: '1m', target: 2000 },    // Ramp up to 2k users
    { duration: '1m', target: 3000 },    // Ramp up to 3k users
    { duration: '1m', target: 4000 },    // Ramp up to 4k users
    { duration: '5m', target: 4000 },    // Stay at 4k users for 5 minutes
    { duration: '1m', target: 0 },       // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'], // 95% of requests under 500ms, 99% under 1s
    'http_req_failed': ['rate<0.01'],                  // Less than 1% errors
    'queue_join_success': ['rate>0.95'],               // 95% join success rate
    'queue_status_success': ['rate>0.98'],             // 98% status check success rate
  },
};

// Base URL - can be overridden with K6_BASE_URL environment variable
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const EVENT_ID = __ENV.EVENT_ID || 'test-event-001';
const ADMIN_API_KEY = __ENV.ADMIN_API_KEY || 'staging-admin-api-key-12345';

// Generate unique user identifiers
function generateUserID(vu) {
  return `user-${vu}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function generateDeviceID(vu) {
  return `device-${vu}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Setup: Configure event before test starts
export function setup() {
  const url = `${BASE_URL}/admin/config`;
  const payload = JSON.stringify({
    event_id: EVENT_ID,
    enabled: true,
    max_size: 0, // Unlimited
    release_rate: 100, // Release 100 users per second
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Admin-API-Key': ADMIN_API_KEY,
    },
  };

  const res = http.post(url, payload, params);
  check(res, {
    'event config set': (r) => r.status === 200,
  });

  return { eventId: EVENT_ID };
}

// Main test function
export default function (data) {
  const userID = generateUserID(__VU);
  const deviceID = generateDeviceID(__VU);
  let queueID = null;

  // Scenario 1: Join Queue
  const joinPayload = JSON.stringify({
    event_id: data.eventId,
    device_id: deviceID,
    user_id: userID,
    priority_bucket: 'normal',
  });

  const joinParams = {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'JoinQueue' },
  };

  const joinStart = Date.now();
  const joinRes = http.post(`${BASE_URL}/queue/join`, joinPayload, joinParams);
  const joinDurationMs = Date.now() - joinStart;

  const joinSuccess = check(joinRes, {
    'join status is 200': (r) => r.status === 200,
    'join response has queue_id': (r) => {
      try {
        const body = JSON.parse(r.body);
        if (body.queue_id) {
          queueID = body.queue_id;
          return true;
        }
        return false;
      } catch (e) {
        return false;
      }
    },
    'join response has position': (r) => {
      try {
        const body = JSON.parse(r.body);
        return typeof body.position === 'number';
      } catch (e) {
        return false;
      }
    },
  });

  joinSuccessRate.add(joinSuccess);
  joinDuration.add(joinDurationMs);

  if (!queueID) {
    sleep(1);
    return;
  }

  // Scenario 2: Poll Queue Status (simulate user waiting)
  const statusChecks = Math.floor(Math.random() * 5) + 3; // 3-7 status checks
  for (let i = 0; i < statusChecks; i++) {
    const statusParams = {
      params: { queue_id: queueID },
      tags: { name: 'GetQueueStatus' },
    };

    const statusStart = Date.now();
    const statusRes = http.get(`${BASE_URL}/queue/status`, statusParams);
    const statusDurationMs = Date.now() - statusStart;

    const statusSuccess = check(statusRes, {
      'status check is 200': (r) => r.status === 200,
      'status response has position': (r) => {
        try {
          const body = JSON.parse(r.body);
          return typeof body.position === 'number';
        } catch (e) {
          return false;
        }
      },
    });

    statusCheckRate.add(statusSuccess);
    statusCheckDuration.add(statusDurationMs);

    // Check if user was admitted
    try {
      const body = JSON.parse(statusRes.body);
      if (body.admitted === true && body.admission_token) {
        // User was admitted - simulate token usage
        check(body, {
          'admission token exists': (t) => typeof t.admission_token === 'string',
          'admission token is not empty': (t) => t.admission_token.length > 0,
        });
        break; // Exit polling loop
      }
    } catch (e) {
      // Continue polling
    }

    // Wait between status checks (simulate realistic polling interval)
    sleep(Math.random() * 2 + 1); // 1-3 seconds
  }

  // Scenario 3: Send Heartbeat (if still in queue)
  if (queueID) {
    const heartbeatPayload = JSON.stringify({
      queue_id: queueID,
    });

    const heartbeatParams = {
      headers: { 'Content-Type': 'application/json' },
      tags: { name: 'SendHeartbeat' },
    };

    const heartbeatStart = Date.now();
    const heartbeatRes = http.post(
      `${BASE_URL}/queue/heartbeat`,
      heartbeatPayload,
      heartbeatParams
    );
    const heartbeatDurationMs = Date.now() - heartbeatStart;

    const heartbeatSuccess = check(heartbeatRes, {
      'heartbeat status is 200': (r) => r.status === 200,
    });

    heartbeatSuccessRate.add(heartbeatSuccess);
    heartbeatDuration.add(heartbeatDurationMs);
  }

  sleep(1);
}

// Teardown: Clean up after test
export function teardown(data) {
  // Optionally disable the event or reset configuration
  const url = `${BASE_URL}/admin/config`;
  const payload = JSON.stringify({
    event_id: data.eventId,
    enabled: false,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Admin-API-Key': ADMIN_API_KEY,
    },
  };

  http.post(url, payload, params);
}
