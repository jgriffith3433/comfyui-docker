#!/bin/bash
# =============================================================================
# Setup Docker storage on EC2 for ComfyUI
#
# Problem: g4dn.xlarge has a 115GB ephemeral NVMe that's FAST but LOST on
# stop/terminate. Models (20GB+) need to survive restarts.
#
# Solution: Move Docker data-root to NVMe for speed, but understand that
# models will need re-downloading after instance stop. For persistent models,
# attach a separate EBS volume.
#
# Option A (ephemeral, fast): Docker on NVMe — models re-download on restart
# Option B (persistent, recommended): Attach EBS volume for /var/lib/docker
#
# Usage:
#   ./setup-server-storage.sh [ephemeral|ebs]
# =============================================================================
set -e

MODE="${1:-ephemeral}"

setup_ephemeral() {
    echo "[STORAGE] Setting up Docker on ephemeral NVMe..."
    
    # Move Docker to NVMe
    sudo systemctl stop docker 2>/dev/null || true
    sudo mkdir -p /opt/dlami/nvme/docker
    
    # Only copy if not already there
    if [ ! -d /opt/dlami/nvme/docker/volumes ]; then
        sudo rsync -aP /var/lib/docker/ /opt/dlami/nvme/docker/
    fi
    
    # Configure Docker data-root
    sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
    "data-root": "/opt/dlami/nvme/docker",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF
    
    sudo systemctl start docker
    echo "[STORAGE] Docker now using NVMe. WARNING: Data lost on instance stop!"
}

setup_ebs() {
    echo "[STORAGE] Setting up Docker on EBS..."
    
    # Resize root EBS to use all available space
    # (After you resize the EBS volume in AWS console)
    sudo growpart /dev/nvme0n1 1 2>/dev/null || true
    sudo resize2fs /dev/nvme0n1p1 2>/dev/null || true
    
    # Keep Docker on root EBS (persistent)
    sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF
    
    sudo systemctl restart docker
    echo "[STORAGE] Docker using EBS root volume. Data persists across stop/start."
}

case "$MODE" in
    ephemeral)
        setup_ephemeral
        ;;
    ebs)
        setup_ebs
        ;;
    *)
        echo "Usage: $0 [ephemeral|ebs]"
        exit 1
        ;;
esac

echo "[STORAGE] Done. Docker root: $(docker info 2>/dev/null | grep 'Docker Root')"
echo "[STORAGE] Disk usage:"
df -h / /opt/dlami/nvme 2>/dev/null
