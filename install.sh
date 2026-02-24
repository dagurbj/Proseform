#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    printf "[install] %s\n" "$*"
}

warn() {
    printf "[install][warn] %s\n" "$*" >&2
}

die() {
    printf "[install][error] %s\n" "$*" >&2
    exit 1
}

if [[ "$(uname -s)" != "Linux" ]]; then
    die "This installer currently supports Linux only."
fi

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        die "Please run as root or install sudo."
    fi
fi

PKG_MGR=""
if command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
elif command -v zypper >/dev/null 2>&1; then
    PKG_MGR="zypper"
else
    die "Unsupported package manager. Supported: apt, dnf, pacman, zypper."
fi

install_required_packages() {
    log "Installing required system packages with ${PKG_MGR}..."
    case "${PKG_MGR}" in
        apt)
            ${SUDO} apt-get update
            ${SUDO} apt-get install -y pandoc nodejs npm curl ca-certificates tar xz-utils
            ;;
        dnf)
            ${SUDO} dnf install -y pandoc nodejs npm curl ca-certificates tar xz
            ;;
        pacman)
            ${SUDO} pacman -Sy --noconfirm pandoc nodejs npm curl ca-certificates tar xz
            ;;
        zypper)
            ${SUDO} zypper --non-interactive install pandoc nodejs npm curl ca-certificates tar xz \
                || ${SUDO} zypper --non-interactive install pandoc nodejs20 npm20 curl ca-certificates tar xz
            ;;
    esac
}

install_pandoc_crossref_package() {
    if command -v pandoc-crossref >/dev/null 2>&1; then
        return
    fi

    log "Trying package-manager install for pandoc-crossref..."
    case "${PKG_MGR}" in
        apt)
            ${SUDO} apt-get install -y pandoc-crossref >/dev/null 2>&1 || true
            ;;
        dnf)
            ${SUDO} dnf install -y pandoc-crossref >/dev/null 2>&1 || true
            ;;
        pacman)
            ${SUDO} pacman -S --noconfirm pandoc-crossref >/dev/null 2>&1 || true
            ;;
        zypper)
            ${SUDO} zypper --non-interactive install pandoc-crossref >/dev/null 2>&1 || true
            ;;
    esac
}

install_optional_puppeteer_libs() {
    log "Installing optional browser runtime libraries for Mermaid rendering..."
    local pkg
    case "${PKG_MGR}" in
        apt)
            local apt_pkgs=(
                libasound2 libatk1.0-0 libatk-bridge2.0-0 libcups2 libcairo2
                libdrm2 libgbm1 libnss3 libpango-1.0-0 libx11-xcb1 libxcb1
                libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2
                libxshmfence1 fonts-liberation
            )
            for pkg in "${apt_pkgs[@]}"; do
                ${SUDO} apt-get install -y "${pkg}" >/dev/null 2>&1 || true
            done
            ;;
        dnf)
            local dnf_pkgs=(
                alsa-lib atk at-spi2-atk cairo cups-libs libdrm libgbm nss pango
                libX11-xcb libXcomposite libXdamage libXfixes libxkbcommon
                libXrandr libxcb libxshmfence liberation-fonts
            )
            for pkg in "${dnf_pkgs[@]}"; do
                ${SUDO} dnf install -y "${pkg}" >/dev/null 2>&1 || true
            done
            ;;
        pacman)
            local pacman_pkgs=(
                alsa-lib atk at-spi2-core cairo cups libdrm libx11 libxcomposite
                libxdamage libxfixes libxkbcommon libxrandr libxshmfence libxcb
                nss pango ttf-liberation
            )
            for pkg in "${pacman_pkgs[@]}"; do
                ${SUDO} pacman -S --noconfirm "${pkg}" >/dev/null 2>&1 || true
            done
            ;;
        zypper)
            local zypper_pkgs=(
                alsa atk cairo cups-libs libdrm2 libgbm1 mozilla-nss pango
                libX11-xcb1 libXcomposite1 libXdamage1 libXfixes3 libxkbcommon0
                libXrandr2 libxcb1 libxshmfence1 liberation-fonts
            )
            for pkg in "${zypper_pkgs[@]}"; do
                ${SUDO} zypper --non-interactive install "${pkg}" >/dev/null 2>&1 || true
            done
            ;;
    esac
}

install_mermaid_filter() {
    if command -v mermaid-filter >/dev/null 2>&1; then
        log "mermaid-filter already installed: $(command -v mermaid-filter)"
        return
    fi

    log "Installing mermaid-filter via npm (includes Mermaid CLI)..."
    if npm install -g mermaid-filter; then
        return
    fi

    if [[ -n "${SUDO}" ]]; then
        ${SUDO} npm install -g mermaid-filter
    else
        die "Failed to install mermaid-filter with npm."
    fi
}

install_pandoc_crossref_fallback() {
    if command -v pandoc-crossref >/dev/null 2>&1; then
        return
    fi

    log "pandoc-crossref package was unavailable; installing latest binary release..."

    local arch token release_json url tmpdir binary
    arch="$(uname -m)"
    case "${arch}" in
        x86_64|amd64)
            token="X64"
            ;;
        aarch64|arm64)
            token="ARM64"
            ;;
        *)
            die "Unsupported CPU architecture for pandoc-crossref fallback: ${arch}"
            ;;
    esac

    release_json="$(curl -fsSL https://api.github.com/repos/lierdakil/pandoc-crossref/releases/latest)"
    url="$(printf "%s" "${release_json}" \
        | sed -n 's/.*"browser_download_url":"\([^"]*\)".*/\1/p' \
        | sed 's/\\\//\//g' \
        | grep "pandoc-crossref-Linux-${token}\.tar\.xz" \
        | head -n 1)"

    [[ -n "${url}" ]] || die "Could not find a Linux ${token} pandoc-crossref release asset."

    tmpdir="$(mktemp -d)"

    curl -fL "${url}" -o "${tmpdir}/pandoc-crossref.tar.xz"
    tar -xJf "${tmpdir}/pandoc-crossref.tar.xz" -C "${tmpdir}"
    binary="$(find "${tmpdir}" -type f -name pandoc-crossref | head -n 1)"
    [[ -n "${binary}" ]] || die "Could not extract pandoc-crossref binary."

    if [[ "${EUID}" -eq 0 ]]; then
        install -m 0755 "${binary}" /usr/local/bin/pandoc-crossref
    elif [[ -n "${SUDO}" ]]; then
        if ! ${SUDO} install -m 0755 "${binary}" /usr/local/bin/pandoc-crossref; then
            mkdir -p "${HOME}/.local/bin"
            install -m 0755 "${binary}" "${HOME}/.local/bin/pandoc-crossref"
            warn "Installed pandoc-crossref to ${HOME}/.local/bin. Ensure this path is in PATH."
        fi
    else
        mkdir -p "${HOME}/.local/bin"
        install -m 0755 "${binary}" "${HOME}/.local/bin/pandoc-crossref"
        warn "Installed pandoc-crossref to ${HOME}/.local/bin. Ensure this path is in PATH."
    fi

    rm -rf "${tmpdir}"
}

verify_tools() {
    hash -r
    command -v pandoc >/dev/null 2>&1 || die "pandoc is missing."
    command -v pandoc-crossref >/dev/null 2>&1 || die "pandoc-crossref is missing."
    command -v mermaid-filter >/dev/null 2>&1 || die "mermaid-filter is missing."

    log "Tool versions:"
    pandoc --version | sed -n '1,2p'
    pandoc-crossref --version | head -n 1
    log "mermaid-filter: $(command -v mermaid-filter)"
}

verify_project_files() {
    local required_files=(
        todocx.sh
        remove-heading-numbers.lua
        mermaid-caption-from-text.lua
        mermaid-image-to-figure.lua
    )
    local file
    for file in "${required_files[@]}"; do
        [[ -f "${SCRIPT_DIR}/${file}" ]] || die "Missing project file: ${file}"
    done

    if [[ -f "${SCRIPT_DIR}/custom-reference.docx" ]]; then
        log "Found custom-reference.docx."
    elif [[ -f "${SCRIPT_DIR}/old/custom-reference.docx" ]]; then
        warn "custom-reference.docx not in repo root. Falling back to old/custom-reference.docx."
    else
        warn "custom-reference.docx not found. todocx.sh will still work, but with Pandoc's default Word template."
    fi

    if [[ ! -f "${SCRIPT_DIR}/mermaid-config.json" && ! -f "${SCRIPT_DIR}/.mermaid-config.json" ]]; then
        warn "No Mermaid config file found; defaults from mermaid-filter will be used."
    fi
}

install_required_packages
install_optional_puppeteer_libs
install_pandoc_crossref_package
install_pandoc_crossref_fallback
install_mermaid_filter
verify_tools
verify_project_files

log "Installation complete."
log "Usage: ./todocx.sh path/to/file.md"
