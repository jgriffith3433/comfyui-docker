#!/bin/bash
# =============================================================================
# Pre-start hook: runs BEFORE ComfyUI starts
#
# 1. Copy vendored workflows into ComfyUI's workflow directory
# 2. Install custom nodes (git clone or copy)
# 3. Auto-resolve model dependencies for all vendored workflows
# =============================================================================
set -e

echo "========================================"
echo "[HOOK] Running pre-start hook..."
echo "========================================"

COMFYUI_DIR="/root/ComfyUI"
MODELS_DIR="${COMFYUI_DIR}/models"
WORKFLOWS_TARGET="${COMFYUI_DIR}/user/default/workflows"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"

# ---------------------------------------------------------------------------
# 1. Copy vendored workflows
# ---------------------------------------------------------------------------
if [ -d /bundled-workflows ] && [ "$(ls -A /bundled-workflows/*.json 2>/dev/null)" ]; then
    mkdir -p "${WORKFLOWS_TARGET}"
    echo "[HOOK] Copying vendored workflows..."
    cp -v /bundled-workflows/*.json "${WORKFLOWS_TARGET}/"
    echo "[HOOK] $(ls /bundled-workflows/*.json | wc -l) workflow(s) installed."
else
    echo "[HOOK] No bundored workflows found."
fi

# ---------------------------------------------------------------------------
# 2a. Copy build-time advanced nodes to runtime
# ---------------------------------------------------------------------------
BUILD_NODES="/default-comfyui-bundle/ComfyUI/custom_nodes"
if [ -d "$BUILD_NODES" ]; then
    echo "[HOOK] Syncing build-time custom nodes to runtime..."
    for node_dir in "$BUILD_NODES"/*/; do
        case "$node_dir" in *'*'*) break ;; esac
        node_name="$(basename "$node_dir")"
        target="${CUSTOM_NODES_DIR}/${node_name}"
        # Skip non-node entries
        [ -f "${node_dir}/__init__.py" ] || [ -f "${node_dir}/nodes.py" ] || [ -f "${node_dir}/pyproject.toml" ] || continue
        if [ ! -d "${target}" ]; then
            echo "[HOOK] Copying build-time node: ${node_name}"
            cp -r "${node_dir}" "${target}"
        else
            echo "[HOOK] Build-time node already present: ${node_name}"
        fi
    done
fi

# ---------------------------------------------------------------------------
# 2b. Install vendored custom nodes (from /bundled-custom-nodes)
# ---------------------------------------------------------------------------
echo "[HOOK] Checking for vendored custom nodes..."
if [ -d /bundled-custom-nodes ]; then
    for node_dir in /bundled-custom-nodes/*/; do
        case "$node_dir" in *'*'*) break ;; esac

        node_name="$(basename "$node_dir")"
        target="${CUSTOM_NODES_DIR}/${node_name}"

        if [ -f "${node_dir}/repo.txt" ]; then
            repo_url="$(head -1 "${node_dir}/repo.txt" | tr -d '[:space:]')"
            if [ ! -d "${target}/.git" ]; then
                echo "[HOOK] Cloning custom node: ${node_name} from ${repo_url}"
                git clone --depth 1 "${repo_url}" "${target}" || echo "[HOOK] WARN: Failed to clone ${node_name}"
            else
                echo "[HOOK] Custom node already cloned: ${node_name}"
            fi
            if [ -f "${target}/requirements.txt" ]; then
                echo "[HOOK] Installing deps for ${node_name}..."
                pip install --no-cache-dir -r "${target}/requirements.txt" || true
            fi
        elif [ -f "${node_dir}/__init__.py" ] || [ -f "${node_dir}/nodes.py" ]; then
            if [ ! -d "${target}" ]; then
                echo "[HOOK] Copying custom node: ${node_name}"
                cp -r "${node_dir}" "${target}"
            fi
        else
            echo "[HOOK] Skipping ${node_name} (not a custom node)"
        fi
    done
else
    echo "[HOOK] No vendored custom nodes directory found."
fi

# ---------------------------------------------------------------------------
# 3. Auto-resolve models for vendored workflows
# ---------------------------------------------------------------------------
if [ "${RESOLVE_MODELS:-true}" = "true" ]; then
    if [ -f /scripts/resolve_models.py ] && [ -d /bundled-workflows ]; then
        echo "[HOOK] Auto-resolving models for vendored workflows..."
        for wf in /bundled-workflows/*.json; do
            echo "[HOOK] Resolving: $(basename "$wf")"
            python3 /scripts/resolve_models.py \
                --workflow "$wf" \
                --models-dir "${MODELS_DIR}" \
                --auto \
                || echo "[HOOK] WARN: Failed to resolve models for $(basename "$wf")"
        done
    else
        echo "[HOOK] Skipping model resolution (no resolver or workflows)."
    fi
else
    echo "[HOOK] Model resolution disabled (RESOLVE_MODELS=false)."
fi

# ---------------------------------------------------------------------------
# 4. Ensure T5 text encoder exists (needed by CogVideoX, not auto-downloaded)
# ---------------------------------------------------------------------------
T5_DIR="${MODELS_DIR}/clip/t5"
T5_FILE="${T5_DIR}/google_t5-v1_1-xxl_encoderonly-fp8_e4m3fn.safetensors"
if [ ! -f "${T5_FILE}" ]; then
    echo "[HOOK] Downloading T5-XXL FP8 text encoder (~4.9GB)..."
    mkdir -p "${T5_DIR}"
    T5_URL="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors"
    if command -v aria2c &> /dev/null; then
        aria2c -x 16 -s 16 -d "${T5_DIR}" -o "google_t5-v1_1-xxl_encoderonly-fp8_e4m3fn.safetensors" "${T5_URL}" \
            || echo "[HOOK] WARN: T5 download failed"
    else
        wget -O "${T5_FILE}" "${T5_URL}" \
            || echo "[HOOK] WARN: T5 download failed"
    fi
else
    echo "[HOOK] T5 text encoder already present."
fi

echo "========================================"
echo "[HOOK] Pre-start hook complete."
echo "========================================"
