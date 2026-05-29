# Rancher NodePort Deployment

This folder deploys Rancher into the `liontech` EKS cluster as a Kubernetes `Deployment` and exposes it with a `NodePort` service.

## Components

- Namespace: `cattle-system`
- ServiceAccount: `rancher`
- ClusterRoleBinding: `rancher-cluster-admin`
- Secret: `rancher-bootstrap-secret`
- StorageClass: `liontech-gp3`
- PVC: `rancher-data`
- Deployment: `rancher`
- Service: `rancher-nodeport`

The deployment targets LionTech worker nodes with:

```yaml
nodeSelector:
  workernode: liontech-cluster
```

## Deploy

```bash
aws eks update-kubeconfig --region us-east-1 --name liontech
kubectl apply -f rancher-nodeport/rancher-deployment-nodeport.yaml
kubectl rollout status deployment/rancher -n cattle-system --timeout=15m
```

Or apply the folder with Kustomize:

```bash
kubectl apply -k rancher-nodeport/
```

## Access

The service exposes Rancher using fixed NodePort values:

- HTTP: `30081`
- HTTPS: `30443`

Find a worker node public IP:

```bash
kubectl get nodes -o wide
```

Open Rancher:

```text
https://NODE_PUBLIC_IP:30443
```

The manifest ships with a placeholder bootstrap password. Replace it before deploying:

```bash
kubectl -n cattle-system create secret generic rancher-bootstrap-secret \
  --from-literal=bootstrapPassword='REPLACE_WITH_A_STRONG_PASSWORD' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Then restart Rancher:

```bash
kubectl rollout restart deployment/rancher -n cattle-system
```

## Notes

This manifest intentionally uses a `NodePort` service because the LionTech EKS module opens worker node NodePort traffic on ports `30000-32767`. For a stricter production installation, use the Rancher Helm chart with an ingress controller, TLS certificates, and a stable DNS hostname.
