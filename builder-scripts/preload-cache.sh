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
info "Downloading ComfyUI & Nodes..."
info "########################################"

mkdir -p /default-comfyui-bundle
cd /default-comfyui-bundle
gcs 'https://github.com/comfyanonymous/ComfyUI.git'
cd ./ComfyUI
# Using stable version (has a release tag)
git reset --hard "$(git tag | grep -e '^v' | sort -V | tail -1)"

# Create config.ini to disable UV for ComfyUI-Manager.
mkdir -p ../user/__manager
cat <<EOF > ../user/__manager/config.ini
[default]
use_uv = False
security_level = weak
EOF

cd ./custom_nodes

# Core
gcs https://github.com/Comfy-Org/ComfyUI-Manager.git

# Performance
gcs https://github.com/welltop-cn/ComfyUI-TeaCache.git ComfyUI-TeaCache.disabled
gcs https://github.com/city96/ComfyUI-GGUF.git
gcs https://github.com/nunchaku-tech/ComfyUI-nunchaku.git

# Workspace
gcs https://github.com/crystian/ComfyUI-Crystools.git
gcs https://github.com/Amorano/Jovi_Colorizer.git
gcs https://github.com/Amorano/Jovi_Help.git
gcs https://github.com/Amorano/Jovi_Measure.git
gcs https://github.com/Amorano/Jovi_Preset.git

# General
gcs https://github.com/ltdrdata/was-node-suite-comfyui.git
gcs https://github.com/Amorano/Jovimetrix.git
gcs https://github.com/bash-j/mikey_nodes.git
gcs https://github.com/chrisgoringe/cg-use-everywhere.git
gcs https://github.com/jags111/efficiency-nodes-comfyui.git
gcs https://github.com/kijai/ComfyUI-KJNodes.git
gcs https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
gcs https://github.com/rgthree/rgthree-comfy.git
gcs https://github.com/shiimizu/ComfyUI_smZNodes.git
gcs https://github.com/yolain/ComfyUI-Easy-Use.git

# Control
gcs https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
gcs https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git
gcs https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git
gcs https://github.com/chflame163/ComfyUI_LayerStyle.git
gcs https://github.com/Fannovel16/comfyui_controlnet_aux.git
gcs https://github.com/florestefano1975/comfyui-portrait-master.git
gcs https://github.com/huchenlei/ComfyUI-layerdiffuse.git
gcs https://github.com/kijai/ComfyUI-Florence2.git
gcs https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git
gcs https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git
gcs https://github.com/twri/sdxl_prompt_styler.git

# Video
gcs https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
gcs https://github.com/FizzleDorf/ComfyUI_FizzNodes.git
gcs https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git
gcs https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
gcs https://github.com/melMass/comfy_mtb.git
gcs https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git

# More
gcs https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git
gcs https://github.com/SLAPaper/ComfyUI-Image-Selector.git
gcs https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git
gcs https://github.com/MrForExample/ComfyUI-3D-Pack.git

# To be removed in future
gcs https://github.com/cubiq/ComfyUI_essentials.git
gcs https://github.com/cubiq/ComfyUI_FaceAnalysis.git
gcs https://github.com/cubiq/ComfyUI_InstantID.git
gcs https://github.com/cubiq/ComfyUI_IPAdapter_plus.git
gcs https://github.com/cubiq/PuLID_ComfyUI.git
gcs https://github.com/Gourieff/ComfyUI-ReActor.git ComfyUI-ReActor.disabled

info "########################################"
info "3D Pack Installation and Patches..."
info "########################################"

export FORCE_CUDA=1
export TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 10.0"
python ./ComfyUI-3D-Pack/install.py || {
    error "Failed to install 3D Pack. Please check the output for details."
    exit 1
}

# Patch 3D-Pack for diffusers import path changes (>=0.35).
patch_diffusers_controlnet_import() {
    local target_file="$1"
    if [ ! -f "${target_file}" ]; then
        error "controlnet patch target not found: ${target_file}"
        return 1
    fi
    info "Ensuring diffusers controlnet compatibility patch in ${target_file}..."
    python - "${target_file}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

replacement = (
    "try:\n"
    "    from diffusers.models.controlnet import ControlNetOutput\n"
    "except ModuleNotFoundError:\n"
    "    from diffusers.models.controlnets.controlnet import ControlNetOutput"
)

# Repair duplicate/malformed try blocks first.
duplicate_try_pattern = re.compile(
    r"try:\n[ \t]*try:\n[ \t]*from diffusers\.models\.controlnet import ControlNetOutput\n[ \t]*except ModuleNotFoundError:\n[ \t]*from diffusers\.models\.controlnets\.controlnet import ControlNetOutput",
    re.MULTILINE,
)
text, _ = duplicate_try_pattern.subn(replacement, text, count=1)

# Normalize any existing try/except block regardless of indentation quality.
block_pattern = re.compile(
    r"try:\n[ \t]*from diffusers\.models\.controlnet import ControlNetOutput\n[ \t]*except ModuleNotFoundError:\n[ \t]*from diffusers\.models\.controlnets\.controlnet import ControlNetOutput",
    re.MULTILINE,
)
text, block_replacements = block_pattern.subn(replacement, text, count=1)

# If no block exists yet, replace legacy single-line import.
if block_replacements == 0:
    text, _ = re.subn(
        r"from diffusers\.models\.controlnet import ControlNetOutput",
        replacement,
        text,
        count=1,
    )

path.write_text(text, encoding="utf-8")
PY

    if python -m py_compile "${target_file}"; then
        success "controlnet compatibility patch validated: ${target_file}"
        return 0
    else
        error "controlnet patch produced invalid Python syntax: ${target_file}"
        return 1
    fi
}

for f in \
    ./ComfyUI-3D-Pack/Gen_3D_Modules/Stable3DGen/stablex/controlnetvae.py \
    ./ComfyUI-3D-Pack/Checkpoints/Diffusers/Stable3DGen/stablex/yoso-normal-v1-8-1/controlnet/controlnetvae.py
do
    patch_diffusers_controlnet_import "$f"
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

info "########################################"
info "[INFO] Downloading Models..."
info "########################################"

cd /default-comfyui-bundle/ComfyUI/models/vae_approx
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

success "Preload cache completed. ComfyUI bundle is ready at '/default-comfyui-bundle/ComfyUI'."