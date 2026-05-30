#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-liontech-production-terraform-state}"
TF_STATE_KEY="${TF_STATE_KEY:-production/eks/liontech.tfstate}"
TF_STATE_DYNAMODB_TABLE="${TF_STATE_DYNAMODB_TABLE:-liontech-production-terraform-locks}"
TFVARS_FILE="${TFVARS_FILE:-environments/prod/prod.tfvars}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
FORCE_REMOVE_UNREACHABLE_HELM_STATE="${FORCE_REMOVE_UNREACHABLE_HELM_STATE:-false}"

if [[ "$AUTO_APPROVE" != "true" ]]; then
  read -r -p "Type DESTROY to destroy the liontech EKS cluster: " confirmation
  if [[ "$confirmation" != "DESTROY" ]]; then
    echo "Destroy cancelled."
    exit 1
  fi
fi

terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${TF_STATE_KEY}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_STATE_DYNAMODB_TABLE}" \
  -backend-config="encrypt=true"

var_file_args=()
if [[ -f "$TFVARS_FILE" ]]; then
  var_file_args+=("-var-file=${TFVARS_FILE}")
fi

helm_state="$(terraform state list | grep '^module.autoscaling.helm_release' || true)"

if [[ "$FORCE_REMOVE_UNREACHABLE_HELM_STATE" == "true" ]]; then
  if [[ -n "$helm_state" ]]; then
    echo "$helm_state" | while read -r address; do
      terraform state rm "$address"
    done
  else
    echo "No Helm release resources found in Terraform state."
  fi

  terraform plan -destroy \
    "${var_file_args[@]}" \
    -var="configure_kubernetes_provider=false" \
    -out=destroy.tfplan
  terraform apply -auto-approve destroy.tfplan
  exit 0
fi

if [[ -n "$helm_state" ]]; then
  target_args=()
  while read -r address; do
    target_args+=("-target=${address}")
  done <<< "$helm_state"

  echo "Destroying Helm-managed Kubernetes add-ons before deleting EKS..."
  terraform destroy -auto-approve "${var_file_args[@]}" "${target_args[@]}"
else
  echo "No Helm release resources found in Terraform state."
fi

terraform plan -destroy "${var_file_args[@]}" -out=destroy.tfplan
terraform apply -auto-approve destroy.tfplan
