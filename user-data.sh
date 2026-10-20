
#!/usr/bin/env bash
set -Eeuo pipefail

REGION=eu-west-1
APP_NAME=karlkirbyca1
FRONTEND_NAME=karlkirbyca1-frontend
BUCKET=karlkirbyca1-uploads-974280729622

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

# Install and start Docker
dnf install -y docker
systemctl enable --now docker

# Load settings and secrets from SSM Parameter Store
aws ssm get-parameters-by-path \
  --region "$REGION" \
  --path "/$APP_NAME/" \
  --with-decryption \
  --query 'Parameters[].[Name,Value]' \
  --output text \
  | sed "s|^/$APP_NAME/||" \
  | tr '\t' '=' > /etc/karlkirbyca1.env

# Ensure production storage settings are present
sed -i '/^STORAGE_DRIVER=/d; /^AWS_REGION=/d' /etc/karlkirbyca1.env
cat >> /etc/karlkirbyca1.env <<EOF
STORAGE_DRIVER=s3
AWS_REGION=$REGION
EOF

chmod 600 /etc/karlkirbyca1.env

# Authenticate with ECR
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# Pull both images
docker pull "$REGISTRY/$APP_NAME:latest"
docker pull "$REGISTRY/$FRONTEND_NAME:latest"

# Create the private network if needed
docker network inspect karlkirbyca1-network >/dev/null 2>&1 \
  || docker network create karlkirbyca1-network

# Start the backend
docker rm -f "$APP_NAME" 2>/dev/null || true

docker run -d \
  --name "$APP_NAME" \
  --network karlkirbyca1-network \
  --network-alias backend \
  --restart unless-stopped \
  --env-file /etc/karlkirbyca1.env \
  "$REGISTRY/$APP_NAME:latest"

# Start the frontend
docker rm -f "$FRONTEND_NAME" 2>/dev/null || true

docker run -d \
  --name "$FRONTEND_NAME" \
  --network karlkirbyca1-network \
  --restart unless-stopped \
  -p 80:80 \
  "$REGISTRY/$FRONTEND_NAME:latest"


