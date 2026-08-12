#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure user-level fallback installs are discoverable during this run.
if [[ -n "${HOME:-}" ]]; then
    case ":${PATH}:" in
        *":${HOME}/.local/bin:"*) ;;
        *) export PATH="${HOME}/.local/bin:${PATH}" ;;
    esac
fi

NODE_MAJOR="${NODE_MAJOR:-20}"

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
            log "Configuring NodeSource Node.js ${NODE_MAJOR}.x repository for apt..."
            ${SUDO} apt-get update
            ${SUDO} apt-get install -y curl ca-certificates gnupg
            curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | ${SUDO} bash -
            local apt_node_conflicts=(libnode-dev nodejs-doc)
            for pkg in "${apt_node_conflicts[@]}"; do
                if dpkg -s "${pkg}" >/dev/null 2>&1; then
                    log "Removing conflicting package: ${pkg}"
                    ${SUDO} apt-get purge -y "${pkg}"
                fi
            done
            ${SUDO} apt-get install -y pandoc nodejs tar xz-utils
            ;;
        dnf)
            log "Configuring NodeSource Node.js ${NODE_MAJOR}.x repository for dnf..."
            ${SUDO} dnf install -y curl ca-certificates
            curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR}.x" | ${SUDO} bash -
            ${SUDO} dnf install -y pandoc nodejs tar xz
            ;;
        pacman)
            ${SUDO} pacman -S --noconfirm pandoc nodejs npm curl ca-certificates tar xz
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

get_pandoc_version() {
    pandoc --version | awk 'NR==1 {print $2}'
}

get_pandoc_crossref_build_version() {
    local version_line crossref_version
    version_line="$(pandoc-crossref --version 2>/dev/null | head -n 1 || true)"
    crossref_version="$(printf "%s" "${version_line}" | sed -n 's/.*built with Pandoc v\([0-9][0-9.]*\).*/\1/p')"
    [[ -n "${crossref_version}" ]] || return 1
    printf "%s\n" "${crossref_version}"
}

pandoc_crossref_is_compatible() {
    local pandoc_version crossref_version
    pandoc_version="$(get_pandoc_version)"
    crossref_version="$(get_pandoc_crossref_build_version)" || return 1
    [[ "${pandoc_version}" == "${crossref_version}" ]]
}

install_pandoc_binary() {
    local requested_tag="${1:-}"
    local arch pandoc_arch release_tag latest_tag_url url tmpdir binary

    arch="$(uname -m)"
    case "${arch}" in
        x86_64|amd64)
            pandoc_arch="amd64"
            ;;
        aarch64|arm64)
            pandoc_arch="arm64"
            ;;
        *)
            die "Unsupported CPU architecture for pandoc binary install: ${arch}"
            ;;
    esac

    if [[ -n "${requested_tag}" ]]; then
        release_tag="${requested_tag}"
        log "Installing pandoc ${release_tag} binary from GitHub releases..."
    else
        log "Installing latest pandoc binary from GitHub releases..."
        latest_tag_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/jgm/pandoc/releases/latest)"
        release_tag="${latest_tag_url##*/}"
        [[ -n "${release_tag}" ]] || die "Could not determine latest pandoc release tag."
    fi

    url="https://github.com/jgm/pandoc/releases/download/${release_tag}/pandoc-${release_tag}-linux-${pandoc_arch}.tar.gz"

    tmpdir="$(mktemp -d)"
    curl -fL "${url}" -o "${tmpdir}/pandoc.tar.gz" \
        || die "Could not download pandoc release asset from ${url}."
    tar -xzf "${tmpdir}/pandoc.tar.gz" -C "${tmpdir}"

    binary="$(find "${tmpdir}" -type f -path '*/bin/pandoc' | head -n 1)"
    [[ -n "${binary}" ]] || die "Could not extract pandoc binary."

    if [[ "${EUID}" -eq 0 ]]; then
        install -m 0755 "${binary}" /usr/local/bin/pandoc
    elif [[ -n "${SUDO}" ]]; then
        if ! ${SUDO} install -m 0755 "${binary}" /usr/local/bin/pandoc; then
            mkdir -p "${HOME}/.local/bin"
            install -m 0755 "${binary}" "${HOME}/.local/bin/pandoc"
            warn "Installed pandoc to ${HOME}/.local/bin. Ensure this path is in PATH."
        fi
    else
        mkdir -p "${HOME}/.local/bin"
        install -m 0755 "${binary}" "${HOME}/.local/bin/pandoc"
        warn "Installed pandoc to ${HOME}/.local/bin. Ensure this path is in PATH."
    fi

    rm -rf "${tmpdir}"
    hash -r
}

install_latest_pandoc_binary() {
    install_pandoc_binary
}

install_pandoc_binary_for_version() {
    install_pandoc_binary "$1"
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
        hash -r
        return
    fi

    if [[ -n "${HOME:-}" ]]; then
        warn "Global npm install failed; trying user-local npm prefix at ${HOME}/.local..."
        if npm install -g --prefix "${HOME}/.local" mermaid-filter; then
            hash -r
            return
        fi
    fi

    if [[ -n "${SUDO}" ]]; then
        warn "User-local npm install failed; retrying global install with sudo..."
        if ${SUDO} npm install -g mermaid-filter; then
            hash -r
            return
        fi
    fi

    die "Failed to install mermaid-filter with npm (global, user-local, and sudo fallback)."
}

find_mermaid_filter_module_dir() {
    local mermaid_bin npm_prefix npm_root
    mermaid_bin="$(command -v mermaid-filter || true)"
    if [[ -n "${mermaid_bin}" ]]; then
        npm_prefix="$(cd "$(dirname "${mermaid_bin}")/.." && pwd)"
        if [[ -d "${npm_prefix}/lib/node_modules/mermaid-filter" ]]; then
            printf "%s\n" "${npm_prefix}/lib/node_modules/mermaid-filter"
            return 0
        fi
    fi

    npm_root="$(npm root -g 2>/dev/null || true)"
    if [[ -n "${npm_root}" && -d "${npm_root}/mermaid-filter" ]]; then
        printf "%s\n" "${npm_root}/mermaid-filter"
        return 0
    fi

    return 1
}

install_puppeteer_browser_for_mermaid() {
    local module_dir browsers_cli chromium_revision cache_dir target_home
    local -a browsers_runner=()

    module_dir="$(find_mermaid_filter_module_dir || true)"
    if [[ -z "${module_dir}" ]]; then
        die "Could not locate mermaid-filter module directory after install."
    fi

    browsers_cli="${module_dir}/node_modules/.bin/browsers"
    if [[ ! -x "${browsers_cli}" ]]; then
        die "Could not find Puppeteer browsers CLI at ${browsers_cli}."
    fi

    chromium_revision="$(NODE_PATH_TARGET="${module_dir}" node - <<'NODE'
const path = require('path');
const moduleDir = process.env.NODE_PATH_TARGET;
try {
  const revisions = require(path.join(moduleDir, 'node_modules/puppeteer-core/lib/cjs/puppeteer/revisions.js'));
  process.stdout.write(revisions.PUPPETEER_REVISIONS.chromium || '');
} catch (_) {
  process.stdout.write('');
}
NODE
)"

    target_home="${HOME}"
    if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        target_home="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
        browsers_runner=(sudo -H -u "${SUDO_USER}")
    fi

    cache_dir="${PUPPETEER_CACHE_DIR:-${target_home}/.cache/puppeteer}"
    if (( ${#browsers_runner[@]} )); then
        "${browsers_runner[@]}" mkdir -p "${cache_dir}"
    else
        mkdir -p "${cache_dir}"
    fi

    if [[ -n "${chromium_revision}" ]]; then
        log "Installing Puppeteer Chromium revision ${chromium_revision} for mermaid-filter..."
        "${browsers_runner[@]}" "${browsers_cli}" install "chromium@${chromium_revision}" --path "${cache_dir}" >/dev/null \
            || die "Failed to install Puppeteer Chromium revision ${chromium_revision}."
    else
        warn "Could not determine required Chromium revision from mermaid-filter; installing latest Puppeteer Chrome build."
        "${browsers_runner[@]}" "${browsers_cli}" install chrome --path "${cache_dir}" >/dev/null \
            || die "Failed to install Puppeteer Chrome browser."
    fi
}

install_pandoc_crossref_fallback() {
    local pandoc_version detected_crossref_version

    if command -v pandoc-crossref >/dev/null 2>&1 && pandoc_crossref_is_compatible; then
        return
    fi

    pandoc_version="$(get_pandoc_version)"
    if command -v pandoc-crossref >/dev/null 2>&1; then
        detected_crossref_version="$(get_pandoc_crossref_build_version || true)"
        if [[ -n "${detected_crossref_version}" ]]; then
            warn "Detected pandoc-crossref built for Pandoc v${detected_crossref_version}, but installed pandoc is v${pandoc_version}."
        else
            warn "Could not determine which Pandoc version the installed pandoc-crossref was built for."
        fi
    fi

    local arch token asset_name requested_tag url tmpdir binary
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

    asset_name="pandoc-crossref-Linux-${token}.tar.xz"
    requested_tag="${PANDOC_CROSSREF_TAG:-}"
    if [[ -n "${requested_tag}" ]]; then
        log "Installing pandoc-crossref release tag ${requested_tag} via direct download URL..."
        url="https://github.com/lierdakil/pandoc-crossref/releases/download/${requested_tag}/${asset_name}"
    else
        log "Installing latest pandoc-crossref release via direct download URL..."
        url="https://github.com/lierdakil/pandoc-crossref/releases/latest/download/${asset_name}"
    fi

    tmpdir="$(mktemp -d)"

    curl -fL "${url}" -o "${tmpdir}/pandoc-crossref.tar.xz" \
        || die "Could not download pandoc-crossref release asset from ${url}."
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

    hash -r
    if ! pandoc_crossref_is_compatible; then
        detected_crossref_version="$(get_pandoc_crossref_build_version || true)"
        if [[ -n "${detected_crossref_version}" && -z "${requested_tag}" ]]; then
            warn "Installing pandoc v${detected_crossref_version} to match pandoc-crossref..."
            install_pandoc_binary_for_version "${detected_crossref_version}"
            pandoc_version="$(get_pandoc_version)"
            if pandoc_crossref_is_compatible; then
                return
            fi
            die "After installing pandoc v${detected_crossref_version}, pandoc-crossref still reports an incompatibility with pandoc v${pandoc_version}. Set PANDOC_CROSSREF_TAG to a compatible release tag."
        elif [[ -n "${detected_crossref_version}" ]]; then
            die "Requested pandoc-crossref tag ${requested_tag} is built for Pandoc v${detected_crossref_version}, but local pandoc is v${pandoc_version}."
        fi
        die "Installed pandoc-crossref but could not verify compatibility with pandoc v${pandoc_version}. Try setting PANDOC_CROSSREF_TAG."
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
        filters/normalize-headings.lua
        filters/mermaid-caption-from-text.lua
        filters/mermaid-image-to-figure.lua
        config/mermaid-config.json
    )
    local file
    for file in "${required_files[@]}"; do
        [[ -f "${SCRIPT_DIR}/${file}" ]] || die "Missing project file: ${file}"
    done

    if [[ -f "${SCRIPT_DIR}/templates/custom-reference.docx" ]]; then
        log "Found templates/custom-reference.docx."
    else
        warn "templates/custom-reference.docx not found. todocx.sh will still work, but with Pandoc's default Word template."
    fi

    if [[ ! -f "${SCRIPT_DIR}/config/mermaid-config.json" && ! -f "${SCRIPT_DIR}/.mermaid-config.json" ]]; then
        warn "No Mermaid config file found; defaults from mermaid-filter will be used."
    fi
}

install_required_packages
install_optional_puppeteer_libs
install_pandoc_crossref_package
install_pandoc_crossref_fallback
install_mermaid_filter
install_puppeteer_browser_for_mermaid
verify_tools
verify_project_files

log "Installation complete."
log "Usage: ./todocx.sh [-hlb] path/to/file.md"
log "After installing, test Proseform's capabilities by converting docs/DEMO.md."
log "Command: ./todocx.sh docs/DEMO.md (creates docs/DEMO.docx)"
