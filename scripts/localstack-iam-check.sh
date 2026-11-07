#!/usr/bin/env bash
# Proves the CI role is least-privilege: it may write under loadtest/ and nothing else.
# Exits non-zero if any call does not behave as expected. ENDPOINT="" targets real AWS (uses your own profile).
set -uo pipefail

ENDPOINT="${ENDPOINT-http://localhost:4566}"
BUCKET="${BUCKET:-sentinel-results}"
ROLE_ARN="$(terraform -chdir=terraform/localstack-iam output -raw ci_role_arn)"
if [ -n "$ENDPOINT" ]; then
  # LocalStack accepts any non-empty keys
  export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
  aws_ls() { aws --endpoint-url "$ENDPOINT" "$@"; }
else
  aws_ls() { aws "$@"; }
fi

creds="$(aws_ls sts assume-role --role-arn "$ROLE_ARN" --role-session-name iam-check \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)" || { echo "assume-role failed" >&2; exit 1; }
read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<<"$creds"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
echo "as $(aws_ls sts get-caller-identity --query Arn --output text)"

body="$(mktemp)"
echo '{"check":"iam"}' >"$body"
failures=0

expect() {
  local want="$1" label="$2"; shift 2
  local out got
  if out="$("$@" 2>&1)"; then got=allowed; else got=denied; fi
  if [ "$got" = "$want" ]; then
    echo "PASS  $label -> $got"
  else
    echo "FAIL  $label -> $got (wanted $want): $(echo "$out" | tail -1)"
    failures=$((failures + 1))
  fi
}

expect allowed "put s3://$BUCKET/loadtest/check.json" aws_ls s3api put-object --bucket "$BUCKET" --key loadtest/check.json --body "$body"
expect denied  "put s3://$BUCKET/other/check.json"    aws_ls s3api put-object --bucket "$BUCKET" --key other/check.json --body "$body"
expect denied  "get s3://$BUCKET/loadtest/check.json" aws_ls s3api get-object --bucket "$BUCKET" --key loadtest/check.json /dev/null
expect denied  "list s3://$BUCKET"                    aws_ls s3api list-objects-v2 --bucket "$BUCKET"
expect denied  "delete s3://$BUCKET/loadtest/check.json" aws_ls s3api delete-object --bucket "$BUCKET" --key loadtest/check.json
expect denied  "create bucket sentinel-other"         aws_ls s3api create-bucket --bucket sentinel-other
expect denied  "iam list-roles"                       aws_ls iam list-roles

rm -f "$body"
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "All IAM checks passed."
