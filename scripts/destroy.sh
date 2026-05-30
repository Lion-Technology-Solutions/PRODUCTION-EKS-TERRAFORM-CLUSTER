#!/bin/sh
set -eu

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-liontech-production-terraform-state}"
TF_STATE_KEY="${TF_STATE_KEY:-production/eks/liontech.tfstate}"
TF_STATE_DYNAMODB_TABLE="${TF_STATE_DYNAMODB_TABLE:-liontech-production-terraform-locks}"
TFVARS_FILE="${TFVARS_FILE:-environments/prod/prod.tfvars}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
FORCE_REMOVE_UNREACHABLE_HELM_STATE="${FORCE_REMOVE_UNREACHABLE_HELM_STATE:-false}"

if [ "$AUTO_APPROVE" != "true" ]; then
  printf '%s' "Type DESTROY to destroy the liontech EKS cluster: "
  read -r confirmation
  if [ "$confirmation" != "DESTROY" ]; then
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

VAR_FILE_ARG=""
if [ -f "$TFVARS_FILE" ]; then
  VAR_FILE_ARG="-var-file=${TFVARS_FILE}"
fi

helm_state="$(terraform state list | grep '^module.autoscaling.helm_release' || true)"

if [ "$FORCE_REMOVE_UNREACHABLE_HELM_STATE" = "true" ]; then
  if [ -n "$helm_state" ]; then
    old_ifs=$IFS
    IFS='
'
    for address in $helm_state; do
      if [ -n "$address" ]; then
        terraform state rm "$address"
      fi
    done
    IFS=$old_ifs
  else
    echo "No Helm release resources found in Terraform state."
  fi

  set -- plan -destroy
  if [ -n "$VAR_FILE_ARG" ]; then
    set -- "$@" "$VAR_FILE_ARG"
  fi
  set -- "$@" -var=configure_kubernetes_provider=false -out=destroy.tfplan
  terraform "$@"
  terraform apply -auto-approve destroy.tfplan
  exit 0
fi

if [ -n "$helm_state" ]; then
  set -- destroy -auto-approve
  if [ -n "$VAR_FILE_ARG" ]; then
    set -- "$@" "$VAR_FILE_ARG"
  fi

  old_ifs=$IFS
  IFS='
'
  for address in $helm_state; do
    if [ -n "$address" ]; then
      set -- "$@" "-target=${address}"
    fi
  done
  IFS=$old_ifs

  echo "Destroying Helm-managed Kubernetes add-ons before deleting EKS..."
  terraform "$@"
else
  echo "No Helm release resources found in Terraform state."
fi

set -- plan -destroy
if [ -n "$VAR_FILE_ARG" ]; then
  set -- "$@" "$VAR_FILE_ARG"
fi
set -- "$@" -out=destroy.tfplan
terraform "$@"
terraform apply -auto-approve destroy.tfplan
