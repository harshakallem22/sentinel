// Rate climbs in steps up to MAX_RATE to find where latency bends. Usage: k6 run -e MAX_RATE=60 loadtest/k6/ramp.js
import { shopper, thresholds } from './lib.js';

const MAX = Number(__ENV.MAX_RATE || 60);
const STEPS = 6;
const stages = [];
for (let i = 1; i <= STEPS; i++) {
  const target = Math.round((MAX * i) / STEPS);
  stages.push({ target, duration: '15s' }, { target, duration: '45s' });
}

export const options = {
  scenarios: {
    ramp: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      stages,
      preAllocatedVUs: 20,
      maxVUs: 200,
    },
  },
  thresholds,
};

export default shopper;
