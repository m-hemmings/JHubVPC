#!/usr/bin/env bash
set -euo pipefail

set -o allexport
source ./.env
set +o allexport

docker build -t "${DATASCI_IMAGE}" images/datasci
docker build -t "${DESKTOP_IMAGE}" images/desktop

if [ "${PUSH_IMAGES:-0}" = "1" ]; then
  echo "PUSH_IMAGES=1 -> pushing images..."
  docker push "${DATASCI_IMAGE}"
  docker push "${DESKTOP_IMAGE}"
else
  echo "PUSH_IMAGES!=1 -> skipping push"
fi
