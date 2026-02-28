#!/bin/bash
# =============================================================================
# Initialize ComfyUI GPU server after boot
#
# Run this after starting/rebooting an EC2 instance:
#   ssh ubuntu@<ip> 'bash ~/comfyui-docker/scripts/init-server.sh'
#
# What it does:
#   1. Enable swap (16GB) — persists via fstab
#   2. Configure Docker with nvidia runtime on EBS
#   3. Start ComfyUI container
#   4. Wait for API to respond
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "[INIT] ComfyUI Server Initialization"
echo "=========================================="

# 1. Setup storage + swap
echo "[INIT] Setting up storage and swap..."
bash "$SCRIPT_DIR/setup-server-storage.sh" ebs

# 2. Start ComfyUI
echo "[INIT] Starting ComfyUI container..."
cd "$REPO_DIR"
docker compose -f docker-compose.gpu.yml up -d

# 3. Wait for API
echo "[INIT] Waiting for ComfyUI API..."
for i in $(seq 1 60); do
    if curl -s --max-time 5 http://localhost:8188/system_stats > /dev/null 2>&1; then
        echo "[INIT] ✅ ComfyUI is ready! (took ${i}0 seconds)"
        echo "[INIT] GPU info:"
        nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader
        echo "[INIT] RAM:"
        free -h | head -3
        exit 0
    fi
    sleep 10
done

echo "[INIT] ⚠️ ComfyUI not responding after 10 minutes. Check: docker logs comfyui"
exit 1
