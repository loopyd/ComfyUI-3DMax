#!/bin/bash
set -euo pipefail

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

CSCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults can be overridden by exporting environment variables before running the script
TZ="${TZ:-America/Los_Angeles}"
LOCALE="${LOCALE:-en_US.UTF-8}"
CUDA_VERSION="${CUDA_VERSION:-12.8}"
CUDA_MINOR_FALLBACK="${CUDA_MINOR_FALLBACK:-8}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
PYTHON_MINOR_FALLBACK="${PYTHON_MINOR_FALLBACK:-12}"
TORCH_VERSION="${TORCH_VERSION:-2.7.0}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.22.0}"
TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-2.7.0}"
XFORMERS_VERSION="${XFORMERS_VERSION:-0.0.30}"
GCC_VERSION="${GCC_VERSION:-14}"
TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.0 8.6 8.9 9.0 10.0}"
IMAGE_NAME="${IMAGE_NAME:-loopyd/comfyui-boot:3dmax}"

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
prepare_directories() {
    info "Preparing directories for Docker volume mounts..."
    declare -A dirs=(
        ["storage"]="storage"
        ["models"]="storage-models/models"
        ["hf-hub"]="storage-models/hf-hub"
        ["torch-hub"]="storage-models/torch-hub"
        ["input"]="storage-user/input"
        ["output"]="storage-user/output"
        ["workflows"]="storage-user/workflows"
    )
    for dir in "${!dirs[@]}"; do
        if [ ! -d "${CSCRIPT_DIR}/${dirs[$dir]}" ]; then
            mkdir -p "${CSCRIPT_DIR}/${dirs[$dir]}"
            success "Created directory: ${CSCRIPT_DIR}/${dirs[$dir]}"
        else
            info "Directory already exists: ${CSCRIPT_DIR}/${dirs[$dir]}"
        fi
    done
}
docker_image_is_built() {
    local image_name="$1"
    [[ -n "$(docker images -q "${image_name}" 2>/dev/null)" ]]
}
docker_container_exists() {
    local container_name="$1"
    [[ -n "$(docker ps -a -q --filter "name=^/${container_name}$" 2>/dev/null)" ]]
}

docker_clean() {
    local container_name="$1"
    local image_name="$2"
    if docker_container_exists "${container_name}"; then
        info "Removing existing Docker container named '${container_name}'..."
        if docker rm -f "${container_name}" > /dev/null; then
            success "Existing '${container_name}' container removed successfully."
        else
            warning "Failed to remove existing '${container_name}' container. You may want to check and clean it up manually."
        fi
    else
        info "No existing Docker container named '${container_name}' found."
    fi
    if docker_image_is_built "${image_name}"; then
        info "Removing existing Docker image '${image_name}'..."
        if docker rmi -f "${image_name}" > /dev/null; then
            success "Existing Docker image removed successfully."
        else
            warning "Failed to remove existing Docker image. You may want to check and clean it up manually."
        fi
    else
        info "No existing Docker image '${image_name}' found."
    fi
    local -a dangling_images=()
    mapfile -t dangling_images < <(docker images -f "dangling=true" -q)
    if [ "${#dangling_images[@]}" -gt 0 ]; then
        info "Removing dangling Docker images..."
        if docker rmi -f "${dangling_images[@]}" > /dev/null; then
            success "Dangling Docker images removed successfully."
        else
            warning "Failed to remove dangling Docker images. You may want to check and clean them up manually."
        fi
    else
        info "No dangling Docker images found."
    fi
}

docker_build() {
    local -a build_progress_args=()
    if docker build --help | grep -q -- '--progress'; then
        build_progress_args=(--progress=plain)
    fi

    if docker_image_is_built "${IMAGE_NAME}"; then
        info "Docker image '${IMAGE_NAME}' already exists. Skipping build."
    else
        info "Building Docker image '${IMAGE_NAME}' with plain progress output..."
        if DOCKER_BUILDKIT=1 BUILDKIT_PROGRESS=plain docker build \
            "${build_progress_args[@]}" \
            --build-arg TZ="${TZ}" \
            --build-arg LOCALE="${LOCALE}" \
            --build-arg CUDA_VERSION="${CUDA_VERSION}" \
            --build-arg CUDA_MINOR_FALLBACK="${CUDA_MINOR_FALLBACK}" \
            --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
            --build-arg PYTHON_MINOR_FALLBACK="${PYTHON_MINOR_FALLBACK}" \
            --build-arg TORCH_VERSION="${TORCH_VERSION}" \
            --build-arg TORCHVISION_VERSION="${TORCHVISION_VERSION}" \
            --build-arg TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION}" \
            --build-arg XFORMERS_VERSION="${XFORMERS_VERSION}" \
            --build-arg GCC_VERSION="${GCC_VERSION}" \
            -t "${IMAGE_NAME}" \
            -f "${CSCRIPT_DIR}/Dockerfile" \
            "${CSCRIPT_DIR}"; then
            success "Docker image built successfully."
        else
            error "Failed to build Docker image."
            exit 1
        fi
    fi
}

docker_run() {
    if ! docker run -it --rm \
        --name comfyui \
        --runtime nvidia \
        --gpus all \
        -p 8188:8188 \
        -v "${CSCRIPT_DIR}"/storage:/root \
        -v "${CSCRIPT_DIR}"/storage-models/models:/root/ComfyUI/models \
        -v "${CSCRIPT_DIR}"/storage-models/hf-hub:/root/.cache/huggingface/hub \
        -v "${CSCRIPT_DIR}"/storage-models/torch-hub:/root/.cache/torch/hub \
        -v "${CSCRIPT_DIR}"/storage-user/input:/root/ComfyUI/input \
        -v "${CSCRIPT_DIR}"/storage-user/output:/root/ComfyUI/output \
        -v "${CSCRIPT_DIR}"/storage-user/workflows:/root/ComfyUI/user/default/workflows \
        -e TZ="${TZ}" \
        -e LANG="${LOCALE}" \
        -e LC_ALL="${LOCALE}" \
        -e TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST}" \
        -e CLI_ARGS="--disable-xformers --use-pytorch-cross-attention --fast" \
        -e NVIDIA_VISIBLE_DEVICES=all \
        -e NVIDIA_DRIVER_CAPABILITIES=all \
        "${IMAGE_NAME}"; then
        error "Failed to run Docker container."
        exit 1
    else
        success "Docker container ran successfully."
    fi
}

prepare_directories
docker_clean "comfyui" "${IMAGE_NAME}"
docker_build 
docker_run