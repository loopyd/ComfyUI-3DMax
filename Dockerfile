FROM ubuntu:24.04

LABEL maintainer="loopyd <toothy@sabertoothmediagroup.net"

RUN set -eu

ARG USING_GITHUB_ACTIONS=false
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC
ARG LOCALE=en_US.UTF-8
ARG CUDA_VERSION=12.8
ARG CUDA_MINOR_FALLBACK=8
ARG PYTHON_VERSION=3.12
ARG PYTHON_MINOR_FALLBACK=12
ARG TORCH_VERSION=2.7.0
ARG TORCHVISION_VERSION=0.22.0
ARG TORCHAUDIO_VERSION=2.7.0
ARG XFORMERS_VERSION=0.0.30
ARG GCC_VERSION=14
ARG CUDNN_VERSION=9.19.1.2-1

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV PYOPENGL_PLATFORM=egl

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        locales \
        tzdata \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && printf '%s UTF-8\n' "${LOCALE}" > /etc/locale.gen \
    && locale-gen "${LOCALE}" \
    && update-locale LANG="${LOCALE}" LC_ALL="${LOCALE}"

ENV TZ="${TZ}" \
    LANG="${LOCALE}" \
    LC_ALL="${LOCALE}"

# Fully upgrade base Ubuntu packages before adding CUDA/toolchain layers.
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update \
    && apt-get -y full-upgrade

# Copy and write version env files for CUDA, Python, PyTorch, etc. These will be used in later layers to install specific versions of packages and tools.
COPY --chmod=755 builder-scripts/write-version-env.sh /builder-scripts/write-version-env.sh
RUN /builder-scripts/write-version-env.sh

################################################################################
# NVIDIA CUDA Toolkit and cuDNN

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        wget \
    && wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub | gpg --dearmor -o /usr/share/keyrings/nvidia-cuda.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/ /" > /etc/apt/sources.list.d/cuda-ubuntu2404-x86_64.list \
    && apt-get update \
    && . /etc/cuda-version.env \
    && apt-get install -y --no-install-recommends \
"cuda-cccl-${CUDA_VER_DASH}" \
"cuda-command-line-tools-${CUDA_VER_DASH}" \
"cuda-compat-${CUDA_VER_DASH}" \
"cuda-cudart-${CUDA_VER_DASH}" \
"cuda-minimal-build-${CUDA_VER_DASH}" \
"cuda-nvcc-${CUDA_VER_DASH}" \
"cuda-nvprof-${CUDA_VER_DASH}" \
"cuda-nvtx-${CUDA_VER_DASH}" \
"libcublas-${CUDA_VER_DASH}" \
"libnpp-${CUDA_VER_DASH}" \
"cuda-cudart-dev-${CUDA_VER_DASH}" \
"cuda-nvml-dev-${CUDA_VER_DASH}" \
"cuda-nvrtc-dev-${CUDA_VER_DASH}" \
"libcublas-dev-${CUDA_VER_DASH}" \
"libnpp-dev-${CUDA_VER_DASH}" \
"cuda-libraries-${CUDA_VER_DASH}" \
"cuda-libraries-dev-${CUDA_VER_DASH}" \
"libcudnn9-cuda-${CUDA_VER_MAJOR}=${CUDNN_VERSION}" \
"libcudnn9-dev-cuda-${CUDA_VER_MAJOR}=${CUDNN_VERSION}" \
"libcusparselt-dev"

RUN . /etc/cuda-version.env \
    && if [ -d "/usr/local/cuda-${CUDA_VER_DOT}" ]; then \
        ln -sfn "/usr/local/cuda-${CUDA_VER_DOT}" /usr/local/cuda; \
    elif [ -d "/usr/local/cuda-${CUDA_VER_MAJOR}" ]; then \
        ln -sfn "/usr/local/cuda-${CUDA_VER_MAJOR}" /usr/local/cuda; \
    else \
        echo "Unable to find installed CUDA directory for CUDA_VERSION='${CUDA_VERSION}'." >&2; \
        ls -1 /usr/local | grep '^cuda' || true; \
        exit 1; \
    fi \
    && if [ ! -e /usr/local/cuda/include/cuda_runtime.h ] && [ -e /usr/local/cuda/targets/x86_64-linux/include/cuda_runtime.h ]; then \
        ln -sfn /usr/local/cuda/targets/x86_64-linux/include /usr/local/cuda/include; \
    fi \
    && if [ ! -d /usr/local/cuda/lib64 ] && [ -d /usr/local/cuda/targets/x86_64-linux/lib ]; then \
        ln -sfn /usr/local/cuda/targets/x86_64-linux/lib /usr/local/cuda/lib64; \
    fi \
    && if [ ! -f /usr/local/cuda/include/cuda_runtime.h ]; then \
        echo "cuda_runtime.h not found after CUDA path normalization." >&2; \
        find /usr/local/cuda -maxdepth 4 -name cuda_runtime.h -print || true; \
        exit 1; \
    fi

ENV PATH="${PATH}:/usr/local/cuda/bin" \
    LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/local/cuda/lib64:/usr/local/cuda/targets/x86_64-linux/lib" \
    LIBRARY_PATH="/usr/local/cuda/lib64/stubs:/usr/local/cuda/targets/x86_64-linux/lib" \
    CPATH="/usr/local/cuda/include:/usr/local/cuda/targets/x86_64-linux/include" \
    CPLUS_INCLUDE_PATH="/usr/local/cuda/include:/usr/local/cuda/targets/x86_64-linux/include" \
    CUDA_HOME="/usr/local/cuda" \
    FORCE_CUDA=1 \
    TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 10.0"

################################################################################
# Python and tools

RUN --mount=type=cache,target=/var/cache/apt \
    . /etc/python-version.env \
    && apt-get install -y --no-install-recommends \
"python${PY_VER_DOT}" \
"python${PY_VER_DOT}-dev" \
"python${PY_VER_DOT}-venv" \
python3-pip \
python3-wheel \
python3-setuptools \
cython3 \
libopencv-dev \
python3-opencv \
libgl1 \
libglib2.0-0 \
libgomp1 \
qt5-qmake \
qtbase5-dev \
libqt5core5t64 \
libqt5gui5t64 \
libqt5widgets5t64 \
libqt5xml5t64 \
libqt5opengl5t64 \
    && ln -sf "/usr/bin/python${PY_VER_DOT}" /usr/bin/python3 \
    && ln -sf "/usr/bin/python${PY_VER_DOT}" /usr/bin/python \
    && rm -f /usr/lib/python${PY_VER_DOT}/EXTERNALLY-MANAGED

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get install -y --no-install-recommends \
make \
cmake \
bison \
gawk \
ninja-build \
rustc \
cargo \
git \
git-lfs \
aria2 \
findutils \
fish \
fd-find \
vim \
tar \
xz-utils \
wget \
curl \
fonts-noto-core \
fonts-noto-cjk

# FFmpeg from BtbN
RUN --mount=type=cache,target=/tmp/ffmpeg_download \
    cd /tmp/ffmpeg_download \
    && wget -N https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.0-latest-linux64-gpl-shared-8.0.tar.xz \
    && tar -xf ffmpeg-n8.0-latest-linux64-gpl-shared-8.0.tar.xz \
    && rm -vf ffmpeg-n8.0-latest-linux64-gpl-shared-8.0/*.txt \
    && for item in ffmpeg-n8.0-latest-linux64-gpl-shared-8.0/*; do \
        if [ "$(basename "$item")" = "man" ]; then \
            mkdir -p /usr/local/man && cp -r "$item"/* /usr/local/man/; \
        else \
            cp -r "$item" /usr/local/; \
        fi; \
    done

# Fix for SentencePiece on CMAKE 4+
ENV CMAKE_POLICY_VERSION_MINIMUM=3.5

################################################################################
# GCC (configurable)

RUN --mount=type=cache,target=/var/cache/apt \
    . /etc/toolchain-version.env \
    && apt-get install -y --no-install-recommends \
        "gcc-${GCC_VER_MAJOR}" \
        "g++-${GCC_VER_MAJOR}" \
        "cpp-${GCC_VER_MAJOR}" \
    && rm -f /etc/alternatives/cpp /lib/cpp /usr/bin/cpp \
    && update-alternatives --install /usr/bin/gcc gcc "/usr/bin/gcc-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/g++ g++ "/usr/bin/g++-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/cpp cpp "/usr/bin/cpp-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/cc cc "/usr/bin/gcc-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/c++ c++ "/usr/bin/g++-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/gcc-ar gcc-ar "/usr/bin/gcc-ar-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/gcc-nm gcc-nm "/usr/bin/gcc-nm-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/gcc-ranlib gcc-ranlib "/usr/bin/gcc-ranlib-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/gcov gcov "/usr/bin/gcov-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/gcov-dump gcov-dump "/usr/bin/gcov-dump-${GCC_VER_MAJOR}" 90 \
    && update-alternatives --install /usr/bin/gcov-tool gcov-tool "/usr/bin/gcov-tool-${GCC_VER_MAJOR}" 90

################################################################################
# PyTorch, xFormers, Triton

# Break down the steps, so we have more but smaller image layers.
RUN --mount=type=cache,target=/root/.cache/pip \
    . /etc/cuda-version.env \
    && . /etc/torch-version.env \
    && pip list \
    && pip install \
        --upgrade --ignore-installed pip wheel setuptools Cython numpy \
    && pip install \
        --dry-run "xformers==${XFORMERS_VER}" "torch==${TORCH_VER_DOT}" "torchvision==${TORCHVISION_VER_DOT}" "torchaudio==${TORCHAUDIO_VER_DOT}" \
        --index-url "https://download.pytorch.org/whl/${PYTORCH_CUDA_TAG}"

RUN --mount=type=cache,target=/root/.cache/pip \
    . /etc/cuda-version.env \
    && . /etc/python-version.env \
    && . /etc/torch-version.env \
    && py_site="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')" \
    && pip install \
        "xformers==${XFORMERS_VER}" "torch==${TORCH_VER_DOT}" "torchvision==${TORCHVISION_VER_DOT}" "torchaudio==${TORCHAUDIO_VER_DOT}" \
        --index-url "https://download.pytorch.org/whl/${PYTORCH_CUDA_TAG}" \
    && pip uninstall --yes torch \
    && find "${py_site}/nvidia/" -mindepth 1 -maxdepth 1 ! -name 'nccl' ! -name 'nvshmem' -exec rm -rfv {} +

RUN --mount=type=cache,target=/root/.cache/pip \
    . /etc/cuda-version.env \
    && . /etc/torch-version.env \
    && pip install \
        "xformers==${XFORMERS_VER}" "torch==${TORCH_VER_DOT}" "torchvision==${TORCHVISION_VER_DOT}" "torchaudio==${TORCHAUDIO_VER_DOT}" \
        --index-url "https://download.pytorch.org/whl/${PYTORCH_CUDA_TAG}"

RUN py_site="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')" \
    && ln -sfn "${py_site}" /usr/local/lib/python-site-packages

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}\
:/usr/local/lib/python-site-packages/torch/lib\
:/usr/local/lib/python-site-packages/nvidia/nccl/lib\
:/usr/local/lib/python-site-packages/nvidia/nvshmem/lib"

# Install Triton and PyTorch-Triton from PyTorch's CUDA-specific index, to ensure we get versions compatible with the installed PyTorch and CUDA.
RUN --mount=type=cache,target=/root/.cache/pip \
    . /etc/cuda-version.env \
    && pip install \
        triton pytorch-triton \
        --index-url "https://download.pytorch.org/whl/${PYTORCH_CUDA_TAG}"

################################################################################
# Python packages and dependencies for ComfyUI and custom nodes

# Deps for ComfyUI & custom nodes
COPY builder-scripts/.  /builder-scripts/

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        -r /builder-scripts/pak3.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        -r /builder-scripts/pak5.txt

# Remove broken cmake Python package before building dlib from pak7's dependency pool.
RUN pip uninstall -y cmake || true \
    && rm -f /usr/local/bin/cmake

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        -r /builder-scripts/pak7.txt

# Prevent SAM-2 from installing CUDA packages
RUN --mount=type=cache,target=/root/.cache/pip \
    cd /builder-scripts \
    && git clone https://github.com/facebookresearch/sam2.git \
    && cd sam2 \
    && SAM2_BUILD_CUDA=1 pip install \
        -e . --no-deps --no-build-isolation \
    && cd /

# Prevent SAM-3 from installing NumPy1
RUN --mount=type=cache,target=/root/.cache/pip \
    cd /builder-scripts \
    && git clone https://github.com/facebookresearch/sam3.git \
    && cd sam3 \
    && pip install \
        -e . --no-deps --no-build-isolation \
    && cd /

# Updated nunchaku wheel with support for PyTorch 2.7 and CUDA 12.8.
RUN --mount=type=cache,target=/root/.cache/pip \
    . /etc/python-version.env \
    && . /etc/torch-version.env \
    && pip install "https://github.com/nunchaku-ai/nunchaku/releases/download/v1.2.0/nunchaku-1.2.0+torch${TORCH_VER_MM}-${PYTHON_TAG_CP}-${PYTHON_TAG_CP}-linux_x86_64.whl"

# FlashAttention (version pair with xFormers, binary pair with PyTorch & CUDA)
RUN --mount=type=cache,target=/root/.cache/pip \
    . /etc/cuda-version.env \
    && . /etc/python-version.env \
    && . /etc/torch-version.env \
    pip install \
https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.7.16/flash_attn-2.8.3+cu${CUDA_VER_NODOT}${TORCH_WHL_TAG}-${PYTHON_TAG_CP}-${PYTHON_TAG_CP}-linux_x86_64.whl

# Build sageattn2++ from source for Blackwell (since pre-built wheels are not available for latest PyTorch/CUDA)
# Set TORCH_CUDA_ARCH_LIST to target multiple GPU architectures: Ampere, Ada, Hopper, Blackwell
RUN --mount=type=cache,target=/root/.cache/pip \
    cd /builder-scripts \
    && git clone https://github.com/thu-ml/SageAttention.git \
    && cd SageAttention \
    && TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 10.0" python setup.py install

################################################################################
# Bundle ComfyUI in the image

WORKDIR /default-comfyui-bundle

RUN --mount=type=cache,target=/root/.cache/pip \
    bash /builder-scripts/preload-cache.sh

# Install deps (comfyui-frontend-package, etc) pair to the preloaded ComfyUI version
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        -r '/default-comfyui-bundle/ComfyUI/requirements.txt' \
        -r '/default-comfyui-bundle/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt'

################################################################################

# Clean cache to avoid GitHub Actions "No space left on device"
RUN --mount=type=cache,target=/root/.cache/pip \
    if [ "${USING_GITHUB_ACTIONS}" = "true" ]; then \
        rm -rf /root/.cache/pip/* ; \
    fi

# RUN du -ah /root \
#     && rm -rfv /root/* \
#     && rm -rfv /root/.[^.]* /root/.??*

COPY runner-scripts/.  /runner-scripts/

USER root
VOLUME /root
WORKDIR /root
EXPOSE 8188
ENV CLI_ARGS=""
CMD ["bash","/runner-scripts/entrypoint.sh"]
