# Argo CD

This repository uses [Argo CD] to manage Kubernetes cluster applications using
GitOps.

## Bootstrapping Argo CD

After provisioning the EKS cluster, you will need to install Argo CD so it can
manage and reconcile applications.

Run the following commands to create the namespace and apply the required
manifests:

```bash
kubectl create namespace argocd
kubectl apply --kustomize cluster-addons/argocd/ --server-side
```

This installs Argo CD in HA mode, using the upstream kustomization manifests and
allows Argo to manage itself by creating the `applicationsets` [App of
Apps][app-of-apps].

## Access Argo CD

By default, Argo CD isn't exposed outside the cluster. To access Argo CD from
your browser or CLI, you'll need to connect via `kubectl port-forward`:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

The API server can then be accessed using `https://localhost:8080`

The initial password for the `admin` account is auto-generated and stored as
clear text in the field `password` in a secret named
`argocd-initial-admin-secret` in your Argo CD installation namespace.

You can simply retrieve this password using the following command:

```bash
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | jq -r '. |= @base64d | .'
```

> **WARN**: You should delete the argocd-initial-admin-secret from the `argocd`
> namespace once you changed the password. See the following section for
> details.

## Enable SSO

After verifying you can log into the Argo CD web ui using the steps above, you
will need to [follow these steps to install Dex and set up SSO][sso-dex].

By default, this repo uses the following RBAC for GitHub's SSO (defined in
`cluster-addons/argocd/policy.csv`):

```csv
g, acme:admin, role:admin
g, acme:viewer, role:viewer
g, acme:my-team, role:my-team
```

## Cleanup

Once SSO is enabled and working, you will need to disable the `admin` account
and delete the default password. This can be done by uncommenting the
`admin.enabled` line in the `argocd-cm` patch, eg:

```diff
# cluster-addons/argocd/argocd-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
data:
-  # admin.enabled: 'false'
+  admin.enabled: 'false'
```

After that change has been committed and Argo synced, you can go ahead and
delete the secret with the user credentials:

```bash
kubectl delete secret -n argocd argocd-initial-admin-secret
```

## Miscellaneous

The `argocd-cm` and `argocd-rbac-cm` resources are patched automatically for
hardening and configuration-specific changes.

The `argocd-secret` is deleted from the base definition to avoid
overwriting the existing config and prevent a sync-loop. ESO must supply
`server.secretkey` and `dex.github.clientSecret` before SSO is enabled, or dex
won't start a connector.

[Argo CD]: https://argo-cd.readthedocs.io/en/stable/
[app-of-apps]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#app-of-apps
[sso-dex]: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#dex
