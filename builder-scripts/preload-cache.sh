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
    git clone --quiet --depth=1 --no-tags --recurse-submodules --shallow-submodules "$@" || {
        warning "Failed to clone $1"
    }
}

download_model_if_missing() {
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
git clone --quiet 'https://github.com/comfyanonymous/ComfyUI.git'
cd /default-comfyui-bundle/ComfyUI
# Using stable version (has a release tag)
git reset --hard "$(git tag | grep -e '^v' | sort -V | tail -1)"

cd /default-comfyui-bundle/ComfyUI/custom_nodes
gcs https://github.com/Comfy-Org/ComfyUI-Manager.git

# Force ComfyUI-Manager to use PIP instead of UV
mkdir -p /default-comfyui-bundle/ComfyUI/user/__manager

cat <<EOF > /default-comfyui-bundle/ComfyUI/user/__manager/config.ini
[default]
use_uv = False
security_level = weak
EOF

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

# Hunyuan3D is bundled inside ComfyUI-3D-Pack; no standalone clone required.
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
python /default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-3D-Pack/install.py || {
    error "Failed to install 3D Pack. You may want to check and install it manually."
    exit 1
}

# Patch 3D-Pack for diffusers import path changes (>=0.35).
patch_diffusers_controlnet_import() {
    local target_file="$1"

    if [ ! -f "${target_file}" ]; then
        warning "controlnet patch target not found: ${target_file}"
        return 0
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
    else
        error "controlnet patch produced invalid Python syntax: ${target_file}"
        exit 1
    fi
}

for f in \
    /default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-3D-Pack/Gen_3D_Modules/Stable3DGen/stablex/controlnetvae.py \
    /default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-3D-Pack/Checkpoints/Diffusers/Stable3DGen/stablex/yoso-normal-v1-8-1/controlnet/controlnetvae.py
do
    patch_diffusers_controlnet_import "$f"
done

# Compile Hunyuan3D modules bundled in ComfyUI-3D-Pack.
HUNYUAN_PAINT_ROOT="/default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-3D-Pack/Gen_3D_Modules/Hunyuan3D_2_1/hy3dpaint"
if [ ! -d "${HUNYUAN_PAINT_ROOT}" ]; then
    HUNYUAN_PAINT_ROOT="$(find "/default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-3D-Pack" -type d -path "*/Gen_3D_Modules/Hunyuan3D_2_1/hy3dpaint" | head -n1 || true)"
fi

RASTER_SETUP="${HUNYUAN_PAINT_ROOT}/custom_rasterizer/setup.py"
DIFF_RENDER_DIR="${HUNYUAN_PAINT_ROOT}/DifferentiableRenderer"
DIFF_RENDER_COMPILE="${DIFF_RENDER_DIR}/compile_mesh_painter.sh"
MESH_INPAINT_WHEEL_SETUP="${HUNYUAN_PAINT_ROOT}/mesh_inpaint_wheel/setup.py"

if [ -n "${HUNYUAN_PAINT_ROOT}" ] && [ -f "${RASTER_SETUP}" ]; then
    export FORCE_CUDA=1
    export TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 10.0"

    info "Compiling bundled Hunyuan3D custom rasterizer from ComfyUI-3D-Pack..."
    cd "$(dirname "${RASTER_SETUP}")"
    python setup.py install || {
        error "Failed to compile bundled Hunyuan3D custom rasterizer"
        exit 1
    }
    success "Bundled Hunyuan3D custom rasterizer compiled successfully"

    if [ -f "${DIFF_RENDER_COMPILE}" ]; then
        info "Compiling bundled Hunyuan3D DifferentiableRenderer mesh_inpaint_processor..."
        python -m pip install --no-cache-dir pybind11 || {
            warning "pybind11 install failed; DifferentiableRenderer compile may fail"
        }
        cd "${DIFF_RENDER_DIR}"
        bash ./compile_mesh_painter.sh || {
            error "Failed to compile DifferentiableRenderer mesh_inpaint_processor"
            exit 1
        }

        if ls "${DIFF_RENDER_DIR}"/mesh_inpaint_processor*.so >/dev/null 2>&1; then
            success "DifferentiableRenderer compiled extension detected"
        else
            warning "DifferentiableRenderer compile finished but no mesh_inpaint_processor*.so was found"
        fi
    else
        warning "DifferentiableRenderer compile script not found: ${DIFF_RENDER_COMPILE}"
    fi

    if [ -f "${MESH_INPAINT_WHEEL_SETUP}" ]; then
        info "Installing mesh_inpaint_processor wheel package..."
        cd "$(dirname "${MESH_INPAINT_WHEEL_SETUP}")"
        python -m pip install --no-cache-dir . || {
            warning "mesh_inpaint_processor wheel install failed; DifferentiableRenderer may use Python fallback"
        }
    else
        warning "mesh_inpaint_wheel/setup.py not found; skipping mesh_inpaint_processor package install"
    fi

    success "Bundled Hunyuan3D modules updated successfully."

    # Install and patch xatlas for high-poly mesh support.
    info "Installing patched xatlas for high-poly mesh UV unwrapping..."
    python -m pip uninstall -y xatlas 2>/dev/null || true

    cd /default-comfyui-bundle
    rm -rf xatlas-python >/dev/null 2>&1 || true
    git clone --quiet --recursive https://github.com/mworchel/xatlas-python.git || {
        warning "Failed to clone xatlas-python fork, skipping UV unwrapping patch"
    }

    if [ -d "/default-comfyui-bundle/xatlas-python/extern" ]; then
        cd /default-comfyui-bundle/xatlas-python/extern

        rm -rf xatlas
        git clone --quiet --recursive https://github.com/jpcy/xatlas || {
            warning "Failed to clone jpcy/xatlas, xatlas-python install may fail"
        }

        XATLAS_CPP="xatlas/source/xatlas/xatlas.cpp"
        if [ -f "${XATLAS_CPP}" ]; then
            info "Applying xatlas high-poly mesh patch (line 6774 and 6778)..."
            sed -i '6774s|^#if 0$|//#if 0|;6778s|^#endif$|//#endif|' "${XATLAS_CPP}"
            info "xatlas patch applied successfully"
        else
            warning "xatlas.cpp not found, skipping xatlas source patch"
        fi

        cd /default-comfyui-bundle
        python -m pip install --no-cache-dir ./xatlas-python || {
            warning "xatlas-python build may have failed; high-poly UV unwrapping may not work"
        }
        success "xatlas-python installation step finished"
    else
        warning "xatlas-python extern directory not found, skipping xatlas installation and patch"
    fi

    success "Bundled Hunyuan3D modules installation completed."
else
    warning "Bundled Hunyuan3D custom_rasterizer/setup.py not found under Gen_3D_Modules/Hunyuan3D_2_1/hy3dpaint. InPaint feature may be unavailable."
fi

info "########################################"
info "[INFO] Downloading Models..."
info "########################################"

cd /default-comfyui-bundle/ComfyUI/models/vae_approx
gcs https://github.com/madebyollin/taesd.git
cp taesd/*.pth .
rm -rf taesd

ANIMATEDIFF_MODELS_DIR="/default-comfyui-bundle/ComfyUI/models/animatediff_models"
ANIMATEDIFF_NODE_MODELS_DIR="/default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-AnimateDiff-Evolved/models"
ANIMATEDIFF_DEFAULT_MODEL="mm_sd_v15_v2.ckpt"
ANIMATEDIFF_DEFAULT_URL="https://huggingface.co/guoyww/animatediff/resolve/main/${ANIMATEDIFF_DEFAULT_MODEL}"

if download_model_if_missing "${ANIMATEDIFF_DEFAULT_URL}" "${ANIMATEDIFF_MODELS_DIR}/${ANIMATEDIFF_DEFAULT_MODEL}"; then
    mkdir -p "${ANIMATEDIFF_NODE_MODELS_DIR}"
    ln -sfn "${ANIMATEDIFF_MODELS_DIR}/${ANIMATEDIFF_DEFAULT_MODEL}" "${ANIMATEDIFF_NODE_MODELS_DIR}/${ANIMATEDIFF_DEFAULT_MODEL}"
    success "AnimateDiff default motion model installed and linked for ComfyUI-AnimateDiff-Evolved."
else
    warning "Failed to download AnimateDiff motion model (${ANIMATEDIFF_DEFAULT_MODEL}). AnimateDiff-Evolved may report missing models."
fi

success "Preload cache completed. ComfyUI bundle is ready at '/default-comfyui-bundle/ComfyUI'."