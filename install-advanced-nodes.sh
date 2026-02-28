#!/bin/bash
# Install advanced video generation nodes for ComfyUI

echo "🚀 Installing advanced video generation nodes..."

cd /default-comfyui-bundle/ComfyUI/custom_nodes || exit 1

# Stable Video Diffusion - PRIORITY 1
echo "📹 Installing SVD (Stable Video Diffusion)..."
git clone https://github.com/Stability-AI/generative-models.git SVD-generative-models || echo "SVD clone failed"
git clone https://github.com/marshmellow77/ComfyUI-SVD.git || echo "ComfyUI-SVD clone failed"

# CogVideoX - PRIORITY 1  
echo "🧠 Installing CogVideoX..."
git clone https://github.com/kijai/ComfyUI-CogVideoXWrapper.git || echo "CogVideoX clone failed"

# LTX-Video - PRIORITY 1
echo "⚡ Installing LTX-Video..."
git clone https://github.com/kijai/ComfyUI-LTXVideo.git || echo "LTX-Video clone failed"

# HunyuanVideo - PRIORITY 2
echo "🌟 Installing HunyuanVideo..."
git clone https://github.com/kijai/ComfyUI-HunyuanVideoWrapper.git || echo "HunyuanVideo clone failed"

# Control and Quality nodes - PRIORITY 2
echo "🎛️ Installing control nodes..."
git clone https://github.com/huchenlei/ComfyUI-IC-Light.git || echo "IC-Light clone failed"
git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git || echo "ControlNet-Aux clone failed"
git clone https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git || echo "Advanced-ControlNet clone failed"
git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git || echo "Frame-Interpolation clone failed"
git clone https://github.com/spacepxl/ComfyUI-Depth-Pro.git || echo "Depth-Pro clone failed"

# Motion control - PRIORITY 3
echo "🎬 Installing motion control nodes..."
git clone https://github.com/chaojie/ComfyUI-MotionCtrl.git || echo "MotionCtrl clone failed"

echo "✅ Advanced nodes installation complete!"
echo ""
echo "🎯 Installed video generation models:"
echo "  • SVD (Stable Video Diffusion) - Best for character consistency"
echo "  • CogVideoX - Excellent temporal stability" 
echo "  • LTX-Video - Latest high-quality model"
echo "  • HunyuanVideo - Alternative high-end model"
echo "  • Advanced controls for camera, lighting, motion"