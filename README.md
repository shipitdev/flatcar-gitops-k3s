# Flatcar GitOps K3s Cluster 🚀

[![CI/CD Pipeline](https://github.com/shipitdev/flatcar-gitops-k3s/actions/workflows/ci.yaml/badge.svg)](https://github.com/shipitdev/flatcar-gitops-k3s/actions/workflows/ci.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Go Version](https://img.shields.io/badge/Go-1.24-00ADD8?logo=go)](app/main.go)
[![Flatcar Linux](https://img.shields.io/badge/Flatcar-Container%20Linux-00A98F?logo=linux)](https://www.flatcar.org)
[![Kubernetes K3s](https://img.shields.io/badge/Kubernetes-K3s%20v1.31-FFC61E?logo=kubernetes)](https://k3s.io)
[![FluxCD](https://img.shields.io/badge/GitOps-FluxCD%20v2-5468FF?logo=flux)](https://fluxcd.io)
[![Prometheus](https://img.shields.io/badge/Metrics-Prometheus-E6522C?logo=prometheus)](https://prometheus.io)

An enterprise-grade, immutable infrastructure and automated **GitOps** pipeline running on **Flatcar Container Linux** via QEMU. Zero manual setup, fully declarative from bare-metal bootstrap to application lifecycle and observability.

---

## Architecture Overview

```
                        +----------------------------------------------------+
                        |           GitHub (shipitdev/flatcar-gitops-k3s)    |
                        |   - Go Microservice Code (/app)                    |
                        |   - Declarative Manifests (/k8s)                   |
                        +-------------------------+--------------------------+
                                                  |
                     +----------------------------+----------------------------+
                     | push event                                              | 1-minute poll
                     v                                                         v
        +----------------------------+                          +-------------------------------+
        |    GitHub Actions CI/CD    |                          |   FluxCD GitOps Controller    |
        |  - Unit Tests & Linting    |                          |   (In-Cluster Reconciler)     |
        |  - Multi-Arch Docker Build |                          +---------------+---------------+
        |  - Push to GHCR Registry   |                                          |
        +-------------+--------------+                                          | Applies Kustomization
                      |                                                         v
                      v                                         +-------------------------------+
        +----------------------------+                          |       K3s Kubernetes Engine   |
        |       GHCR Registry        |                          |   - Deployment (RollingUpdate)|
        |  (linux/amd64, arm64)      | <----------------------- |   - HorizontalPodAutoscaler   |
        +----------------------------+    Pulls New Container   |   - ServiceMonitor (/metrics) |
                                                                +---------------+---------------+
                                                                                |
                                                                                v
                                                                +-------------------------------+
                                                                |     Flatcar Container Linux   |
                                                                |   - Ignition / Butane Boot    |
                                                                |   - Read-Only OS Filesystem   |
                                                                |   - Hardened systemd Units    |
                                                                +-------------------------------+
```

---

## Highlights & Engineering Features

- **Immutable OS Architecture**: Runs on Flatcar Container Linux where `/usr` is read-only. Configuration is managed entirely declaratively via **Butane** / **Ignition** (`flatcar.bu`), eliminating configuration drift.
- **Zero-Touch Multi-Arch Provisioning**: Automatically detects CPU architecture (`x86_64` vs Apple Silicon `arm64`) and configures native hardware virtualization (`hvf` on macOS, `kvm` on Linux).
- **Automated GitOps Reconciliation**: FluxCD v2 runs inside the cluster, polling Git every 60 seconds and auto-healing the cluster to match the declared desired state without manual `kubectl` access.
- **Built-in Cloud-Native Observability**:
  - The Go microservice exposes standard **Prometheus metrics** on `/metrics` (`http_requests_total`, `http_request_duration_seconds`, process/runtime stats).
  - Production **Kubernetes Probes**: `/healthz` (liveness) and `/readyz` (readiness).
  - Pre-configured `ServiceMonitor` for seamless Prometheus Operator scraping.
- **Auto-Scaling & Resilience**:
  - Declarative `HorizontalPodAutoscaler` (HPA) targeting CPU utilization.
  - Hardened non-root Distroless container image (`USER 65532:65532`).
  - Graceful termination signal handling (`SIGINT`/`SIGTERM`) with active connection draining.
- **End-to-End Multi-Arch CI/CD Pipeline**:
  - GitHub Actions workflow tests Go code, validates Kustomize/YAML syntax, builds multi-arch container images (`linux/amd64` and `linux/arm64`), and publishes directly to GitHub Container Registry (GHCR).

---

## Repository Layout

```
.
├── ci/
│   └── ci.yaml               # GitHub Actions CI/CD multi-arch pipeline
├── app/
│   ├── Dockerfile            # Multi-stage, multi-arch Distroless build
│   ├── main.go               # Go microservice with Prometheus & health endpoints
│   └── main_test.go          # Unit and benchmark tests
├── k8s/
│   ├── kustomization.yaml    # Kustomize entrypoint for FluxCD
│   ├── deployment.yaml       # Deployment manifest with probes & resource limits
│   ├── service.yaml          # ClusterIP service exposing app & metrics ports
│   ├── hpa.yaml              # Horizontal Pod Autoscaler (1-5 replicas)
│   └── servicemonitor.yaml   # Prometheus Operator scraping configuration
├── flatcar.bu                # Butane declarative OS & K3s bootstrap config
├── boot.sh                   # Universal multi-arch bootstrapper for QEMU
├── go.mod                    # Go module definition
└── README.md
```

---

## Quickstart

### Prerequisites
- macOS (Apple Silicon / Intel) or Linux
- QEMU (`brew install qemu` or `apt-get install qemu-system`)
- Container runtime (`podman` or `docker`) or `butane` CLI

### Launch the Cluster
Run the single-entrypoint bootstrapper:

```bash
./boot.sh
```

The script will automatically:
1. Transpile `flatcar.bu` into `config.ign`.
2. Fetch the correct multi-arch Flatcar production QEMU image.
3. Boot the headless Flatcar VM with hardware acceleration.
4. Auto-install K3s into `/opt/bin` and bootstrap FluxCD.
5. Forward host port `8080` to the guest microservice.

---

## Verifying the Deployment

Once booted, test the service directly from your host machine:

### 1. Application Endpoint
```bash
curl -s http://localhost:8080 | jq
```
```json
{
  "message": "Flatcar GitOps K3s Cluster: Enterprise Edition 🚀",
  "timestamp": "2026-09-07T18:00:00Z",
  "hostname": "flatcar-localhost",
  "version": "v2.0.0",
  "uptime": "1m42s",
  "environment": "production"
}
```

### 2. Kubernetes Health Probes
```bash
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/readyz
```

### 3. Prometheus Metrics Endpoint
```bash
curl -s http://localhost:8080/metrics | grep http_
```
```promql
# HELP http_requests_total Total number of HTTP requests processed...
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/",status="200"} 4
# HELP http_request_duration_seconds Histogram of response latency...
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",path="/",le="0.005"} 4
```

---

## GitOps in Action

To trigger an automatic deployment:
1. Make a change in `k8s/` or update application logic in `app/`.
2. Commit and push:
   ```bash
   git commit -am "feat: tune resource allocations"
   git push origin master
   ```
3. Watch FluxCD detect the commit and reconcile the cluster within 60 seconds without manual intervention.

---

## License
Apache License 2.0. See [LICENSE](LICENSE) for details.
