ExternalProject_Add(capstone
    GIT_REPOSITORY
        "https://github.com/capstone-engine/capstone"
    GIT_TAG
        "087889d" # next
    GIT_PROGRESS
        ON
    CMAKE_CACHE_ARGS
        ${CMAKE_ARGS}
        "-DCAPSTONE_BUILD_TESTS:STRING=OFF"
    CMAKE_GENERATOR
        "Ninja"
)