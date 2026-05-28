#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"

CLUSTER_NAME="${CLUSTER_NAME:-kubedelta}"
KIND_CONFIG="${ROOT}/cluster/kind-config.yaml"
IMAGE="kubedelta-extender:dev"

"${ROOT}/scripts/install-tools.sh"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start OrbStack/Docker Desktop first." >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster ${CLUSTER_NAME} already exists"
else
  echo "Creating kind cluster (kubeadm) ${CLUSTER_NAME} ..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}" --wait 120s
fi

echo "Building kubedelta-extender image ..."
docker build -t "${IMAGE}" "${ROOT}"

echo "Loading image into kind ..."
kind load docker-image "${IMAGE}" --name "${CLUSTER_NAME}"

kubectl config use-context "kind-${CLUSTER_NAME}"

echo "Deploying kubedelta components ..."
kubectl apply -f "${ROOT}/deploy/00-namespace.yaml"
kubectl apply -f "${ROOT}/deploy/10-rbac-scheduler.yaml"
kubectl apply -f "${ROOT}/deploy/20-scheduler.yaml"
kubectl apply -f "${ROOT}/deploy/30-mock-oms.yaml"
kubectl apply -f "${ROOT}/deploy/40-demo-workload.yaml"

kubectl -n kube-system rollout status deploy/kubedelta-scheduler --timeout=180s
kubectl get nodes -L nodepool.kubedelta.io/name,kubedelta.io/tolerance
echo ""
echo "Cluster ready. Context: kind-${CLUSTER_NAME}"
echo "Verify: kubectl -n kubedelta-system get pods -o wide"
echo "Task IDs: kubectl -n kubedelta-system get pods -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{.metadata.annotations.kubedelta\\.io/task-id}{\"\\n\"}{end}'"
