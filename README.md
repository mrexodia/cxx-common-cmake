# dependencies

## Building

```sh
cmake -B build
cmake --build build
```

_Linux_: For Ubuntu/Debian you need to run: `sudo apt install gcc-multilib g++-multilib gcc-12 g++-12`. This is necessary for cross-compiling a part of remill in 32-bit.

_Windows_: You need to use `clang-cl` to build these dependencies. From a Visual Studio 2022 command prompt, run: `cmake -G "NMake Makefiles" -DCMAKE_C_COMPILER=clang-cl.exe -DCMAKE_CXX_COMPILER=clang-cl.exe -B build`

## Debugging

- If a build of a submodule fails and you want to force a rebuild you can delete `build/<submodule>-prefix`
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
