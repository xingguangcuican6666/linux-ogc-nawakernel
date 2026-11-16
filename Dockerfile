FROM archlinux
# ENTRYPOINT [ "executable" ]
RUN mkdir -p /work/source
RUN mkdir -p /work/scripts
RUN mkdir -p /work/patch
COPY scripts/ /work/scripts/
RUN pacman -Syuu --noconfirm base-devel git bc cpio gettext libelf pahole perl python rust rust-bindgen rust-src tar xz zstd openssl

ENTRYPOINT ["/work/scripts/build.sh"]