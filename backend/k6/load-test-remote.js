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

// Test configuration - optimized for remote staging server
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
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'], // More lenient for remote
    'http_req_failed': ['rate<0.02'],                  // Allow up to 2% errors for remote
    'queue_join_success': ['rate>0.90'],                // 90% join success rate
    'queue_status_success': ['rate>0.95'],             // 95% status check success rate
  },
  // Add connection reuse and timeouts for remote server
  httpReq: {
    expectedContent: 'application/json',
  },
};

// Base URL - REQUIRED for remote testing
const BASE_URL = __ENV.BASE_URL;
if (!BASE_URL) {
  throw new Error('BASE_URL environment variable is required. Example: k6 run -e BASE_URL=https://staging.example.com k6/load-test-remote.js');
}

const EVENT_ID = __ENV.EVENT_ID || 'test-event';
const ADMIN_API_KEY = __ENV.ADMIN_API_KEY || 'WNt7PkqU1xgt7WnZJUKn7yELhYXIfCby';

// Generate unique user identifiers
function generateUserID(vu) {
  return `remote-user-${vu}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function generateDeviceID(vu) {
  return `remote-device-${vu}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Setup: Configure event before test starts
export function setup() {
  console.log(`Setting up test against: ${BASE_URL}`);
  console.log(`Event ID: ${EVENT_ID}`);
  
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
    timeout: '30s',
  };

  const res = http.post(url, payload, params);
  const setupSuccess = check(res, {
    'event config set': (r) => r.status === 200,
  });

  if (!setupSuccess) {
    console.error(`Failed to setup event config. Status: ${res.status}, Body: ${res.body}`);
    throw new Error('Failed to setup event configuration');
  }

  console.log('✅ Event configuration set successfully');
  return { eventId: EVENT_ID, baseUrl: BASE_URL };
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
    timeout: '30s',
  };

  const joinStart = Date.now();
  const joinRes = http.post(`${data.baseUrl}/queue/join`, joinPayload, joinParams);
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
      timeout: '30s',
    };

    const statusStart = Date.now();
    const statusRes = http.get(`${data.baseUrl}/queue/status`, statusParams);
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
      timeout: '30s',
    };

    const heartbeatStart = Date.now();
    const heartbeatRes = http.post(
      `${data.baseUrl}/queue/heartbeat`,
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
  console.log('Cleaning up test configuration...');
  
  // Optionally disable the event or reset configuration
  const url = `${data.baseUrl}/admin/config`;
  const payload = JSON.stringify({
    event_id: data.eventId,
    enabled: false,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Admin-API-Key': ADMIN_API_KEY,
    },
    timeout: '30s',
  };

  const res = http.post(url, payload, params);
  if (res.status === 200) {
    console.log('✅ Test cleanup completed');
  } else {
    console.warn(`⚠️  Cleanup returned status ${res.status}`);
  }
}
