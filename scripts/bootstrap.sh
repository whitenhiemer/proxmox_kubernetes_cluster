#!/usr/bin/env bash
# bootstrap.sh - Generate Talos configs, apply them, and bootstrap the cluster
#
# Prerequisites:
#   - talosctl installed
#   - VMs created and booted from Talos ISO (via Terraform)
#   - Network connectivity to VM IPs
#
# Usage: ./scripts/bootstrap.sh
set -euo pipefail

# --- Configuration (override via environment or edit here) ---
CLUSTER_NAME="${CLUSTER_NAME:-talos-proxmox}"
CLUSTER_VIP="${CLUSTER_VIP:?Set CLUSTER_VIP to your API server VIP}"
TALOS_VERSION="${TALOS_VERSION:-v1.9.0}"
CONTROLPLANE_IPS="${CONTROLPLANE_IPS:?Set CONTROLPLANE_IPS as comma-separated list}"
WORKER_IPS="${WORKER_IPS:?Set WORKER_IPS as comma-separated list}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TALOS_DIR="${REPO_ROOT}/talos"
OUTPUT_DIR="${TALOS_DIR}/_out"

# --- Functions ---
log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- Generate configs ---
log "Generating Talos machine configs for cluster '${CLUSTER_NAME}'"
mkdir -p "${OUTPUT_DIR}"

# Export vars for envsubst in patch files
export CLUSTER_VIP TALOS_VERSION

# Generate base configs with patches
talosctl gen config "${CLUSTER_NAME}" "https://${CLUSTER_VIP}:6443" \
  --config-patch @"${TALOS_DIR}/patches/controlplane.yaml" \
  --config-patch-worker @"${TALOS_DIR}/patches/worker.yaml" \
  --output-dir "${OUTPUT_DIR}" \
  --force

log "Configs generated in ${OUTPUT_DIR}"

# --- Apply control plane configs ---
IFS=',' read -ra CP_NODES <<< "${CONTROLPLANE_IPS}"
for i in "${!CP_NODES[@]}"; do
  ip="${CP_NODES[$i]}"
  log "Applying controlplane config to ${ip}"
  talosctl apply-config \
    --insecure \
    --nodes "${ip}" \
    --file "${OUTPUT_DIR}/controlplane.yaml"
done

# --- Apply worker configs ---
IFS=',' read -ra WORKER_NODES <<< "${WORKER_IPS}"
for i in "${!WORKER_NODES[@]}"; do
  ip="${WORKER_NODES[$i]}"
  log "Applying worker config to ${ip}"
  talosctl apply-config \
    --insecure \
    --nodes "${ip}" \
    --file "${OUTPUT_DIR}/worker.yaml"
done

# --- Wait for nodes to be ready ---
log "Waiting for nodes to finish installing..."
sleep 30

# --- Bootstrap the cluster ---
FIRST_CP="${CP_NODES[0]}"
log "Bootstrapping etcd on ${FIRST_CP}"

# Set talosconfig
export TALOSCONFIG="${OUTPUT_DIR}/talosconfig"
talosctl config endpoint "${FIRST_CP}"
talosctl config node "${FIRST_CP}"

talosctl bootstrap --nodes "${FIRST_CP}"

log "Bootstrap initiated. Waiting for Kubernetes API..."
sleep 60

# --- Retrieve kubeconfig ---
log "Fetching kubeconfig"
talosctl kubeconfig "${OUTPUT_DIR}/kubeconfig" \
  --nodes "${FIRST_CP}" \
  --force

log "======================================"
log "Cluster bootstrap complete!"
log "======================================"
log ""
log "Talos config:  ${OUTPUT_DIR}/talosconfig"
log "Kubeconfig:    ${OUTPUT_DIR}/kubeconfig"
log ""
log "Next steps:"
log "  export TALOSCONFIG=${OUTPUT_DIR}/talosconfig"
log "  export KUBECONFIG=${OUTPUT_DIR}/kubeconfig"
log "  kubectl get nodes"
log "  talosctl health --nodes ${FIRST_CP}"
