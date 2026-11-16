FROM archlinux
# ENTRYPOINT [ "executable" ]
RUN mkdir -p /work/source
RUN mkdir -p /work/scripts
RUN mkdir -p /work/patchs
RUN mkdir -p /work/build
RUN mkdir -p /work/cache/source
RUN mkdir -p /work/cache/build
RUN mkdir -p /work/cache/packages
RUN mkdir -p /work/out
COPY scripts/ /work/scripts
COPY patchs/ /work/patchs
RUN chmod +x /work/scripts/*.sh
RUN pacman -Syuu --noconfirm base-devel git bc cpio gettext libelf pahole perl python rust rust-bindgen rust-src tar xz zstd openssl

ENTRYPOINT ["/work/scripts/build.sh"]