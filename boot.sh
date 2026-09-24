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
    IMAGE_PREFIX="flatcar_production_qemu_uefi"
else
    FLATCAR_ARCH="amd64-usr"
    IMAGE_PREFIX="flatcar_production_qemu"
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

if [ ! -f "${IMAGE_PREFIX}.sh" ]; then
    echo "==> Fetching ${IMAGE_PREFIX}.sh..."
    curl -fsSL "${BASE_URL}/${IMAGE_PREFIX}.sh" -o "${IMAGE_PREFIX}.sh"
    chmod +x "${IMAGE_PREFIX}.sh"
fi

IMG_NAME="${IMAGE_PREFIX}_image.img"
if [ ! -f "${IMG_NAME}" ]; then
    echo "==> Downloading Flatcar QEMU image for ${FLATCAR_ARCH} (this may take a few moments)..."
    curl -fsSL "${BASE_URL}/${IMG_NAME}.bz2" -o "${IMG_NAME}.bz2"
    bunzip2 "${IMG_NAME}.bz2"
    echo "✓ Image ready: ${IMG_NAME}"
fi

if [ "${FLATCAR_ARCH}" = "arm64-usr" ]; then
    for FIRMWARE in "${IMAGE_PREFIX}_efi_code.qcow2" "${IMAGE_PREFIX}_efi_vars.qcow2"; do
        if [ ! -f "${FIRMWARE}" ]; then
            curl -fsSL "${BASE_URL}/${FIRMWARE}" -o "${FIRMWARE}"
        fi
    done
fi

# 4. Launch Flatcar VM
# Maps host port 8080 to the Kubernetes NodePort.
echo "=========================================================="
echo " 🌟 Booting Flatcar K3s Cluster in QEMU"
echo "    - Web Service:  http://localhost:8080"
echo "    - Metrics:      http://localhost:8080/metrics"
echo "    - Health Probe: http://localhost:8080/healthz"
echo "=========================================================="

./"${IMAGE_PREFIX}.sh" \
    -i config.ign \
    -M 4096 \
    -f 8080:30080 \
    -- -snapshot -smp 2 -nographic \
    "$@"
