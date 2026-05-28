#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"

echo "== nodes (nodepool / tolerance) =="
kubectl get nodes -L nodepool.kubedelta.io/name,kubedelta.io/tolerance

echo ""
echo "== kubedelta control plane =="
kubectl -n kube-system get deploy kubedelta-scheduler kubedelta-extender
kubectl -n kube-system rollout status deploy/kubedelta-scheduler --timeout=60s
kubectl -n kube-system rollout status deploy/kubedelta-extender --timeout=60s

echo ""
echo "== demo workloads =="
kubectl -n kubedelta-system get deploy,pod,hpa

echo ""
echo "== scheduling audit (task-id after bind) =="
kubectl -n kubedelta-system get pods -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
SCHEDULER:.spec.schedulerName,\
TASK:.metadata.annotations.kubedelta\\.io/task-id,\
POOL:.metadata.annotations.kubedelta\\.io/nodepool

echo ""
echo "== HPA / metrics (may take ~1min after metrics-server ready) =="
kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s 2>/dev/null || true
kubectl -n kubedelta-system describe hpa demo-app 2>/dev/null | sed -n '1,25p' || echo "(HPA not applied)"

echo ""
echo "OK — cluster verification finished."
