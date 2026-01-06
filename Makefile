SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Files we generate
DC_GEN := docker-compose.generated.yml
HELM_GEN := helm/values.generated.yaml

# Defaults
DEFAULT_NS := jhub
DEFAULT_RELEASE := jhub

.PHONY: help setup env render images clean dc-up dc-down k8s-up k8s-down

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
		cp .env.example .env; \
		echo "Created .env from .env.example"; \
	else \
		echo "Creating default .env"; \
		cat > .env <<'EOF' ;\
PROJECT_NAME=jhub \
TAG=0.1.0 \
REGISTRY=yourdockerhubusername \
COMPOSE_HUB_HTTP_PORT=8000 \
VNC_PW=changeme \
VNC_RESOLUTION=1600x900 \
VNC_COL_DEPTH=24 \
K8S_NAMESPACE=jhub \
HELM_RELEASE=jhub \
DUMMY_PASSWORD=changeme \
# Used to protect destructive 'make k8s-down' \
K8S_DOWN_PASSWORD=please-change-me \
DATASCI_IMAGE=$${REGISTRY}/jhub-datasci-proxy:$${TAG} \
DESKTOP_IMAGE=$${REGISTRY}/jhub-desktop-xfce-novnc:$${TAG} \
EOF \
		; \
		echo "Created default .env (edit REGISTRY/passwords/etc.)"; \
	fi

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
