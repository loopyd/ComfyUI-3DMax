#!/bin/bash

set -e

echo "########################################"

# Run user's set-proxy script
cd /root
if [ ! -f "/root/user-scripts/set-proxy.sh" ] ; then
    mkdir -p /root/user-scripts
    cp /runner-scripts/set-proxy.sh.example /root/user-scripts/set-proxy.sh
else
    echo "[INFO] Running set-proxy script..."

    chmod +x /root/user-scripts/set-proxy.sh
    source /root/user-scripts/set-proxy.sh
fi ;

# Copy ComfyUI from cache to workdir if it doesn't exist
cd /root
if [ ! -f "/root/ComfyUI/main.py" ] ; then
    mkdir -p /root/ComfyUI
    # 'cp --archive': all file timestamps and permissions will be preserved
    # 'cp --update=none': do not overwrite
    if cp --archive --update=none "/default-comfyui-bundle/ComfyUI/." "/root/ComfyUI/" ; then
        echo "[INFO] Setting up ComfyUI..."
        echo "[INFO] Using image-bundled ComfyUI (copied to workdir)."
    else
        echo "[ERROR] Failed to copy ComfyUI bundle to '/root/ComfyUI'" >&2
        exit 1
    fi
else
    echo "[INFO] Using existing ComfyUI in user storage..."
fi

# Run user's pre-start script
cd /root
if [ ! -f "/root/user-scripts/pre-start.sh" ] ; then
    mkdir -p /root/user-scripts
    cp /runner-scripts/pre-start.sh.example /root/user-scripts/pre-start.sh
else
    echo "[INFO] Running pre-start script..."

    chmod +x /root/user-scripts/pre-start.sh
    source /root/user-scripts/pre-start.sh
fi ;

echo "[INFO] Starting ComfyUI..."
echo "########################################"

# Let .pyc files be stored in one place
export PYTHONPYCACHEPREFIX="/root/.cache/pycache"
# Let PIP install packages to /root/.local
export PIP_USER=true
# Add above to PATH
export PATH="${PATH}:/root/.local/bin"
# Suppress [WARNING: Running pip as the 'root' user]
export PIP_ROOT_USER_ACTION=ignore
# Keep thread and JIT defaults explicit to reduce noisy runtime warnings.
export NUMEXPR_MAX_THREADS="${NUMEXPR_MAX_THREADS:-16}"
export NUMBA_THREADING_LAYER="${NUMBA_THREADING_LAYER:-workqueue}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.0 8.6 8.9 9.0 10.0}"

# PyMeshLab workaround for Qt symbol conflicts on some Linux setups.
# Upstream reports show that prepending pymeshlab's bundled lib directory to
# LD_LIBRARY_PATH avoids loading incompatible system Qt libraries.
PYMESHLAB_LIB="$(python3 -m pip show pymeshlab 2>/dev/null | awk -F': ' '/^Location:/{print $2"/pymeshlab/lib"; exit}' || true)"
if [ -z "${PYMESHLAB_LIB}" ] || [ ! -d "${PYMESHLAB_LIB}" ]; then
    PYMESHLAB_LIB="$(find /usr/local/lib /usr/lib -type d \( -path '*/python*/dist-packages/pymeshlab/lib' -o -path '*/python*/site-packages/pymeshlab/lib' \) 2>/dev/null | head -n1 || true)"
fi

if [ -n "${PYMESHLAB_LIB}" ] && [ -d "${PYMESHLAB_LIB}" ]; then
    # Check if bundled Qt libraries exist
    if ls "${PYMESHLAB_LIB}"/libQt5*.so* >/dev/null 2>&1; then
        export LD_LIBRARY_PATH="${PYMESHLAB_LIB}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        if [ -d "${PYMESHLAB_LIB}/plugins" ]; then
            export QT_PLUGIN_PATH="${PYMESHLAB_LIB}/plugins${QT_PLUGIN_PATH:+:${QT_PLUGIN_PATH}}"
        fi
        echo "[INFO] PyMeshLab Qt workaround enabled: LD_LIBRARY_PATH starts with ${PYMESHLAB_LIB}"
    else
        echo "[WARN] PyMeshLab Qt libraries not found in ${PYMESHLAB_LIB}, workaround skipped"
    fi
else
    echo "[WARN] Could not locate pymeshlab lib directory, Qt workaround skipped"
fi

cd /root

python3 ./ComfyUI/main.py --listen --port 8188 ${CLI_ARGS}
