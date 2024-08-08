# Reference: https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/

# Build stage (no need to optimize for size)
FROM ubuntu:22.04 as build
WORKDIR /cxx-common
COPY . .
RUN ./ubuntu-dependencies.sh
RUN \
    cmake -B build \
        "-DCMAKE_C_COMPILER=$(which clang)" \
        "-DCMAKE_CXX_COMPILER=$(which clang++)" \
        "-DCMAKE_INSTALL_PREFIX=$(pwd)/install" \
        && \
    cmake --build build && \
    rm -rf build

# Actual final image
FROM ubuntu:22.04 as cxx-common
WORKDIR /cxx-common/install
COPY --from=build /cxx-common/install .
ENV CMAKE_PREFIX_PATH=/cxx-common/install
ENV LD_LIBRARY_PATH=/cxx-common/install/lib
RUN apt-get update && apt-get install -y \
    libstdc++-11-dev \
    libxml2-dev \
    ncurses-dev \
    libz-dev \
    libsqlite3-dev \
    sqlite3 \
    && apt remove -y gcc gcc-11 \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*
LABEL org.opencontainers.image.source=https://github.com/mrexodia/cxx-common-cmake