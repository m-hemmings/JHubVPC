#!/usr/bin/env bash
set -euo pipefail

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run: make setup"
  exit 1
fi

# Auto-export everything loaded from .env
set -o allexport
source ./.env
set +o allexport

mkdir -p helm

envsubst < docker-compose.template.yml > docker-compose.generated.yml
envsubst < helm/values.template.yaml > helm/values.generated.yaml

echo "Wrote:"
echo "  docker-compose.generated.yml"
echo "  helm/values.generated.yaml"
