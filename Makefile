SHELL := /bin/bash
.DEFAULT_GOAL := help

ANSIBLE_DIR := ansible
TF_DIR      := terraform/cloudflared
TF          ?= terraform

.PHONY: help
help: ## Show available targets
	@grep -hE '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------------

.PHONY: secrets-check
secrets-check: ## Scan files that would be published for common secrets
	@echo "==> Scanning publishable files for secret patterns"
	@patterns='cfat_[A-Za-z0-9_-]+|ghp_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+|sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]+|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'; \
	if git ls-files -z --cached --others --exclude-standard | xargs -0 grep -InE "$$patterns" 2>/dev/null; then \
		echo "ERROR: possible secrets found in publishable files."; \
		exit 1; \
	fi
	@echo "==> Checking that local secret files are ignored"
	@for f in \
		terraform/cloudflared/terraform.tfvars \
		terraform/cloudflared/terraform.tfstate \
		ansible/.vault_pass \
		ansible/inventory/hosts.yml; do \
		if [ -e "$$f" ] && ! git check-ignore -q "$$f"; then \
			echo "ERROR: $$f exists but is not ignored."; \
			exit 1; \
		fi; \
	done
	@echo "OK: no obvious secrets in publishable files."

.PHONY: check
check: secrets-check tf-fmt-check tf-validate ansible-syntax-check ## Run all non-mutating checks

# ---------------------------------------------------------------------------
# Ansible
# ---------------------------------------------------------------------------

.PHONY: ansible-syntax-check
ansible-syntax-check: ## Check the Ansible playbook syntax
	cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check site.yml

.PHONY: ansible-ping
ansible-ping: ## Test connectivity to the servers
	cd $(ANSIBLE_DIR) && ansible servers -m ping

.PHONY: deploy
deploy: ## Apply the Ansible site playbook
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml

.PHONY: vault-edit
vault-edit: ## Edit the encrypted Ansible vault
	cd $(ANSIBLE_DIR) && ansible-vault edit group_vars/servers/vault.yml

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------

.PHONY: tf-init
tf-init: ## Initialize Terraform providers
	cd $(TF_DIR) && $(TF) init

.PHONY: tf-fmt
tf-fmt: ## Format Terraform files
	cd $(TF_DIR) && $(TF) fmt -recursive

.PHONY: tf-fmt-check
tf-fmt-check: ## Check Terraform formatting
	cd $(TF_DIR) && $(TF) fmt -check -recursive

.PHONY: tf-validate
tf-validate: ## Validate the Terraform configuration
	cd $(TF_DIR) && $(TF) validate

.PHONY: tf-plan
tf-plan: ## Show the Terraform plan (read-only)
	cd $(TF_DIR) && $(TF) plan

.PHONY: tf-apply
tf-apply: ## Apply the Terraform plan
	cd $(TF_DIR) && $(TF) apply

.PHONY: tf-output
tf-output: ## Show Terraform outputs
	cd $(TF_DIR) && $(TF) output

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

.PHONY: clean
clean: ## Remove local Terraform provider cache
	rm -rf $(TF_DIR)/.terraform
