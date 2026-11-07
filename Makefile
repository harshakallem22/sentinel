CLUSTER    := sentinel
K3D_CONFIG := cluster/k3d-config.yaml
TF_DIR     := terraform/bootstrap
CONTEXT    := k3d-$(CLUSTER)

.DEFAULT_GOAL := help
.PHONY: help up down destroy status cluster images secrets repo-secret grafana-secret bootstrap validate argocd-ui argocd-admin grafana-ui grafana-admin

help: ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

up: cluster images secrets bootstrap ## create or start the cluster, build images, then bootstrap Argo CD
	@echo "Platform is up. Run 'make status'."

cluster: ## create the k3d cluster, or start it if it exists
	@if k3d cluster list $(CLUSTER) >/dev/null 2>&1; then \
		k3d cluster start $(CLUSTER); \
	else \
		k3d cluster create --config $(K3D_CONFIG); \
	fi
	@kubectl config use-context $(CONTEXT) >/dev/null

images: ## build the Online Boutique images for arm64 into the local registry (skips existing)
	@./scripts/build-boutique-images.sh

secrets: repo-secret grafana-secret ## create all in-cluster secrets (never stored in Git)

repo-secret: ## give Argo CD read access to the private repo
	@./scripts/argocd-repo-secret.sh

grafana-secret: ## create Grafana's admin login with a random password
	@./scripts/grafana-admin-secret.sh

bootstrap: ## install Argo CD and the root app with Terraform
	terraform -chdir=$(TF_DIR) init -input=false -upgrade=false
	terraform -chdir=$(TF_DIR) apply -input=false -auto-approve

down: ## stop the cluster but keep its data
	k3d cluster stop $(CLUSTER)

destroy: ## delete the cluster and Terraform state (used for the full rebuild test)
	k3d cluster delete --config $(K3D_CONFIG)
	rm -f $(TF_DIR)/terraform.tfstate $(TF_DIR)/terraform.tfstate.backup

status: ## Argo CD apps, pods and node usage
	@kubectl -n argocd get applications.argoproj.io 2>/dev/null || true
	@echo
	@kubectl get pods -A
	@echo
	@kubectl top nodes 2>/dev/null || echo "metrics not ready yet"

argocd-ui: ## open the Argo CD UI on http://localhost:8081
	kubectl -n argocd port-forward svc/argocd-server 8081:80

argocd-admin: ## print the initial admin login for the UI (never paste it anywhere)
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

grafana-ui: ## open Grafana on http://localhost:3000
	kubectl -n monitoring port-forward svc/kps-grafana 3000:80

grafana-admin: ## print Grafana's admin login (never paste it anywhere)
	@kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo

validate: ## lint YAML, check Terraform, validate manifests (run before every commit)
	yamllint .
	terraform fmt -check -recursive terraform
	terraform -chdir=$(TF_DIR) init -backend=false -input=false >/dev/null
	terraform -chdir=$(TF_DIR) validate
	kubeconform -strict -summary -ignore-missing-schemas \
		-schema-location default \
		-schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
		gitops platform/rbac
	kubectl kustomize platform/dashboards | kubeconform -strict -summary -
	kubectl kustomize gitops/boutique | kubeconform -strict -summary -
