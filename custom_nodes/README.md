# Custom Nodes

Each subfolder here becomes a ComfyUI custom node installed at container startup.

## Two installation methods:

### 1. Git-based (recommended for third-party nodes)
Create a folder with a `repo.txt` file containing the git clone URL:
```
custom_nodes/
  ComfyUI-Impact-Pack/
    repo.txt          # contains: https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
```
The entrypoint will `git clone --depth 1` it on first boot and install its `requirements.txt`.

### 2. Direct copy (for your own custom nodes)
Just put your Python files directly in the folder:
```
custom_nodes/
  my-custom-node/
    __init__.py
    nodes.py
    requirements.txt  # optional
```

## Dependencies
- Per-node: add a `requirements.txt` in the node's folder (installed at Docker build time for direct copies, at first boot for git clones)
- Global: add to the root `requirements.txt`
