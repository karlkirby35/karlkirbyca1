#!/usr/bin/env bash
# Deploys a specific application version with automatic rollback.
# Usage: deploy-notes <tag>

set -Eeuo pipefail
exec 2>&1

TAG="${1:?Image tag is required}"
REGION="eu-west-1"
APP="karlkirbyca1"
NETWORK="karlkirbyca1-network"
PREVIOUS="${APP}-previous"
HEALTH_URL="http://127.0.0.1:8000/health"
MAX_ATTEMPTS=30
HAD_PREVIOUS=false
DEPLOYMENT_COMPLETE=false

rollback() {
  if [ "$DEPLOYMENT_COMPLETE" = true ]; then
    return
  fi

  echo "Deployment failed. Restoring previous version..."

  docker rm -f "$APP" 2>/dev/null || true

  if [ "$HAD_PREVIOUS" = true ]; then
    docker rename "$PREVIOUS" "$APP"
    docker start "$APP"
    echo "Previous version restored."
  else
    echo "No previous version was available."
  fi
}

trap 'rollback' ERR
trap 'rollback; exit 1' INT TERM

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
IMAGE="$REGISTRY/$APP:$TAG"

echo "Preparing deployment: $IMAGE"

aws ssm get-parameters-by-path \
  --region "$REGION" \
  --path /karlkirbyca1/ \
  --with-decryption \
  --query 'Parameters[].[Name,Value]' \
  --output text \
  | sed 's|^/karlkirbyca1/||' \
  | tr '\t' '=' > /etc/notes.env

chmod 600 /etc/notes.env

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker pull "$IMAGE"

# Run migrations before replacing the existing application.
docker run --rm \
  --network "$NETWORK" \
  --env-file /etc/notes.env \
  "$IMAGE" node db/migrate.js

echo "Database migrations completed."

# Preserve the current container for rollback.
if docker inspect "$PREVIOUS" >/dev/null 2>&1; then
  echo "A previous recovery container already exists. Stopping deployment safely."
  exit 1
fi

if docker inspect "$APP" >/dev/null 2>&1; then
  docker stop "$APP"
  docker rename "$APP" "$PREVIOUS"
  HAD_PREVIOUS=true
fi

# Start the new version.
docker run -d \
  --name "$APP" \
  --restart unless-stopped \
  --network "$NETWORK" \
  --env-file /etc/notes.env \
  "$IMAGE"

# Check application and database health.
HEALTHY=false

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if docker exec "$APP" node -e \
    "fetch('$HEALTH_URL').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
  then
    HEALTHY=true
    break
  fi

  echo "Health check $attempt/$MAX_ATTEMPTS failed."
  sleep 5
done

if [ "$HEALTHY" != true ]; then
  echo "New version failed its health checks."
  rollback
  trap - ERR INT TERM
  exit 1
fi

# Keep the new version and remove the old container.
if [ "$HAD_PREVIOUS" = true ]; then
  docker rm -f "$PREVIOUS"
fi

DEPLOYMENT_COMPLETE=true
trap - ERR INT TERM

echo "Deployment successful: $IMAGE"
