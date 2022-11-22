# https://alexreinking.com/blog/how-to-use-cmake-without-the-agonizing-pain-part-1.html
cmake_minimum_required(VERSION 3.24)

# Bail out early for multi-config generators
if(GENERATOR_IS_MULTI_CONFIG)
    message(FATAL_ERROR "Multi-config generators are not supported. Use Make/NMake instead")
endif()

project(Dependencies)

# Default to a Release config
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release")
endif()
message(STATUS "Configuration: ${CMAKE_BUILD_TYPE}")

# Default to build/install (setting this variable is not recommended and might cause conflicts)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/install" CACHE PATH "Install prefix" FORCE)
endif()
message(STATUS "Install prefix: ${CMAKE_INSTALL_PREFIX}")

# Git is necessary for submodules
find_package(Git REQUIRED)
message(STATUS "Git: ${GIT_EXECUTABLE}")

# Ninja is necessary for building the dependencies
find_program(NINJA_EXECUTABLE ninja NO_CACHE NO_PACKAGE_ROOT_PATH NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH NO_CMAKE_INSTALL_PREFIX NO_CMAKE_FIND_ROOT_PATH)
if(NINJA_EXECUTABLE STREQUAL "NINJA_EXECUTABLE-NOTFOUND")
    message(FATAL_ERROR "Could not find 'ninja' in the PATH")
endif()
message(STATUS "Ninja: ${NINJA_EXECUTABLE}")

# Documentation: https://cmake.org/cmake/help/latest/module/ExternalProject.html
include(ExternalProject)

# Hook for ExternalProject_Add to make sure projects build in order
function(ExternalProject_Add name)
    # The DEPENDS argument is fully implicit
    cmake_parse_arguments(HOOK "" "" DEPENDS ${ARGN})
    if(HOOK_DEPENDS)
        message(FATAL_ERROR "Explicit DEPENDS (${HOOK_DEPENDS}) not supported")
    endif()

    # Update the LAST_EXTERNAL_PROJECT property
    get_property(LAST_EXTERNAL_PROJECT GLOBAL PROPERTY LAST_EXTERNAL_PROJECT)
    set_property(GLOBAL PROPERTY LAST_EXTERNAL_PROJECT ${name})

    # Pass the previous project as a dependency to this call
    if(LAST_EXTERNAL_PROJECT)
        set(HOOK_ARGS DEPENDS "${LAST_EXTERNAL_PROJECT}")
        message(STATUS "ExternalProject: ${name} depends on ${LAST_EXTERNAL_PROJECT}")
    else()
        message(STATUS "ExternalProject: ${name}")
    endif()
    _ExternalProject_Add(${name} ${ARGN} ${HOOK_ARGS})
endfunction()


# Default cache variables for all projects
list(APPEND CMAKE_ARGS
    "-DCMAKE_PREFIX_PATH:FILEPATH=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_INSTALL_PREFIX:FILEPATH=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}"
    "-DGFLAGS_USE_TARGET_NAMESPACE:STRING=ON"
    "-DBUILD_SHARED_LIBS:STRING=OFF"
    "-DCMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}"
    "-DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}"
    "-DCMAKE_C_FLAGS:STRING=${CMAKE_C_FLAGS}"
    "-DCMAKE_CXX_FLAGS:STRING=${CMAKE_CXX_FLAGS}"
)

function(simple_git repo tag)
    get_filename_component(name "${repo}" NAME_WE)
    ExternalProject_Add(${name}
        GIT_REPOSITORY
            "${repo}"
        GIT_TAG
            "${tag}"
        GIT_PROGRESS
            ON
        CMAKE_CACHE_ARGS
            ${CMAKE_ARGS}
        CMAKE_GENERATOR
            "Ninja"
    )
endfunction()

function(simple_submodule folder)
    set(folder_path "${CMAKE_CURRENT_SOURCE_DIR}/${folder}")
    if(NOT EXISTS "${folder_path}" OR NOT EXISTS "${folder_path}/CMakeLists.txt")
        message(STATUS "Submodule '${folder}' not initialized, running git...")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" submodule update --init
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.."
            COMMAND_ERROR_IS_FATAL ANY
        )
    endif()
    ExternalProject_Add(${folder}
        SOURCE_DIR
            "${folder_path}"
        CMAKE_CACHE_ARGS
            ${CMAKE_ARGS}
        CMAKE_GENERATOR
            "Ninja"
        # Always trigger the build step (necessary because there is no download step)
        BUILD_ALWAYS
            ON
    )
endfunction()

simple_git(https://github.com/gflags/gflags v2.2.2)
simple_git(https://github.com/google/glog v0.6.0)
simple_git(https://github.com/google/googletest release-1.12.1)
simple_git(https://github.com/redis/hiredis afc29ee)
simple_submodule(LIEF)
include(capstone.cmake)
include(z3.cmake)
include(xed.cmake)
include(llvm.cmake)
include(remill.cmake)
simple_submodule(alive2)
simple_submodule(souper)