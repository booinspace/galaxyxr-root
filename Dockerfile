FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    ANDROID_HOME=/work/android-sdk \
    ANDROID_NDK_HOME=/work/android-sdk/ndk/29.0.14206865 \
    RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/work/cargo \
    PATH=/opt/cargo/bin:/opt/android/cmdline-tools/latest/bin:/usr/lib/jvm/java-21-openjdk-amd64/bin:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi bison build-essential ca-certificates \
    cmake cpio curl dwarves file flex git kmod libclang-dev libelf-dev \
    libssl-dev ninja-build openjdk-21-jdk-headless pkg-config python3 python-is-python3 \
    openssl rsync unzip xz-utils zip zstd \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/android-tools.zip \
      https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip \
    && echo '4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583  /tmp/android-tools.zip' | sha256sum -c - \
    && mkdir -p /opt/android/cmdline-tools/latest \
    && unzip -q /tmp/android-tools.zip -d /tmp/android-tools \
    && mv /tmp/android-tools/cmdline-tools/* /opt/android/cmdline-tools/latest/ \
    && rm -rf /tmp/android-tools /tmp/android-tools.zip

RUN CARGO_HOME=/opt/cargo curl -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh \
    && CARGO_HOME=/opt/cargo sh /tmp/rustup-init.sh -y --no-modify-path \
         --default-toolchain 1.99.0 --profile minimal \
    && CARGO_HOME=/opt/cargo rustup target add aarch64-linux-android \
    && chmod -R a+rX /opt/cargo /opt/rustup \
    && rm /tmp/rustup-init.sh

WORKDIR /repo
