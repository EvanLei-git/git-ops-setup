helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f vault-values.yaml



```bash
# 1. Add and update the vault Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 2. Install vault using the values file
helm install vault hashicorp/vault --namespace vault --create-namespace --values vault-values.yaml


# 3. Upgrade vault (when modifying vault-values.yaml)
helm upgrade  vault hashicorp/vault -n vault -f vault-values.yaml
```
