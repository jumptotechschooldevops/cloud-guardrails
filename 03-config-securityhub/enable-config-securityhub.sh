#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="config-logs-${ACCOUNT_ID}-${REGION}"

echo "Using region: $REGION"
echo "Using bucket: $BUCKET"

aws s3api create-bucket \
  --bucket $BUCKET \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION \
  2>/dev/null || true

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/AWSConfigRole"
echo "Using role ARN: $ROLE_ARN"

aws configservice put-configuration-recorder \
  --configuration-recorder file://recorder.json \
  --region $REGION

aws configservice put-delivery-channel \
  --delivery-channel file://delivery.json \
  --region $REGION

aws configservice start-configuration-recorder \
  --configuration-recorder-name default \
  --region $REGION

echo "AWS Config enabled."

aws securityhub enable-security-hub --region $REGION || true

aws securityhub batch-enable-standards \
 --standards-subscription-requests "[
   {\"StandardsArn\":\"arn:aws:securityhub:${REGION}::standards/aws-foundational-security-best-practices/v/1.0.0\"},
   {\"StandardsArn\":\"arn:aws:securityhub:${REGION}::standards/cis-aws-foundations-benchmark/v/1.4.0\"}
 ]" \
 --region $REGION

echo "Security Hub standards enabled in $REGION"

