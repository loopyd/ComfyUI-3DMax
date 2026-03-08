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
gcs() {
    info "Cloning $1..."
    git clone --quiet --recurse-submodules "$@" || {
        error "Failed to clone $1"
        return 1
    }
    return 0
}
download_model() {
    local url="$1"
    local dst="$2"
    local tmp="${dst}.part"
    mkdir -p "$(dirname "${dst}")"
    if [ -s "${dst}" ]; then
        info "Model already present: ${dst}"
        return 0
    fi
    info "Downloading model $(basename "${dst}")..."
    rm -f "${tmp}"
    if curl -L --fail --retry 3 --retry-delay 5 --output "${tmp}" "${url}"; then
        mv "${tmp}" "${dst}"
        success "Downloaded model: ${dst}"
        return 0
    fi
    rm -f "${tmp}"
    return 1
}


info "########################################"
info "[INFO] Downloading Models..."
info "########################################"

cd /default-comfyui-bundle/ComfyUI/models/vae_approx || {
    error "Failed to change directory to VAE models for downloading"
    exit 1
}

gcs https://github.com/madebyollin/taesd.git
cp taesd/*.pth .
rm -rf taesd

ANIMATEDIFF_MODEL_NAME="mm_sd_v15_v2.ckpt"
if download_model "https://huggingface.co/guoyww/animatediff/resolve/main/${ANIMATEDIFF_MODEL_NAME}" "/default-comfyui-bundle/ComfyUI/models/animatediff_models/${ANIMATEDIFF_MODEL_NAME}"; then
    mkdir -p "/default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-AnimateDiff-Evolved/models"
    ln -sfn "/default-comfyui-bundle/ComfyUI/models/animatediff_models/${ANIMATEDIFF_MODEL_NAME}" "/default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-AnimateDiff-Evolved/models/${ANIMATEDIFF_MODEL_NAME}"
    success "AnimateDiff default motion model installed and linked for ComfyUI-AnimateDiff-Evolved."
else
    warning "Failed to download AnimateDiff motion model (${ANIMATEDIFF_MODEL_NAME}). AnimateDiff-Evolved may report missing models."
fi