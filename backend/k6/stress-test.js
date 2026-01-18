import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const joinSuccessRate = new Rate('queue_join_success');
const joinDuration = new Trend('queue_join_duration');

// Stress test configuration - rapid ramp up to 4k users
export const options = {
  stages: [
    { duration: '10s', target: 4000 },   // Rapid ramp to 4k users
    { duration: '2m', target: 4000 },    // Sustain 4k users for 2 minutes
    { duration: '30s', target: 0 },      // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'], // More lenient for stress test
    'http_req_failed': ['rate<0.05'],                   // Allow up to 5% errors
    'queue_join_success': ['rate>0.90'],                // 90% join success rate
  },
};

// Base URL
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const EVENT_ID = __ENV.EVENT_ID || 'stress-test-event';
const ADMIN_API_KEY = __ENV.ADMIN_API_KEY || 'staging-admin-api-key-12345';

// Generate unique user identifiers
function generateUserID(vu) {
  return `stress-user-${vu}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function generateDeviceID(vu) {
  return `stress-device-${vu}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Setup: Configure event
export function setup() {
  const url = `${BASE_URL}/admin/config`;
  const payload = JSON.stringify({
    event_id: EVENT_ID,
    enabled: true,
    max_size: 0,
    release_rate: 200, // Higher release rate for stress test
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

// Main test function - focused on join operations
export default function (data) {
  const userID = generateUserID(__VU);
  const deviceID = generateDeviceID(__VU);

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
    'join status is 200 or 503': (r) => r.status === 200 || r.status === 503,
    'join response is valid': (r) => {
      if (r.status === 503) return true; // Service unavailable is acceptable
      try {
        const body = JSON.parse(r.body);
        return body.queue_id !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  joinSuccessRate.add(joinSuccess);
  joinDuration.add(joinDurationMs);

  sleep(0.5); // Minimal sleep for maximum throughput
}

// Teardown
export function teardown(data) {
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
