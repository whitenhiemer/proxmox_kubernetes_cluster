#!/usr/bin/env bash
# destroy.sh - Tear down the Kubernetes cluster and Proxmox VMs
#
# Usage: ./scripts/destroy.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- Confirm ---
echo ""
echo "WARNING: This will destroy all cluster VMs and remove generated configs."
echo ""
read -r -p "Are you sure? (yes/no): " confirm
if [[ "${confirm}" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

# --- Terraform destroy ---
log "Destroying Proxmox VMs via Terraform"
cd "${REPO_ROOT}/terraform"
terraform destroy -auto-approve

# --- Clean generated configs ---
log "Removing generated Talos configs"
rm -rf "${REPO_ROOT}/talos/_out"

log "======================================"
log "Cluster destroyed."
log "======================================"
