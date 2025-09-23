#############################################################################
# Copyright (c) 2025,
#
# Distributed under the terms of the GNU General Public License v3.
#
# The full license is in the file LICENSE, distributed with this software.
#############################################################################

cmake_minimum_required(VERSION 3.8)
project(xeus-ocaml)
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")

set(XEUS_OCAML_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Versioning
# ===========

file(STRINGS "${XEUS_OCAML_INCLUDE_DIR}/xeus-ocaml/xeus_ocaml_config.hpp" version_defines
     REGEX "#define XEUS_OCAML_VERSION_(MAJOR|MINOR|PATCH)")
foreach (ver ${version_defines})
    if (ver MATCHES "#define XEUS_OCAML_VERSION_(MAJOR|MINOR|PATCH) +([^ ]+)$")
        set(XEUS_OCAML_VERSION_${CMAKE_MATCH_1} "${CMAKE_MATCH_2}" CACHE INTERNAL "")
    endif ()
endforeach ()
set(${PROJECT_NAME}_VERSION
    ${XEUS_OCAML_VERSION_MAJOR}.${XEUS_OCAML_VERSION_MINOR}.${XEUS_OCAML_VERSION_PATCH})
message(STATUS "Building xeus-ocaml v${${PROJECT_NAME}_VERSION}")

# Configuration
# =============

include(GNUInstallDirs)

if (NOT DEFINED XEUS_OCAML_KERNELSPEC_PATH)
    set(XEUS_OCAML_KERNELSPEC_PATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}/")
endif ()

configure_file (
    "${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels/xocaml/kernel.json.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels/xocaml/kernel.json"
)

# Build options
# =============

option(XEUS_OCAML_BUILD_STATIC "Build xeus-ocaml static library" ON)
OPTION(XEUS_OCAML_BUILD_SHARED "Split xocaml build into executable and library" ON)
OPTION(XEUS_OCAML_BUILD_EXECUTABLE "Build the xocaml executable" ON)

OPTION(XEUS_OCAML_USE_SHARED_XEUS "Link xocaml  with the xeus shared library (instead of the static library)" ON)
OPTION(XEUS_OCAML_USE_SHARED_XEUS_OCAML "Link xocaml  with the xeus shared library (instead of the static library)" ON)


if(EMSCRIPTEN)
    add_compile_definitions(XEUS_OCAML_EMSCRIPTEN_WASM_BUILD)
    message("Build with emscripten")
    string(REPLACE "-march=nocona" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    string(REPLACE "-mtune=haswell" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    string(REPLACE "-ftree-vectorize" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    string(REPLACE "-fstack-protector-strong" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    string(REPLACE "-fno-plt" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    SET(XEUS_OCAML_BUILD_STATIC ON)
    SET(XEUS_OCAML_BUILD_SHARED OFF)
    SET(XEUS_OCAML_BUILD_EXECUTABLE OFF)
    SET(XEUS_OCAML_USE_SHARED_XEUS OFF)
    SET(XEUS_OCAML_USE_SHARED_XEUS_OCAML OFF)
    SET(XEUS_OCAML_BUILD_TESTS OFF)
endif()


# Dependencies
# ============


set(xeus_REQUIRED_VERSION 5.0.0)

find_package(xeus ${xeus_REQUIRED_VERSION} REQUIRED)


# Flags
# =====
include(CheckCXXCompilerFlag)

if (MSVC)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4251 /wd4141")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4018 /wd4267 /wd4715 /wd4146 /wd4129")
endif ()

if (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID MATCHES "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Intel")
    if(NOT EMSCRIPTEN)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wunused-parameter -Wextra -Wreorder")
    endif()

    CHECK_CXX_COMPILER_FLAG("-std=c++17" HAS_CPP_17_FLAG)
    if (HAS_CPP_17_FLAG)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
    else ()
        message(FATAL_ERROR "Unsupported compiler -- xeus requires C++17 support!")
    endif ()
endif ()


# Source files
# ============

set(XEUS_OCAML_HEADERS
    include/xeus-ocaml/xeus_ocaml_config.hpp
    include/xeus-ocaml/xinterpreter.hpp
)

set(XEUS_OCAML_SRC
    src/xinterpreter.cpp
)

set(XEUS_OCAML_MAIN_SRC
    src/main.cpp
)


# Targets and link - Macros
# =========================
macro(xeus_ocaml_set_common_options target_name)
    if (MSVC)
        target_compile_options(${target_name} PUBLIC /wd4251 /wd4141)
        target_compile_options(${target_name} PUBLIC /wd4018 /wd4267 /wd4715 /wd4146 /wd4129)
    endif ()

    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR
        CMAKE_CXX_COMPILER_ID MATCHES "GNU" OR
        CMAKE_CXX_COMPILER_ID MATCHES "Intel")

        target_compile_options(${target_name} PUBLIC -Wunused-parameter -Wextra -Wreorder)

        # C++17 flag
        CHECK_CXX_COMPILER_FLAG("-std=c++17" HAS_CPP_17_FLAG)
        if (HAS_CPP_17_FLAG)
            target_compile_features(${target_name} PRIVATE cxx_std_17)
        else ()
            message(FATAL_ERROR "Unsupported compiler -- xeus-ocaml requires C++17 support!")
        endif ()
    endif ()

    if (APPLE)
        set_target_properties(${target_name} PROPERTIES
            MACOSX_RPATH ON
        )
    else ()
        set_target_properties(${target_name} PROPERTIES
            BUILD_WITH_INSTALL_RPATH 1
            SKIP_BUILD_RPATH FALSE
        )
    endif ()

    set_target_properties(${target_name} PROPERTIES
        INSTALL_RPATH_USE_LINK_PATH TRUE
    )
endmacro()

macro(xeus_ocaml_set_kernel_options target_name)
    if (XEUS_OCAML_USE_SHARED_XEUS_OCAML)
        target_link_libraries(${target_name} PRIVATE xeus-ocaml)
        if(CMAKE_DL_LIBS)
            target_link_libraries(${target_name} PRIVATE ${CMAKE_DL_LIBS} util)
        endif()
    else ()
        target_link_libraries(${target_name} PRIVATE xeus-ocaml-static)
    endif()

    if(NOT EMSCRIPTEN)
        find_package(Threads)
        target_link_libraries(${target_name} PRIVATE ${CMAKE_THREAD_LIBS_INIT})
    endif()
endmacro()

macro(xeus_ocaml_create_target target_name linkage output_name)
    string(TOUPPER "${linkage}" linkage_upper)

    if (NOT ${linkage_upper} MATCHES "^(SHARED|STATIC)$")
        message(FATAL_ERROR "Invalid library linkage: ${linkage}")
    endif ()

    add_library(${target_name} ${linkage_upper} ${XEUS_OCAML_SRC} ${XEUS_OCAML_HEADERS})
    xeus_ocaml_set_common_options(${target_name})

    set_target_properties(${target_name} PROPERTIES
                          PUBLIC_HEADER "${XEUS_OCAML_HEADERS}"
                          PREFIX ""
                          VERSION ${${PROJECT_NAME}_VERSION}
                          SOVERSION ${XEUS_OCAML_VERSION_MAJOR}
                          OUTPUT_NAME "lib${output_name}")

    target_compile_definitions(${target_name} PUBLIC "XEUS_OCAML_EXPORTS")

    target_compile_features(${target_name} PRIVATE cxx_std_17)

    target_include_directories(${target_name}
                               PUBLIC
                               $<BUILD_INTERFACE:${XEUS_OCAML_INCLUDE_DIR}>
                               $<INSTALL_INTERFACE:include>)

    if (XEUS_OCAML_USE_SHARED_XEUS)
        set(XEUS_OCAML_XEUS_TARGET xeus)
    else ()
        set(XEUS_OCAML_XEUS_TARGET xeus-static)
    endif ()

    target_link_libraries(${target_name} PUBLIC ${XEUS_OCAML_XEUS_TARGET})
    if (WIN32 OR CYGWIN)
        #
    elseif (APPLE)
        target_link_libraries(${target_name} PRIVATE "-undefined dynamic_lookup")
    endif ()
    if(NOT EMSCRIPTEN)
        find_package(Threads)
        target_link_libraries(${target_name} PRIVATE ${CMAKE_THREAD_LIBS_INIT})
    endif()
endmacro()

# xeus-ocaml
# ===========

set(XEUS_OCAML_TARGETS "")

if (XEUS_OCAML_BUILD_SHARED)
    xeus_ocaml_create_target(xeus-ocaml SHARED xeus-ocaml)
    list(APPEND XEUS_OCAML_TARGETS xeus-ocaml)
endif ()

if (XEUS_OCAML_BUILD_STATIC)
    if (CMAKE_HOST_WIN32)
        xeus_ocaml_create_target(xeus-ocaml-static STATIC xeus-ocaml-static)
    else ()
        xeus_ocaml_create_target(xeus-ocaml-static STATIC xeus-ocaml)
    endif ()
    if(EMSCRIPTEN)
        target_compile_options(xeus-ocaml-static PRIVATE -fPIC)
    endif()
    list(APPEND XEUS_OCAML_TARGETS xeus-ocaml-static)
endif ()

# xocaml
# =======
if (XEUS_OCAML_BUILD_EXECUTABLE)
    find_package(xeus-zmq 1.0.2 REQUIRED)
    add_executable(xocaml ${XEUS_OCAML_MAIN_SRC})
    target_compile_features(xocaml PRIVATE cxx_std_17)
    xeus_ocaml_set_common_options(xocaml)
    xeus_ocaml_set_kernel_options(xocaml)
    target_link_libraries(xocaml PRIVATE xeus-zmq)
endif()

if(EMSCRIPTEN)
    include(WasmBuildOptions)
    find_package(xeus-lite REQUIRED)
    add_executable(xocaml src/main_emscripten_kernel.cpp )
    set_target_properties(xocaml PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
    )
    target_link_libraries(xocaml PRIVATE xeus-lite)
    target_compile_options(xocaml PRIVATE -fPIC)
    xeus_ocaml_set_kernel_options(xocaml)
    xeus_wasm_compile_options(xocaml)

    # Linker options for wasm.
    # Add --pre-js to prepend our OCaml-generated JS to the final output.
    target_link_options(
        xocaml PRIVATE 
            "SHELL:--pre-js ${CMAKE_CURRENT_SOURCE_DIR}/src/ocaml/_build/default/kernel.bc.js"
            )
    # This ensures 'ocaml_kernel' is available globally before the wasm module runs.
    xeus_wasm_link_options(xocaml "web,worker")
endif()

# Installation
# ============
include(CMakePackageConfigHelpers)

set(XEUS_OCAML_CMAKECONFIG_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}" CACHE STRING "install path for xeus-ocamlConfig.cmake")

if (XEUS_OCAML_BUILD_SHARED)
    install(TARGETS ${XEUS_OCAML_TARGETS}
            EXPORT ${PROJECT_NAME}-targets
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
            PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/xeus-ocaml)

    export(EXPORT ${PROJECT_NAME}-targets
           FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Targets.cmake")
endif ()

if (XEUS_OCAML_BUILD_EXECUTABLE)
    install(TARGETS xocaml
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

if (XEUS_OCAML_BUILD_EXECUTABLE OR EMSCRIPTEN)
    set(XJUPYTER_DATA_DIR "share/jupyter"    CACHE STRING "Jupyter data directory")
    set(KERNELSPEC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/share/jupyter/kernels)
    install(DIRECTORY ${KERNELSPEC_DIR}
            DESTINATION ${XJUPYTER_DATA_DIR}
            PATTERN "*.in" EXCLUDE)

    if (XEXTRA_JUPYTER_DATA_DIR)
        install(DIRECTORY ${KERNELSPEC_DIR}
                DESTINATION ${XEXTRA_JUPYTER_DATA_DIR}
                PATTERN "*.in" EXCLUDE)
    endif ()
endif ()

set(XEUS_OCAML_CONFIG_CODE "####### Expanded from \@XEUS_OCAML_CONFIG_CODE\@ #######\n")
set(XEUS_OCAML_CONFIG_CODE "${XEUS_OCAML_CONFIG_CODE}set(CMAKE_MODULE_PATH \"${CMAKE_CURRENT_SOURCE_DIR}/cmake;\${CMAKE_MODULE_PATH}\")\n")
set(XEUS_OCAML_CONFIG_CODE "${XEUS_OCAML_CONFIG_CODE}##################################################")
configure_package_config_file(${PROJECT_NAME}Config.cmake.in
                              "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
                              INSTALL_DESTINATION ${PROJECT_BINARY_DIR})

set(XEUS_OCAML_CONFIG_CODE "")
configure_package_config_file(${PROJECT_NAME}Config.cmake.in
                              "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${PROJECT_NAME}Config.cmake"
                              INSTALL_DESTINATION ${XEUS_OCAML_CMAKECONFIG_INSTALL_DIR})

write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
                                 VERSION ${${PROJECT_NAME}_VERSION}
                                 COMPATIBILITY AnyNewerVersion)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${PROJECT_NAME}Config.cmake
              ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
              DESTINATION ${XEUS_OCAML_CMAKECONFIG_INSTALL_DIR})

if (XEUS_OCAML_BUILD_SHARED)
    install(EXPORT ${PROJECT_NAME}-targets
            FILE ${PROJECT_NAME}Targets.cmake
            DESTINATION ${XEUS_OCAML_CMAKECONFIG_INSTALL_DIR})
endif ()

if(EMSCRIPTEN)
    install(TARGETS xocaml
            ARCHIVE DESTINATION ${XEUS_OCAML_CMAKECONFIG_INSTALL_DIR})

    install(FILES
            "$<TARGET_FILE_DIR:xocaml>/xocaml.js"
            "$<TARGET_FILE_DIR:xocaml>/xocaml.wasm"
            DESTINATION ${CMAKE_INSTALL_BINDIR})
endif ()