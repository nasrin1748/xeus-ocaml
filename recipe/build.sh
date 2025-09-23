# xeus-ocaml-recipe/build.sh

#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.
set -x # Print commands and their arguments as they are executed.

# Configure CMake
cmake -B build \
      -D CMAKE_INSTALL_PREFIX=$PREFIX \
      -D CMAKE_BUILD_TYPE=Release \
      -D XEUS_OCAML_BUILD_SHARED=ON \
      -D XEUS_OCAML_BUILD_EXECUTABLE=ON

# Build the project
cmake --build build -- -j${CPU_COUNT}

# Install the project
cmake --install build