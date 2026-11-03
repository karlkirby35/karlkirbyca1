
#!/usr/bin/env bash
# Deploys a specific version of the application.
# Usage: deploy-notes <tag>

set -euo pipefail
exec 2>&1

TAG="${1:?Image tag is required}"
REGION="eu-west-1"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
IMAGE="$REGISTRY/karlkirbyca1:$TAG"

echo "Deploying $IMAGE"

# Load application configuration
aws ssm get-parameters-by-path \
  --region "$REGION" \
  --path /karlkirbyca1/ \
  --with-decryption \
  --query 'Parameters[].[Name,Value]' \
  --output text \
  | sed 's|^/karlkirbyca1/||' \
  | tr '\t' '=' > /etc/notes.env

chmod 600 /etc/notes.env

# Authenticate and download the image
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker pull "$IMAGE"

# Run database migrations before replacing the application
docker run --rm \
  --network karlkirbyca1-network \
  --env-file /etc/notes.env \
  "$IMAGE" node db/migrate.js

echo "Database migrations completed successfully"

# Replace ONLY the backend container
docker rm -f karlkirbyca1 || true

docker run -d \
  --name karlkirbyca1 \
  --restart unless-stopped \
  --network karlkirbyca1-network \
  --env-file /etc/notes.env \
  "$IMAGE"

echo "Successfully deployed $IMAGE"
