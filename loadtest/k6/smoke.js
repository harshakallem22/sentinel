// One shopper walks every page once; run before any measured test.
import { home, setCurrency, browseProduct, viewCart, checkout } from './lib.js';

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    checks: ['rate==1'],
    checkout_ok: ['rate==1'],
  },
};

export default function () {
  home();
  setCurrency();
  browseProduct();
  checkout();
  viewCart();
}
