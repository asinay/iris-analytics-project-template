#!/usr/bin/env bash
# Build the image and smoke-test it end to end: container boots healthy, every
# IPM module actually installed (not just a green `docker compose build`), and
# embedded Python packages import cleanly.
#
# Runs under its own compose project name and its own ports, so it doesn't
# collide with a dev instance you already have up via `docker compose up -d`,
# and tears itself down on exit (success, failure, or Ctrl-C).
#
# Usage: scripts/verify.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# IPM modules the Dockerfile installs into USER — keep this in sync with the
# module list in the Dockerfile's registry-module loop.
MODULES=(samples-bi analyzethis pivotsubscriptions thirdpartychartportlets bi-export-plus)
# Embedded Python packages the Dockerfile pip-installs — keep in sync too.
PY_PACKAGES=(openpyxl)

PROJECT=iris-analytics-verify
PORT=58773
SUPER_PORT=51973
PASSWORD='VerifyOnly123!'
CONTAINER="${PROJECT}-iris-1"

cleanup() {
  docker compose -p "$PROJECT" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Building image"
docker compose -p "$PROJECT" build

echo "==> Starting container (project ${PROJECT}, ports ${PORT}/${SUPER_PORT})"
IRIS_PORT=$PORT IRIS_SUPER_PORT=$SUPER_PORT IRIS_PASSWORD=$PASSWORD IRIS_USERNAME=_SYSTEM \
  docker compose -p "$PROJECT" up -d

echo "==> Waiting for healthcheck"
status=starting
for _ in $(seq 1 24); do
  status=$(docker inspect --format '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo missing)
  [ "$status" = healthy ] && break
  if [ "$status" = unhealthy ]; then
    echo "Container reported unhealthy:"
    docker logs --tail 50 "$CONTAINER"
    exit 1
  fi
  sleep 5
done
if [ "$status" != healthy ]; then
  echo "Timed out waiting for healthy status (last: $status)"
  docker logs --tail 50 "$CONTAINER"
  exit 1
fi
echo "    healthy"

echo "==> Checking IPM modules"
list_output=$(docker exec "$CONTAINER" iris session IRIS -UUSER '##class(%IPM.Main).Shell("list")')
echo "$list_output"
for module in "${MODULES[@]}"; do
  echo "$list_output" | grep -q "$module" || { echo "Missing IPM module: $module"; exit 1; }
done

echo "==> Checking embedded Python packages"
for package in "${PY_PACKAGES[@]}"; do
  import_output=$(docker exec "$CONTAINER" iris session IRIS -UUSER "##class(%SYS.Python).Import(\"${package}\")" 2>&1)
  if echo "$import_output" | grep -q '<THROW>'; then
    echo "Failed to import ${package}: $import_output"
    exit 1
  fi
  echo "    ${package} OK"
done

echo "==> All checks passed"
