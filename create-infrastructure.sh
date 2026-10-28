#!/usr/bin/env bash
#
# Creates what the continuous deployment tutorial needs before it starts.
#
#   ./create-infrastructure.sh [bucket-name]
#
# It makes, or reuses if they are already there from the container tutorial:
#
#   notes-app-uploads-<account>   an S3 bucket for uploaded files
#   notes-app-containers-sg       a security group allowing HTTP in
#   notes-app-containers-role     an IAM role, so the instance can open a
#                                 Session Manager shell, use the bucket, pull
#                                 an image, and read the app settings
#
# The names and permissions are the same as in the container tutorial, so an
# instance launched there and one launched here are set up the same way.
#
# Unlike the container tutorial's script, it does NOT create a database. The
# notes app in this tutorial keeps its notes in memory.
#
# It deliberately does NOT create the parameters in Parameter Store. Those are
# the tutorial.
#
# Safe to run again if it fails part way through.

set -euo pipefail

REGION="eu-west-1"
NAME="notes-app-containers"
REPO_NAME="karlkirbyca1"
PARAM_PATH="/karlkirbyca1"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${1:-notes-app-uploads-$ACCOUNT_ID}"

echo "Creating infrastructure in $REGION"
echo

# ---------------------------------------------------------------------------
# 1. The bucket
#
# Uploaded files go here, as they did in the S3 tutorial. Bucket names have to
# be unique across every AWS account in the world, so the default name has
# your account number on the end.
# ---------------------------------------------------------------------------

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "Bucket $BUCKET already exists"
else
  echo "Creating bucket $BUCKET"

  if ! aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null 2>&1; then
    echo "Could not create the bucket $BUCKET." >&2
    echo "The name is probably taken by another AWS account. Run the script again" >&2
    echo "with a name of your own, for example:" >&2
    echo "  ./create-infrastructure.sh notes-app-uploads-yourname" >&2
    exit 1
  fi

  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
fi

# ---------------------------------------------------------------------------
# 2. The security group
#
# Allows HTTP in from anywhere. Session Manager doesn't use SSH, so port 80 is
# the only port the instance needs open.
# ---------------------------------------------------------------------------

VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "There is no default VPC in $REGION." >&2
  echo "Create one in the console under VPC, Your VPCs, Actions, Create default VPC," >&2
  echo "then run this script again." >&2
  exit 1
fi

APP_SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$NAME-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || true)

if [ -n "$APP_SG_ID" ] && [ "$APP_SG_ID" != "None" ]; then
  echo "Security group $NAME-sg already exists ($APP_SG_ID)"
else
  echo "Creating security group $NAME-sg"

  APP_SG_ID=$(aws ec2 create-security-group \
    --region "$REGION" \
    --group-name "$NAME-sg" \
    --description "Notes app: HTTP in, nothing else" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' \
    --output text)
fi

# The rule is added outside that block, so that a group left without one by a
# run that stopped half way through gets it on the next run. Adding a rule that
# is already there is an error, and `|| true` is what ignores it.

aws ec2 authorize-security-group-ingress \
  --region "$REGION" \
  --group-id "$APP_SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 3. The IAM role
#
# Four separate permissions, each one scoped to the thing it needs:
#
#   Session Manager   so you can open a shell, and GitHub can run commands
#   S3                read and write the uploads bucket
#   ECR               pull this one repository
#   Parameter Store   read the app settings and decrypt the secret ones
# ---------------------------------------------------------------------------

if aws iam get-role --role-name "$NAME-role" >/dev/null 2>&1; then
  echo "Role $NAME-role already exists"
else
  echo "Creating role $NAME-role"

  aws iam create-role \
    --role-name "$NAME-role" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "ec2.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }]
    }' >/dev/null
fi

# Attaching a policy that is already attached succeeds and changes nothing, so
# this runs every time rather than only when the role is created.

aws iam attach-role-policy \
  --role-name "$NAME-role" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

echo "Granting $NAME-role read and write access to $BUCKET"

aws iam put-role-policy \
  --role-name "$NAME-role" \
  --policy-name NotesAppUploads \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Sid\": \"ReadWriteUploads\",
      \"Effect\": \"Allow\",
      \"Action\": [\"s3:PutObject\", \"s3:GetObject\"],
      \"Resource\": \"arn:aws:s3:::$BUCKET/*\"
    }]
  }"

# GetAuthorizationToken is the login step and cannot be limited to one
# repository, because the token it returns is what identifies you to the
# registry. The three actions that read an image are limited to this repository.

echo "Granting $NAME-role permission to pull $REPO_NAME"

aws iam put-role-policy \
  --role-name "$NAME-role" \
  --policy-name NotesAppPullImage \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"LogIntoTheRegistry\",
        \"Effect\": \"Allow\",
        \"Action\": \"ecr:GetAuthorizationToken\",
        \"Resource\": \"*\"
      },
      {
        \"Sid\": \"PullThisRepository\",
        \"Effect\": \"Allow\",
        \"Action\": [
          \"ecr:BatchGetImage\",
          \"ecr:GetDownloadUrlForLayer\",
          \"ecr:BatchCheckLayerAvailability\"
        ],
        \"Resource\": \"arn:aws:ecr:$REGION:$ACCOUNT_ID:repository/$REPO_NAME\"
      }
    ]
  }"

# The instance reads every setting the app needs out of one place in Parameter
# Store, so it needs to list the path as well as read the values under it.
# Decryption is a separate permission again, for any SecureString parameter.
# The condition limits that to requests that came through Parameter Store.

echo "Granting $NAME-role permission to read $PARAM_PATH/*"

aws iam put-role-policy \
  --role-name "$NAME-role" \
  --policy-name NotesAppConfiguration \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"ReadTheSettings\",
        \"Effect\": \"Allow\",
        \"Action\": [
          \"ssm:GetParameter\",
          \"ssm:GetParameters\",
          \"ssm:GetParametersByPath\"
        ],
        \"Resource\": [
          \"arn:aws:ssm:$REGION:$ACCOUNT_ID:parameter$PARAM_PATH\",
          \"arn:aws:ssm:$REGION:$ACCOUNT_ID:parameter$PARAM_PATH/*\"
        ]
      },
      {
        \"Sid\": \"DecryptTheSecretOnes\",
        \"Effect\": \"Allow\",
        \"Action\": \"kms:Decrypt\",
        \"Resource\": \"*\",
        \"Condition\": {
          \"StringEquals\": { \"kms:ViaService\": \"ssm.$REGION.amazonaws.com\" }
        }
      }
    ]
  }"

# An EC2 instance cannot be given a role directly. It is given an "instance
# profile", which is a container holding exactly one role.

if aws iam get-instance-profile --instance-profile-name "$NAME-role" >/dev/null 2>&1; then
  echo "Instance profile $NAME-role already exists"
else
  echo "Creating instance profile $NAME-role"

  aws iam create-instance-profile --instance-profile-name "$NAME-role" >/dev/null
fi

# A profile holds one role, and putting the role in again is an error, so the
# same `|| true` applies. An empty profile left behind by an earlier run is
# filled in here rather than being skipped.

aws iam add-role-to-instance-profile \
  --instance-profile-name "$NAME-role" \
  --role-name "$NAME-role" >/dev/null 2>&1 || true

cat <<SUMMARY

Done.

  Bucket     $BUCKET
  Security   $NAME-sg ($APP_SG_ID)
  Role       $NAME-role

Use this bucket name for the /notes-app/S3_BUCKET parameter:

  $BUCKET

SUMMARY
