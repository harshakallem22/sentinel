output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "argocd_ui" {
  value = "kubectl -n argocd port-forward svc/argocd-server 8081:80, then open http://localhost:8081"
}
