// Steady browsing traffic through Traefik, used to give a canary something to measure.
// Usage: k6 run -e RATE=5 -e DURATION=10m loadtest/k6/steady.js
import http from 'k6/http';
import { check } from 'k6';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';
const PRODUCTS = ['OLJCESPC7Z', '66VCHSJNUP', '1YMWWN1N4O', 'L9ECAV7KIM', '2ZYFJ3GM2N', '0PUK6V6EV0', 'LS4PSXUNUM', '9SIQT8TOJO', '6E92ZMYYFZ'];

export const options = {
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 5),
      timeUnit: '1s',
      duration: __ENV.DURATION || '5m',
      preAllocatedVUs: 10,
      maxVUs: 50,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = Math.random() < 0.5
    ? http.get(`${BASE}/`, { tags: { page: 'home' } })
    : http.get(`${BASE}/product/${PRODUCTS[Math.floor(Math.random() * PRODUCTS.length)]}`, { tags: { page: 'product' } });
  check(res, { 'status is 200': (r) => r.status === 200 });
}
