# Flatcar + K3s GitOps lab

A single-node QEMU lab for bootstrapping [Flatcar Container Linux](https://www.flatcar.org/), K3s, and Flux. A small Go HTTP service provides a concrete workload for testing the path from a Git commit to a Kubernetes rollout. This is a local systems project, not a production cluster.

## How it works

```text
flatcar.bu -> Ignition -> Flatcar VM -> K3s -> Flux GitRepository/Kustomization
                                                      |
                                                      v
GitHub Actions -> Go tests -> amd64/arm64 image -> GHCR -> k8s/deployment.yaml
                                                      |
                                                      v
                                                K3s Deployment
```

On `master`, [GitHub Actions](.github/workflows/ci.yaml) runs Go tests and manifest validation, builds `linux/amd64` and `linux/arm64` images, then commits the built image's full commit-SHA tag to [`k8s/deployment.yaml`](k8s/deployment.yaml). Flux polls this repository every minute and reconciles [`k8s/`](k8s/). The image-update commit made by `GITHUB_TOKEN` does not start another workflow run.

The service uses a non-root distroless image, resource limits, Kubernetes health probes, and a `/metrics` endpoint. An HPA manifest is included; autoscaling depends on working CPU metrics and enough load. [`k8s/servicemonitor.yaml`](k8s/servicemonitor.yaml) is an optional example for clusters with Prometheus Operator; it is deliberately *not* part of the default Kustomization because the local K3s cluster does not install that CRD.

## Run locally

Prerequisites: QEMU, Butane (or Docker/Podman to run Butane), and network access to Flatcar, GitHub, and GHCR. On Apple Silicon, use Homebrew's QEMU package: its EDK2 firmware avoids a boot hang observed with Flatcar's bundled UEFI firmware under HVF. The script selects the ARM64 UEFI image on ARM hosts and the AMD64 image on x86-64 hosts. Budget at least 4 GiB of memory for the VM. The published GHCR image must be anonymously pullable; if a newly created package is private, make it public in GitHub Packages or configure an image-pull secret. This lab sets the VM's DNS resolver to `1.1.1.1` because QEMU's default DNS proxy did not work on the tested macOS host; change [`flatcar.bu`](flatcar.bu) if your network blocks that resolver.

```bash
./boot.sh
```

The script downloads the Flatcar image and QEMU wrapper on first use. It starts QEMU with `-snapshot`, so VM writes are discarded when the VM exits; each run reprovisions from Ignition. The host forwards port `8080` to the Kubernetes Service's NodePort `30080`. Bootstrapping and image pulls take time; wait for Flux and the Deployment to become ready before testing the app.

Verified on macOS Apple Silicon with QEMU 11.1.0 and Flatcar 4757.2.0: a fresh VM boot installed K3s v1.35.8+k3s1, reconciled Flux v2.9.5, started the API workload, and served all four endpoints below without manual intervention.

Check from the VM console with `sudo /opt/bin/k3s kubectl` (K3s keeps its kubeconfig private by default):

```bash
sudo /opt/bin/k3s kubectl -n flux-system get gitrepositories,kustomizations
sudo /opt/bin/k3s kubectl get deployments,pods,services
sudo /opt/bin/k3s kubectl -n flux-system logs deployment/kustomize-controller --tail=50
```

Then, from the host:

```bash
curl -f http://localhost:8080/
curl -f http://localhost:8080/healthz
curl -f http://localhost:8080/readyz
curl -fsS http://localhost:8080/metrics | grep http_requests_total
```

To test reconciliation, change a field under `k8s/`, commit, and push to `master`; inspect the Flux Kustomization and the resulting Kubernetes object. Changing `app/` triggers a new image build and a subsequent manifest commit. If Actions cannot push to `master` (for example, because of branch protection), promote the built SHA by updating the image tag in `k8s/deployment.yaml` yourself.

## Scope and limitations

- This is one disposable local node, not a highly available or production-ready setup.
- Bootstrap downloads pinned K3s and Flux releases, but Flatcar's `stable/current` image changes over time. For repeatable OS tests, pin a Flatcar release and verify the downloaded artifacts.
- QEMU's wrapper forwards host port `8080` without explicitly restricting the listen address. Use this demo only on a trusted host/network or firewall that port; the Kubernetes API is not forwarded.
- `/healthz` and `/readyz` report the Go process's HTTP availability, not downstream dependency health.
- CI and unit tests validate build inputs. An end-to-end QEMU boot and Flux reconciliation test is not part of CI.

## Layout

- [`boot.sh`](boot.sh): Flatcar QEMU download and VM launch
- [`flatcar.bu`](flatcar.bu): Ignition/systemd bootstrap of K3s and Flux
- [`k8s/flux-sync.yaml`](k8s/flux-sync.yaml): Flux GitRepository and Kustomization resources
- [`k8s/`](k8s/): workload, NodePort Service, and optional observability manifests
- [`app/`](app/): Go service, tests, and multi-architecture Dockerfile
- [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml): test, build, publish, and image promotion

Licensed under [Apache-2.0](LICENSE).
