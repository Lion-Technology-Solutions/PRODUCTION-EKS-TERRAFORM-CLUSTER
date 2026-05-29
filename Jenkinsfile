pipeline {
  agent any

  options {
    ansiColor('xterm')
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region for the liontech EKS cluster')
    string(name: 'AWS_CREDENTIALS_ID', defaultValue: 'aws-jenkins-terraform', description: 'Jenkins AWS credentials ID')
    string(name: 'TF_STATE_BUCKET', defaultValue: 'liontech-production-terraform-state', description: 'S3 bucket for Terraform state')
    string(name: 'TF_STATE_KEY', defaultValue: 'production/eks/liontech.tfstate', description: 'S3 key for Terraform state')
    string(name: 'TF_STATE_DYNAMODB_TABLE', defaultValue: 'liontech-production-terraform-locks', description: 'DynamoDB lock table')
    string(name: 'TFVARS_FILE', defaultValue: 'environments/prod/prod.tfvars', description: 'Terraform tfvars file in the repository')
    booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Apply the Terraform plan without manual Jenkins confirmation')
  }

  environment {
    TF_IN_AUTOMATION = 'true'
    TF_INPUT         = 'false'
    TF_VAR_aws_region = "${params.AWS_REGION}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Tool Versions') {
      steps {
        sh 'terraform version'
        sh 'aws --version'
      }
    }

    stage('Terraform Format') {
      steps {
        sh 'terraform fmt -recursive -check'
      }
    }

    stage('Terraform Init') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID]]) {
          sh """
            terraform init -upgrade \\
              -backend-config="bucket=${params.TF_STATE_BUCKET}" \\
              -backend-config="key=${params.TF_STATE_KEY}" \\
              -backend-config="region=${params.AWS_REGION}" \\
              -backend-config="dynamodb_table=${params.TF_STATE_DYNAMODB_TABLE}" \\
              -backend-config="encrypt=true"
          """
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
          sh """
            if [ -f "${params.TFVARS_FILE}" ]; then
              terraform plan -var-file="${params.TFVARS_FILE}" -out=tfplan
            else
              terraform plan -out=tfplan
            fi
          """
        }
      }
    }

    stage('Approval') {
      when {
        expression { return !params.AUTO_APPROVE }
      }
      steps {
        input message: 'Create or update the production liontech EKS cluster?', ok: 'Deploy'
      }
    }

    stage('Terraform Apply') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID]]) {
          sh 'terraform apply -auto-approve tfplan'
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: true
    }
  }
}

