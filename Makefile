# Makefile - Workflow orchestration for Proxmox homelab infrastructure
#
# Full lifecycle for a Talos Kubernetes cluster + LXC services on Proxmox.
# Domain: woodhead.tech | DNS: Cloudflare | TLS: Let's Encrypt via Traefik
#
# Deploy order (from fresh Proxmox):
#   make setup          - Verify Proxmox base config
#   make prepare        - Download Talos, TrueNAS ISOs
#   make ddns           - Deploy DDNS updater
#   make init           - Initialize Terraform
#   make apply          - Create all VMs + LXC containers
#   make traefik        - Configure Traefik reverse proxy
#   make recipe-site    - Deploy recipe site
#   make arr-stack      - Deploy ARR media stack
#   make monitoring     - Deploy monitoring stack
#   make openclaw       - Deploy OpenClaw AI agent
#   make authelia       - Deploy Authelia SSO gateway
#   make wireguard      - Deploy WireGuard VPN tunnel
#   make bootstrap      - Bootstrap Talos K8s cluster
#   make k8s-base       - Apply base K8s manifests
#   make harden         - Security hardening

.PHONY: setup prepare prepare-truenas ddns init plan apply \
        apply-truenas apply-homeassistant apply-lxc plan-lxc \
        traefik recipe-site arr-stack plex jellyfin monitoring openclaw authelia wireguard \
        bootstrap kubeconfig health k8s-base harden \
        patch-proxmox patch-lxc patch-docker destroy clean help

TERRAFORM_DIR := terraform
TALOS_DIR := talos
ANSIBLE_DIR := ansible
SCRIPTS_DIR := scripts
K8S_DIR := k8s
TALOS_OUT := $(TALOS_DIR)/_out

# Load environment overrides if available
-include .env

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ===== Phase 0: Proxmox Base Setup =====

setup: ## Verify and configure Proxmox hosts (run once after fresh install)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-proxmox-base.yml

prepare: ## Download Talos ISO to Proxmox host
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/prepare-proxmox.yml

prepare-truenas: ## Download TrueNAS Scale ISO to Proxmox host
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/prepare-truenas.yml

# ===== Phase 1: DDNS =====

ddns: ## Deploy Cloudflare DDNS updater to Proxmox host
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-ddns.yml

# ===== Terraform (VMs + LXCs) =====

init: ## Initialize Terraform providers
	cd $(TERRAFORM_DIR) && terraform init

plan: ## Preview all Terraform changes (VMs + LXCs)
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## Create/update all infrastructure (VMs + LXCs)
	cd $(TERRAFORM_DIR) && terraform apply

apply-truenas: ## Create TrueNAS NAS VM only (pass through data disks separately)
	cd $(TERRAFORM_DIR) && terraform apply \
		-target=proxmox_virtual_environment_vm.truenas

apply-homeassistant: ## Create Home Assistant VM (HAOS image must be pre-downloaded)
	cd $(TERRAFORM_DIR) && terraform apply \
		-target=proxmox_virtual_environment_vm.homeassistant

plan-lxc: ## Preview LXC container changes only
	cd $(TERRAFORM_DIR) && terraform plan \
		-target=proxmox_virtual_environment_container.traefik \
		-target=proxmox_virtual_environment_container.recipe_site \
		-target=proxmox_virtual_environment_container.arr \
		-target=proxmox_virtual_environment_container.plex \
		-target=proxmox_virtual_environment_container.jellyfin \
		-target=proxmox_virtual_environment_container.monitoring \
		-target=proxmox_virtual_environment_container.openclaw \
		-target=proxmox_virtual_environment_container.authelia \
		-target=proxmox_virtual_environment_container.wireguard \
		-target=proxmox_virtual_environment_container.libby_alert

apply-lxc: ## Create/update LXC containers only
	cd $(TERRAFORM_DIR) && terraform apply \
		-target=proxmox_virtual_environment_container.traefik \
		-target=proxmox_virtual_environment_container.recipe_site \
		-target=proxmox_virtual_environment_container.arr \
		-target=proxmox_virtual_environment_container.plex \
		-target=proxmox_virtual_environment_container.jellyfin \
		-target=proxmox_virtual_environment_container.monitoring \
		-target=proxmox_virtual_environment_container.openclaw \
		-target=proxmox_virtual_environment_container.authelia \
		-target=proxmox_virtual_environment_container.wireguard \
		-target=proxmox_virtual_environment_container.libby_alert

# ===== Phase 2-3: LXC Services =====

traefik: ## Configure Traefik reverse proxy in its LXC
	@# Source Cloudflare token from DDNS env file (same token used for DNS-01 ACME)
	@if [ ! -f $(SCRIPTS_DIR)/ddns/cloudflare.env ]; then \
		echo "Error: scripts/ddns/cloudflare.env not found. Run 'make ddns' first."; \
		exit 1; \
	fi
	. $(SCRIPTS_DIR)/ddns/cloudflare.env && cd $(ANSIBLE_DIR) && \
		ansible-playbook playbooks/setup-traefik.yml \
		--extra-vars "cf_api_token=$$CF_API_TOKEN acme_email=admin@woodhead.tech"

recipe-site: ## Deploy recipe site into its LXC
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-recipe-site.yml

arr-stack: ## Deploy ARR media stack (Sonarr, Radarr, Prowlarr, etc.) into its LXC
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-arr-stack.yml

plex: ## Deploy Plex Media Server into its LXC (with iGPU passthrough)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-plex.yml

jellyfin: ## Deploy Jellyfin Media Server into its LXC (with iGPU passthrough)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-jellyfin.yml

monitoring: ## Deploy monitoring stack (Prometheus, Grafana, Alertmanager) into its LXC
	@# Usage: make monitoring DISCORD_WEBHOOK=https://... GRAFANA_PASSWORD=... PVE_USER=monitoring@pve PVE_TOKEN_NAME=prometheus PVE_TOKEN_VALUE=...
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-monitoring.yml \
		$(if $(DISCORD_WEBHOOK),--extra-vars "discord_webhook=$(DISCORD_WEBHOOK)") \
		$(if $(GRAFANA_PASSWORD),--extra-vars "grafana_password=$(GRAFANA_PASSWORD)") \
		$(if $(PVE_USER),--extra-vars "pve_user=$(PVE_USER) pve_token_name=$(PVE_TOKEN_NAME) pve_token_value=$(PVE_TOKEN_VALUE)")

openclaw: ## Deploy OpenClaw AI agent framework into its LXC
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-openclaw.yml

authelia: ## Deploy Authelia SSO gateway into its LXC
	@if [ -z "$(AUTHELIA_ADMIN_PASSWORD)" ]; then \
		echo "Error: AUTHELIA_ADMIN_PASSWORD is required. Usage: make authelia AUTHELIA_ADMIN_PASSWORD=..."; \
		exit 1; \
	fi
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-authelia.yml \
		--extra-vars "authelia_admin_password=$(AUTHELIA_ADMIN_PASSWORD)"

wireguard: ## Deploy WireGuard VPN tunnel into its LXC
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-wireguard.yml

libby-alert: ## Deploy Libby life alert QR website into its LXC
	@if [ -z "$(TWILIO_SID)" ] || [ -z "$(TWILIO_TOKEN)" ] || [ -z "$(TWILIO_FROM)" ] || [ -z "$(ALERT_PHONES)" ]; then \
		echo "Error: Required vars: TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM, ALERT_PHONES"; \
		echo "Usage: make libby-alert TWILIO_SID=ACxxx TWILIO_TOKEN=xxx TWILIO_FROM=+1xxx ALERT_PHONES=+1xxx,+1yyy DISCORD_WEBHOOK=https://..."; \
		exit 1; \
	fi
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/setup-libby-alert.yml \
		--extra-vars "twilio_account_sid=$(TWILIO_SID) twilio_auth_token=$(TWILIO_TOKEN) \
		twilio_from_number=$(TWILIO_FROM) alert_phone_numbers=$(ALERT_PHONES) \
		$(if $(DISCORD_WEBHOOK),discord_webhook=$(DISCORD_WEBHOOK)) \
		$(if $(COOLDOWN),alert_cooldown_minutes=$(COOLDOWN))"

# ===== Phase 4: Talos K8s Cluster =====

bootstrap: ## Generate Talos configs and bootstrap the cluster
	chmod +x $(SCRIPTS_DIR)/bootstrap.sh
	./$(SCRIPTS_DIR)/bootstrap.sh

kubeconfig: ## Fetch kubeconfig from the running cluster
	@if [ ! -f "$(TALOS_OUT)/talosconfig" ]; then \
		echo "Error: No talosconfig found. Run 'make bootstrap' first."; \
		exit 1; \
	fi
	TALOSCONFIG=$(TALOS_OUT)/talosconfig talosctl kubeconfig $(TALOS_OUT)/kubeconfig --force
	@echo "Kubeconfig written to $(TALOS_OUT)/kubeconfig"

health: ## Check cluster health
	@if [ ! -f "$(TALOS_OUT)/talosconfig" ]; then \
		echo "Error: No talosconfig found. Run 'make bootstrap' first."; \
		exit 1; \
	fi
	TALOSCONFIG=$(TALOS_OUT)/talosconfig talosctl health

k8s-base: ## Apply base K8s manifests (namespaces, optional MetalLB)
	chmod +x $(SCRIPTS_DIR)/apply-k8s-base.sh
	./$(SCRIPTS_DIR)/apply-k8s-base.sh

k8s-base-metallb: ## Apply base K8s manifests with MetalLB
	chmod +x $(SCRIPTS_DIR)/apply-k8s-base.sh
	./$(SCRIPTS_DIR)/apply-k8s-base.sh --with-metallb

# ===== Patching =====

patch-proxmox: ## Patch Proxmox VE hosts (serial, one at a time)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/patch-proxmox.yml

patch-lxc: ## Patch Debian packages on all LXC containers
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/patch-lxc.yml

patch-docker: ## Pull latest Docker images and restart all stacks
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/patch-docker.yml

# ===== Phase 5: Security =====

harden: ## Apply security hardening to Proxmox hosts
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/harden-proxmox.yml

# ===== Teardown =====

destroy: ## Tear down VMs and clean generated configs
	chmod +x $(SCRIPTS_DIR)/destroy.sh
	./$(SCRIPTS_DIR)/destroy.sh

clean: ## Remove generated Talos configs (does not destroy VMs)
	rm -rf $(TALOS_OUT)
	@echo "Cleaned generated configs."
