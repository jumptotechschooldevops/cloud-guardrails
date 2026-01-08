#!/usr/bin/env bash
set -euo pipefail
cd terraform
terraform init -input=false
terraform plan -out=tfplan -input=false
terraform show -json tfplan | conftest test --policy ../conftest-policies -
echo "Conftest passed."

