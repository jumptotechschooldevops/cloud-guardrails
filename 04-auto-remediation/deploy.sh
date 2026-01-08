#!/usr/bin/env bash
set -euo pipefail

# Default region = us-east-2
REGION=${1:-us-east-2}
FN=auto-remediate-s3-public

echo "Deploying Auto-Remediation in region: $REGION"

###########################################
# 1. ZIP THE LAMBDA FUNCTION
###########################################
echo "Packaging Lambda function..."
cd lambda_s3_public_block
zip -qr function.zip .
cd ..

###########################################
# 2. CREATE IAM ROLE FOR LAMBDA
###########################################
echo "Creating IAM role (if not exists)..."

aws iam create-role --role-name lambda-s3-remediate-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"lambda.amazonaws.com"},
      "Action":"sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists."

echo "Attaching inline policy..."
aws iam put-role-policy \
  --role-name lambda-s3-remediate-role \
  --policy-name lambda-s3-remediate-policy \
  --policy-document file://lambda_s3_public_block/policy.json

ROLE_ARN=$(aws iam get-role \
  --role-name lambda-s3-remediate-role \
  --query 'Role.Arn' \
  --output text)

echo "Using Role ARN: $ROLE_ARN"


###########################################
# 3. CREATE OR UPDATE LAMBDA FUNCTION
###########################################
echo "Deploying Lambda function..."

aws lambda get-function --function-name $FN --region $REGION >/dev/null 2>&1 && EXISTS=1 || EXISTS=0

if [ "$EXISTS" -eq 0 ]; then
  echo "Creating Lambda..."
  aws lambda create-function \
    --function-name $FN \
    --runtime python3.11 \
    --handler handler.lambda_handler \
    --zip-file fileb://lambda_s3_public_block/function.zip \
    --role $ROLE_ARN \
    --timeout 60 \
    --memory-size 256 \
    --region $REGION
else
  echo "Updating Lambda code..."
  aws lambda update-function-code \
    --function-name $FN \
    --zip-file fileb://lambda_s3_public_block/function.zip \
    --region $REGION
fi


###########################################
# 4. CREATE EVENTBRIDGE RULE
###########################################
echo "Creating EventBridge rule..."
RULE=ConfigNonCompliant

aws events put-rule \
  --name $RULE \
  --event-pattern file://eventbridge-rule.json \
  --region $REGION


###########################################
# 5. ADD LAMBDA AS A TARGET
###########################################
echo "Adding Lambda target to EventBridge..."

TARGET_ARN=$(aws lambda get-function \
  --function-name $FN \
  --region $REGION \
  --query 'Configuration.FunctionArn' \
  --output text)

aws events put-targets \
  --rule $RULE \
  --targets "Id"="1","Arn"="$TARGET_ARN" \
  --region $REGION


###########################################
# 6. ALLOW EVENTBRIDGE TO INVOKE LAMBDA
###########################################
echo "Adding invoke permission..."

aws lambda add-permission \
  --function-name $FN \
  --statement-id evtrule \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "$(aws events describe-rule --name $RULE --query Arn --output text --region $REGION)" \
  --region $REGION 2>/dev/null || echo "Permission already exists."


###########################################
# DONE
###########################################
echo "===================================================="
echo "Auto-remediation deployed successfully in $REGION"
echo "Lambda Function:      $FN"
echo "EventBridge Rule:     $RULE"
echo "Invocation Target ARN: $TARGET_ARN"
echo "===================================================="

