#!/usr/bin/env bash
set -euo pipefail

set -a
source ./.env
set +a

docker build -t "${DATASCI_IMAGE}" images/datasci
docker build -t "${DESKTOP_IMAGE}" images/desktop

docker push "${DATASCI_IMAGE}"
docker push "${DESKTOP_IMAGE}"
