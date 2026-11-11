# Terraform EKS Cluster

This is an example implementation of an EKS cluster using infrastructure-as-code
(Iac) with [Terraform] and following [AWS' best-practices][eks-best-practices]
recommendations.

## Getting started

You will need an AWS account, aws-cli, terraform and kubectl installed locally.

Refer to the [docs](./docs/01-getting-started.md) folder for guides on how to
provision the cluster and its resources.

## Repo Structure

Repo structure follows the AWS Organizational Unit structure, where `acme` is
the default root account.

Each environment is then split in subfolders according to the following pattern:

```text
org-root/$ENVIRONMENT/$REGION/$COMPONENT
```

This allows for a clean separation of concerns between remote states and
contains the blast radius in case of problems.

Argo CD and GitOps components are located under `argocd` and `cluster-addons`
folders respectively. The `cluster-addons/argocd` folder contains the Argo CD
kustomization overlay that allows argo to self-manage and deploy an App of Apps
to sync cluster components using ApplicationSets.

[Terraform]: https://www.terraform.io/
[eks-best-practices]: https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html
