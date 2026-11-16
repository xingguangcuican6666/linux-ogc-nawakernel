#!/usr/bin/bash

clone_repo_latest() {
    rm -rvf "$2" || true
    git clone "$1" --verbose "$$2"
    Latest_tag=$(git --no-pager -C "$2" tag | tail -n 1)
    git -C "$2" checkout "$Latest_tag" --force
}

patch_pkgbuild() {
    Latest_tag=$(git --no-pager -C "$2" tag | tail -n 1)
    # git -C "$2" checkout "$Latest_tag" --force
    formatted=$(printf '%s\n' "$Latest_tag" | sed 's/^v//; s/-/./')
    # echo "$formatted"
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
    target="$1/arch/linux-${VERSION}.tar.xz"
    wget -O "$target" "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-${VERSION}.tar.xz"
    if [[ "$?" != 0 ]]; then
        if [[ "$RETRY" == 0 ]]; then
            echo "Download source failed: https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-${VERSION}.tar.xz"
            exit 1
        fi
        RETRY=$((RETRY - 1))
        download_source "$target"
    fi;
    RETRY=3
}

inject_config() {
    local config="$1"
    sed -i "/make olddefconfig/i\\${config}" "$2/arch/PKGBUILD"
}

start_build() {
    ( 
        cd "$1/arch" || exit 1
        SRCDEST="$2/sources" \
            BUILDDIR="$2/build" \
            PKGDEST="$2/packages" \
            makepkg -sf --noconfirm
    ) || return 1

    mkdir -p "$3/rej/"
    cp -rvf "$2"/*.rej "$3/rej" || true
    cp -rvf "$2"/*.pkg.tar.zst "$3" || true
    (
        cd "$3" || exit 1
        tar zcvf rej.tar.gz rej/*
        rm -rvf rej || true
    ) || return 1
}