import json, os
import boto3

s3 = boto3.client("s3")

def lambda_handler(event, context):
    # Expect Config event with resourceId == bucket name
    detail = event.get("detail", {})
    resource = detail.get("resourceId") or (detail.get("newEvaluationResult") or {}).get("evaluationResultIdentifier", {}).get("evaluationResultQualifier", {}).get("resourceId")

    if not resource:
        print("No resourceId in event:", json.dumps(event))
        return {"status": "no_resource"}

    bucket = resource
    print(f"Auto-remediating S3 bucket: {bucket}")

    # Block all public access
    s3.put_public_access_block(
        Bucket=bucket,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True
        }
    )
    # Remove public ACL if present
    try:
        s3.put_bucket_acl(Bucket=bucket, ACL="private")
    except Exception as e:
        print("ACL update failed (may already be private):", e)

    # Optional: attach deny public policy
    bucket_policy = {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [f"arn:aws:s3:::{bucket}", f"arn:aws:s3:::{bucket}/*"],
        "Condition": {"Bool": {"aws:SecureTransport": "false"}}
      }]
    }
    try:
        s3.put_bucket_policy(Bucket=bucket, Policy=json.dumps(bucket_policy))
    except Exception as e:
        print("Policy set failed (may have existing policy):", e)

    print("Remediation complete.")
    return {"status": "ok", "bucket": bucket}
