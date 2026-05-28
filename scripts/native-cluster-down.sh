#!/usr/bin/env bash
set -euo pipefail

if [[ -f /etc/kubernetes/admin.conf ]]; then
  echo "Running kubeadm reset ..."
  sudo kubeadm reset -f
fi
sudo rm -rf /etc/cni/net.d "$HOME/.kube/config" 2>/dev/null || true
echo "Native cluster removed."
