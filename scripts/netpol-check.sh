#!/usr/bin/env bash
# Proves default-deny: an unlabelled pod in boutique gets no answer from paymentservice, productcatalogservice
# or redis, while a pod labelled like the frontend does reach productcatalogservice (allowed-path control).
# Probes wait for a real reply, because Istio ambient completes TCP handshakes locally even when the path is blocked.
set -euo pipefail

NS=boutique
IMAGE='curlimages/curl:8.17.0@sha256:935d9100e9ba842cdb060de42472c7ca90cfe9a7c96e4dacb55e79e560b3ff40'
failures=0

run_probe() {
  local labels="$1" script="$2"
  kubectl -n "$NS" run "netpol-probe-$RANDOM" --rm -i --restart=Never --quiet --image="$IMAGE" --labels="$labels" \
    --overrides='{"spec":{"containers":[{"name":"p","image":"'"$IMAGE"'","command":["sh","-c","'"$script"'"],"resources":{"limits":{"cpu":"50m","memory":"32Mi"}}}]}}' \
    2>/dev/null | tail -1
}

# An empty gRPC message (5 zero bytes) to the standard health service; any HTTP status means the server answered
grpc() {
  echo 'printf \"\\0\\0\\0\\0\\0\" > /tmp/b; c=$(curl -s -m 5 --http2-prior-knowledge -o /dev/null -w %{http_code} -X POST -H content-type:application/grpc -H te:trailers --data-binary @/tmp/b http://'"$1"'/grpc.health.v1.Health/Check); [ \"$c\" != 000 ] && echo open || echo blocked'
}
redis() {
  echo 'printf \"PING\\r\\n\" | curl -s -m 4 telnet://'"$1"' | grep -q PONG && echo open || echo blocked'
}

check() {
  local want="$1" label="$2" labels="$3" script="$4" got
  got="$(run_probe "$labels" "$script")"
  if [ "$got" = "$want" ]; then
    echo "PASS  $label -> $got"
  else
    echo "FAIL  $label -> ${got:-no result} (wanted $want)"
    failures=$((failures + 1))
  fi
}

check blocked "debug pod -> paymentservice:50051"        run=netpol-probe "$(grpc paymentservice:50051)"
check blocked "debug pod -> productcatalogservice:3550"  run=netpol-probe "$(grpc productcatalogservice:3550)"
check blocked "debug pod -> redis-cart:6379"             run=netpol-probe "$(redis redis-cart:6379)"
check open    "app=frontend pod -> productcatalogservice:3550 (allowed path)" app=frontend "$(grpc productcatalogservice:3550)"

[ "$failures" -eq 0 ] && echo "All NetworkPolicy checks passed." || { echo "$failures check(s) failed" >&2; exit 1; }
