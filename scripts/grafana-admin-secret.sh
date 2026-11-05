#!/usr/bin/env bash
# Creates Grafana's admin login with a random password that exists only inside the cluster.
set -euo pipefail

NAMESPACE=monitoring
SECRET=grafana-admin

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

if kubectl -n "$NAMESPACE" get secret "$SECRET" >/dev/null 2>&1; then
  echo "Grafana admin secret already exists"
  exit 0
fi

kubectl -n "$NAMESPACE" create secret generic "$SECRET" \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"

echo "Grafana admin secret created (read it with: make grafana-admin)"
