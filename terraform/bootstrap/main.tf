provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kube_context
  }
}

# Terraform owns the Argo CD release (ADR-003); Argo CD owns everything under gitops/apps.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [file("${path.module}/values/argocd.yaml")]
}

# A separate chart creates the root Application, so no Argo CD CRDs are needed at plan time.
resource "helm_release" "root_app" {
  name       = "argocd-root"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = "argocd"

  values = [templatefile("${path.module}/values/root-app.yaml.tftpl", {
    repo_url        = var.repo_url
    target_revision = var.target_revision
  })]

  depends_on = [helm_release.argocd]
}
