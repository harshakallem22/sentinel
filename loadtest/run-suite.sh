#!/usr/bin/env bash
# Runs one k6 profile several times, saving each JSON summary, k6 output and node usage, then prints one line per trial.
# Usage: loadtest/run-suite.sh <smoke|steady|ramp|spike> [trials]
# Env: RATE, DURATION, MAX_RATE, BASE_RATE, SPIKE_RATE, BASE_URL go to k6; OUT_DIR, LABEL, WARMUP=1, COOLDOWN (seconds)
set -euo pipefail

profile="${1:?usage: run-suite.sh <smoke|steady|ramp|spike> [trials]}"
trials="${2:-1}"
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/k6/$profile.js"
[ -f "$script" ] || { echo "no such profile: $script" >&2; exit 1; }
out="${OUT_DIR:-$here/results}"
label="${LABEL:-$profile}"
mkdir -p "$out"

# The app's own loadgenerator would add unmeasured traffic
gen="$(kubectl -n boutique get deploy loadgenerator -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
[ "$gen" = "0" ] || { echo "loadgenerator has $gen replicas; scale it to 0 first" >&2; exit 1; }

sample_node() {
  while true; do
    echo "$(date -u +%FT%TZ) $(kubectl top node --no-headers 2>/dev/null | awk '{print $2, $3, $4, $5}')"
    sleep 10
  done
}

run() {
  local name="$1" sampler
  sample_node > "$out/$name-node.txt" &
  sampler=$!
  {
    echo "# $(date -u +%FT%TZ) git $(git -C "$here" rev-parse --short HEAD) profile $profile"
    echo "# env RATE=${RATE:-} DURATION=${DURATION:-} MAX_RATE=${MAX_RATE:-} BASE_RATE=${BASE_RATE:-} SPIKE_RATE=${SPIKE_RATE:-}"
  } > "$out/$name.log"
  # Threshold failures exit non-zero but are still results worth keeping
  k6 run --quiet --summary-trend-stats 'avg,min,med,max,p(90),p(95),p(99)' \
    --summary-export "$out/$name.json" "$script" >> "$out/$name.log" 2>&1 || true
  kill "$sampler" 2>/dev/null || true
  wait "$sampler" 2>/dev/null || true
}

summarise() {
  jq -r --arg n "$1" '
    .metrics as $m |
    [$n,
     ($m.http_req_duration.med | . * 10 | round / 10),
     ($m.http_req_duration["p(95)"] | . * 10 | round / 10),
     ($m.http_req_duration["p(99)"] | . * 10 | round / 10),
     (($m.http_req_failed.value // 0) * 100 | . * 100 | round / 100),
     ($m.http_reqs.rate | . * 10 | round / 10),
     ($m.vus_max.max // $m.vus_max.value),
     (if $m.checkout_ok then ($m.checkout_ok.value * 100 | . * 100 | round / 100) else "-" end)
    ] | @tsv' "$out/$1.json"
}

if [ "${WARMUP:-0}" = "1" ]; then
  echo "warm-up (discarded)"
  run "$label-warmup"
  sleep "${COOLDOWN:-30}"
fi

printf 'trial\tp50_ms\tp95_ms\tp99_ms\terr_%%\treq_s\tvus_max\tcheckout_ok_%%\n'
for i in $(seq 1 "$trials"); do
  name="$label-$i"
  run "$name"
  summarise "$name"
  if [ "$i" -lt "$trials" ]; then sleep "${COOLDOWN:-30}"; fi
done
