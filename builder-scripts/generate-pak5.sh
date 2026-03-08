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

echo '#' > pak5.txt

array=(
https://github.com/comfyanonymous/ComfyUI/raw/refs/heads/master/requirements.txt
https://github.com/Comfy-Org/ComfyUI-Manager/raw/refs/heads/main/requirements.txt
# Performance
https://github.com/welltop-cn/ComfyUI-TeaCache/raw/refs/heads/main/requirements.txt
https://github.com/city96/ComfyUI-GGUF/raw/refs/heads/main/requirements.txt
https://github.com/nunchaku-tech/ComfyUI-nunchaku/raw/refs/heads/main/requirements.txt
# Workspace
https://github.com/crystian/ComfyUI-Crystools/raw/refs/heads/main/requirements.txt
# General
https://github.com/ltdrdata/was-node-suite-comfyui/raw/refs/heads/main/requirements.txt
https://github.com/kijai/ComfyUI-KJNodes/raw/refs/heads/main/requirements.txt
https://github.com/jags111/efficiency-nodes-comfyui/raw/refs/heads/main/requirements.txt
https://github.com/yolain/ComfyUI-Easy-Use/raw/refs/heads/main/requirements.txt
# Control
https://github.com/ltdrdata/ComfyUI-Impact-Pack/raw/refs/heads/Main/requirements.txt
https://github.com/ltdrdata/ComfyUI-Impact-Subpack/raw/refs/heads/main/requirements.txt
https://github.com/ltdrdata/ComfyUI-Inspire-Pack/raw/refs/heads/main/requirements.txt
https://github.com/Fannovel16/comfyui_controlnet_aux/raw/refs/heads/main/requirements.txt
https://github.com/Gourieff/ComfyUI-ReActor/raw/refs/heads/main/requirements.txt
https://github.com/huchenlei/ComfyUI-layerdiffuse/raw/refs/heads/main/requirements.txt
https://github.com/kijai/ComfyUI-Florence2/raw/refs/heads/main/requirements.txt
https://github.com/Ltamann/ComfyUI-TBG-SAM3/raw/refs/heads/main/requirements.txt
# Video
https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite/raw/refs/heads/main/requirements.txt
https://github.com/Fannovel16/ComfyUI-Frame-Interpolation/raw/refs/heads/main/requirements-no-cupy.txt
https://github.com/melMass/comfy_mtb/raw/refs/heads/main/requirements.txt
https://github.com/FizzleDorf/ComfyUI_FizzNodes/raw/refs/heads/main/requirements.txt
https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler/raw/refs/heads/main/requirements.txt
# Pending Removal
# cubiq is no longer developing ComfyUI custom nodes
https://github.com/cubiq/ComfyUI_essentials/raw/refs/heads/main/requirements.txt
https://github.com/cubiq/ComfyUI_FaceAnalysis/raw/refs/heads/main/requirements.txt
https://github.com/cubiq/PuLID_ComfyUI/raw/refs/heads/main/requirements.txt
https://github.com/cubiq/ComfyUI_InstantID/raw/refs/heads/main/requirements.txt
# Pending Removal 2
# Most of these deps are already included in deps above
https://github.com/akatz-ai/ComfyUI-AKatz-Nodes/raw/refs/heads/main/requirements.txt
https://github.com/akatz-ai/ComfyUI-DepthCrafter-Nodes/raw/refs/heads/main/requirements.txt
https://github.com/digitaljohn/comfyui-propost/raw/refs/heads/master/requirements.txt
https://github.com/Jonseed/ComfyUI-Detail-Daemon/raw/refs/heads/main/requirements.txt
https://github.com/kijai/ComfyUI-DepthAnythingV2/raw/refs/heads/main/requirements.txt
https://github.com/neverbiasu/ComfyUI-SAM2/raw/refs/heads/main/requirements.txt
https://github.com/pydn/ComfyUI-to-Python-Extension/raw/refs/heads/main/requirements.txt
# LayerStyle
# Note that some deps in LayerStyle_Advance are outdated (causing trouble), pick wisely
https://github.com/chflame163/ComfyUI_LayerStyle/raw/refs/heads/main/requirements.txt
https://github.com/chflame163/ComfyUI_LayerStyle/raw/refs/heads/main/repair_dependency_list.txt
#https://github.com/chflame163/ComfyUI_LayerStyle_Advance/raw/refs/heads/main/requirements.txt
#https://github.com/chflame163/ComfyUI_LayerStyle_Advance/raw/refs/heads/main/repair_dependency_list.txt
# 3DMax
https://github.com/MrForExample/ComfyUI-3D-Pack/raw/refs/heads/main/requirements.txt
#https://github.com/lrzjason/ComfyUI-EditUtils - doesn't have any extra requirements.
)

for line in "${array[@]}";do
    info "Processing $line"
    if ! curl -w "\n" -sSL "${line}" >> pak5.txt; then
        warning "Failed to process $line"
    fi
done

sed -i \
    -e '/^#/d' \
    -e 's/[[:space:]]*$//' \
    -e 's/[[:space:]]*;.*$//' \
    -e 's/\(<=\|==\|>=\).*$//' \
    -e 's/_/-/g' pak5.txt

# Don't "sort foo.txt >foo.txt". See: https://stackoverflow.com/a/29244408
sort -ufo pak5.txt pak5.txt

# Remove duplicate items, compare to pak3.txt and pak7.txt
grep -Fixv -f pak3.txt pak5.txt > temp.txt && mv temp.txt pak5.txt
grep -Fixv -f pak7.txt pak5.txt > temp.txt && mv temp.txt pak5.txt

success "<pak5.txt> generated. Check before use."
