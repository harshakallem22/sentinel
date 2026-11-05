#!/usr/bin/env bash
# Gives Argo CD read-only access to the private repo using a deploy key that never enters Git.
set -euo pipefail

KEY_PATH="${ARGOCD_DEPLOY_KEY:-$HOME/.ssh/sentinel_argocd_deploy}"
REPO_URL="${REPO_URL:-git@github.com:harshakallem22/sentinel.git}"
NAMESPACE=argocd

if [ ! -f "$KEY_PATH" ]; then
  echo "Deploy key not found at $KEY_PATH"
  echo "Create it:  ssh-keygen -t ed25519 -N '' -C sentinel-argocd -f $KEY_PATH"
  echo "Register:   gh repo deploy-key add $KEY_PATH.pub --title sentinel-argocd"
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NAMESPACE" create secret generic sentinel-repo \
  --from-literal=type=git \
  --from-literal=url="$REPO_URL" \
  --from-file=sshPrivateKey="$KEY_PATH" \
  --dry-run=client -o yaml \
  | kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
  | kubectl apply -f -

echo "Repository secret applied for $REPO_URL"
