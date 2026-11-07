#!/usr/bin/env bash
# Proves default-deny: an unlabelled pod in boutique cannot reach paymentservice or redis, while checkout still works.
# The probe pod uses the same busybox image upstream already pins.
set -euo pipefail

NS=boutique
IMAGE='busybox:1.38.0@sha256:dc2d74b28e4cf8984fa52af1f39bc7c3d9c73760b41a74d629f5d11b1ab28616'
failures=0

probe() {
  local target="$1"
  kubectl -n "$NS" run "netpol-probe-$RANDOM" --rm -i --restart=Never --quiet --image="$IMAGE" \
    --overrides='{"spec":{"containers":[{"name":"p","image":"'"$IMAGE"'","command":["sh","-c","nc -z -w 3 '"${target%:*}"' '"${target#*:}"' && echo open || echo blocked"],"resources":{"limits":{"cpu":"50m","memory":"16Mi"}}}]}}' \
    2>/dev/null | tail -1
}

for target in paymentservice:50051 redis-cart:6379 productcatalogservice:3550; do
  result="$(probe "$target")"
  if [ "$result" = blocked ]; then
    echo "PASS  debug pod -> $target blocked"
  else
    echo "FAIL  debug pod -> $target $result"
    failures=$((failures + 1))
  fi
done

[ "$failures" -eq 0 ] && echo "All NetworkPolicy checks passed." || { echo "$failures check(s) failed" >&2; exit 1; }
