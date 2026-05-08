What I did:
Created the PVC Manifest: Added netbird-pvc.yaml in your git-ops-setup/argocd directory for the persistent storage that Netbird needs.
Updated Helm Values: Patched your argocd-values.yaml to include the volumes and extraContainers configuration under the repoServer deployment.
Next Steps for You:
1. Apply the PVC: Run the following command to create the Persistent Volume Claim in your cluster:

bash
kubectl apply -f /home/evanlei/Documents/Norbloc/task-3-argo/git-ops-setup/argocd/netbird-pvc.yaml
2. Deploy the Changes: Commit these changes to your Git repository and push them. ArgoCD will detect the update to the argocd-values.yaml file, upgrade its own Helm release, and spin up the new repo-server pod with the Netbird sidecar.

3. Log in to Netbird (The Hacker Workaround): Once the new repo-server pod is running, find its name:

bash
kubectl get pods -n argocd | grep repo-server
Then execute into the netbird container:

bash
kubectl exec -it <YOUR-POD-NAME> -n argocd -c netbird -- netbird up --management-url https://netbird.norbloc.com:443
Follow the URL provided in the terminal to log in via SSO.