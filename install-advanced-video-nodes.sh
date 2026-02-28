#!/bin/bash
set -e

echo "🚀 Installing Advanced Video Generation Nodes for ComfyUI"
echo "========================================================="

NODES_DIR="/default-comfyui-bundle/ComfyUI/custom_nodes"

if [ ! -d "$NODES_DIR" ]; then
    echo "❌ ComfyUI custom_nodes directory not found at $NODES_DIR"
    exit 1
fi

cd "$NODES_DIR"

clone_node() {
    local name="$1"
    local url="$2"
    if [ ! -d "$name" ]; then
        echo "📦 Installing $name..."
        git clone --depth 1 "$url" "$name" && echo "  ✅ $name installed" || echo "  ❌ $name FAILED"
    else
        echo "  ✅ $name already exists"
    fi
}

# ==========================================================================
# Video Generation Nodes
# ==========================================================================
echo ""
echo "🎬 VIDEO GENERATION NODES"

# CogVideoX — best for character consistency from a reference image
clone_node "ComfyUI-CogVideoXWrapper" "https://github.com/kijai/ComfyUI-CogVideoXWrapper.git"

# LTX-Video — official Lightricks node, high quality video gen
clone_node "ComfyUI-LTXVideo" "https://github.com/Lightricks/ComfyUI-LTXVideo.git"

# NOTE: SVD (Stable Video Diffusion) is BUILT INTO ComfyUI core.
# Uses ImageOnlyCheckpointLoader + SVD_img2vid_Conditioning. No custom node needed.

# ==========================================================================
# Control & Enhancement Nodes
# ==========================================================================
echo ""
echo "🎛️ CONTROL & ENHANCEMENT NODES"

clone_node "ComfyUI-Advanced-ControlNet" "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
clone_node "comfyui_controlnet_aux"      "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
clone_node "ComfyUI-Frame-Interpolation" "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
clone_node "ComfyUI-IC-Light"            "https://github.com/huchenlei/ComfyUI-IC-Light.git"

# ==========================================================================
# Install Python dependencies for all cloned nodes
# ==========================================================================
echo ""
echo "📦 INSTALLING PYTHON DEPENDENCIES"
for req in "$NODES_DIR"/*/requirements.txt; do
    [ -f "$req" ] || continue
    node="$(basename "$(dirname "$req")")"
    echo "  pip install for $node..."
    pip install --no-cache-dir -r "$req" 2>&1 | tail -1 || true
done

echo ""
echo "🎉 Advanced node installation complete!"
ls -1 "$NODES_DIR/" | grep -vE '(example|websocket|__pycache__)'
