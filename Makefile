CLUSTER    := sentinel
K3D_CONFIG := cluster/k3d-config.yaml
TF_DIR     := terraform/bootstrap
CONTEXT    := k3d-$(CLUSTER)
IAM_DIR    := terraform/localstack-iam
LOCALSTACK := localstack/localstack:2026.09.1

.DEFAULT_GOAL := help
.PHONY: help up down destroy status cluster images secrets grafana-secret bootstrap validate argocd-ui argocd-admin grafana-ui grafana-admin localstack-up localstack-down iam iam-check

help: ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

up: cluster images secrets bootstrap ## create or start the cluster, build images, then bootstrap Argo CD
	@echo "Platform is up. Run 'make status'."

cluster: ## create the k3d cluster, or start it if it exists
	@if k3d cluster list $(CLUSTER) >/dev/null 2>&1; then \
		k3d cluster start $(CLUSTER) && \
		kubectl config use-context $(CONTEXT) >/dev/null && \
		./scripts/remesh-after-restart.sh; \
	else \
		k3d cluster create --config $(K3D_CONFIG); \
	fi
	@kubectl config use-context $(CONTEXT) >/dev/null

images: ## build the Online Boutique images for arm64 into the local registry (skips existing)
	@./scripts/build-boutique-images.sh

secrets: grafana-secret ## create all in-cluster secrets (never stored in Git)

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

localstack-up: ## start LocalStack (needs LOCALSTACK_AUTH_TOKEN in .env) with IAM enforcement on
	@test -f .env || { echo "Copy .env.example to .env and set LOCALSTACK_AUTH_TOKEN"; exit 1; }
	@docker start sentinel-localstack >/dev/null 2>&1 || docker run -d --name sentinel-localstack \
		--env-file .env -e ENFORCE_IAM=1 -p 127.0.0.1:4566:4566 --memory 1g $(LOCALSTACK) >/dev/null
	@until curl -fsS localhost:4566/_localstack/health >/dev/null 2>&1; do sleep 2; done; echo "LocalStack is up on localhost:4566"

localstack-down: ## stop and remove LocalStack (its data is not kept)
	docker rm -f sentinel-localstack

iam: ## create the results bucket and least-privilege CI role in LocalStack
	terraform -chdir=$(IAM_DIR) init -input=false -upgrade=false
	terraform -chdir=$(IAM_DIR) apply -input=false -auto-approve

iam-check: ## prove the CI role can write only under loadtest/
	@./scripts/localstack-iam-check.sh

validate: ## lint YAML, check Terraform, validate manifests (run before every commit)
	yamllint .
	terraform fmt -check -recursive terraform
	terraform -chdir=$(TF_DIR) init -backend=false -input=false >/dev/null
	terraform -chdir=$(TF_DIR) validate
	terraform -chdir=$(IAM_DIR) init -backend=false -input=false >/dev/null
	terraform -chdir=$(IAM_DIR) validate
	kubeconform -strict -summary -ignore-missing-schemas \
		-schema-location default \
		-schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
		gitops platform/rbac platform/traefik chaos/experiments
	kubectl kustomize platform/dashboards | kubeconform -strict -summary -
	kubectl kustomize gitops/boutique | kubeconform -strict -summary -schema-location default \
		-schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' -
