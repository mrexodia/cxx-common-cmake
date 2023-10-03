#!/bin/bash

# Determine the right libstdc++ cross-compilation package
arch=$(uname -m)
if [ "$arch" == "aarch64" ]; then
    cross_packages="libstdc++-12-dev-armhf-cross"
elif [ "$arch" == "x86_64" ]; then
    cross_packages="libstdc++-9-dev-i386-cross"
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

# Install the dependencies
apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    flex \
    bison \
    clang \
    $cross_packages \
    && rm -rf /var/lib/apt/lists/*
