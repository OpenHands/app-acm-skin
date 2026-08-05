#!/usr/bin/env bash
# Deploy acm-skin: an Agent Canvas instance (feature/skins build) running
# the ACM skin from OpenHands/skin-acm@main.
#
# One-off secrets (NOT part of this script's manifests; values come from
# the environment, never from the repo):
#
#   # session API key for the instance (any random value):
#   kubectl create secret generic acm-skin-session -n agent-canvas-apps \
#     --from-literal=sessionApiKey="$(python3 -c 'import secrets;print(secrets.token_urlsafe(32))')"
#
#   # GitHub token — required: skin-acm is private (skin clone) and the
#   # marketplace/skin repos are private too:
#   kubectl create secret generic acm-skin-github -n agent-canvas-apps \
#     --from-literal=token="$GITHUB_PERSONAL_ACCESS_TOKEN"
#
#   # global store key (shared with the acm app; usually already exists):
#   kubectl create secret generic acm-store -n agent-canvas-apps \
#     --from-literal=session-key="<store instance X-Session-API-Key>"
set -euo pipefail
NS=agent-canvas-apps
DIR="$(cd "$(dirname "$0")" && pwd)"

# No vendored chart: install from the LIVE helm/agent-canvas chart on
# OpenHands/OpenHands branch feature/skins.
CHART_REF="${CHART_REF:-feature/skins}"
CHART_CHECKOUT="$(mktemp -d)"
trap 'rm -rf "$CHART_CHECKOUT"' EXIT
git clone -q --depth 1 -b "$CHART_REF" \
  https://github.com/OpenHands/OpenHands.git "$CHART_CHECKOUT"

# Release AND resources are `acmskin` (no hyphen): ACM fleet listings
# (helm releases prefixed `acm-`) must not pick this host up, and a
# Service named acm-skin would inject ACM_SKIN_PORT=tcp://... into every
# pod in the namespace, crashing ACM backends (see README "Sharp edges").
helm upgrade --install acmskin "$CHART_CHECKOUT/helm/agent-canvas" -n "$NS" \
  -f "$DIR/k8s/values.yaml" --wait --timeout 8m

kubectl -n "$NS" rollout status statefulset/acmskin

# The skins image ships no kubectl/helm, but the ACM backend shells out to
# both. Install them onto the persistent workspace volume (survives pod
# restarts; values.yaml puts ~/workspace/bin on PATH).
kubectl -n "$NS" exec acmskin-0 -- sh -c '
set -e
mkdir -p ~/workspace/bin
if [ ! -x ~/workspace/bin/kubectl ]; then
  curl -sSLo ~/workspace/bin/kubectl "https://dl.k8s.io/release/$(curl -sSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ~/workspace/bin/kubectl
fi
if [ ! -x ~/workspace/bin/helm ]; then
  curl -sSL https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz | tar xz -C /tmp
  mv /tmp/linux-amd64/helm ~/workspace/bin/helm
fi
~/workspace/bin/helm version --short'

echo "── verify ──"
kubectl -n "$NS" exec acmskin-0 -- curl -s http://127.0.0.1:8000/skin-api/status
echo
kubectl -n "$NS" get certificate acmskin-tls
