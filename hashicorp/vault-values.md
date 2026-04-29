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


# This installs the Operator and teaches K8s what a VaultStaticSecret is
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator-system \
  --create-namespace
```



Keys test:
```bash 
kubectl exec -n vault vault-0 -- vault operator init
```

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.


Step 2: Unseal Vault
By default, Vault requires 3 of those 5 Unseal Keys to unlock the database (this is the Threshold mentioned in your logs).

You need to run the unseal command three separate times, pasting a different unseal key each time.

Run this command 3 times and paste 3 different keys:

```bash
kubectl exec -ti -n vault vault-0 -- vault operator unseal
```



# Understanding what we did above:


1. Is it open to the public now?
No, absolutely not. Unsealing Vault does not bypass authentication.

Think of Vault like a highly secure bank.

When Vault is sealed, the entire bank is locked inside a titanium vault, and even the bank tellers (the Vault API) are locked out. Nobody can do anything.

When Vault is unsealed, the bank opens for business. The tellers are at their desks and ready to help.

However, anyone walking into the bank (your apps, or you as an admin) still needs to show ID and prove they have an account before the teller will give them any money (secrets). Your data is completely safe; apps still need to log in to read anything.

2. Are those Unseal Keys going to be used again?
Yes! Keep them extremely safe. Because Vault stores everything in memory, it forgets the Master Key the second it loses power. If your vault-0 pod crashes, if Kubernetes restarts the node, or if you update Vault via ArgoCD, the pod will spin back up in a sealed state.

Every single time the Vault pod restarts, someone (or an automated script) will need to provide 3 of those 5 keys again to wake it back up.

(Note: For enterprise production, teams usually set up "Auto-Unseal" using AWS KMS or Azure Key Vault so they don't have to type keys manually at 3:00 AM when a pod restarts, but manual unsealing is standard for development).

3. Can it get sealed again?
Yes, in two ways:

Accidental/Infrastructure: As mentioned above, if the pod restarts or dies, it defaults to a sealed state.

The "Panic Button": You can intentionally seal it. If you suspect your cluster has been hacked or compromised, you can run kubectl exec -n vault vault-0 -- vault operator seal. This instantly locks the database, cutting off all access to secrets until you manually unseal it again.

4. What did we do exactly, and why did it fix it?
Vault encrypts all your secrets "at rest" (on the disk) using an Encryption Key. But to protect the Encryption Key, Vault encrypts that key with a Master Key.

When Vault starts up, it doesn't know what the Master Key is. Therefore, it literally cannot read its own database. This is the "sealed" state.

Here is exactly what your commands did:

vault operator init: This told Vault to generate a brand-new Master Key. Because giving one person the Master Key is dangerous, Vault uses a mathematical concept called Shamir's Secret Sharing to shatter the Master Key into 5 separate shards (your Unseal Keys).

vault operator unseal: By entering 3 of the 5 shards, you provided Vault with enough math to reconstruct the Master Key in its memory.

Once Vault reconstructed the Master Key, it could decrypt its database, read its configuration, and finally tell Kubernetes, "I am awake and ready to serve traffic!" which is why the Readiness Probe finally passed.


# SO..how to get initial access to Vault


Now, let's crush those production tasks. You can do all of this via the UI, but it is much faster and more reproducible to do it via the CLI inside your Vault pod.

Run this command to drop into the shell of your Vault pod:

Bash
kubectl exec -ti -n vault vault-0 -- sh
Then, log in to the CLI (paste your Root Token when prompted):

Bash
vault login
Here is the step-by-step guide to fulfilling all your acceptance criteria.

Step 1: Store App Credentials (KV Engine)
First, we need a place to store the database passwords. Vault uses "Secrets Engines" for this. We will enable the Key-Value (KV) engine and save a dummy Postgres password.

Bash
# 1. Enable the KV v2 secrets engine at the path "secret/"
vault secrets enable -path=secret kv-v2

# 2. Store a username and password for your app
vault kv put secret/myapp/database username="dbuser" password="SuperSecretProductionPassword"
Step 2: Restrict Access via Vault Policies
By default, nobody has access to the secrets we just created. We need to create a strict policy that only allows reading that specific database secret.

Bash
# Create a policy named 'myapp-kv-read'
vault policy write myapp-kv-read - <<EOF
path "secret/data/myapp/database" {
  capabilities = ["read"]
}
EOF




Step 3: Configure Kubernetes Auth Method
This is where the magic happens. We will tell Vault to trust the Kubernetes cluster it is running inside. This allows Vault to verify the identity of your application pods using their Kubernetes ServiceAccount.

Bash
# 1. Enable the Kubernetes authentication method
vault auth enable kubernetes

# 2. Tell Vault how to communicate with the internal Kubernetes API
vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

# 3. Create a role that binds your Kubernetes ServiceAccount to the Vault Policy
vault write auth/kubernetes/role/myapp-role bound_service_account_names=myapp-sa bound_service_account_namespaces=default policies=myapp-kv-read ttl=24h
(Note: I used default as the namespace. If your Nginx/Postgres app lives in a different namespace, change it here).