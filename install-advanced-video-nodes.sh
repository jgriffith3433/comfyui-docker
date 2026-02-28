#!/bin/bash
set -e

echo "🚀 Installing Advanced Video Generation Nodes for ComfyUI"
echo "========================================================="

# Check ComfyUI directory exists
if [ ! -d "/default-comfyui-bundle/ComfyUI/custom_nodes" ]; then
    echo "❌ ComfyUI custom_nodes directory not found!"
    ls -la /default-comfyui-bundle/ComfyUI/ || true
    exit 1
fi

cd /default-comfyui-bundle/ComfyUI/custom_nodes

echo "📁 Working directory: $(pwd)"

# Install Priority 1: Essential video generation models
echo ""
echo "🎬 PRIORITY 1: Core Video Generation Models"
echo "============================================"

# SVD (Stable Video Diffusion) - BEST for character consistency
echo "📹 Installing SVD (Stable Video Diffusion)..."
if [ ! -d "ComfyUI-SVD" ]; then
    git clone https://github.com/marshmellow77/ComfyUI-SVD.git && \
    echo "✅ SVD installed" || echo "❌ SVD failed"
else
    echo "✅ SVD already exists"
fi

# CogVideoX - Excellent temporal stability
echo "🧠 Installing CogVideoX..."  
if [ ! -d "ComfyUI-CogVideoXWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-CogVideoXWrapper.git && \
    echo "✅ CogVideoX installed" || echo "❌ CogVideoX failed"
else
    echo "✅ CogVideoX already exists"
fi

# LTX-Video - Latest high-quality model
echo "⚡ Installing LTX-Video..."
if [ ! -d "ComfyUI-LTXVideo" ]; then
    git clone https://github.com/kijai/ComfyUI-LTXVideo.git && \
    echo "✅ LTX-Video installed" || echo "❌ LTX-Video failed"  
else
    echo "✅ LTX-Video already exists"
fi

# Install Priority 2: Control and enhancement nodes
echo ""
echo "🎛️ PRIORITY 2: Control & Enhancement Nodes" 
echo "==========================================="

# ControlNet Auxiliary - Camera control
echo "🎮 Installing ControlNet-Aux..."
if [ ! -d "comfyui_controlnet_aux" ]; then
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    echo "✅ ControlNet-Aux installed" || echo "❌ ControlNet-Aux failed"
else
    echo "✅ ControlNet-Aux already exists"
fi

# Advanced ControlNet
echo "🎛️ Installing Advanced-ControlNet..."
if [ ! -d "ComfyUI-Advanced-ControlNet" ]; then
    git clone https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git && \
    echo "✅ Advanced-ControlNet installed" || echo "❌ Advanced-ControlNet failed"
else
    echo "✅ Advanced-ControlNet already exists"
fi

# Frame Interpolation
echo "🎞️ Installing Frame-Interpolation..."
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git && \
    echo "✅ Frame-Interpolation installed" || echo "❌ Frame-Interpolation failed"
else  
    echo "✅ Frame-Interpolation already exists"
fi

# IC-Light for better lighting
echo "💡 Installing IC-Light..."
if [ ! -d "ComfyUI-IC-Light" ]; then
    git clone https://github.com/huchenlei/ComfyUI-IC-Light.git && \
    echo "✅ IC-Light installed" || echo "❌ IC-Light failed"
else
    echo "✅ IC-Light already exists"  
fi

echo ""
echo "🎉 ADVANCED VIDEO NODES INSTALLATION COMPLETE!"
echo "==============================================="
echo ""
echo "✅ Installed nodes:"
ls -1 /default-comfyui-bundle/ComfyUI/custom_nodes/ | grep -E "(SVD|CogVideo|LTX|controlnet|ControlNet|Frame|IC-Light)" || echo "⚠️ No advanced nodes found"

echo ""
echo "🎯 Ready for Veo-quality video generation!"
echo "Models will be downloaded on first use."