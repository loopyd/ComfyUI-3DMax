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
CSCRIPT_ARGS=($@)
CSCRIPT_ACTION=""
CSCRIPT_BARGS=()
CSCRUOT_CARGS=("--disable-xformers" "--use-pytorch-cross-attention" "--fast")
CSCRIPT_FORCE=0

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

declare -A TRACKED_DIRS=(
    ["storage"]="storage"
    ["models"]="storage-models/models"
    ["hf-hub"]="storage-models/hf-hub"
    ["torch-hub"]="storage-models/torch-hub"
    ["input"]="storage-user/input"
    ["output"]="storage-user/output"
    ["workflows"]="storage-user/workflows"
)

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
prepare_dirs() {
    info "Preparing tracked directories..."
    for dir in "${!TRACKED_DIRS[@]}"; do
        if [ ! -d "${CSCRIPT_DIR}/${TRACKED_DIRS[$dir]}" ]; then
            mkdir -p "${CSCRIPT_DIR}/${TRACKED_DIRS[$dir]}"
            info "Created directory: $dir @ ${CSCRIPT_DIR}/${TRACKED_DIRS[$dir]}"
        else
            warning "Directory already exists: $dir @ ${CSCRIPT_DIR}/${TRACKED_DIRS[$dir]}"
        fi
    done
    success "Directory preparation completed."
}
clean_dirs() {
    info "Cleaning up tracked directories..."
    for dir in "${!TRACKED_DIRS[@]}"; do
        if [ -d "${CSCRIPT_DIR}/${TRACKED_DIRS[$dir]}" ]; then
            rm -rf "${CSCRIPT_DIR}/${TRACKED_DIRS[$dir]}"
            info "Cleaned directory: $dir @ ${CSCRIPT_DIR}/${TRACKED_DIRS[$dir]}"
        fi
    done
    success "Directory cleanup completed."
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
    if docker_image_is_built "${IMAGE_NAME}" && [ "${CSCRIPT_FORCE}" -ne 1 ]; then
        error "Docker image '${IMAGE_NAME}' already exists. Use -f|--force option if you wish to force rebuild."
        return
    fi
    if docker build --help | grep -q -- '--progress'; then
        build_progress_args=(--progress=plain)
    fi
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
}
docker_run() {
    if ! docker_image_is_built "${IMAGE_NAME}"; then
        error "Docker image '${IMAGE_NAME}' does not exist. Please build it first."
        exit 1
    fi
    if [ "${#CSCRIPT_BARGS[@]}" -gt 0 ]; then
        CSCRIPT_CARGS=(${CSCRIPT_BARGS[*]})
    fi
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
        -e CLI_ARGS="${CSCRIPT_CARGS[*]}" \
        "${IMAGE_NAME}"; then
        error "Failed to run Docker container."
        exit 1
    else
        success "Docker container ran successfully."
    fi
}
usage() {
    echo "loopyd-3DMax ComfyUI Docker Project"
    echo "Author: LoopyD (loopyd@github.com)"
    echo ""
    case "$CSCRIPT_ACTION" in
        build) 
            echo "Usage: $0 build [OPTIONS]"
            echo "  Use this action to build the project"
            echo ""
            echo "  Build customization options:"
            echo "    -tz, --timezone TZ                Set the timezone (default: ${TZ})"
            echo "    -l, --locale LOCALE               Set the locale (default: ${LOCALE})"
            echo "    -cv, --cuda-version VERSION       Set the CUDA version (default: ${CUDA_VERSION})"
            echo "    -cvf, --cuda-minor-fallback VERSION  Set the CUDA minor version fallback (default: ${CUDA_MINOR_FALLBACK})"
            echo "    -pv, --python-version VERSION      Set the Python version (default: ${PYTHON_VERSION})"
            echo "    -pvf, --python-minor-fallback VERSION  Set the Python minor version fallback (default: ${PYTHON_MINOR_FALLBACK})"
            echo "    -tv, --torch-version VERSION       Set the PyTorch version (default: ${TORCH_VERSION})"
            echo "    -tvv, --torchvision-version VERSION  Set the TorchVision version (default: ${TORCHVISION_VERSION})"
            echo "    -tva, --torchaudio-version VERSION       Set the TorchAudio version (default: ${TORCHAUDIO_VERSION})"
            echo "    -xv, --xformers-version VERSION    Set the xFormers version (default: ${XFORMERS_VERSION})"
            echo "    -gccv, --gcc-version VERSION       Set the GCC version (default: ${GCC_VERSION})"
            echo "    -f, --force                        Force rebuild the Docker image even if it already exists"
            ;;
        run)
            echo "Usage: $0 run [CLI_ARGS]"
            echo "  Run the Docker container"
            echo ""
            echo "  Any additional arguments will be passed as CLI_ARGS environment variable to the ComfyUI container."
            echo "  Default CLI_ARGS: ${CSCRIPT_CARGS[*]}"
            ;;
        clean)
            echo "Usage: $0 clean"
            echo "  Clean up existing Docker images, containers, and tracked directories"
            ;;
        help|*)
            echo "Usage: $0 [ACTION] [ARGS...]"
            echo "  build - Build the Docker image (if not already built)"
            echo "  run   - Run the Docker container"
            echo "  clean - Clean up existing Docker images, containers, and tracked directories"
            echo "  help  - Show this help message"
            exit 1
            ;;
    esac
    echo ""
    echo "Global options:"
    echo "  -h, --help                  Show help, and exit."
    echo "  -nc, --nocolor              Disable colored output."
}
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$CSCRIPT_ACTION" in
            "")
                case "$1" in
                    build|run|clean|help)
                        CSCRIPT_ACTION="$1"
                        shift
                        ;;
                    -h|--help)
                        CSCRIPT_ACTION="help"
                        shift
                        ;;
                    *)
                        error "Unknown action: $1"
                        usage ""
                        exit 1
                        ;;
                esac
                ;;
            build)
                case "$1" in
                    -h|--help)
                        usage "build"
                        exit 0
                        ;;
                    -tz|--timezone)
                        if [ -n "${2:-}" ]; then
                            TZ="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -l|--locale)
                        if [ -n "${2:-}" ]; then
                            LOCALE="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -cv|--cuda-version)
                        if [ -n "${2:-}" ]; then
                            CUDA_VERSION="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -cvf|--cuda-minor-fallback)
                        if [ -n "${2:-}" ]; then
                            CUDA_MINOR_FALLBACK="$2"
                            shift 2
                        else    
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -pv|--python-version)
                        if [ -n "${2:-}" ]; then
                            PYTHON_VERSION="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -pvf|--python-minor-fallback)
                        if [ -n "${2:-}" ]; then
                            PYTHON_MINOR_FALLBACK="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -tv|--torch-version)
                        if [ -n "${2:-}" ]; then
                            TORCH_VERSION="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -tvv|--torchvision-version)
                        if [ -n "${2:-}" ]; then
                            TORCHVISION_VERSION="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -tva|--torchaudio-version)
                        if [ -n "${2:-}" ]; then
                            TORCHAUDIO_VERSION="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -xv|--xformers-version)
                        if [ -n "${2:-}" ]; then
                            XFORMERS_VERSION="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -gccv|--gcc-version)
                        if [ -n "${2:-}" ]; then
                            GCC_VERSION="$2"
                            shift 2
                        else
                            error "Missing value for $1"
                            usage "build"
                            exit 1
                        fi
                        ;;
                    -f|--force)
                        CSCRIPT_FORCE=1
                        shift
                        ;;
                    -nc|--nocolor)
                        C_RED=""
                        C_GREEN=""
                        C_YELLOW=""
                        C_BLUE=""
                        C_RESET=""
                        C_BOLD=""
                        shift
                        ;;
                    *)
                        error "Unknown option for build action: $1."
                        usage "build"
                        exit 1
                        ;;
                esac
                ;;
            run)
                case "$1" in
                    -h|--help)
                        usage "run"
                        exit 0
                        ;;
                    -nc|--nocolor)
                        C_RED=""
                        C_GREEN=""
                        C_YELLOW=""
                        C_BLUE=""
                        C_RESET=""
                        C_BOLD=""
                        shift
                        ;;
                    *)
                        CSCRIPT_BARGS+=("$1")
                        shift
                        ;;
                esac
                ;;
            clean)
                case "$1" in
                    -h|--help)
                        usage "clean"
                        exit 0
                        ;;
                    -nc|--nocolor)
                        C_RED=""
                        C_GREEN=""
                        C_YELLOW=""
                        C_BLUE=""
                        C_RESET=""
                        C_BOLD=""
                        shift
                        ;;
                    *)
                        error "Unknown option for clean action: $1."
                        exit 1
                        ;;
                esac
                ;;
            help)
                # No additional args expected for help.
                ;;
            *)
                case "$1" in
                    -h|--help)
                        CSCRIPT_ACTION="help"
                        ;;
                    *)
                        CSCRIPT_BARGS+=("$1")
                        ;;
                esac
                shift
                ;;
        esac
    done
}

parse_args "${CSCRIPT_ARGS[@]}"

case "$CSCRIPT_ACTION" in
    build)
        prepare_dirs
        docker_build
        ;;
    run)
        docker_run
        ;;
    clean)
        docker_clean "comfyui" "${IMAGE_NAME}"
        clean_dirs
        ;;
    help|*)
        usage ""
        exit 1
        ;;
esac