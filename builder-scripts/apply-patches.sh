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
patch_diffusers_controlnet_import() {
    local target_file="$1"
    if [ ! -f "${target_file}" ]; then
        error "Controlnet compatibility patch target not found: ${target_file}"
        return 1
    fi
    info "Applying controlnet compatibility patch: ${target_file}..."
    python /builder-scripts/controlnet_patcher.py "${target_file}" || {
        error "Failed to apply controlnet compatibility patch to ${target_file}"
        return 1
    }
    if python -m py_compile "${target_file}"; then
        success "Controlnet compatibility patch validated: ${target_file}"
        return 0
    else
        error "Controlnet compatibility patch produced invalid Python syntax: ${target_file}"
        return 1
    fi
}

info "########################################"
info "3DMax Patches"
info "########################################"

# Create config.ini to disable UV for ComfyUI-Manager.
mkdir -p /default-comfyui-bundle/ComfyUI/user/__manager
cat <<EOF > /default-comfyui-bundle/ComfyUI/user/__manager/config.ini
[default]
use_uv = False
security_level = weak
EOF

cd /default-comfyui-bundle/ComfyUI/custom_nodes || {
    error "Failed to change directory to ComfyUI custom_nodes for patching"
    exit 1
}

# Patch controlnet compatibility for older diffusers versions. The patch is idempotent.
for f in \
    ./ComfyUI-3D-Pack/Gen_3D_Modules/Stable3DGen/stablex/controlnetvae.py \
    ./ComfyUI-3D-Pack/Checkpoints/Diffusers/Stable3DGen/stablex/yoso-normal-v1-8-1/controlnet/controlnetvae.py
do
    patch_diffusers_controlnet_import "$f" || exit 1
done

# Compile Hunyuan3D modules bundled in ComfyUI-3D-Pack.
HUNYUAN_PAINT_ROOT="./ComfyUI-3D-Pack/Gen_3D_Modules/Hunyuan3D_2_1/hy3dpaint"
if [ ! -d "${HUNYUAN_PAINT_ROOT}" ]; then
    HUNYUAN_PAINT_ROOT="$(find "./ComfyUI-3D-Pack" -type d -path "*/Gen_3D_Modules/Hunyuan3D_2_1/hy3dpaint" | head -n1 || true)"
fi
info "Located Hunyuan3D paint module at: ${HUNYUAN_PAINT_ROOT}"

info "Compiling bundled Hunyuan3D custom rasterizer from ComfyUI-3D-Pack..."
cd "${HUNYUAN_PAINT_ROOT}/custom_rasterizer"
python setup.py install || {
    error "Failed to compile bundled Hunyuan3D custom_rasterizer"
    exit 1
}
success "Bundled Hunyuan3D custom_rasterizer compiled successfully"

info "Compiling bundled Hunyuan3D DifferentiableRenderer..."
cd "../DifferentiableRenderer"
bash -c "./compile_mesh_painter.sh" || {
    error "Failed to compile DifferentiableRenderer"
    exit 1
}
success "DifferentiableRenderer compiled successfully"

info "Installing mesh_inpaint_processor wheel package..."
cd "../mesh_inpaint_wheel"
python -m pip install --no-cache-dir . || {
    warning "mesh_inpaint_processor wheel install failed; DifferentiableRenderer may use Python fallback"
}
success "mesh_inpaint_processor wheel package installation step finished"

# Install and patch xatlas for high-poly mesh support.
info "Installing patched xatlas for high-poly mesh UV unwrapping..."
cd "/default-comfyui-bundle"
python -m pip uninstall -y xatlas 2>/dev/null || true
rm -rf xatlas-python >/dev/null 2>&1 || true
gcs https://github.com/mworchel/xatlas-python.git || exit $?
cd "./xatlas-python/extern"
rm -rf xatlas >/dev/null 2>&1 || true
gcs https://github.com/jpcy/xatlas.git || exit $?

# Patch xatlas to disable the fallback for large meshes, which can cause OOM and instability.
# The patch is idempotent.
sed -i '6774s|^#if 0$|//#if 0|;6778s|^#endif$|//#endif|' "./xatlas/source/xatlas/xatlas.cpp" || {
    error "Failed to patch xatlas for high-poly mesh support"
    exit 1
}

python -m pip install --no-cache-dir /default-comfyui-bundle/xatlas-python || {
    warning "xatlas-python build may have failed; high-poly UV unwrapping may not work"
}
success "xatlas-python patch for high-poly mesh support completed."
