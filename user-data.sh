#!/usr/bin/env bash
set -e

REGION=eu-west-1
APP_NAME=karlkirbyca1

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

# Install and start Docker
dnf install -y docker
systemctl enable --now docker

# Load application settings from Parameter Store
aws ssm get-parameters-by-path \
  --region "$REGION" \
  --path "/$APP_NAME/" \
  --with-decryption \
  --query 'Parameters[].[Name,Value]' \
  --output text \
  | sed "s|^/$APP_NAME/||" \
  | tr '\t' '=' > /etc/karlkirbyca1.env

chmod 600 /etc/karlkirbyca1.env

# Authenticate with ECR
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# Pull the production image
docker pull "$REGISTRY/$APP_NAME:latest"
