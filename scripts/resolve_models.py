#!/usr/bin/env python3
"""
ComfyUI Workflow Model Resolver

Parses a ComfyUI API-format workflow JSON, identifies all required model files,
checks if they exist locally, and downloads missing ones.

Model lookup sources (checked in order):
  1. Local overrides   — model-overrides.json (custom/edge-case models you maintain)
  2. ComfyUI-Manager   — model-list.json (cached from GitHub, huge community DB)
  3. HuggingFace API   — searches by filename across all public repos
  4. Civitai API       — searches by model name
  5. Interactive prompt — asks user for URL, saves to overrides for next time

Usage:
  python resolve_models.py --workflow workflow.json --models-dir /path/to/models
  python resolve_models.py --workflow workflow.json --auto
  python resolve_models.py --workflow workflow.json --dry-run
  python resolve_models.py --refresh-cache
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path

# ---------------------------------------------------------------------------
# Mapping: ComfyUI node class_type → (model subfolder, input field name(s))
# ---------------------------------------------------------------------------
LOADER_MAP = {
    # Checkpoints
    "CheckpointLoaderSimple":   ("checkpoints", "ckpt_name"),
    "CheckpointLoader":         ("checkpoints", "ckpt_name"),
    "unCLIPCheckpointLoader":   ("checkpoints", "ckpt_name"),
    # Diffusion / UNet
    "UNETLoader":               ("diffusion_models", "unet_name"),
    # CLIP
    "CLIPLoader":               ("clip", "clip_name"),
    "DualCLIPLoader":           ("clip", ["clip_name1", "clip_name2"]),
    "TripleCLIPLoader":         ("clip", ["clip_name1", "clip_name2", "clip_name3"]),
    "CLIPVisionLoader":         ("clip_vision", "clip_name"),
    # VAE
    "VAELoader":                ("vae", "vae_name"),
    # LoRA
    "LoraLoader":               ("loras", "lora_name"),
    "LoraLoaderModelOnly":      ("loras", "lora_name"),
    # ControlNet
    "ControlNetLoader":         ("controlnet", "control_net_name"),
    # Upscale
    "UpscaleModelLoader":       ("upscale_models", "model_name"),
    # Style
    "StyleModelLoader":         ("style_models", "style_model_name"),
    # GLIGEN
    "GLIGENLoader":             ("gligen", "gligen_name"),
    # Hypernetwork
    "HypernetworkLoader":       ("hypernetworks", "hypernetwork_name"),
    # Embeddings (textual inversion)
    "EmbeddingLoader":          ("embeddings", "embedding_name"),
}

# Some loaders check multiple directories
FALLBACK_DIRS = {
    "diffusion_models": ["unet"],
    "unet": ["diffusion_models"],
    "clip": ["text_encoders"],
    "text_encoders": ["clip"],
}

# ---------------------------------------------------------------------------
# Cache config
# ---------------------------------------------------------------------------
MANAGER_MODEL_LIST_URL = "https://raw.githubusercontent.com/ltdrdata/ComfyUI-Manager/main/model-list.json"
CACHE_MAX_AGE_HOURS = 24
HF_API_BASE = "https://huggingface.co/api"
CIVITAI_API_BASE = "https://civitai.com/api/v1"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_script_dir():
    return Path(__file__).resolve().parent


def get_cache_dir():
    d = get_script_dir() / ".cache"
    d.mkdir(parents=True, exist_ok=True)
    return d


def get_overrides_path():
    return get_script_dir() / "model-overrides.json"


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def http_get_json(url, timeout=30):
    """GET a URL and return parsed JSON."""
    req = urllib.request.Request(url, headers={"User-Agent": "ComfyUI-ModelResolver/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download_file(url, dest, chunk_size=8192):
    """Download a file with progress."""
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".tmp")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ComfyUI-ModelResolver/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            total = resp.headers.get("Content-Length")
            total = int(total) if total else None
            downloaded = 0
            with open(tmp, "wb") as f:
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        pct = downloaded * 100 / total
                        mb_dl = downloaded / 1048576
                        mb_tot = total / 1048576
                        print(f"\r  ⬇️  {mb_dl:.1f}/{mb_tot:.1f} MB ({pct:.0f}%)", end="", flush=True)
                    else:
                        print(f"\r  ⬇️  {downloaded / 1048576:.1f} MB", end="", flush=True)
            print()
        tmp.rename(dest)
        return True
    except Exception as e:
        if tmp.exists():
            tmp.unlink()
        print(f"  ❌ Download failed: {e}")
        return False


# ===================================================================
#  SOURCE 1: Local Overrides
# ===================================================================

class OverridesSource:
    """Local model-overrides.json — user-maintained edge-case mappings."""
    name = "local-overrides"

    def __init__(self):
        self.data = {}
        self._load()

    def _load(self):
        path = get_overrides_path()
        if path.exists():
            raw = load_json(path)
            for m in raw.get("models", []):
                fname = m.get("filename", "")
                url = m.get("url", "")
                if fname and url:
                    self.data[fname.lower()] = m

    def lookup(self, filename, subfolder):
        entry = self.data.get(filename.lower())
        if entry:
            return entry.get("url")
        return None

    def add_entry(self, filename, subfolder, url, name=None):
        """Add a new entry and persist to disk."""
        path = get_overrides_path()
        raw = load_json(path) if path.exists() else {"models": []}
        entry = {
            "name": name or filename.replace(".safetensors", "").replace(".pth", "").replace("_", " ").title(),
            "type": subfolder,
            "base": "unknown",
            "save_path": subfolder,
            "filename": filename,
            "url": url,
            "description": "Auto-added by resolver",
        }
        raw["models"].append(entry)
        save_json(path, raw)
        self.data[filename.lower()] = entry
        print(f"  💾 Saved to overrides: {filename} → {url[:80]}...")


# ===================================================================
#  SOURCE 2: ComfyUI-Manager model-list.json
# ===================================================================

class ManagerSource:
    """ComfyUI-Manager's community-maintained model list."""
    name = "comfyui-manager"

    def __init__(self, force_refresh=False):
        self.data = {}
        self._load(force_refresh)

    def _load(self, force=False):
        cache_path = get_cache_dir() / "model-list.json"
        need_fetch = force or not cache_path.exists()
        if not need_fetch:
            age_hours = (time.time() - cache_path.stat().st_mtime) / 3600
            if age_hours >= CACHE_MAX_AGE_HOURS:
                need_fetch = True

        if need_fetch:
            print("📥 Fetching ComfyUI-Manager model list...")
            try:
                raw = http_get_json(MANAGER_MODEL_LIST_URL)
                save_json(cache_path, raw)
            except Exception as e:
                print(f"  ⚠️  Fetch failed: {e}")
                if cache_path.exists():
                    raw = load_json(cache_path)
                else:
                    raw = {"models": []}
        else:
            raw = load_json(cache_path)

        for m in raw.get("models", []):
            fname = m.get("filename", "")
            if fname:
                self.data[fname.lower()] = m

        print(f"  📦 ComfyUI-Manager: {len(self.data)} models indexed")

    def lookup(self, filename, subfolder):
        entry = self.data.get(filename.lower())
        if entry:
            return entry.get("url")
        return None


# ===================================================================
#  SOURCE 3: HuggingFace API
# ===================================================================

class HuggingFaceSource:
    """Search HuggingFace for model files by filename."""
    name = "huggingface"

    # Known ComfyUI model repos on HF (checked first for speed)
    KNOWN_REPOS = [
        "Comfy-Org/z_image_turbo",
        "Comfy-Org/stable-diffusion-3.5-fp8",
        "Comfy-Org/flux1-schnell",
        "Comfy-Org/flux1-dev",
        "black-forest-labs/FLUX.1-schnell",
        "black-forest-labs/FLUX.1-dev",
        "stabilityai/stable-diffusion-3-medium",
        "stabilityai/stable-diffusion-xl-base-1.0",
        "stabilityai/sdxl-turbo",
    ]

    # Map subfolder → HF tree path within repos (Comfy-Org convention)
    SUBFOLDER_PATHS = {
        "diffusion_models": "split_files/diffusion_models",
        "unet": "split_files/diffusion_models",
        "text_encoders": "split_files/text_encoders",
        "clip": "split_files/text_encoders",
        "vae": "split_files/vae",
        "loras": "split_files/loras",
        "checkpoints": "",
    }

    def __init__(self):
        self._cache = {}  # filename → url

    def _search_known_repos(self, filename, subfolder):
        """Check known Comfy-Org repos for the file."""
        # Try subfolder-specific paths first
        tree_paths = []
        sp = self.SUBFOLDER_PATHS.get(subfolder)
        if sp:
            tree_paths.append(sp)
        # Also try root and common paths
        tree_paths.extend(["split_files/diffusion_models", "split_files/text_encoders",
                           "split_files/vae", "split_files/loras", ""])

        for repo in self.KNOWN_REPOS:
            for tree_path in tree_paths:
                try:
                    url = f"{HF_API_BASE}/models/{repo}/tree/main"
                    if tree_path:
                        url += f"/{tree_path}"
                    files = http_get_json(url)
                    for f in files:
                        if f.get("type") == "file" and f["path"].endswith(filename):
                            dl_url = f"https://huggingface.co/{repo}/resolve/main/{f['path']}"
                            return dl_url
                except Exception:
                    continue
        return None

    def _search_api(self, filename):
        """Search HuggingFace models API by filename stem."""
        stem = filename.replace(".safetensors", "").replace(".pth", "").replace(".ckpt", "")
        try:
            query = urllib.parse.quote(stem)
            results = http_get_json(f"{HF_API_BASE}/models?search={query}&limit=10&sort=downloads&direction=-1")
            for model in results:
                model_id = model.get("modelId", model.get("id", ""))
                if not model_id:
                    continue
                # Check if this repo has our exact file
                try:
                    siblings = http_get_json(f"{HF_API_BASE}/models/{model_id}?blobs=false")
                    for sib in siblings.get("siblings", []):
                        rfilename = sib.get("rfilename", "")
                        if rfilename.endswith(filename):
                            return f"https://huggingface.co/{model_id}/resolve/main/{rfilename}"
                except Exception:
                    continue
                # Also check tree for repos with split_files structure
                for subdir in ["", "split_files/diffusion_models", "split_files/text_encoders",
                               "split_files/vae", "split_files/loras"]:
                    try:
                        tree_url = f"{HF_API_BASE}/models/{model_id}/tree/main"
                        if subdir:
                            tree_url += f"/{subdir}"
                        tree = http_get_json(tree_url)
                        for f in tree:
                            if f.get("type") == "file" and f["path"].endswith(filename):
                                return f"https://huggingface.co/{model_id}/resolve/main/{f['path']}"
                    except Exception:
                        continue
        except Exception as e:
            print(f"  ⚠️  HuggingFace search failed: {e}")
        return None

    def lookup(self, filename, subfolder):
        key = filename.lower()
        if key in self._cache:
            return self._cache[key]

        print(f"  🔍 Searching HuggingFace for {filename}...")

        # Try known repos first (fast)
        url = self._search_known_repos(filename, subfolder)
        if url:
            self._cache[key] = url
            return url

        # Fall back to API search (slower)
        url = self._search_api(filename)
        if url:
            self._cache[key] = url
            return url

        self._cache[key] = None
        return None


# ===================================================================
#  SOURCE 4: Civitai API
# ===================================================================

class CivitaiSource:
    """Search Civitai for models by name."""
    name = "civitai"

    def __init__(self):
        self._cache = {}

    def lookup(self, filename, subfolder):
        key = filename.lower()
        if key in self._cache:
            return self._cache[key]

        print(f"  🔍 Searching Civitai for {filename}...")

        # Search by cleaned name
        stem = filename.replace(".safetensors", "").replace(".pth", "").replace(".ckpt", "")
        query = stem.replace("_", " ")

        try:
            encoded = urllib.parse.quote(query)
            results = http_get_json(f"{CIVITAI_API_BASE}/models?query={encoded}&limit=5&sort=Highest%20Rated")
            for item in results.get("items", []):
                for version in item.get("modelVersions", []):
                    for f in version.get("files", []):
                        fname = f.get("name", "")
                        # Check exact filename match or close match
                        if fname.lower() == filename.lower():
                            dl_url = f.get("downloadUrl")
                            if dl_url:
                                self._cache[key] = dl_url
                                return dl_url
                        # Also check if the file stem matches
                        if fname.lower().replace(".safetensors", "") == stem.lower():
                            dl_url = f.get("downloadUrl")
                            if dl_url:
                                self._cache[key] = dl_url
                                return dl_url
        except Exception as e:
            print(f"  ⚠️  Civitai search failed: {e}")

        self._cache[key] = None
        return None


# ===================================================================
#  Workflow parsing
# ===================================================================

def extract_required_models(workflow):
    """Parse workflow JSON and return list of required model dicts."""
    required = []
    for node_id, node in workflow.items():
        class_type = node.get("class_type", "")
        if class_type not in LOADER_MAP:
            continue
        subfolder, field_names = LOADER_MAP[class_type]
        if isinstance(field_names, str):
            field_names = [field_names]
        inputs = node.get("inputs", {})
        for field in field_names:
            filename = inputs.get(field)
            if filename and isinstance(filename, str):
                required.append({
                    "filename": filename,
                    "subfolder": subfolder,
                    "node_id": node_id,
                    "class_type": class_type,
                    "field": field,
                    "title": node.get("_meta", {}).get("title", class_type),
                })
    return required


def check_model_exists(models_dir, subfolder, filename):
    """Check if model exists in subfolder or fallback dirs."""
    primary = Path(models_dir) / subfolder / filename
    if primary.exists():
        return primary
    for alt in FALLBACK_DIRS.get(subfolder, []):
        alt_path = Path(models_dir) / alt / filename
        if alt_path.exists():
            return alt_path
    return None


# ===================================================================
#  Multi-source resolver
# ===================================================================

class ModelResolver:
    """Chains multiple lookup sources in priority order."""

    def __init__(self, sources):
        self.sources = sources

    def resolve(self, filename, subfolder):
        """Try each source in order. Returns (url, source_name) or (None, None)."""
        for source in self.sources:
            try:
                url = source.lookup(filename, subfolder)
                if url:
                    return url, source.name
            except Exception as e:
                print(f"  ⚠️  {source.name} error: {e}")
        return None, None


# ===================================================================
#  Run modes
# ===================================================================

def run_resolve(workflow_path, models_dir, dry_run=False, auto=False, interactive=True, json_output=False):
    """Main resolution logic."""
    workflow = load_json(workflow_path)
    required = extract_required_models(workflow)

    if not required:
        print("✅ No model loader nodes found in workflow.")
        return []

    print(f"\n📋 Workflow: {Path(workflow_path).name}")
    print(f"   Models required: {len(required)}\n")

    # Initialize sources
    overrides = OverridesSource()
    manager = ManagerSource()
    hf = HuggingFaceSource()
    civitai = CivitaiSource()
    resolver = ModelResolver([overrides, manager, hf, civitai])

    found_local = []
    downloadable = []
    no_source = []

    for model in required:
        existing = check_model_exists(models_dir, model["subfolder"], model["filename"])
        if existing:
            found_local.append({**model, "status": "found", "path": str(existing)})
            print(f"  ✅ {model['filename']} ({model['subfolder']}/)")
            continue

        url, source_name = resolver.resolve(model["filename"], model["subfolder"])
        if url:
            entry = {**model, "url": url, "source": source_name, "status": "downloadable"}
            downloadable.append(entry)
            print(f"  ⬇️  {model['filename']} → {model['subfolder']}/ [{source_name}]")

            # Auto-save HF/Civitai finds to overrides for next time
            if source_name in ("huggingface", "civitai"):
                overrides.add_entry(model["filename"], model["subfolder"], url)
        else:
            no_source.append({**model, "status": "no_source"})
            print(f"  ❓ {model['filename']} ({model['subfolder']}/) — NO SOURCE FOUND")

    # Summary
    print(f"\n{'='*60}")
    print(f"   ✅ Found locally:  {len(found_local)}")
    print(f"   ⬇️  Downloadable:  {len(downloadable)}")
    print(f"   ❓ No source:      {len(no_source)}")
    print(f"{'='*60}")

    results = found_local[:]

    # Handle downloads
    if downloadable and not dry_run:
        if auto:
            to_download = downloadable
        elif interactive:
            print(f"\n  Models to download:\n")
            for i, m in enumerate(downloadable, 1):
                size_note = ""
                print(f"    {i}. {m['filename']} [{m['source']}] {size_note}")

            try:
                answer = input("\n  Download all? [Y/n/comma-separated numbers]: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                answer = "n"

            if answer in ("", "y", "yes"):
                to_download = downloadable
            elif answer in ("n", "no"):
                to_download = []
            else:
                try:
                    indices = [int(x.strip()) - 1 for x in answer.split(",") if x.strip().isdigit()]
                    to_download = [downloadable[i] for i in indices if 0 <= i < len(downloadable)]
                except (ValueError, IndexError):
                    to_download = []
        else:
            to_download = []

        for m in to_download:
            dest = Path(models_dir) / m["subfolder"] / m["filename"]
            print(f"\n  Downloading: {m['filename']} → {dest}")
            ok = download_file(m["url"], dest)
            m["status"] = "downloaded" if ok else "download_failed"
            results.append(m)

        # Add non-downloaded ones to results
        for m in downloadable:
            if m not in to_download:
                results.append(m)
    else:
        results.extend(downloadable)

    # Handle no-source models interactively
    if no_source and interactive and not dry_run:
        print(f"\n  The following models have no known download source:\n")
        for m in no_source:
            print(f"  🔍 {m['filename']} ({m['subfolder']}/)")
            try:
                url = input("     Enter download URL (or Enter to skip): ").strip()
            except (EOFError, KeyboardInterrupt):
                url = ""

            if url:
                overrides.add_entry(m["filename"], m["subfolder"], url)
                dest = Path(models_dir) / m["subfolder"] / m["filename"]
                print(f"     Downloading to: {dest}")
                ok = download_file(url, dest)
                m["status"] = "downloaded" if ok else "download_failed"
                m["url"] = url
            results.append(m)
    else:
        results.extend(no_source)

    # Final status check
    if not dry_run:
        print(f"\n{'='*60}")
        print("  Final status:")
        all_ok = True
        for model in required:
            existing = check_model_exists(models_dir, model["subfolder"], model["filename"])
            if existing:
                print(f"  ✅ {model['filename']}")
            else:
                print(f"  ❌ {model['filename']} — STILL MISSING")
                all_ok = False

        if all_ok:
            print(f"\n🎉 All models resolved! Workflow is ready to run.")
        else:
            print(f"\n⚠️  Some models are still missing.")
            print(f"    Add URLs to: {get_overrides_path()}")
        print(f"{'='*60}")

    if json_output:
        print(json.dumps(results, indent=2, default=str))

    return results


# ===================================================================
#  Auto-detect models dir
# ===================================================================

def auto_detect_models_dir():
    candidates = [
        Path("/home/node/.openclaw/workspace/comfyui-models"),  # Claw container
        Path("/root/ComfyUI/models"),                            # ComfyUI container
        Path.home() / "ComfyUI" / "models",                     # Local install
        Path("./data/models"),                                   # Relative to comfyui-docker
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


# ===================================================================
#  Main
# ===================================================================

def main():
    ap = argparse.ArgumentParser(
        description="Resolve and download missing ComfyUI workflow model dependencies",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Sources (checked in order):
  1. model-overrides.json  — your local custom mappings
  2. ComfyUI-Manager       — community model list (cached 24h)
  3. HuggingFace           — API search across public repos
  4. Civitai               — API search by model name
  5. Interactive prompt     — ask for URL, save to overrides

Examples:
  python resolve_models.py -w workflow.json                  # Interactive
  python resolve_models.py -w workflow.json --auto           # Auto-download all
  python resolve_models.py -w workflow.json --dry-run        # Just report
  python resolve_models.py --refresh-cache                   # Refresh model list
        """,
    )
    ap.add_argument("--workflow", "-w", help="Path to ComfyUI API workflow JSON")
    ap.add_argument("--models-dir", "-m", help="Path to ComfyUI models/ directory")
    ap.add_argument("--auto", action="store_true", help="Non-interactive: auto-download all found models")
    ap.add_argument("--dry-run", action="store_true", help="Report only, no downloads")
    ap.add_argument("--refresh-cache", action="store_true", help="Force refresh model list cache")
    ap.add_argument("--json-output", action="store_true", help="Output results as JSON")
    args = ap.parse_args()

    if args.refresh_cache:
        ManagerSource(force_refresh=True)
        print("✅ Cache refreshed.")
        if not args.workflow:
            return

    if not args.workflow:
        ap.print_help()
        sys.exit(1)

    if not os.path.exists(args.workflow):
        print(f"❌ Workflow file not found: {args.workflow}")
        sys.exit(1)

    models_dir = args.models_dir
    if not models_dir:
        detected = auto_detect_models_dir()
        if detected:
            models_dir = str(detected)
            print(f"📂 Auto-detected models dir: {models_dir}")
        else:
            print("❌ Could not auto-detect models directory. Use --models-dir.")
            sys.exit(1)

    if not os.path.isdir(models_dir):
        print(f"⚠️  Creating models directory: {models_dir}")
        os.makedirs(models_dir, exist_ok=True)

    interactive = not args.auto and not args.dry_run and not args.json_output
    run_resolve(
        args.workflow, models_dir,
        dry_run=args.dry_run,
        auto=args.auto,
        interactive=interactive,
        json_output=args.json_output,
    )


if __name__ == "__main__":
    main()
