# =============================================================================
# Custom ComfyUI image built on top of yanwk/comfyui-boot:cpu
#
# What this adds:
#   - Vendored workflow files (workflows/) copied into the image
#   - Model resolver script for auto-downloading missing model weights
#   - Custom node installation (custom_nodes/ definitions)
#   - pip dependencies for custom nodes
#   - pre-start hook that auto-resolves models for all vendored workflows
# =============================================================================

FROM yanwk/comfyui-boot:cpu

# ---------------------------------------------------------------------------
# 1. System tools needed by the resolver (already have python3, git, aria2)
# ---------------------------------------------------------------------------
# (base image already has everything we need)

# ---------------------------------------------------------------------------
# 2. Copy scripts (model resolver, entrypoint wrapper)
# ---------------------------------------------------------------------------
COPY scripts/ /scripts/

# ---------------------------------------------------------------------------
# 3. Copy vendored workflows into the image
#    These get copied to /root/ComfyUI/user/default/workflows/ at first boot
#    AND are used by the auto-resolver on startup
# ---------------------------------------------------------------------------
COPY workflows/ /bundled-workflows/

# ---------------------------------------------------------------------------
# 4. Custom nodes
#    Each subfolder under custom_nodes/ contains a requirements.txt (if needed)
#    and gets cloned/copied into ComfyUI's custom_nodes at first boot.
#    For git-based nodes, create a file: custom_nodes/<name>/repo.txt
#    containing the git clone URL.
# ---------------------------------------------------------------------------
COPY custom_nodes/ /bundled-custom-nodes/

# ---------------------------------------------------------------------------
# 5. Install pip dependencies for custom nodes (at build time for speed)
#    Each custom node dir can have a requirements.txt
# ---------------------------------------------------------------------------
RUN for req in /bundled-custom-nodes/*/requirements.txt; do \
        if [ -f "$req" ]; then \
            echo "[BUILD] Installing deps from $req" && \
            pip install --no-cache-dir -r "$req" || true; \
        fi; \
    done

# ---------------------------------------------------------------------------
# 6. Extra pip packages (add any global deps here)
# ---------------------------------------------------------------------------
COPY requirements.txt /bundled-requirements.txt
RUN if [ -s /bundled-requirements.txt ]; then \
        pip install --no-cache-dir -r /bundled-requirements.txt; \
    fi

# ---------------------------------------------------------------------------
# 7. Pre-start hook: auto-resolve models + install custom nodes + copy workflows
#    The base image runs /root/user-scripts/pre-start.sh before ComfyUI starts.
#    We inject our own and the entrypoint copies it on first boot.
# ---------------------------------------------------------------------------
COPY entrypoint-hook.sh /bundled-pre-start.sh

# Override the entrypoint to inject our hook before the base entrypoint
COPY entrypoint-wrapper.sh /entrypoint-wrapper.sh
RUN chmod +x /entrypoint-wrapper.sh

CMD ["bash", "/entrypoint-wrapper.sh"]
