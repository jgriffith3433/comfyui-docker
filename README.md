# ComfyUI Docker

Local ComfyUI instance for image generation, designed to work with the OpenClaw agent.

## Quick Start

1. **Prerequisites:** Docker Desktop with WSL2 + NVIDIA GPU drivers + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
2. Double-click `start.bat` (or run `docker compose up -d`)
3. Open **http://localhost:8188** in your browser

## Configuration

| Variable | Default | Description |
|---|---|---|
| `COMFYUI_PORT` | `8188` | Host port for the ComfyUI web UI / API |

Create a `.env` file to override defaults:
```
COMFYUI_PORT=8188
```

## Volumes

| Volume | Container Path | Purpose |
|---|---|---|
| `comfyui-storage` | `/root` | ComfyUI installation, venvs, config |
| `comfyui-models` | `/root/ComfyUI/models` | Model weights (checkpoints, LoRAs, VAEs, etc.) |
| `comfyui-hf-cache` | `/root/.cache/huggingface/hub` | Hugging Face model cache |
| `comfyui-torch-cache` | `/root/.cache/torch/hub` | PyTorch model cache |
| `comfyui-output` | `/root/ComfyUI/output` | Generated images |
| `comfyui-input` | `/root/ComfyUI/input` | Input images for img2img, inpainting, etc. |
| `comfyui-workflows` | `/root/ComfyUI/user/default/workflows` | Saved workflows |
| `comfyui-custom-nodes` | `/root/ComfyUI/custom_nodes` | Custom node packages |

## Integration with OpenClaw

The OpenClaw agent connects to ComfyUI at `host.docker.internal:8188` via its `comfyui` skill. The claw-docker project mounts this folder into the agent workspace and passes `COMFYUI_HOST` / `COMFYUI_PORT` environment variables.
