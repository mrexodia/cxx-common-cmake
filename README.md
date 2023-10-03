# dependencies

## Building (macOS)

```sh
brew install cmake ninja flex bison
cmake -B build
cmake --build build
```

## Building (Linux)

**Building with GCC is not supported.**

```sh
sudo apt install cmake ninja-build gcc-multilib g++-multilib libstdc++-12-dev-armhf-cross gcc-12 g++-12 flex bison clang git
cmake -B build "-DCMAKE_C_COMPILER=$(which clang-14)" "-DCMAKE_CXX_COMPILER=$(which clang++-14)"
cmake --build build
```

## Building (Windows)

**Windows is currently not supported**

**Important**: You need to use `clang-cl` to build the dependencies. Run the command below from a Visual Studio 2022 command prompt.

```sh
cmake -G "NMake Makefiles" -DCMAKE_C_COMPILER=clang-cl.exe -DCMAKE_CXX_COMPILER=clang-cl.exe -B build
cmake --build build
```

## Debugging

- If a build of a submodule fails and you want to force a full rebuild you can delete `build/<submodule>-prefix`
- For an external project you can delete `build/<project>-prefix/src/<project>-stamp`

## How it works

This folder is a standalone CMake project that uses [ExternalProject_Add](https://cmake.org/cmake/help/latest/module/ExternalProject.html) to compile all dependencies statically into their own prefix. No system dependencies (except Git and Ninja) are used in the build process, which streamlines the build between platforms.

The key is that every dependency's build process outputs a proper CMake package into the _prefix_. Take the capstone installation as an example:

```
── bin
│   └── cstool
├── include
│   └── capstone
│       ├── arm.h
│       ├── arm64.h
│       ├── bpf.h
│       ├── capstone.h
│       ├── evm.h
│       ├── m680x.h
│       ├── m68k.h
│       ├── mips.h
│       ├── mos65xx.h
│       ├── platform.h
│       ├── ppc.h
│       ├── riscv.h
│       ├── sparc.h
│       ├── systemz.h
│       ├── tms320c64x.h
│       ├── wasm.h
│       ├── x86.h
│       └── xcore.h
└── lib
    ├── cmake
    │   └── capstone
    │       ├── capstone-config-version.cmake
    │       ├── capstone-config.cmake
    │       ├── capstone-targets-noconfig.cmake
    │       └── capstone-targets.cmake
    ├── libcapstone.a
    └── pkgconfig
        └── capstone.pc
```

The files in `lib/cmake/capstone` allow you to link to capstone in your project's `CMakeLists.txt` like this:

```cmake
cmake_minimum_required(VERSION 3.24)
project(MyProject)

find_package(capstone REQUIRED)

add_executable(myproject src/main.cpp)
target_link_libraries(myproject PRIVATE capstone::capstone)
```

If the `capstone` package is set up correctly this will propagate all requirements capstone has (build flags, C++ standard, defines, ...) to your `myproject` target.

This `dependencies` project downloads, builds and installs all dependencies in `build/install` together. During the build of the dependencies the variable `CMAKE_PREFIX_PATH` is set to `build/install` as well, which is how recursive dependencies are handled.

## Updating a dependency

To update a dependency like LLVM all you have to do is modify the corresponding CMake. See `CMakeLists.txt` for details. In this specific example you would modify the `URL` and `URL_HASH` in `llvm.cmake`:

```cmake
ExternalProject_Add(llvm
    URL
        "https://github.com/llvm/llvm-project/releases/download/llvmorg-15.0.4/llvm-project-15.0.4.src.tar.xz"
    URL_HASH
        "SHA256=a3112dca9bdea4095361829910b74fb6b9da8ae6e3500db67c43c540ad6072da"
    CMAKE_CACHE_ARGS
        ${CMAKE_ARGS}
        "-DLLVM_ENABLE_PROJECTS:STRING=clang;lld"
        "-DLLVM_ENABLE_ASSERTIONS:STRING=ON"
        "-DLLVM_ENABLE_DUMP:STRING=ON"
        "-DLLVM_ENABLE_RTTI:STRING=ON"
    CMAKE_GENERATOR
        "Ninja"
    SOURCE_SUBDIR
        "llvm"
)
```

For the `simple_git` helper and `ExternalProject_Add` with the `GIT_REPOSITORY` argument it is important to pin a specific _commit_ of a dependency (instead of a branch name like `master`). Doing this ensures that you will still be able to build a specific set of dependencies in the future.

Another thing to be aware of is that the order of dependencies matters. Dependencies lower in the tree should be first, otherwise the dependencies higher up the tree will not build.

## Updating a dependency (submodule)

Submodules are checked out in a [detached HEAD state](https://www.cloudbees.com/blog/git-detached-head). To make some changes the first thing you do it check out the branch you want to modify:

```sh
cd dependencies/souper
git checkout cmake-package
```

At this point you can change files in `dependencies/souper` however you wish (building the `dependencies` project will automatically build and install the updated version for you to test on the parent project).

When you are happy with your changes you commit **and push** the changes:

```sh
cd dependencies/souper
git add myfiles
git commit -m "My message"
git push
```

Now all you did was modify the `souper` repository, but you still need to commit the changes to the submodule:

```sh
git add dependencies/souper
git commit -m "Updated souper"
git push
```

Remember to tell the team because when they `git pull` they need to update the submodule and build the dependencies:

```sh
git submodule update
cmake -B dependencies/build -S dependencies
cmake --build dependencies/build
```

## Docker

For convenience there is a [`Dockerfile`](./Dockerfile) provided.

To build:

```
git submodule update --init
docker buildx build --platform linux/arm64,linux/amd64 -t ghcr.io/mrexodia/cxx-common-cmake:latest .
```

Then push (maintainer's only):

```
docker push ghcr.io/mrexodia/cxx-common-cmake:latest
```

The hash (tag) is generated from `python hash.py`

References:
- https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/
- https://docs.docker.com/build/building/multi-stage/

## GitHub Actions

Below is an example `.github/workflows/build.yml` that uses `hash.py` to build and cache the dependencies:

```yml
name: build

on:
  push:
  schedule:
    # Build master every 5 days to avoid costly cache rebuilds
    - cron: 0 0 */5 * * # https://crontab.guru/#0_0_*/5_*_*

jobs:
  build:
    runs-on: ubuntu-22.04

    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Install Ninja
        run: |
          if [ "$RUNNER_OS" == "Linux" ]; then
            sudo apt-get install -y ninja-build
          elif [ "$RUNNER_OS" == "macOS" ]; then
            brew install ninja
          elif [ "$RUNNER_OS" == "Windows" ]; then
            choco install ninja
          else
            echo "$RUNNER_OS not supported!"
            exit 1
          fi
        shell: bash

      - name: Hash Dependencies
        id: hash-dependencies
        run: |
          python dependencies/hash.py debug > $GITHUB_OUTPUT
        shell: bash

      - name: Cache Dependencies
        id: cache-dependencies
        uses: actions/cache@v3
        with:
          path: dependencies/build/install
          key: ${{ runner.os }}-${{ steps.hash-dependencies.outputs.file_hash }}
          restore-keys: |
            ${{ runner.os }}-${{ steps.hash-dependencies.outputs.restore_hash }}

      - name: Build Dependencies
        if: steps.cache-dependencies.outputs.cache-hit != 'true'
        run: |
          sudo apt-get update
          sudo apt-get install -y gcc-multilib g++-multilib flex bison
          cmake -B dependencies/build -S dependencies "-DCMAKE_C_COMPILER=$(which clang-14)" "-DCMAKE_CXX_COMPILER=$(which clang++-14)"
          cmake --build dependencies/build

      - name: Build Project
        run: |
          cmake -B build -G Ninja "-DCMAKE_BUILD_TYPE=Debug" "-DCMAKE_PREFIX_PATH=$(pwd)/dependencies/build/install" "-DCMAKE_C_COMPILER=$(which clang-14)" "-DCMAKE_CXX_COMPILER=$(which clang++-14)"
          cmake --build build
```
