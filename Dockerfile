FROM ubuntu:16.04

RUN apt-get update -y && apt-get install -y --no-install-recommends \
      bzip2 \
      curl \
      ca-certificates \
      qemu-system-arm \
      cpio \
      gcc \
      libc6-dev \
      gcc-arm-linux-gnueabihf \
      libc6-dev-armhf-cross \
      xz-utils \
      bc \
      make

ENV ARCH=arm \
    CROSS_COMPILE=arm-linux-gnueabihf- \
    PATH=$PATH:/root/.cargo/bin \
    CARGO_TARGET_ARM_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc

WORKDIR /build

# Compile the kernel that we're going to run and be emulating with. The first
# defconfig target that we run `make` for configures the kernel for the board
# that we're going to be emulating below.
RUN curl https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.42.tar.xz | \
      tar xJf - && \
      cd /build/linux-4.4.42 && \
      make vexpress_defconfig && \
      make -j$(nproc) all && \
      cp arch/arm/boot/zImage /tmp && \
      cd /build && \
      rm -rf linux-4.4.42

# Compile an instance of busybox as this provides a lightweight system and init
# binary which we will boot into. Only trick here is configuring busybox to
# build static binaries.
RUN curl https://www.busybox.net/downloads/busybox-1.21.1.tar.bz2 | tar xjf - && \
      cd busybox-1.21.1 && \
      make defconfig && \
      sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config && \
      make -j$(nproc) && \
      make install && \
      mv _install /tmp/rootfs && \
      cd /build && \
      rm -rf busybox-1.12.1

# Download the ubuntu rootfs, which we'll use as a chroot for all our tests.
WORKDIR /tmp
RUN mkdir rootfs/ubuntu
RUN curl http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04-core-armhf.tar.gz | \
      tar xzf - -C rootfs/ubuntu && \
      cd rootfs && mkdir proc sys dev etc etc/init.d

# Copy over our init script, which starts up our test server and also a few
# other misc tasks.
COPY rcS rootfs/etc/init.d/rcS
RUN chmod +x rootfs/etc/init.d/rcS

# Helper to quickly fill the entropy pool in the kernel.
ADD addentropy.c /tmp/
RUN arm-linux-gnueabihf-gcc addentropy.c -o rootfs/addentropy -static

# Compile our test daemon (this should probably be done elsewhere)
ADD testd /tmp/testd/
RUN curl https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly && \
      rustup target add arm-unknown-linux-gnueabihf && \
      cargo build --manifest-path testd/Cargo.toml --release && \
      cargo build --manifest-path testd/Cargo.toml --target arm-unknown-linux-gnueabihf --release && \
      cp testd/target/arm-unknown-linux-gnueabihf/release/testd rootfs

# Compile our rootfs into a cpio archive, this will be our initial ram disk that
# we pass to qemu and the kernel reads.
RUN cd rootfs && find . -print0 | cpio --null -o --format=newc > /tmp/rootfs.img

# TODO: What is this?!
RUN curl -O http://ftp.nl.debian.org/debian/dists/jessie/main/installer-armhf/current/images/device-tree/vexpress-v2p-ca15-tc1.dtb

# Command to run the emulator
CMD \
  qemu-system-arm \
    -M vexpress-a15 \
    -m 1024 \
    -kernel /tmp/zImage \
    -initrd /tmp/rootfs.img \
    -dtb vexpress-v2p-ca15-tc1.dtb \
    -append "console=ttyAMA0 root=/dev/ram rdinit=/sbin/init init=/sbin/init" \
    -nographic \
    -serial stdio \
    -monitor none \
    -redir tcp:12345::12345
