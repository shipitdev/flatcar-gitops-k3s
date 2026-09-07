#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "=========================================================="
echo " 🚀 Flatcar GitOps K3s Cluster - Automated Bootstrapper"
echo "=========================================================="

# 1. Detect Architecture & OS
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

if [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "aarch64" ]; then
    FLATCAR_ARCH="arm64-usr"
    QEMU_ARCH="aarch64"
else
    FLATCAR_ARCH="amd64-usr"
    QEMU_ARCH="x86_64"
fi

echo "Detected Host OS: ${OS} (${ARCH}) -> Target Flatcar Arch: ${FLATCAR_ARCH}"

# 2. Transpile Butane config to Ignition
echo "==> Transpiling Butane config (flatcar.bu) to Ignition (config.ign)..."
if command -v butane >/dev/null 2>&1; then
    butane --pretty --strict < flatcar.bu > config.ign
elif command -v podman >/dev/null 2>&1; then
    podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < flatcar.bu > config.ign
elif command -v docker >/dev/null 2>&1; then
    docker run --interactive --rm quay.io/coreos/butane:release --pretty --strict < flatcar.bu > config.ign
else
    echo "ERROR: Neither 'butane', 'podman', nor 'docker' is installed to transpile flatcar.bu."
    exit 1
fi
echo "✓ Generated config.ign successfully."

# 3. Download official Flatcar QEMU scripts & image if needed
CHANNEL="stable"
BASE_URL="https://${CHANNEL}.release.flatcar-linux.net/${FLATCAR_ARCH}/current"

if [ ! -f flatcar_production_qemu.sh ]; then
    echo "==> Fetching flatcar_production_qemu.sh..."
    curl -fsSL "${BASE_URL}/flatcar_production_qemu.sh" -o flatcar_production_qemu.sh
    chmod +x flatcar_production_qemu.sh
fi

IMG_NAME="flatcar_production_qemu_image.img"
if [ ! -f "${IMG_NAME}" ]; then
    echo "==> Downloading Flatcar QEMU image for ${FLATCAR_ARCH} (this may take a few moments)..."
    curl -fsSL "${BASE_URL}/${IMG_NAME}.bz2" -o "${IMG_NAME}.bz2"
    bunzip2 "${IMG_NAME}.bz2"
    echo "✓ Image ready: ${IMG_NAME}"
fi

# 4. Launch Flatcar VM
# Maps host port 8080 -> guest port 8080 (Go App / Metrics) and host port 6443 -> guest 6443 (Kubernetes API)
echo "=========================================================="
echo " 🌟 Booting Flatcar K3s Cluster in QEMU"
echo "    - Web Service:  http://localhost:8080"
echo "    - Metrics:      http://localhost:8080/metrics"
echo "    - Health Probe: http://localhost:8080/healthz"
echo "=========================================================="

./flatcar_production_qemu.sh \
    -i config.ign \
    -m 2048 \
    -c 2 \
    -nographic \
    -p 8080:8080 \
    -p 6443:6443 \
    "$@"
