# Sentinel

A GitOps Kubernetes platform (Terraform, Helm, Argo CD, Prometheus, Grafana, Loki, Istio, OpenTelemetry, Argo Rollouts, Chaos Mesh) running Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) microservices demo on a local k3d cluster.

**Status:** work in progress. This README will cover setup, architecture, measured results and limitations as each part is built and verified.

## Attribution

[Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) is developed by Google and licensed under the [Apache License 2.0](https://github.com/GoogleCloudPlatform/microservices-demo/blob/v0.10.7/LICENSE). This project deploys and operates it without modifying its source code:

- `gitops/boutique/upstream/kubernetes-manifests.yaml` is Google's v0.10.7 release manifest, copied unchanged; all configuration is a Kustomize overlay next to it.
- Google publishes v0.10.7 images for amd64 only, so `scripts/build-boutique-images.sh` builds them for arm64 from the unmodified v0.10.7 source.

This is a portfolio project.
