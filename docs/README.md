# Project Documentation

This directory contains the source files for the `xeus-ocaml` documentation, built with [Sphinx](https://www.sphinx-doc.org/).

The documentation automatically pulls in API references from both the C++ and OCaml source code.

## Prerequisites

The documentation build process is managed by `pixi`. All required tools (Sphinx, Doxygen, etc.) are defined in the `[feature.docs]` section of the root `pixi.toml` file.

## Building the Documentation

1.  **Activate the environment**: If not already done, ensure you are in the pixi shell.
    ```bash
    pixi shell
    ```

2.  **Build the OCaml code (required for odoc)**: The OCaml documentation is generated from the compiled artifacts, so the project must be built first.
    ```bash
    pixi run -e ocaml build
    ```

3.  **Build all documentation components**: This single command will run Doxygen, Odoc, and Sphinx in the correct order.
    ```bash
    pixi run build-docs
    ```

4.  **Serve the documentation locally**: To view the generated website, run the local server.
    ```bash
    pixi run serve-docs
    ```

The site will be available at `http://localhost:8000`. The output is generated in the `doc/build/html/` directory.