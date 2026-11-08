#!/usr/bin/env bash
# After a stopped cluster starts again, pods that restarted before Istio's CNI agent was ready get no ambient
# redirection (mesh traffic to them is refused), so this recreates exactly those pods once the agent is up.
set -euo pipefail

if ! kubectl -n istio-system get ds istio-cni-node >/dev/null 2>&1; then
  echo "Istio CNI not installed yet; nothing to do"
  exit 0
fi
kubectl -n istio-system rollout status ds/istio-cni-node --timeout=300s
kubectl -n istio-system rollout status ds/ztunnel --timeout=300s

cni_ready="$(kubectl -n istio-system get pods -l k8s-app=istio-cni-node \
  -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].lastTransitionTime}')"

for ns in $(kubectl get ns -l istio.io/dataplane-mode=ambient -o jsonpath='{.items[*].metadata.name}'); do
  # Pod sandboxes created before the agent was ready are the ones it never enrolled
  stale="$(kubectl -n "$ns" get pods -o json | python3 -c '
import json, sys
cni = sys.argv[1]
for p in json.load(sys.stdin)["items"]:
    sandbox = [c["lastTransitionTime"] for c in p["status"].get("conditions", []) if c["type"] == "PodReadyToStartContainers"]
    if sandbox and sandbox[0] < cni:
        print(p["metadata"]["name"])' "$cni_ready")"
  if [ -n "$stale" ]; then
    echo "Recreating $(echo "$stale" | wc -l | tr -d ' ') pods in $ns that started before the Istio CNI agent"
    echo "$stale" | xargs kubectl -n "$ns" delete pod --wait=false
  fi
done
