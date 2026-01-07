#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-local}"

if [[ -f .env ]]; then
  read -r -p ".env already exists. Overwrite it? [y/N]: " ans
  case "$ans" in
    y|Y|yes|YES)
      echo "Overwriting .env..."
      rm -f .env
      ;;
    *)
      echo "Keeping existing .env."
      exit 0
      ;;
  esac
fi

read -r -p "Docker Hub username/org (REGISTRY) [yourdockerhubusername]: " REG
REG="${REG:-yourdockerhubusername}"

read -r -s -p "Set K8S_DOWN_PASSWORD (leave blank to auto-generate): " KP
echo
if [[ -z "${KP}" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    KP="$(openssl rand -hex 12)"
  else
    KP="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  fi
  echo "Generated K8S_DOWN_PASSWORD: ${KP}"
fi

if [[ "${MODE}" == "k8s" ]]; then
  PUSH=1
else
  PUSH=0
fi

cat > .env <<EOF
PROJECT_NAME=jhub
TAG=0.1.0
REGISTRY=${REG}
PUSH_IMAGES=${PUSH}

COMPOSE_HUB_HTTP_PORT=8000

VNC_PW=changeme
VNC_RESOLUTION=1600x900
VNC_COL_DEPTH=24

K8S_NAMESPACE=jhub
HELM_RELEASE=jhub
DUMMY_PASSWORD=changeme
K8S_DOWN_PASSWORD=${KP}

DATASCI_IMAGE=\${REGISTRY}/jhub-datasci-proxy:\${TAG}
DESKTOP_IMAGE=\${REGISTRY}/jhub-desktop-xfce-novnc:\${TAG}
EOF

echo "Wrote .env (MODE=${MODE}, PUSH_IMAGES=${PUSH})"
