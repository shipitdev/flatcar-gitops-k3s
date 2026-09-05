#!/bin/bash

# Convert Butane to Ignition
podman run --interactive --rm quay.io/coreos/butane:release \
       --pretty --strict < flatcar.bu > config.ign

echo "Ignition config generated."
echo "Booting Flatcar VM with K3s..."

# Download Flatcar script and image if not exists
if [ ! -f flatcar_production_qemu.sh ]; then
    wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu.sh
    chmod +x flatcar_production_qemu.sh
fi

if [ ! -f flatcar_production_qemu_image.img ]; then
    wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_image.img.bz2
    bunzip2 flatcar_production_qemu_image.img.bz2
fi

./flatcar_production_qemu.sh -i config.ign -m 2048 -v -nographic
