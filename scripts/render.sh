#!/usr/bin/env bash
set -euo pipefail

# Load .env into the environment
source ./.env
set +a

mkdir -p helm

# Generate docker-compose.yml from template
envsubst < docker-compose.template.yml > docker-compose.generated.yml

# Generate helm values from template
envsubst < helm/values.template.yaml > helm/values.generated.yaml

echo "Wrote:"
echo "  docker-compose.generated.yml"
echo "  helm/values.generated.yaml"
