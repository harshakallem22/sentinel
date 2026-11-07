// Quiet traffic, a sudden jump, then quiet again, to watch autoscaling. Usage: k6 run -e BASE_RATE=5 -e SPIKE_RATE=40 loadtest/k6/spike.js
import { shopper, thresholds } from './lib.js';

const BASE_RATE = Number(__ENV.BASE_RATE || 5);
const SPIKE_RATE = Number(__ENV.SPIKE_RATE || 40);

export const options = {
  scenarios: {
    spike: {
      executor: 'ramping-arrival-rate',
      startRate: BASE_RATE,
      timeUnit: '1s',
      stages: [
        { target: BASE_RATE, duration: '1m' },
        { target: SPIKE_RATE, duration: '10s' },
        { target: SPIKE_RATE, duration: __ENV.SPIKE_DURATION || '3m' },
        { target: BASE_RATE, duration: '10s' },
        { target: BASE_RATE, duration: '2m' },
      ],
      preAllocatedVUs: 20,
      maxVUs: 200,
    },
  },
  thresholds,
};

export default shopper;
