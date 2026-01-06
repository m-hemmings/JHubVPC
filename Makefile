SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Files we generate
DC_GEN := docker-compose.generated.yml
HELM_GEN := helm/values.generated.yaml

# Defaults
DEFAULT_NS := jhub
DEFAULT_RELEASE := jhub

.PHONY: help setup env render images clean dc-up dc-down k8s-up k8s-down all-local all-k8s

help:
	@echo "Targets:"
	@echo "  make setup     - render templates + create/overwrite .env (with prompt)"
	@echo "  make images    - build images (uses .env)"
	@echo "  make clean     - remove generated files"
	@echo "  make dc-up     - start local docker-compose"
	@echo "  make dc-down   - stop local docker-compose"
	@echo "  make k8s-up    - deploy JupyterHub to k8s via Helm (prompts for namespace)"
	@echo "  make k8s-down  - uninstall Helm release + delete namespace (prompts + password)"

setup:
	@$(MAKE) env
	@$(MAKE) render

env:
	@set -euo pipefail; \
	if [ -f .env ]; then \
		read -p ".env already exists. Overwrite it? [y/N]: " ans; \
		case "$$ans" in \
			y|Y|yes|YES) \
				echo "Overwriting .env..."; \
				rm -f .env; \
			;; \
			*) \
				echo "Keeping existing .env."; \
				exit 0; \
			;; \
		esac; \
	fi; \
	if [ -f .env.example ]; then \
		echo "Creating .env from .env.example (will still prompt for key values)"; \
		cp .env.example .env; \
	fi; \
	\
	# Prompt for Docker Hub username (REGISTRY) \
	read -p "Docker Hub username/org (REGISTRY) [yourdockerhubusername]: " REG; \
	REG=$${REG:-yourdockerhubusername}; \
	\
	# Prompt for k8s teardown password (stored in .env, used as a speed bump) \
	read -s -p "Set K8S_DOWN_PASSWORD (leave blank to auto-generate): " KP; \
	echo; \
	if [ -z "$$KP" ]; then \
		if command -v openssl >/dev/null 2>&1; then \
			KP=$$(openssl rand -hex 12); \
		else \
			KP=$$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'); \
		fi; \
		echo "Generated K8S_DOWN_PASSWORD: $$KP"; \
	fi; \
	\
	# If we started from .env.example, we still want to ensure required keys exist. \
	# We'll rewrite the file to a known-good baseline so behavior is deterministic. \
	echo "Writing .env..."; \
	printf '%s\n' \
'PROJECT_NAME=jhub' \
'TAG=0.1.0' \
"REGISTRY=$$REG" \
'COMPOSE_HUB_HTTP_PORT=8000' \
'VNC_PW=changeme' \
'VNC_RESOLUTION=1600x900' \
'VNC_COL_DEPTH=24' \
'K8S_NAMESPACE=jhub' \
'HELM_RELEASE=jhub' \
'DUMMY_PASSWORD=changeme' \
"K8S_DOWN_PASSWORD=$$KP" \
'DATASCI_IMAGE=$${REGISTRY}/jhub-datasci-proxy:$${TAG}' \
'DESKTOP_IMAGE=$${REGISTRY}/jhub-desktop-xfce-novnc:$${TAG}' \
		> .env; \
	echo "Done. Edit .env if you want different ports/tags/passwords."



render:
	@./scripts/render.sh
	@echo "Rendered: $(DC_GEN), $(HELM_GEN)"

images:
	@./scripts/build.sh

clean:
	@rm -f $(DC_GEN) $(HELM_GEN)
	@echo "Removed generated files: $(DC_GEN) $(HELM_GEN)"

dc-up: render
	@docker compose --env-file .env -f $(DC_GEN) up -d
	@echo "Local Hub should be at: http://localhost:$$(grep -E '^COMPOSE_HUB_HTTP_PORT=' .env | cut -d= -f2)"

dc-down:
	@if [ -f $(DC_GEN) ]; then \
		docker compose --env-file .env -f $(DC_GEN) down; \
	else \
		echo "$(DC_GEN) not found. Run: make render"; \
	fi

k8s-up: render
	@read -p "Namespace [$(DEFAULT_NS)]: " NS; \
	NS=$${NS:-$(DEFAULT_NS)}; \
	echo "Using namespace: $$NS"; \
	kubectl create namespace "$$NS" >/dev/null 2>&1 || true; \
	helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/ >/dev/null 2>&1 || true; \
	helm repo update >/dev/null; \
	RELEASE=$$(grep -E '^HELM_RELEASE=' .env | cut -d= -f2 | head -n1); \
	RELEASE=$${RELEASE:-$(DEFAULT_RELEASE)}; \
	echo "Using release: $$RELEASE"; \
	helm upgrade --install "$$RELEASE" jupyterhub/jupyterhub \
		--namespace "$$NS" \
		--values $(HELM_GEN)

k8s-down:
	@set -euo pipefail; \
	read -p "Namespace to remove [$(DEFAULT_NS)]: " NS; \
	NS=$${NS:-$(DEFAULT_NS)}; \
	RELEASE=$$(grep -E '^HELM_RELEASE=' .env | cut -d= -f2 | head -n1); \
	RELEASE=$${RELEASE:-$(DEFAULT_RELEASE)}; \
	echo; \
	echo "About to DESTROY the following:"; \
	echo "  - Helm release: $$RELEASE"; \
	echo "  - Kubernetes namespace: $$NS"; \
	echo; \
	read -p "Type the namespace again to confirm: " NS2; \
	if [ "$$NS2" != "$$NS" ]; then \
		echo "Confirmation failed. Aborting."; \
		exit 1; \
	fi; \
	KPASS=$$(grep -E '^K8S_DOWN_PASSWORD=' .env | cut -d= -f2- | head -n1); \
	if [ -z "$$KPASS" ]; then \
		echo "K8S_DOWN_PASSWORD is not set in .env. Aborting."; \
		exit 1; \
	fi; \
	read -s -p "Enter K8S_DOWN_PASSWORD to proceed: " INPASS; \
	echo; \
	if [ "$$INPASS" != "$$KPASS" ]; then \
		echo "Password incorrect. Aborting."; \
		exit 1; \
	fi; \
	echo "Uninstalling release '$$RELEASE' from namespace '$$NS'..."; \
	helm uninstall "$$RELEASE" -n "$$NS" >/dev/null 2>&1 || true; \
	echo "Deleting namespace '$$NS'..."; \
	kubectl delete namespace "$$NS" --wait=true

all-local:
	@echo "=== Running full local setup ==="
	@$(MAKE) setup
	@$(MAKE) images
	@$(MAKE) dc-up
	@echo "=== Local environment is up ==="

all-k8s:
	@echo "=== Running full Kubernetes setup ==="
	@$(MAKE) setup
	@$(MAKE) images
	@$(MAKE) k8s-up
	@echo "=== Kubernetes environment is up ==="
