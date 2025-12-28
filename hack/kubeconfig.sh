#!/usr/bin/env bash
set -euo pipefail

IP="${1:-}"
if [[ -z "$IP" ]]; then
  echo "Usage: $0 <EC2_PUBLIC_IP>"
  exit 1
fi

ssh -o StrictHostKeyChecking=no ubuntu@"${IP}" "sudo cat /etc/rancher/k3s/k3s.yaml" \
  | sed "s/127.0.0.1/${IP}/" > ./kubeconfig

echo "Wrote ./kubeconfig"
echo "export KUBECONFIG=$(pwd)/kubeconfig"