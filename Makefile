SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Files we generate
DC_GEN := docker-compose.generated.yml
HELM_GEN := helm/values.generated.yaml

# Defaults
DEFAULT_NS := jhub
DEFAULT_RELEASE := jhub

.PHONY: help setup env render images clean dc-up dc-down k8s-up k8s-down all-local all-k8s setup-local setup-k8s

help:
	@echo "Targets:"
	@echo "  make setup     - render templates + create/overwrite .env (with prompt)"
	@echo "  make images    - build images (uses .env)"
	@echo "  make clean     - remove generated files"
	@echo "  make dc-up     - start local docker-compose"
	@echo "  make dc-down   - stop local docker-compose"
	@echo "  make k8s-up    - deploy JupyterHub to k8s via Helm (prompts for namespace)"
	@echo "  make k8s-down  - uninstall Helm release + delete namespace (prompts + password)"

setup-local:
	@$(MAKE) setup MODE=local

setup-k8s:
	@$(MAKE) setup MODE=k8s

setup:
	@MODE=$${MODE:-local}; \
	$(MAKE) env MODE="$$MODE"; \
	$(MAKE) render


env:
	@MODE=$${MODE:-local} ./scripts/env-init.sh

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
	@$(MAKE) setup MODE=local
	@PUSH_IMAGES=0 $(MAKE) images
	@$(MAKE) dc-up
	@echo "=== Local environment is up ==="

all-k8s:
	@echo "=== Running full Kubernetes setup ==="
	@$(MAKE) setup MODE=k8s
	@PUSH_IMAGES=1 $(MAKE) images
	@$(MAKE) k8s-up
	@echo "=== Kubernetes environment is up ==="
