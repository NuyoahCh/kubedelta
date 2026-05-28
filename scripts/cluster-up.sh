#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"

CLUSTER_NAME="${CLUSTER_NAME:-kubedelta}"
KIND_CONFIG="${ROOT}/cluster/kind-config.yaml"
IMAGE="kubedelta-extender:dev"

"${ROOT}/scripts/install-tools.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found. Ubuntu: sudo apt-get install -y docker.io" >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker engine not reachable. Start it: sudo systemctl start docker" >&2
  echo "If permission denied, run: sudo usermod -aG docker \$USER && newgrp docker" >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster ${CLUSTER_NAME} already exists"
else
  echo "Creating kind cluster (kubeadm) ${CLUSTER_NAME} ..."
  # 嵌套/受限环境上 kubeadm 可能较慢，适当拉长等待
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}" --wait 300s
fi

echo "Building kubedelta-extender image ..."
arch="$(uname -m)"
case "${arch}" in
  arm64|aarch64) buildarch=arm64 ;;
  x86_64|amd64) buildarch=amd64 ;;
  *) echo "unsupported arch: ${arch}" >&2; exit 1 ;;
esac
docker build --build-arg TARGETARCH="${buildarch}" -t "${IMAGE}" "${ROOT}"

echo "Loading image into kind ..."
kind load docker-image "${IMAGE}" --name "${CLUSTER_NAME}"

kubectl config use-context "kind-${CLUSTER_NAME}"

echo "Deploying kubedelta components ..."
kubectl apply -f "${ROOT}/deploy/00-namespace.yaml"
kubectl apply -f "${ROOT}/deploy/10-rbac-scheduler.yaml"
kubectl apply -f "${ROOT}/deploy/20-scheduler.yaml"
kubectl apply -f "${ROOT}/deploy/30-mock-oms.yaml"
kubectl apply -f "${ROOT}/deploy/40-demo-workload.yaml"
kubectl apply -f "${ROOT}/deploy/51-metrics-server.yaml"
kubectl apply -f "${ROOT}/deploy/50-hpa.yaml"

kubectl -n kube-system rollout status deploy/kubedelta-scheduler --timeout=180s
kubectl -n kube-system rollout status deploy/kubedelta-extender --timeout=180s
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

kubectl get nodes -L nodepool.kubedelta.io/name,kubedelta.io/tolerance
echo ""
echo "Cluster ready. Context: kind-${CLUSTER_NAME}"
echo "Verify:  make verify"
echo "Scale node pool (lamby sim): bash scripts/simulate-lamby-scale.sh pool-c"
