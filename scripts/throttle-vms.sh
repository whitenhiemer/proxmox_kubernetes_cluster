#!/bin/bash
# throttle-vms.sh - Apply IOPS throttling to all VMs in the cluster
# Targets scsi0 and virtio0 devices with conservative limits.

# Standard Limits
DEFAULT_IOPS=1000
TALOS_IOPS=200
TRUENAS_IOPS=2000

# Proxmox Nodes
NODES=("192.168.86.29" "192.168.86.30" "192.168.86.31" "192.168.86.130" "192.168.86.147")
SSH_KEY="$HOME/.ssh/id_ansible"

for node in "${NODES[@]}"; do
    echo "--- Checking node $node ---"
    # Get list of running VMs
    vms=$(ssh -i $SSH_KEY -o BatchMode=yes root@$node "qm list | awk 'NR>1 {print \$1}'")
    
    for vmid in $vms; do
        # Determine limits
        limit=$DEFAULT_IOPS
        if [[ "$vmid" == "300" ]]; then
            limit=$TRUENAS_IOPS
        elif [[ "$vmid" =~ ^4[0-9]{2}$ ]]; then
            limit=$TALOS_IOPS
        fi
        
        echo "Throttling VM $vmid to $limit IOPS..."
        
        # Extract scsi0 or virtio0 full line
        config=$(ssh -i $SSH_KEY root@$node "qm config $vmid")
        
        scsi0=$(echo "$config" | grep "^scsi0:" | awk '{print $2}')
        if [ ! -z "$scsi0" ]; then
            # Remove any existing iops_rd/wr/iothread from the string to avoid duplicates
            clean_scsi0=$(echo "$scsi0" | sed -E 's/,iops_(rd|wr)=[0-9]+//g' | sed -E 's/,iothread=[01]//g')
            ssh -i $SSH_KEY root@$node "qm set $vmid -scsi0 ${clean_scsi0},iops_rd=$limit,iops_wr=$limit,iothread=1"
        fi
        
        virtio0=$(echo "$config" | grep "^virtio0:" | awk '{print $2}')
        if [ ! -z "$virtio0" ]; then
            clean_virtio0=$(echo "$virtio0" | sed -E 's/,iops_(rd|wr)=[0-9]+//g' | sed -E 's/,iothread=[01]//g')
            ssh -i $SSH_KEY root@$node "qm set $vmid -virtio0 ${clean_virtio0},iops_rd=$limit,iops_wr=$limit,iothread=1"
        fi
    done
done
