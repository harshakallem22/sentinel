variable "kubeconfig_path" {
  description = "Path to the kubeconfig that k3d writes."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubeconfig context of the k3d cluster."
  type        = string
  default     = "k3d-sentinel"
}

variable "repo_url" {
  description = "Git repository that Argo CD syncs from."
  type        = string
  default     = "https://github.com/harshakallem22/sentinel.git"
}

variable "target_revision" {
  description = "Branch, tag or commit that Argo CD tracks."
  type        = string
  default     = "main"
}

variable "argocd_chart_version" {
  description = "Pinned argo-cd Helm chart version."
  type        = string
  default     = "10.10.5"
}

variable "argocd_apps_chart_version" {
  description = "Pinned argocd-apps Helm chart version."
  type        = string
  default     = "2.0.7"
}
