#!/usr/bin/env bash
# Builds the Online Boutique images for this machine's CPU from unmodified upstream source
# and pushes them to the cluster's local registry. Skips images that are already there.
set -euo pipefail

VERSION=v0.10.7
UPSTREAM_COMMIT=5b608cb1dfe317d05e4f1bb8c99b7618452fde87
REPO_URL=https://github.com/GoogleCloudPlatform/microservices-demo.git
SRC_DIR="${SRC_DIR:-$HOME/.cache/sentinel/microservices-demo}"
REGISTRY="${REGISTRY:-127.0.0.1:5001}"
PLATFORM="${PLATFORM:-linux/arm64}"
ARCH="${PLATFORM#linux/}"
FORCE="${FORCE:-0}"

SERVICES="adservice cartservice checkoutservice currencyservice emailservice frontend
loadgenerator paymentservice productcatalogservice recommendationservice shippingservice"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --quiet --depth 1 --branch "$VERSION" "$REPO_URL" "$SRC_DIR"
fi
actual="$(git -C "$SRC_DIR" rev-parse HEAD)"
if [ "$actual" != "$UPSTREAM_COMMIT" ]; then
  echo "Upstream source at $SRC_DIR is $actual, expected $UPSTREAM_COMMIT ($VERSION)" >&2
  exit 1
fi
if [ -n "$(git -C "$SRC_DIR" status --porcelain)" ]; then
  echo "Upstream source at $SRC_DIR has local changes; refusing to build" >&2
  exit 1
fi

curl -fsS "http://$REGISTRY/v2/" >/dev/null || { echo "Registry $REGISTRY is not reachable; run 'make cluster' first" >&2; exit 1; }

for svc in $SERVICES; do
  image="$REGISTRY/boutique/$svc:$VERSION"
  if [ "$FORCE" != 1 ] && curl -fsS "http://$REGISTRY/v2/boutique/$svc/manifests/$VERSION" \
      -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json' >/dev/null 2>&1; then
    echo "skip  $svc (already in registry)"
    continue
  fi
  context="$SRC_DIR/src/$svc"
  # cartservice keeps its Dockerfile one level down
  [ "$svc" = cartservice ] && context="$SRC_DIR/src/cartservice/src"
  echo "build $svc"
  # Upstream Dockerfiles default these args to amd64; set them so every stage is native
  docker build --quiet --platform "$PLATFORM" \
    --build-arg BUILDPLATFORM="$PLATFORM" \
    --build-arg TARGETOS=linux \
    --build-arg TARGETARCH="$ARCH" \
    -t "$image" "$context" >/dev/null
  docker push --quiet "$image" >/dev/null
  echo "push  $image"
done

echo "All Online Boutique images are in $REGISTRY"
