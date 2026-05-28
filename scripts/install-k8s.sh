#!/usr/bin/env bash
# 在 Ubuntu 上安装 kubeadm / kubelet / kubectl（与集群版本 v1.31 对齐）
set -euo pipefail

K8S_VERSION="${K8S_VERSION:-v1.31}"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-k8s.sh 仅支持 Debian/Ubuntu" >&2
  exit 1
fi

if swapon --show | grep -q .; then
  echo "Disabling swap (kubeadm 要求) ..."
  sudo swapoff -a
  sudo sed -i.bak-kubedelta '/ swap / s/^\(.*\)$/#\1/' /etc/fstab || true
fi

sudo apt-get install -y -qq conntrack ethtool socat 2>/dev/null || true

if ! command -v kubeadm >/dev/null 2>&1; then
  echo "Adding Kubernetes apt repo (${K8S_VERSION}) ..."
  if ! command -v gpg >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq gnupg ca-certificates curl
  fi
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update -qq
  sudo apt-get install -y -qq kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
else
  echo "kubeadm already installed: $(kubeadm version -o short 2>/dev/null || kubeadm version)"
fi

if ! command -v containerd >/dev/null 2>&1; then
  sudo apt-get install -y -qq containerd
fi

if [[ ! -f /etc/containerd/config.toml ]]; then
  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
fi

sudo systemctl enable --now containerd
sudo systemctl enable kubelet

echo "Kubernetes packages ready."
