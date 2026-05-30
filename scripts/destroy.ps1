[CmdletBinding()]
param(
  [string]$AwsRegion = $env:AWS_REGION,
  [string]$TfStateBucket = $env:TF_STATE_BUCKET,
  [string]$TfStateKey = $env:TF_STATE_KEY,
  [string]$TfStateDynamoDbTable = $env:TF_STATE_DYNAMODB_TABLE,
  [string]$TfvarsFile = $env:TFVARS_FILE,
  [switch]$AutoApprove,
  [switch]$ForceRemoveUnreachableHelmState
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($AwsRegion)) {
  $AwsRegion = 'us-east-1'
}

if ([string]::IsNullOrWhiteSpace($TfStateBucket)) {
  $TfStateBucket = 'liontech-production-terraform-state'
}

if ([string]::IsNullOrWhiteSpace($TfStateKey)) {
  $TfStateKey = 'production/eks/liontech.tfstate'
}

if ([string]::IsNullOrWhiteSpace($TfStateDynamoDbTable)) {
  $TfStateDynamoDbTable = 'liontech-production-terraform-locks'
}

if ([string]::IsNullOrWhiteSpace($TfvarsFile)) {
  $TfvarsFile = 'environments/prod/prod.tfvars'
}

if (-not $AutoApprove) {
  $confirmation = Read-Host 'Type DESTROY to destroy the liontech EKS cluster'
  if ($confirmation -ne 'DESTROY') {
    Write-Output 'Destroy cancelled.'
    exit 1
  }
}

$initArgs = @(
  'init',
  "-backend-config=bucket=$TfStateBucket",
  "-backend-config=key=$TfStateKey",
  "-backend-config=region=$AwsRegion",
  "-backend-config=dynamodb_table=$TfStateDynamoDbTable",
  '-backend-config=encrypt=true'
)
& terraform @initArgs

$varFileArgs = @()
if (Test-Path -Path $TfvarsFile) {
  $varFileArgs += "-var-file=$TfvarsFile"
}

$helmState = @(& terraform state list | Where-Object { $_ -like 'module.autoscaling.helm_release*' })

if ($ForceRemoveUnreachableHelmState) {
  if ($helmState.Count -gt 0) {
    foreach ($address in $helmState) {
      & terraform state rm $address
    }
  } else {
    Write-Output 'No Helm release resources found in Terraform state.'
  }

  $planArgs = @('plan', '-destroy') + $varFileArgs + @('-var=configure_kubernetes_provider=false', '-out=destroy.tfplan')
  & terraform @planArgs
  & terraform apply -auto-approve destroy.tfplan
  exit 0
}

if ($helmState.Count -gt 0) {
  $destroyArgs = @('destroy', '-auto-approve') + $varFileArgs
  foreach ($address in $helmState) {
    $destroyArgs += "-target=$address"
  }

  Write-Output 'Destroying Helm-managed Kubernetes add-ons before deleting EKS...'
  & terraform @destroyArgs
} else {
  Write-Output 'No Helm release resources found in Terraform state.'
}

$fullPlanArgs = @('plan', '-destroy') + $varFileArgs + @('-out=destroy.tfplan')
& terraform @fullPlanArgs
& terraform apply -auto-approve destroy.tfplan
