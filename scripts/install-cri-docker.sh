#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker.io
fi

if ! command -v cri-dockerd >/dev/null 2>&1; then
  echo "Installing cri-dockerd v0.4.3 ..."
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/cri-dockerd.tgz" \
    "https://github.com/Mirantis/cri-dockerd/releases/download/v0.4.3/cri-dockerd-0.4.3.amd64.tgz"
  sudo tar xzf "${tmp}/cri-dockerd.tgz" -C /usr/local/bin cri-dockerd/cri-dockerd
  sudo chmod +x /usr/local/bin/cri-dockerd
  rm -rf "${tmp}"
fi

if [[ ! -f /etc/systemd/system/cri-docker.service ]]; then
  sudo tee /etc/systemd/system/cri-docker.service >/dev/null <<'EOF'
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --network-plugin=cni --pod-infra-container-image=registry.k8s.io/pause:3.10
Restart=always
RestartSec=5
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
  sudo tee /etc/systemd/system/cri-docker.socket >/dev/null <<'EOF'
[Unit]
Description=CRI Docker Socket for the API
Documentation=https://docs.mirantis.com

[Socket]
ListenStream=/var/run/cri-dockerd.sock
StreamProtocol=tcp

[Install]
WantedBy=sockets.target
EOF
fi

sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.socket cri-docker.service
echo "cri-dockerd ready at unix:///var/run/cri-dockerd.sock"
