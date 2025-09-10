### Commands

- set alias for microk8s

```bash
alias kubectl='microk8s kubectl'
```

### Setup

- Helm needs $USER/.kube/config
- Copy current kube config to $USER/.kube/config

```bash
kubectl config view --raw > ~/.kube/config
```

### Helm dependency update

```bash
helm dep up ph-ee-engine
```

### Upgrade helm charts + install

```bash
helm upgrade -f ph-ee-engine/values.yaml ph-ee-engine ph-ee-engine/ --install
```

### Prometheus setup

- Install prometheus stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus-stack prometheus-community/kube-prometheus-stack
```

### Create bulk processor secrets for AWS

```bash
export ENV_NAMESPACE=default
kubectl delete secret bulk-processor-secret -n $ENV_NAMESPACE || echo "delete the secret if exist"
kubectl create secret generic bulk-processor-secret \
    --from-literal=aws-access-key="$S3_ACCESS_KEY_ID" \
    --from-literal=aws-secret-key="$S3_SECRET_ACCESS_KEY" -n $ENV_NAMESPACE

```

### Port Forward

- forward keycloak requests from localhost:8081

```bash
kubectl port-forward svc/keycloak-http 8080:80 --address='0.0.0.0'
```

### View pod environment variables

```bash
kubectl exec -it ph-ee-operations-web-55cc755677-g4wwk -- printenv
```
