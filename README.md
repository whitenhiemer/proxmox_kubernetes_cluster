# Proxmox Kubernetes Cluster

Deploy a [Talos Linux](https://www.talos.dev/) Kubernetes cluster on Proxmox VE using Terraform and Ansible.

## Architecture

- **Talos Linux** -- immutable, API-driven Kubernetes OS (no SSH)
- **Terraform** (bpg/proxmox provider) -- provisions VMs on Proxmox with Ceph storage
- **Ansible** -- prepares Proxmox hosts (downloads Talos ISO)
- **talosctl** -- configures and bootstraps the Kubernetes cluster

Default topology: 1 control plane + 2 workers. Configurable via `terraform.tfvars`.

## Prerequisites

- Proxmox VE 8.x with Ceph storage configured
- API token for Proxmox (User > API Tokens in the Proxmox UI)
- Local tools installed:
  - [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
  - [talosctl](https://www.talos.dev/v1.9/introduction/getting-started/#talosctl)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/)

## Quick Start

```bash
# 1. Download Talos ISO to Proxmox
#    Edit ansible/inventory/hosts.yml with your Proxmox host details first
make prepare

# 2. Configure Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your IPs, storage, and credentials

# 3. Create VMs
make init
make plan
make apply

# 4. Bootstrap Kubernetes
export CLUSTER_VIP="10.0.0.100"
export CONTROLPLANE_IPS="10.0.0.101"
export WORKER_IPS="10.0.0.111,10.0.0.112"
make bootstrap

# 5. Use the cluster
export KUBECONFIG=talos/_out/kubeconfig
kubectl get nodes
```

## Makefile Targets

| Target      | Description                                  |
|-------------|----------------------------------------------|
| `prepare`   | Download Talos ISO to Proxmox host           |
| `init`      | Initialize Terraform providers               |
| `plan`      | Preview Terraform changes                    |
| `apply`     | Create/update VMs on Proxmox                 |
| `bootstrap` | Generate Talos configs and bootstrap cluster |
| `kubeconfig`| Fetch kubeconfig from running cluster        |
| `health`    | Check cluster health via talosctl            |
| `destroy`   | Tear down VMs and clean configs              |
| `clean`     | Remove generated configs only                |

## Project Structure

```
.
├── Makefile                    # Workflow orchestration
├── terraform/
│   ├── versions.tf             # Provider config (bpg/proxmox)
│   ├── variables.tf            # Input variables
│   ├── control-plane.tf        # CP VM definitions
│   ├── workers.tf              # Worker VM definitions
│   ├── outputs.tf              # Useful outputs
│   └── terraform.tfvars.example
├── talos/
│   ├── talconfig.yaml          # Cluster topology reference
│   └── patches/
│       ├── controlplane.yaml   # CP-specific Talos patches
│       └── worker.yaml         # Worker-specific Talos patches
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.yml
│   └── playbooks/
│       └── prepare-proxmox.yml # Downloads Talos ISO
└── scripts/
    ├── bootstrap.sh            # Talos config generation + bootstrap
    └── destroy.sh              # Teardown with confirmation
```

## Scaling

To add more nodes, update `terraform.tfvars`:

```hcl
controlplane_count = 3
controlplane_ips   = ["10.0.0.101", "10.0.0.102", "10.0.0.103"]

worker_count = 5
worker_ips   = ["10.0.0.111", "10.0.0.112", "10.0.0.113", "10.0.0.114", "10.0.0.115"]
```

Then run `make apply` to create the VMs and re-run `make bootstrap` for the new nodes.

## Migrating to kubeadm

If Talos doesn't fit your needs, the Terraform configs can be reused with a standard Ubuntu/Debian cloud image instead of the Talos ISO. Swap the `cdrom` block for a `clone` from a cloud-init template and add Ansible roles for kubeadm setup.
