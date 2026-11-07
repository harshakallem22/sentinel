#!/usr/bin/env bash
# Places a real order through the frontend: home page, add to cart, checkout. Fails unless the order completes.
# Usage: scripts/checkout-smoke.sh [base-url]   (default http://localhost:8080)
set -euo pipefail

BASE="${1:-http://localhost:8080}"
jar="$(mktemp)"
page="$(mktemp)"
trap 'rm -f "$jar" "$page"' EXIT
c() { curl -fsS --max-time 15 -c "$jar" -b "$jar" "$@"; }

c -o "$page" "$BASE/"
product="$(grep -o '/product/[A-Z0-9]*' "$page" | head -1 | cut -d/ -f3)"
[ -n "$product" ] || { echo "no product found on home page" >&2; exit 1; }
echo "home page ok, product $product"

c -o /dev/null -X POST -d "product_id=$product&quantity=1" "$BASE/cart"
echo "added to cart"

# Demo checkout form values (the app's own test card), not real payment data
c -o "$page" -X POST "$BASE/cart/checkout" \
  -d email=someone@example.com \
  --data-urlencode 'street_address=1600 Amphitheatre Parkway' \
  -d zip_code=94043 --data-urlencode 'city=Mountain View' -d state=CA --data-urlencode 'country=United States' \
  -d credit_card_number=4432801561520454 -d credit_card_expiration_month=1 \
  -d credit_card_expiration_year=2030 -d credit_card_cvv=672

if grep -q 'Your order is complete' "$page"; then
  echo "checkout ok, order $(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$page" | head -1)"
else
  echo "checkout did not complete" >&2
  exit 1
fi
