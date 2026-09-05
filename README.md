# Flatcar GitOps K3s Cluster

This repository provisions a lightweight Kubernetes (K3s) cluster on Flatcar Container Linux, fully automated via Butane/Ignition, with FluxCD handling continuous deployment (GitOps) of the cluster workloads.

## Architecture

- **Infrastructure as Code (IaC):** The base OS provisioning and K3s bootstrapping are declared in `flatcar.bu`.
- **Zero-Touch Provisioning:** On first boot, Ignition automatically pulls the K3s binary, initializes the cluster, and installs FluxCD via a systemd unit.
- **GitOps Sync:** FluxCD connects to this repository and continuously reconciles the Kubernetes manifests located in `k8s/`.

## Usage

### Prerequisites
- macOS/Linux host
- `podman` or `docker` (for transpiling Butane to Ignition)
- `qemu`

### Bootstrap
Run the boot script to generate the Ignition configuration, download the latest Flatcar production image, and launch the headless QEMU instance:

```bash
./boot.sh
```

Once the VM is running, K3s and FluxCD are installed automatically. Any subsequent modifications to the manifests in the `k8s/` directory will be synced to the cluster without manual intervention.

## Repository Layout
- `app/`: Source code and Dockerfile for the example Go microservice.
- `k8s/`: Kubernetes manifests (Deployment, Service) monitored by Flux.
- `flatcar.bu`: Butane configuration for OS and cluster bootstrapping.
- `boot.sh`: Entrypoint script to provision and launch the VM.
