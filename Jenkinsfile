pipeline {
  agent any

  options {
    ansiColor('xterm')
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    skipDefaultCheckout(true)
    timeout(time: 120, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'DEPLOY_ACTION', choices: ['PLAN', 'APPLY'], description: 'PLAN previews changes. APPLY creates or updates the EKS cluster.')
    string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region for the EKS cluster and Terraform backend.')
    string(name: 'AWS_CREDENTIALS_ID', defaultValue: 'aws-jenkins-terraform', description: 'Jenkins AWS Credentials credential ID.')
    string(name: 'TF_STATE_BUCKET', defaultValue: 'liontech-production-terraform-state', description: 'Existing S3 bucket for Terraform state.')
    string(name: 'TF_STATE_KEY', defaultValue: 'production/eks/liontech.tfstate', description: 'S3 object key for Terraform state.')
    string(name: 'TF_STATE_DYNAMODB_TABLE', defaultValue: 'liontech-production-terraform-locks', description: 'Existing DynamoDB table used for state locking.')
    string(name: 'TFVARS_FILE', defaultValue: 'environments/prod/prod.tfvars.example', description: 'Optional repository-relative Terraform variable file.')
    string(name: 'CLUSTER_NAME', defaultValue: 'liontech', description: 'EKS cluster name.')
    string(name: 'KUBERNETES_VERSION', defaultValue: '1.30', description: 'EKS Kubernetes control-plane version.')
    string(name: 'DEPLOYMENT_ENVIRONMENT', defaultValue: 'production', description: 'Environment value passed to Terraform.')
    string(name: 'NODE_MIN_SIZE', defaultValue: '2', description: 'Minimum managed-node count.')
    string(name: 'NODE_DESIRED_SIZE', defaultValue: '3', description: 'Desired managed-node count.')
    string(name: 'NODE_MAX_SIZE', defaultValue: '8', description: 'Maximum managed-node count.')
    booleanParam(name: 'INIT_UPGRADE', defaultValue: false, description: 'Allow terraform init to upgrade provider selections.')
    booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip the Jenkins input prompt for APPLY.')
    booleanParam(name: 'CONFIRM_APPLY', defaultValue: false, description: 'Required safety confirmation when DEPLOY_ACTION is APPLY.')
  }

  environment {
    TF_IN_AUTOMATION = 'true'
    TF_INPUT = 'false'
    TF_CLI_ARGS = '-no-color'
    TF_PLAN_FILE = "eks-${BUILD_NUMBER}.tfplan"
    AWS_REGION = "${params.AWS_REGION}"
    AWS_DEFAULT_REGION = "${params.AWS_REGION}"
    AWS_PAGER = ''
    DEPLOY_ACTION = "${params.DEPLOY_ACTION}"
    TF_STATE_BUCKET = "${params.TF_STATE_BUCKET}"
    TF_STATE_KEY = "${params.TF_STATE_KEY}"
    TF_STATE_DYNAMODB_TABLE = "${params.TF_STATE_DYNAMODB_TABLE}"
    TFVARS_FILE = "${params.TFVARS_FILE}"
    CLUSTER_NAME = "${params.CLUSTER_NAME}"
    KUBERNETES_VERSION = "${params.KUBERNETES_VERSION}"
    DEPLOYMENT_ENVIRONMENT = "${params.DEPLOYMENT_ENVIRONMENT}"
    NODE_MIN_SIZE = "${params.NODE_MIN_SIZE}"
    NODE_DESIRED_SIZE = "${params.NODE_DESIRED_SIZE}"
    NODE_MAX_SIZE = "${params.NODE_MAX_SIZE}"
    INIT_UPGRADE = "${params.INIT_UPGRADE}"
    AUTO_APPROVE = "${params.AUTO_APPROVE}"
    CONFIRM_APPLY = "${params.CONFIRM_APPLY}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Validate Parameters and Tools') {
      steps {
        sh '''
          set -eu

          command -v terraform >/dev/null
          command -v aws >/dev/null
          terraform version
          aws --version

          for value in "$AWS_REGION" "$TF_STATE_BUCKET" "$TF_STATE_KEY" "$TF_STATE_DYNAMODB_TABLE" "$CLUSTER_NAME" "$KUBERNETES_VERSION" "$DEPLOYMENT_ENVIRONMENT"; do
            test -n "$value"
          done

          case "$AWS_REGION" in *[!a-z0-9-]*) echo "AWS_REGION contains invalid characters"; exit 1;; esac
          case "$CLUSTER_NAME" in *[!A-Za-z0-9_-]*) echo "CLUSTER_NAME contains invalid characters"; exit 1;; esac
          case "$DEPLOYMENT_ENVIRONMENT" in *[!A-Za-z0-9_-]*) echo "DEPLOYMENT_ENVIRONMENT contains invalid characters"; exit 1;; esac
          case "$KUBERNETES_VERSION" in *[!0-9.]*) echo "KUBERNETES_VERSION must contain only digits and periods"; exit 1;; esac
          case "$TFVARS_FILE" in /*|*..*) echo "TFVARS_FILE must be a safe repository-relative path"; exit 1;; esac

          for value in "$NODE_MIN_SIZE" "$NODE_DESIRED_SIZE" "$NODE_MAX_SIZE"; do
            case "$value" in ''|*[!0-9]*) echo "Node counts must be non-negative integers"; exit 1;; esac
          done

          if [ "$NODE_MIN_SIZE" -gt "$NODE_DESIRED_SIZE" ] || [ "$NODE_DESIRED_SIZE" -gt "$NODE_MAX_SIZE" ]; then
            echo "Node counts must satisfy NODE_MIN_SIZE <= NODE_DESIRED_SIZE <= NODE_MAX_SIZE"
            exit 1
          fi

          if [ "$DEPLOY_ACTION" = 'APPLY' ] && [ "$CONFIRM_APPLY" != 'true' ]; then
            echo 'Set CONFIRM_APPLY=true before running APPLY.'
            exit 1
          fi

          if [ -n "$TFVARS_FILE" ] && [ ! -f "$TFVARS_FILE" ]; then
            echo "Terraform variable file not found: $TFVARS_FILE"
            exit 1
          fi
        '''
      }
    }

    stage('Terraform Format') {
      steps {
        sh 'terraform fmt -recursive -check -diff'
      }
    }

    stage('Terraform Init') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID]]) {
          sh '''
            set -eu
            set -- terraform init -input=false \
              -backend-config="bucket=$TF_STATE_BUCKET" \
              -backend-config="key=$TF_STATE_KEY" \
              -backend-config="region=$AWS_REGION" \
              -backend-config="dynamodb_table=$TF_STATE_DYNAMODB_TABLE" \
              -backend-config="encrypt=true"

            if [ "$INIT_UPGRADE" = 'true' ]; then
              set -- "$@" -upgrade
            fi

            "$@"
          '''
        }
      }
    }

    stage('Terraform Validate') {
      steps {
        sh 'terraform validate'
      }
    }

    stage('Terraform Plan') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID]]) {
          sh '''
            set -eu
            set -- terraform plan -input=false -lock-timeout=5m -out="$TF_PLAN_FILE"

            if [ -n "$TFVARS_FILE" ]; then
              set -- "$@" -var-file="$TFVARS_FILE"
            fi

            set -- "$@" \
              -var="aws_region=$AWS_REGION" \
              -var="cluster_name=$CLUSTER_NAME" \
              -var="cluster_version=$KUBERNETES_VERSION" \
              -var="environment=$DEPLOYMENT_ENVIRONMENT" \
              -var="node_min_size=$NODE_MIN_SIZE" \
              -var="node_desired_size=$NODE_DESIRED_SIZE" \
              -var="node_max_size=$NODE_MAX_SIZE"

            "$@"
            terraform show "$TF_PLAN_FILE" > terraform-plan.txt
          '''
        }
      }
    }

    stage('Approval') {
      when {
        allOf {
          expression { params.DEPLOY_ACTION == 'APPLY' }
          expression { !params.AUTO_APPROVE }
        }
      }
      steps {
        input message: "Apply the Terraform plan and create/update EKS cluster '${params.CLUSTER_NAME}' in ${params.AWS_REGION}?", ok: 'Deploy EKS'
      }
    }

    stage('Terraform Apply') {
      when {
        expression { params.DEPLOY_ACTION == 'APPLY' }
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID]]) {
          sh 'terraform apply -input=false -auto-approve "$TF_PLAN_FILE"'
        }
      }
    }

    stage('Verify EKS Cluster') {
      when {
        expression { params.DEPLOY_ACTION == 'APPLY' }
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID]]) {
          sh '''
            set -eu
            aws eks wait cluster-active --region "$AWS_REGION" --name "$CLUSTER_NAME"
            aws eks describe-cluster \
              --region "$AWS_REGION" \
              --name "$CLUSTER_NAME" \
              --query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint}' \
              --output table
            terraform output > terraform-outputs.txt

            if command -v kubectl >/dev/null 2>&1; then
              aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" --kubeconfig "$WORKSPACE/kubeconfig"
              KUBECONFIG="$WORKSPACE/kubeconfig" kubectl get nodes -o wide
            else
              echo 'kubectl is not installed; AWS EKS API verification completed successfully.'
            fi
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'terraform-plan.txt, terraform-outputs.txt', allowEmptyArchive: true, fingerprint: true
    }
    success {
      echo "EKS ${params.DEPLOY_ACTION.toLowerCase()} workflow completed for ${params.CLUSTER_NAME} in ${params.AWS_REGION}."
    }
  }
}
