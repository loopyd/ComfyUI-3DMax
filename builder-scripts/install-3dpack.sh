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

info "########################################"
info "3D Pack Installation"
info "########################################"

cd /default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-3D-Pack || {
    error "Failed to change directory to 3D Pack for installation"
    exit 1
}

export FORCE_CUDA=1
export TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 10.0"
python ./install.py || {
    error "Failed to install 3D Pack. Please check the output for details."
    exit 1
}

success "3D Pack installation completed successfully."