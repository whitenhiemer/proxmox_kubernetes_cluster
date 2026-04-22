# Makefile - Workflow orchestration for Talos Kubernetes on Proxmox
#
# Usage:
#   make prepare     - Download Talos ISO to Proxmox
#   make init        - Initialize Terraform
#   make plan        - Preview VM changes
#   make apply       - Create/update VMs on Proxmox
#   make bootstrap   - Generate Talos configs and bootstrap K8s
#   make kubeconfig  - Fetch kubeconfig from the cluster
#   make health      - Check cluster health via talosctl
#   make destroy     - Tear down everything

.PHONY: prepare init plan apply bootstrap kubeconfig health destroy clean help

TERRAFORM_DIR := terraform
TALOS_DIR := talos
ANSIBLE_DIR := ansible
SCRIPTS_DIR := scripts
TALOS_OUT := $(TALOS_DIR)/_out

# Load terraform.tfvars values if available
-include .env

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

prepare: ## Download Talos ISO to Proxmox host
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/prepare-proxmox.yml

init: ## Initialize Terraform providers
	cd $(TERRAFORM_DIR) && terraform init

plan: ## Preview Terraform changes
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## Create/update VMs on Proxmox
	cd $(TERRAFORM_DIR) && terraform apply

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

destroy: ## Tear down VMs and clean generated configs
	chmod +x $(SCRIPTS_DIR)/destroy.sh
	./$(SCRIPTS_DIR)/destroy.sh

clean: ## Remove generated Talos configs (does not destroy VMs)
	rm -rf $(TALOS_OUT)
	@echo "Cleaned generated configs."
