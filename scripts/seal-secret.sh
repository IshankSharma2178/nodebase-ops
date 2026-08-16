#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-prod}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${ROOT}/${ENV}/nodebase"
ENV_FILE="${DIR}/.env"
PLAIN_SECRET="${DIR}/secret.yml"
SEALED_SECRET="${DIR}/sealed-secret.yml"

if [[ "${ENV}" == "staging" ]]; then
  SECRET_NAME="nodebase-staging-secret"
else
  SECRET_NAME="nodebase-secret"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.template and fill values first."
  exit 1
fi

kubectl create secret generic "${SECRET_NAME}" \
  --from-env-file="${ENV_FILE}" \
  --from-file=.env="${ENV_FILE}" \
  --dry-run=client -o yaml > "${PLAIN_SECRET}"

kubeseal \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format yaml \
  < "${PLAIN_SECRET}" > "${SEALED_SECRET}"

rm -f "${PLAIN_SECRET}"
echo "Wrote ${SEALED_SECRET}"
