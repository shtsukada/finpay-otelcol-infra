#!/usr/bin/env bash
set -euo pipefail

# config
KUBECONFIG_OUT="./kubeconfig"
REMOTE_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
SSH_USER="ubuntu"

# default key
DEFAULT_KEY_PATH="${HOME}/.ssh/finpay-otelcol-dev.pem"

# args
EIP="${1:-}"
KEY_PATH="${2:-$DEFAULT_KEY_PATH}"

if [[ -z "$EIP" ]]; then
  echo "Usage: $0 <EIP_PUBLIC_IP> [SSH_KEY_PATH]"
  echo "Example: $0 203.0.113.10 ${DEFAULT_KEY_PATH}"
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "[ERROR] SSH key not found: ${KEY_PATH}"
  exit 1
fi

# security: restrict file permission (600)
umask 077

SSH_OPTS=(
  -i "${KEY_PATH}"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
)

echo "[INFO] Fetching kubeconfig from ${SSH_USER}@${EIP} using key ${KEY_PATH}"

ssh "${SSH_OPTS[@]}" "${SSH_USER}@${EIP}" -- sudo cat "$REMOTE_KUBECONFIG" \
  | sed -E "s#^([[:space:]]*server:[[:space:]]*)https://127\.0\.0\.1:6443#\1https://${EIP}:6443#" \
  > "${KUBECONFIG_OUT}"

echo "[INFO] kubeconfig written to ${KUBECONFIG_OUT}"
echo
echo "Next steps:"
echo "export KUBECONFIG=$(pwd)/${KUBECONFIG_OUT}"
echo "kubectl get ns"
