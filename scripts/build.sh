#!/usr/bin/bash

set -e

export WORK_DIR="/work"
export SOURCE_DIR="/work/source"
export SCRIPT_DIR="$WORK_DIR/scripts"
export PATCH_DIR="$WORK_DIR/patchs"
export CACHE_DIR="$WORK_DIR/cache"
export REPO="https://github.com/OpenGamingCollective/kernel-packages"
export OUT_DIR="$WORK_DIR/out"
export VERSION=""
export RETRY=3
export CONFIG_TEXT=$(cat <<'EOF'
cp "$startdir/db.pem" certs/db.pem
scripts/config --set-str SYSTEM_TRUSTED_KEYS "certs/db.pem"
scripts/config --disable IMA_ARCH_POLICY
scripts/config --disable IMA_APPRAISE_MODSIG
EOF
)

source "$SCRIPT_DIR/common.sh"



clone_repo_latest "$REPO" "$SOURCE_DIR"
patch_pkgbuild "$SOURCE_DIR"
download_source "$SOURCE_DIR"
inject_config "$CONFIG_TEXT" "$SOURCE_DIR"
start-build "$SOURCE_DIR" "$CACHE_DIR" "$OUT_DIR"

# echo "$@"