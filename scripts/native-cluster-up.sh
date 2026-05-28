#!/usr/bin/env bash
# 宿主机 kubeadm 单控制面集群（Ubuntu 原生，无 kind 嵌套）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"
IMAGE="kubedelta-extender:dev"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
CLUSTER_NAME="${CLUSTER_NAME:-kubedelta}"

"${ROOT}/scripts/install-tools.sh"
"${ROOT}/scripts/install-k8s.sh"
"${ROOT}/scripts/install-cri-docker.sh"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "docker required to build extender image" >&2
  exit 1
fi

if [[ -f /etc/kubernetes/admin.conf ]] && ! kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes >/dev/null 2>&1; then
  echo "Previous kubeadm init incomplete, resetting ..."
  sudo kubeadm reset -f
fi

if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  echo "Running kubeadm init (cri-dockerd) ..."
  sudo kubeadm init \
    --kubernetes-version="${K8S_VERSION:-v1.31.4}" \
    --pod-network-cidr="${POD_CIDR}" \
    --service-dns-domain=cluster.local \
    --cri-socket=unix:///var/run/cri-dockerd.sock \
    --ignore-preflight-errors=SystemVerification

  mkdir -p "${HOME}/.kube"
  sudo cp -f /etc/kubernetes/admin.conf "${HOME}/.kube/config"
  sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"
else
  echo "kubeadm cluster already initialized, reusing admin.conf"
  mkdir -p "${HOME}/.kube"
  if [[ ! -f "${HOME}/.kube/config" ]]; then
    sudo cp -f /etc/kubernetes/admin.conf "${HOME}/.kube/config"
    sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"
  fi
fi

export KUBECONFIG="${HOME}/.kube/config"

if ! kubectl get ns kube-flannel >/dev/null 2>&1; then
  echo "Installing Flannel CNI ..."
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
fi

echo "Waiting for node Ready ..."
kubectl wait --for=condition=Ready node --all --timeout=300s

# 单节点测试：允许在 control-plane 上调度
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true

NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
kubectl label node "${NODE}" \
  nodepool.kubedelta.io/name=pool-a \
  kubedelta.io/tolerance=true \
  --overwrite

echo "Building extender image (cri-dockerd uses local Docker images) ..."
arch="$(uname -m)"
case "${arch}" in
  arm64|aarch64) buildarch=arm64 ;;
  x86_64|amd64) buildarch=amd64 ;;
  *) echo "unsupported arch: ${arch}" >&2; exit 1 ;;
esac
docker build --build-arg TARGETARCH="${buildarch}" -t "${IMAGE}" "${ROOT}"

echo "Deploying kubedelta ..."
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
echo "Native kubeadm cluster ready (context: $(kubectl config current-context))"
