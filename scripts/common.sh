#!/usr/bin/bash

clone_repo_latest() {
    rm -rvf "$2" || true
    git clone "$1" --verbose "$2"
    Latest_tag=$(git --no-pager -C "$2" tag | tail -n 1)
    git -C "$2" checkout "$Latest_tag" --force
}

patch_pkgbuild() {
    Latest_tag=$(git --no-pager -C "$1" tag | tail -n 1)
    # git -C "$2" checkout "$Latest_tag" --force
    formatted=$(printf '%s\n' "$Latest_tag" | sed 's/^v//; s/-/./')
    # echo "$formatted"
    wget -O "$1/arch/monolithic.patch" "https://github.com/OpenGamingCollective/linux/releases/download/${Latest_tag}/monolithic.patch"
    version=$(printf '%s\n' "$Latest_tag" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    sed -i "s/@@OGC_VERSION@@/$formatted/g" "$1/arch/PKGBUILD"
    sed -i "s/@@BUILDNUM@@/2/g" "$1/arch/PKGBUILD"
    sed -i "s/@@TAR_KVER@@/$version/g" "$1/arch/PKGBUILD"
    sed -i "s/pkgbase=linux-ogc/pkgbase=linux-nawa/g" "$1/arch/PKGBUILD"
    VERSION="$version"
    if [[ -z "${SECRET_SKEY:-}" ]]; then
        echo Security Boot sig is not set! && exit 1
    fi
    echo "$SECRET_SKEY" | base64 -d > "$1/arch/db.pem"
}

download_source() {
    set +e
    Latest_tag=$(git --no-pager -C "$1" tag | tail -n 1)
    # git -C "$2" checkout "$Latest_tag" --force
    formatted=$(printf '%s\n' "$Latest_tag" | sed 's/^v//; s/-/./')
    # echo "$formatted"
    VERSION=$(printf '%s\n' "$Latest_tag" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    target="$1/arch/linux-${VERSION}.tar.xz"
    local retry=$RETRY
    until wget -O "$target" "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-${VERSION}.tar.xz"; do
        retry=$((retry - 1))
        if [[ "$retry" -le 0 ]]; then
            echo "Download source failed: https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-${VERSION}.tar.xz"
            exit 1
        fi
    done
    (
        local temp_n pkg url
        temp_n=$(mktemp -d) || exit 1
        cd "$temp_n" || exit 1
        url=$(pacman -Sp --print-format '%l' linux-headers 2>/dev/null | grep -m1 '/linux-headers-[^/]*\.pkg\.tar\.zst$')
        if [[ -z "$url" ]]; then
            echo "Cannot resolve linux-headers package URL" >&2
            exit 1
        fi
        pkg="./$(basename "$url")"
        wget -O "$pkg" "$url" || exit 1
        bsdtar -xOf "$pkg" 'usr/lib/modules/*/build/.config' > "$1/arch/base.config"
        local hver
        hver=$(basename "$pkg" | sed -E 's/^linux-headers-([0-9.]+)\..*/\1/')
        if [[ "$hver" != "$VERSION" ]]; then
            echo "WARNING: linux-headers is $hver but kernel source is $VERSION; config may not match" >&2
        fi
        rm -rf "$temp_n"
    ) || { echo "Failed to extract base config from linux-headers" >&2; exit 1; }
    echo "Base config lines: $(wc -l < "$1/arch/base.config")"
    set -e
}

inject_config() {
    local base="$2/arch/base.config"
    local target="$2/arch/.config"
    local f
    if [[ ! -s "$base" ]]; then
        echo "Base config $base is missing; cannot build a working kernel config" >&2
        exit 1
    fi
    cp -f "$base" "$target"
    for f in "$2/config/arch.config.unset" "$2/config/ogc.config.unset"; do
	[ -f "$f" ] && grep -vE '^\s*(#|$)' "$f" | sed -E 's/^[[:space:]]*(CONFIG_[A-Za-z0-9_]+).*/# \1 is not set/' >> "$target"
    done
    for f in "$2/config/arch.config.set" "$2/config/ogc.config.set"; do
	[ -f "$f" ] && grep -vE '^\s*(#|$)' "$f" >> "$target"
    done
    if ! grep -qE '^CONFIG_DEBUG_INFO_BTF=y' "$target"; then
        echo "CONFIG_DEBUG_INFO_BTF is not enabled; bpftool vmlinux.h generation would fail" >&2
        exit 1
    fi
    cp -f "$target" "$2/arch/config"

    local config="${1//\\/\\\\}"
    config="${config//$'\n'/\\$'\n'}"
    sed -i "/make olddefconfig/i\\${config}" "$2/arch/PKGBUILD"
}

set_mirrorlist() {
	echo ::Sync rate mirrorlist
	sudo reflector --sort rate --threads 100 --save /etc/pacman.d/mirrorlist || true
}

config_ccache() {
	ccache --max-size="$1"
}

start_build() {
    local rc=0
    (
        cd "$1/arch" || exit 1
		export USE_CCACHE=1
		export CCACHE_DIR="$HOME/.ccache"
		export CC="ccache gcc"
		export CXX="ccache g++"
		export PATH="/usr/lib/ccache:$PATH"
        SRCDEST="$2/sources" \
            BUILDDIR="$2/build" \
            PKGDEST="$2/packages" \
	    	MAKEFLAGS="-j$(nproc)" \
            makepkg -sf --noconfirm --skippgpcheck --skipchecksums --skipinteg
    ) || rc=$?

    mkdir -p "$3/rej/"
    find "$2" -name '*.rej' -type f -exec cp -vf {} "$3/rej/" \; || true
    cp -rvf "$2"/packages/*.pkg.tar.zst "$3/" || true
    (
        cd "$3" || exit 1
        if compgen -G "rej/*.rej" > /dev/null; then
            tar zcvf rej.tar.gz rej/*.rej
        else
            echo "No rejected patches"
            tar zcvf rej.tar.gz --files-from /dev/null
        fi
        rm -rvf rej || true
    ) || return 1

    if [[ "$rc" -ne 0 ]]; then
        echo "makepkg failed with exit code $rc" >&2
        return "$rc"
    fi
    if ! compgen -G "$3/*.pkg.tar.zst" > /dev/null; then
        echo "No kernel package produced" >&2
        return 1
    fi
}
