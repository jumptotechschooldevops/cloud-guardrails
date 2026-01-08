#!/usr/bin/env bash
set -euo pipefail

REGION="us-east-2"

aws securityhub get-findings --region $REGION --max-results 10 | jq '.Findings | length'

