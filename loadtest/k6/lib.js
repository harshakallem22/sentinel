import http from 'k6/http';
import { check } from 'k6';
import { Rate } from 'k6/metrics';

export const BASE = __ENV.BASE_URL || 'http://localhost:8080';
const PRODUCTS = ['OLJCESPC7Z', '66VCHSJNUP', '1YMWWN1N4O', 'L9ECAV7KIM', '2ZYFJ3GM2N', '0PUK6V6EV0', 'LS4PSXUNUM', '9SIQT8TOJO', '6E92ZMYYFZ'];
const CURRENCIES = ['EUR', 'USD', 'JPY', 'CAD', 'GBP', 'TRY'];
const QUANTITIES = [1, 2, 3, 4, 5, 10];

export const checkoutOk = new Rate('checkout_ok');

const pick = (list) => list[Math.floor(Math.random() * list.length)];
const ok = (res) => check(res, { 'status is 200': (r) => r.status === 200 });

export function home() {
  ok(http.get(`${BASE}/`, { tags: { name: 'home' } }));
}

export function setCurrency() {
  ok(http.post(`${BASE}/setCurrency`, { currency_code: pick(CURRENCIES) }, { tags: { name: 'set_currency' } }));
}

export function browseProduct() {
  ok(http.get(`${BASE}/product/${pick(PRODUCTS)}`, { tags: { name: 'product' } }));
}

export function addToCart() {
  const product = pick(PRODUCTS);
  ok(http.get(`${BASE}/product/${product}`, { tags: { name: 'product' } }));
  ok(http.post(`${BASE}/cart`, { product_id: product, quantity: String(pick(QUANTITIES)) }, { tags: { name: 'cart_add' } }));
}

export function viewCart() {
  ok(http.get(`${BASE}/cart`, { tags: { name: 'cart_view' } }));
}

export function checkout() {
  addToCart();
  // The app's own demo card and address, not real payment data
  const res = http.post(`${BASE}/cart/checkout`, {
    email: 'someone@example.com',
    street_address: '1600 Amphitheatre Parkway',
    zip_code: '94043',
    city: 'Mountain View',
    state: 'CA',
    country: 'United States',
    credit_card_number: '4432801561520454',
    credit_card_expiration_month: '1',
    credit_card_expiration_year: '2030',
    credit_card_cvv: '672',
  }, { tags: { name: 'checkout' } });
  checkoutOk.add(res.status === 200 && res.body.includes('Your order is complete'));
  ok(res);
}

// Same task weights as upstream's loadgenerator, so the mix matches how the app is meant to be exercised
const TASKS = [[home, 1], [setCurrency, 2], [browseProduct, 10], [addToCart, 2], [viewCart, 3], [checkout, 1]];
const TOTAL = TASKS.reduce((sum, [, w]) => sum + w, 0);

export function shopper() {
  let r = Math.random() * TOTAL;
  for (const [task, weight] of TASKS) {
    r -= weight;
    if (r < 0) return task();
  }
  return home();
}

export const thresholds = {
  http_req_failed: ['rate<0.01'],
  checkout_ok: ['rate>0.99'],
};
