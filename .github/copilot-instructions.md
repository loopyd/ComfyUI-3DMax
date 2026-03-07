# ComfyUI-3DMax Project Guidelines
## Project Overview
Docker-based ComfyUI environment optimized for 3D workflows with CUDA 12.8 support on NVIDIA 50-series (Blackwell) GPUs. Built on Ubuntu 24.04  with custom wheel compilation for compatibility.
## Docker Conventions
### Base Image
- **Base OS**: `ubuntu:24.04` (latest LTS, stable CUDA support)
- **CUDA Version**: 12.8 (explicitly specified, locked)
- **cuDNN Version**: 9.8.0.87-1 (compatible with CUDA 12.8)
- **Python Version**: 3.12 (most packages installed via pip)
### Volume Patterns
All volumes MUST be readable AND writable on the host at runtime. Use this structure:
```bash
storage/                                # Root user home persistence
storage-models/models/                  # ComfyUI model files
storage-models/hf-hub/                  # HuggingFace cache
storage-models/torch-hub/               # PyTorch model cache
storage-user/input/                     # User input files
storage-user/output/                    # Generated outputs
storage-user/workflows/                 # ComfyUI workflows
```
Always mount with full paths in container runtime:
- `/root` → `./storage`
- `/root/ComfyUI/models` → `./storage-models/models`
- `/root/.cache/huggingface/hub` → `./storage-models/hf-hub`
- `/root/.cache/torch/hub` → `./storage-models/torch-hub`
- `/root/ComfyUI/input` → `./storage-user/input`
- `/root/ComfyUI/output` → `./storage-user/output`
- `/root/ComfyUI/user/default/workflows` → `./storage-user/workflows`
### GPU Access
**NVIDIA 50-series cards (Blackwell architecture)** - use NVIDIA container runtime on host and ensure proper device access in container:
```bash
docker run --gpus all ...
```
For docker-compose, ensure is tagged for NVIDIA runtime and GPU access:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ['0']
          capabilities: [gpu]
```
Security options for NVIDIA containers:
```yaml
security_opt:
  - "label=disable"
  - "seccomp=unconfined"
```
### Build Optimization
- Use `--mount=type=cache` for package managers to speed up rebuilds
- Cache locations: `/var/cache/apt`, `/root/.cache/pip`, `/tmp/ffmpeg_download`
- Layer ordering matters: CUDA libs first, then Python, then ML packages
### Wheel Building for Blackwell GPUs
50-series cards require custom wheel compilation. Always:
- Include CUDA development libraries (`-dev` packages)
- Build xformers, torchvision, torchaudio from source or compatible wheels
- Set proper environment variables before pip installs:
  ```dockerfile
  ENV PATH="${PATH}:/usr/local/cuda-12.8/bin"
  ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/local/cuda-12.8/lib64"
  ENV CUDA_HOME="/usr/local/cuda-12.8"
  ```
## Shell Script Standards
### Color Output Pattern
For safe color output in scripts, define color variables conditionally:
```bash
if [ -n "${TERM:-}" ] && command -v tput >/dev/null 2>&1 && tput sgr0 >/dev/null 2>&1; then
    C_RED=$(tput setaf 1)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_BLUE=$(tput setaf 4)
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
else
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_RESET=""
    C_BOLD=""
fi
```
### Message Functions
Define consistent output functions:
```bash
error() {
    echo "${C_RED}${C_BOLD}Error:${C_RESET} ${C_RED}$1${C_RESET}" >&2
}
success() {
    echo "${C_GREEN}${C_BOLD}Success:${C_RESET} ${C_GREEN}$1${C_RESET}"
}
info() {
    echo "${C_BLUE}${C_BOLD}Info:${C_RESET} ${C_BLUE}$1${C_RESET}"
}
warning() {
    echo "${C_YELLOW}${C_BOLD}Warning:${C_RESET} ${C_YELLOW}$1${C_RESET}" >&2
}
```
### Script Headers
Always start scripts with:
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```
For interactive scripts (like entrypoint), use `set -e` only.
## ComfyUI Structure
### Bundle Organization
- Builder scripts in `builder-scripts/`: Image-time operations
- Runner scripts in `runner-scripts/`: Container startup operations
- Default bundle path: `/default-comfyui-bundle/ComfyUI`
- Runtime workdir: `/root/ComfyUI`
### Custom Node Installation
Use shallow clones with the `gcs` function:
```bash
gcs() {
    git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules "$@"
}
```
## Documentation
- Use **AsciiDoc** format (`.adoc` files) for READMEs and reference documentation
- Document CLI arguments in reference tables using AsciiDoc syntax
## Usage
### Cleaning
```bash
./3dmax.sh clean  # Cleans up the environment before building, and removes any images.
```
### Building
```bash
./3dmax.sh build  # Builds the image
```
### Running
```bash
./3dmax.sh  run # Runs image and starts container with proper volumes
```
### Docker Compose
```bash
docker compose up --build
```
## Key Conventions
1. **Always build locally**: 50-series GPUs need custom wheels not in pre-built images
2. **Disable xFormers**: Blackwell architecture requires `--disable-xformers` flag
3. **Pin versions**: CUDA 12.8, cuDNN 9.19.1.2-1, Python 3.12 explicitly specified
4. **Host-writable volumes**: All storage directories must be accessible from host
5. **Cache optimization**: Use Docker build cache mounts for faster iterations
6. **Security labels**: Disable SELinux labels for NVIDIA containers
7. **Python packages**: Most packages installed via pip; use Ubuntu system packages for OpenCV and base tools only
## Important Notes
- This is a yawnk **cu128-megapak** variant: includes 40+ custom nodes and CUDA dev kit
- Image size is large (~15GB+) due to full development environment
- Updates are slower than slim images due to wheel compilation requirements
- Container runs as root for NVIDIA GPU access compatibility
