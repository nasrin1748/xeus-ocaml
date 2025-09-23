
opam install dune js_of_ocaml lwt graphics js_of_ocaml-lwt js_of_ocaml-ppx js_of_ocaml-toplevel base


opam -- dune 

micromamba create -f environment-wasm-build.yml -n xeus-ocaml-wasm-build
micromamba activate xeus-ocaml-wasm-build
emsdk update
emsdk install 3.1.73
emsdk activate 3.1.73
source $CONDA_EMSDK_DIR/emsdk_env.sh


micromamba create -f environment-wasm-host.yml --platform=emscripten-wasm32
micromamba activate xeus-ocaml-wasm-host

mkdir build
pushd build

export EMPACK_PREFIX=$MAMBA_ROOT_PREFIX/envs/xeus-ocaml-wasm-build
export PREFIX=$MAMBA_ROOT_PREFIX/envs/xeus-ocaml-wasm-host
export CMAKE_PREFIX_PATH=$PREFIX
export CMAKE_SYSTEM_PREFIX_PATH=$PREFIX

emcmake cmake \
-DCMAKE_BUILD_TYPE=Release                        \
-DCMAKE_PREFIX_PATH=$PREFIX                       \
-DCMAKE_INSTALL_PREFIX=$PREFIX                    \
-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ON            \
..

make -j${{ steps.cpu-cores.outputs.count }}



rattler-build build --recipe recipe/recipe.yaml -c  https://repo.prefix.dev/emscripten-forge-dev  -c conda-forge --target-platform emscripten-wasm32