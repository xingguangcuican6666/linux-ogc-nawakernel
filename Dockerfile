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
RUN pacman -Sy --noconfirm --needed base-devel reflector sudo && \
    useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder
RUN reflector --sort rate --threads 100 --save /etc/pacman.d/mirrorlist
RUN pacman -Syuu --noconfirm base-devel ccache git bc cpio gettext libelf pahole perl python rust rust-bindgen rust-src tar wget xz zstd openssl
RUN chmod 777 /work -Rv
USER builder
WORKDIR /work
ENTRYPOINT ["/usr/bin/bash", "/work/scripts/build.sh"]
