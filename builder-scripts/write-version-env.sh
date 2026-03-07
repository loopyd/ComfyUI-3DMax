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

: "${VERSION_ENV_DIR:=/etc}"

: "${CUDA_VERSION:=12.8}"
: "${CUDA_MINOR_FALLBACK:=8}"
: "${PYTHON_VERSION:=3.12}"
: "${PYTHON_MINOR_FALLBACK:=12}"
: "${TORCH_VERSION:=2.7.0}"
: "${TORCHVISION_VERSION:=0.22.0}"
: "${TORCHAUDIO_VERSION:=2.7.0}"
: "${XFORMERS_VERSION:=0.0.30}"
: "${GCC_VERSION:=14}"

mkdir -p "${VERSION_ENV_DIR}"

normalize_version() {
    local input="$1"
    local name="$2"
    local mode="$3"
    local fallback="${4-}"
    local trimmed
    local normalized
    local major
    local minor
    local patch
    local tail
    local rest

    trimmed="${input#-}"

    case "${mode}" in
        cuda)
            normalized="$(printf '%s' "${trimmed}" | tr '.' '-' | sed 's/^-*//; s/-*$//')"

            if ! printf '%s' "${normalized}" | grep -Eq '^[0-9]+(-[0-9]+)*$'; then
                error "Invalid ${name}: '${input}'. Use 12, 12.8, 12-8, or -12."
                exit 1
            fi

            major="${normalized%%-*}"
            tail="${normalized#${major}}"
            tail="${tail#-}"
            if [ -z "${tail}" ]; then
                if [ -z "${fallback}" ]; then
                    error "Invalid ${name}: fallback value is required."
                    exit 1
                fi
                tail="${fallback}"
            fi

            printf '%s %s %s\n' "${major}" "${tail}" ""
            ;;
        python)
            normalized="$(printf '%s' "${trimmed}" | tr '-' '.')"

            if ! printf '%s' "${normalized}" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
                error "Invalid ${name}: '${input}'. Use 3, 3.12, or 312."
                exit 1
            fi

            if printf '%s' "${normalized}" | grep -Eq '^[0-9]+\.[0-9]+$'; then
                major="${normalized%%.*}"
                minor="${normalized#*.}"
            elif [ "${#normalized}" -eq 1 ]; then
                major="${normalized}"
                minor="${fallback}"
            else
                major="$(printf '%s' "${normalized}" | cut -c1)"
                minor="$(printf '%s' "${normalized}" | cut -c2-)"
            fi

            if [ -z "${minor}" ]; then
                minor="${fallback}"
            fi

            if ! printf '%s' "${major}" | grep -Eq '^[0-9]+$' || ! printf '%s' "${minor}" | grep -Eq '^[0-9]+$'; then
                error "Invalid parsed ${name} from '${input}'."
                exit 1
            fi

            printf '%s %s %s\n' "${major}" "${minor}" ""
            ;;
        package)
            normalized="$(printf '%s' "${trimmed}" | tr '-' '.')"

            if printf '%s' "${normalized}" | grep -Eq '^[0-9]+$'; then
                if [ "${#normalized}" -eq 1 ]; then
                    major="${normalized}"
                    minor="0"
                else
                    major="$(printf '%s' "${normalized}" | cut -c1)"
                    minor="$(printf '%s' "${normalized}" | cut -c2-)"
                fi
                patch="0"
            elif printf '%s' "${normalized}" | grep -Eq '^[0-9]+\.[0-9]+$'; then
                major="${normalized%%.*}"
                minor="${normalized#*.}"
                patch="0"
            elif printf '%s' "${normalized}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
                major="${normalized%%.*}"
                rest="${normalized#*.}"
                minor="${rest%%.*}"
                patch="${rest#*.}"
            else
                error "Invalid ${name}: '${input}'. Use X.Y.Z, X.Y, or XY."
                exit 1
            fi

            printf '%s %s %s\n' "${major}" "${minor}" "${patch}"
            ;;
        major)
            normalized="$(printf '%s' "${trimmed}" | tr '-' '.')"

            if ! printf '%s' "${normalized}" | grep -Eq '^[0-9]+$'; then
                error "Invalid ${name}: '${input}'. Use 14 or 13."
                exit 1
            fi

            printf '%s %s %s\n' "${normalized}" "" ""
            ;;
        *)
            error "Invalid normalize mode '${mode}' for ${name}."
            exit 1
            ;;
    esac
}

write_cuda_env() {
    local cuda_major
    local cuda_tail
    local cuda_normalized_full
    local cuda_dot
    local cuda_nodot

    read -r cuda_major cuda_tail _ <<< "$(normalize_version "${CUDA_VERSION}" "CUDA_VERSION" cuda "${CUDA_MINOR_FALLBACK}")"

    cuda_normalized_full="${cuda_major}-${cuda_tail}"
    cuda_dot="${cuda_major}.$(printf '%s' "${cuda_tail}" | tr '-' '.')"
    cuda_nodot="${cuda_major}$(printf '%s' "${cuda_tail}" | tr -d '-')"

    printf 'CUDA_VERSION_RAW=%s\nCUDA_VER_DASH=%s\nCUDA_VER_DOT=%s\nCUDA_VER_MAJOR=%s\nCUDA_VER_NODOT=%s\nPYTORCH_CUDA_TAG=cu%s\n' \
        "${CUDA_VERSION}" "${cuda_normalized_full}" "${cuda_dot}" "${cuda_major}" "${cuda_nodot}" "${cuda_nodot}" \
        > "${VERSION_ENV_DIR}/cuda-version.env"
    success "CUDA version normalized and written to '${VERSION_ENV_DIR}/cuda-version.env'."
}

write_python_env() {
    local py_major
    local py_minor
    local py_dot
    local py_nodot

    read -r py_major py_minor _ <<< "$(normalize_version "${PYTHON_VERSION}" "PYTHON_VERSION" python "${PYTHON_MINOR_FALLBACK}")"

    py_dot="${py_major}.${py_minor}"
    py_nodot="${py_major}${py_minor}"

    printf 'PYTHON_VERSION_RAW=%s\nPY_VER_DOT=%s\nPY_VER_NODOT=%s\nPY_VER_MAJOR=%s\nPY_VER_MINOR=%s\nPYTHON_TAG_CP=cp%s\nPYTHON_TAG_PY=py%s\n' \
        "${PYTHON_VERSION}" "${py_dot}" "${py_nodot}" "${py_major}" "${py_minor}" "${py_nodot}" "${py_nodot}" \
        > "${VERSION_ENV_DIR}/python-version.env"
    success "Python version normalized and written to '${VERSION_ENV_DIR}/python-version.env'."
}

write_torch_env() {
    local torch_major
    local torch_minor
    local torch_patch
    local tv_major
    local tv_minor
    local tv_patch
    local ta_major
    local ta_minor
    local ta_patch
    local torch_dot
    local tv_dot
    local ta_dot
    local xformers_ver

    read -r torch_major torch_minor torch_patch <<< "$(normalize_version "${TORCH_VERSION}" "TORCH_VERSION" package)"
    read -r tv_major tv_minor tv_patch <<< "$(normalize_version "${TORCHVISION_VERSION}" "TORCHVISION_VERSION" package)"
    read -r ta_major ta_minor ta_patch <<< "$(normalize_version "${TORCHAUDIO_VERSION}" "TORCHAUDIO_VERSION" package)"

    if [ -z "${XFORMERS_VERSION}" ]; then
        error "Invalid XFORMERS_VERSION: value cannot be empty."
        exit 1
    fi

    xformers_ver="${XFORMERS_VERSION#v}"
    if [ -z "${xformers_ver}" ]; then
        error "Invalid XFORMERS_VERSION: '${XFORMERS_VERSION}'."
        exit 1
    fi

    torch_dot="${torch_major}.${torch_minor}.${torch_patch}"
    tv_dot="${tv_major}.${tv_minor}.${tv_patch}"
    ta_dot="${ta_major}.${ta_minor}.${ta_patch}"

    printf 'TORCH_VERSION_RAW=%s\nTORCH_VER_DOT=%s\nTORCH_VER_MM=%s\nTORCH_VER_MAJOR=%s\nTORCH_VER_MINOR=%s\nTORCH_VER_PATCH=%s\nTORCH_WHL_TAG=torch%s.%s\nTORCH_PT_TAG=pt%s%s\nTORCHVISION_VERSION_RAW=%s\nTORCHVISION_VER_DOT=%s\nTORCHAUDIO_VERSION_RAW=%s\nTORCHAUDIO_VER_DOT=%s\nXFORMERS_VERSION_RAW=%s\nXFORMERS_VER=%s\n' \
        "${TORCH_VERSION}" "${torch_dot}" "${torch_major}.${torch_minor}" "${torch_major}" "${torch_minor}" "${torch_patch}" "${torch_major}" "${torch_minor}" "${torch_major}" "${torch_minor}" \
        "${TORCHVISION_VERSION}" "${tv_dot}" "${TORCHAUDIO_VERSION}" "${ta_dot}" "${XFORMERS_VERSION}" "${xformers_ver}" \
        > "${VERSION_ENV_DIR}/torch-version.env"
    success "Torch versions normalized and written to '${VERSION_ENV_DIR}/torch-version.env'."
}

write_toolchain_env() {
    local gcc_major

    read -r gcc_major _ _ <<< "$(normalize_version "${GCC_VERSION}" "GCC_VERSION" major)"

    printf 'GCC_VERSION_RAW=%s\nGCC_VER_MAJOR=%s\n' \
        "${GCC_VERSION}" "${gcc_major}" \
        > "${VERSION_ENV_DIR}/toolchain-version.env"
    success "Toolchain versions normalized and written to '${VERSION_ENV_DIR}/toolchain-version.env'."
}

write_cuda_env
write_python_env
write_torch_env
write_toolchain_env
