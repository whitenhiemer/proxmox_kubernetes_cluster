# Proxmox Kubernetes Cluster

Homelab infrastructure for [woodhead.tech](https://woodhead.tech) -- a Talos Linux Kubernetes cluster, LXC services, and automated DNS/TLS on Proxmox VE.

## Architecture

```
Internet -> [Router :80/:443] -> Traefik LXC (10.0.0.20)
                                    |
                    +---------------+---------------+
                    |                               |
            Recipe Site LXC              K8s VIP (10.0.0.100)
            (10.0.0.21:80)              (talos-proxmox cluster)
                    |
            Future LXCs...
```

- **Proxmox VE 8.x** -- 2-3 node cluster with Ceph storage
- **Talos Linux** -- immutable, API-driven Kubernetes OS (no SSH)
- **Terraform** (bpg/proxmox provider) -- provisions VMs and LXC containers
- **Ansible** -- configures Proxmox hosts, Traefik, and services
- **Traefik** -- reverse proxy + TLS termination (Let's Encrypt via Cloudflare DNS-01)
- **Cloudflare** -- DNS authority for woodhead.tech (free tier, DDNS-friendly API)

Default K8s topology: 1 control plane + 2 workers. Configurable via `terraform.tfvars`.

## Prerequisites

- Proxmox VE 8.x cluster with Ceph storage
- Cloudflare account (free) with woodhead.tech DNS
- API token for Proxmox (User > API Tokens)
- Local tools:
  - [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
  - [talosctl](https://www.talos.dev/v1.9/introduction/getting-started/#talosctl)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/)

## Quick Start

See [docs/RUNBOOK.md](docs/RUNBOOK.md) for the full step-by-step deployment guide.

```bash
# 1. Configure
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
vim terraform/terraform.tfvars
vim ansible/inventory/hosts.yml

# 2. Proxmox base setup + DDNS
make setup
make prepare
make ddns

# 3. Create all infrastructure
make init && make apply

# 4. Configure services
make traefik
make recipe-site

# 5. Bootstrap Kubernetes
export CLUSTER_VIP="10.0.0.100"
export CONTROLPLANE_IPS="10.0.0.101"
export WORKER_IPS="10.0.0.111,10.0.0.112"
make bootstrap

# 6. Verify
export KUBECONFIG=talos/_out/kubeconfig
kubectl get nodes
curl https://recipes.woodhead.tech

# 7. Harden
make harden
```

## Makefile Targets

| Target           | Phase | Description                                    |
|------------------|-------|------------------------------------------------|
| `setup`          | 0     | Verify/configure Proxmox hosts (run once)      |
| `prepare`        | 0     | Download Talos ISO to Proxmox                  |
| `ddns`           | 1     | Deploy Cloudflare DDNS updater                 |
| `init`           | --    | Initialize Terraform providers                 |
| `plan`           | --    | Preview all Terraform changes                  |
| `apply`          | --    | Create/update all VMs + LXCs                   |
| `plan-lxc`       | --    | Preview LXC changes only                       |
| `apply-lxc`      | --    | Create/update LXC containers only              |
| `traefik`        | 2     | Configure Traefik reverse proxy                |
| `recipe-site`    | 3     | Deploy recipe site into its LXC                |
| `bootstrap`      | 4     | Generate Talos configs and bootstrap K8s       |
| `kubeconfig`     | 4     | Fetch kubeconfig from running cluster          |
| `health`         | 4     | Check K8s cluster health via talosctl          |
| `k8s-base`       | 4     | Apply base K8s manifests (namespaces)          |
| `k8s-base-metallb`| 4   | Apply base manifests + MetalLB                 |
| `harden`         | 5     | Security hardening (SSH, firewall, fail2ban)   |
| `destroy`        | --    | Tear down K8s VMs and clean configs            |
| `clean`          | --    | Remove generated Talos configs only            |

## Project Structure

```
.
├── Makefile                              # Workflow orchestration
├── docs/
│   └── RUNBOOK.md                        # Step-by-step deployment guide
├── terraform/
│   ├── versions.tf                       # Provider config (bpg/proxmox)
│   ├── variables.tf                      # K8s VM variables
│   ├── lxc-variables.tf                  # LXC container variables
│   ├── control-plane.tf                  # Talos CP VM definitions
│   ├── workers.tf                        # Talos worker VM definitions
│   ├── lxc-traefik.tf                    # Traefik reverse proxy LXC
│   ├── lxc-recipe-site.tf               # Recipe site LXC
│   ├── outputs.tf                        # Infrastructure outputs
│   └── terraform.tfvars.example          # Configuration template
├── talos/
│   ├── talconfig.yaml                    # Cluster topology reference
│   └── patches/
│       ├── controlplane.yaml             # CP-specific Talos patches
│       └── worker.yaml                   # Worker-specific Talos patches
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.yml               # Multi-group inventory
│   ├── playbooks/
│   │   ├── setup-proxmox-base.yml        # Proxmox verification + base config
│   │   ├── prepare-proxmox.yml           # Download Talos ISO
│   │   ├── setup-ddns.yml                # Deploy DDNS updater
│   │   ├── setup-traefik.yml             # Configure Traefik
│   │   ├── setup-recipe-site.yml         # Deploy recipe site
│   │   └── harden-proxmox.yml            # Security hardening
│   └── files/
│       └── traefik/
│           ├── traefik.yml               # Traefik static config
│           └── dynamic/
│               ├── recipe-site.yml       # Route: recipes.woodhead.tech
│               ├── k8s-ingress.yml       # Route: *.woodhead.tech -> K8s
│               └── dashboard.yml         # Route: traefik.woodhead.tech
├── k8s/
│   └── base/
│       ├── namespace.yml                 # Base namespaces
│       └── metallb/                      # MetalLB LoadBalancer support
│           ├── namespace.yml
│           ├── ip-pool.yml               # IP range: 10.0.0.150-199
│           └── metallb-install.yml       # Installation reference
└── scripts/
    ├── bootstrap.sh                      # Talos config gen + cluster bootstrap
    ├── destroy.sh                        # Teardown with confirmation
    ├── apply-k8s-base.sh                 # Apply base K8s manifests
    └── ddns/
        ├── cloudflare-ddns.sh            # DDNS updater script
        └── cloudflare.env.example        # Cloudflare credentials template
```

## Adding New Services

### New LXC Service

1. Create `terraform/lxc-<name>.tf` with a `proxmox_virtual_environment_container` resource
2. Add variables to `terraform/lxc-variables.tf`
3. Add Traefik route in `ansible/files/traefik/dynamic/<name>.yml`
4. Create Ansible playbook in `ansible/playbooks/setup-<name>.yml`
5. Add host to `ansible/inventory/hosts.yml` under `lxc_services`
6. Run `make apply` then `make traefik`

### New K8s Workload

1. Add manifests to `k8s/<app>/`
2. Uncomment the K8s catch-all route in `ansible/files/traefik/dynamic/k8s-ingress.yml`
3. Run `make traefik` to update routing

## Scaling K8s

Update `terraform.tfvars`:
```hcl
controlplane_count = 3
controlplane_ips   = ["10.0.0.101", "10.0.0.102", "10.0.0.103"]

worker_count = 5
worker_ips   = ["10.0.0.111", "10.0.0.112", "10.0.0.113", "10.0.0.114", "10.0.0.115"]
```

Then `make apply` and `make bootstrap`.

## Migrating to kubeadm

If Talos doesn't fit your needs, the Terraform VM configs can be reused with a standard Ubuntu/Debian cloud image. Swap the `cdrom` block for a `clone` from a cloud-init template and add Ansible roles for kubeadm setup.
