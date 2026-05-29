# Production EKS Terraform Cluster

This repository builds a production-style Amazon EKS cluster named `liontech` for LionTech DevOps students.

It includes:

- Complete VPC with public subnets, private subnets, internet gateway, route tables, NAT gateways, and Kubernetes subnet tags.
- EKS control plane with private and public endpoint support, CloudWatch control plane logs, and KMS secret encryption.
- EKS managed node group with EC2 worker nodes labeled `workernode=liontech-cluster`.
- Worker node security group that allows Kubernetes NodePort access on ports `30000-32767`.
- IAM roles and policies for the EKS cluster, managed nodes, EBS CSI driver, and Cluster Autoscaler IRSA.
- EKS managed add-ons: VPC CNI, CoreDNS, kube-proxy, and AWS EBS CSI driver.
- Cluster Autoscaler deployed by Helm.
- Metrics Server deployed by Helm so Horizontal Pod Autoscaler can scale application pods.
- Optional Vertical Pod Autoscaler Helm installation switch.
- Jenkinsfile to create/update the cluster.
- Jenkinsfile.destroy to destroy the cluster safely.
- Example NodePort application with a HorizontalPodAutoscaler.
- Rancher Deployment manifest exposed with a NodePort service in `rancher-nodeport/`.

## Repository Layout

```text
.
├── Jenkinsfile
├── Jenkinsfile.destroy
├── backend.example.hcl
├── environments/prod/prod.tfvars.example
├── iam-policies/
├── manifests/nodeport-hpa-example.yaml
├── rancher-nodeport/rancher-deployment-nodeport.yaml
├── modules/
│   ├── autoscaling/
│   ├── eks/
│   ├── iam/
│   └── vpc/
├── main.tf
├── outputs.tf
├── providers.tf
├── variables.tf
└── versions.tf
```

## Prerequisites

- Terraform `>= 1.6`
- AWS CLI configured with an IAM role/user that can create EKS, IAM, VPC, KMS, CloudWatch Logs, Auto Scaling, S3 state, and DynamoDB locks.
- kubectl for post-deployment checks.
- Jenkins with Terraform, AWS CLI, and the AWS Credentials plugin installed.

The Jenkins IAM policy example is in `iam-policies/jenkins-terraform-eks-policy.json`.

## Remote State

Create an S3 bucket and DynamoDB lock table before the first run, then initialize Terraform with backend settings:

```bash
terraform init \
  -backend-config="bucket=liontech-production-terraform-state" \
  -backend-config="key=production/eks/liontech.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=liontech-production-terraform-locks" \
  -backend-config="encrypt=true"
```

## Local Deploy

```bash
cp environments/prod/prod.tfvars.example environments/prod/prod.tfvars
terraform fmt -recursive
terraform validate
terraform plan -var-file="environments/prod/prod.tfvars" -out=tfplan
terraform apply tfplan
```

Configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name liontech
kubectl get nodes --show-labels
```

You should see worker nodes with:

```text
workernode=liontech-cluster
```

## Jenkins Create Pipeline

Use `Jenkinsfile` for cluster creation and updates. Required Jenkins credential:

- `aws-jenkins-terraform` by default, or override `AWS_CREDENTIALS_ID`.

Pipeline parameters:

- `AWS_REGION`
- `AWS_CREDENTIALS_ID`
- `TF_STATE_BUCKET`
- `TF_STATE_KEY`
- `TF_STATE_DYNAMODB_TABLE`
- `TFVARS_FILE`
- `AUTO_APPROVE`

The pipeline runs format checks, initializes remote state, validates Terraform, plans, waits for approval unless `AUTO_APPROVE` is checked, and then applies.

## Jenkins Destroy Pipeline

Use `Jenkinsfile.destroy` for cluster teardown. It requires:

- `CONFIRM_DESTROY=true`
- Manual Jenkins approval before applying the destroy plan.

## NodePort Application Access

The module is configured so NodePort applications are reachable from the internet by default:

- Worker nodes are placed in public subnets by default.
- Worker nodes receive public IPs.
- The node security group allows TCP `30000-32767` from `allowed_nodeport_cidrs`.

For a stricter production deployment, change `allowed_nodeport_cidrs` to trusted office, VPN, or corporate NAT CIDRs.

Deploy the sample NodePort app:

```bash
kubectl apply -f manifests/nodeport-hpa-example.yaml
kubectl get svc -n liontech-apps
kubectl get hpa -n liontech-apps
```

Find a node public IP:

```bash
kubectl get nodes -o wide
```

Open:

```text
http://NODE_PUBLIC_IP:30080
```

## Autoscaling

Cluster Autoscaler is installed into `kube-system` using IRSA. The node group Auto Scaling Group is tagged for discovery:

```text
k8s.io/cluster-autoscaler/enabled=true
k8s.io/cluster-autoscaler/liontech=owned
```

Metrics Server is installed so Kubernetes Horizontal Pod Autoscaler can scale application pods. The sample manifest includes an HPA that scales from 2 to 10 pods at 60 percent average CPU utilization.

## Important Security Notes

This repository intentionally enables internet NodePort access because the training requirement asks for NodePort application access. For a stricter production pattern, use private worker nodes and expose applications through AWS Load Balancer Controller with an ALB or NLB instead of public NodePort access.
