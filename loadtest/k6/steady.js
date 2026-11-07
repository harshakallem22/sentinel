// Constant shopper traffic for baselines and canaries. Usage: k6 run -e RATE=10 -e DURATION=60s loadtest/k6/steady.js
import { shopper, thresholds } from './lib.js';

export const options = {
  scenarios: {
    steady: {
      // Arrival rate, not a VU count, so a slow server gets the same offered load instead of fewer requests
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 10),
      timeUnit: '1s',
      duration: __ENV.DURATION || '60s',
      preAllocatedVUs: 20,
      maxVUs: 100,
    },
  },
  thresholds,
};

export default shopper;
