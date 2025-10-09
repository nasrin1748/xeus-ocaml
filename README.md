
# ![xeus-logo](https://raw.githubusercontent.com/jupyter-xeus/xeus/refs/heads/main/docs/source/xeus.svg) OCAML ![xeus-ocaml logo](https://raw.githubusercontent.com/davy39/xeus-ocaml/refs/heads/main/share/jupyter/kernels/xocaml/logo-64x64.png)

[![CI and Auto-Tagging](https://github.com/davy39/xeus-ocaml/actions/workflows/ci.yml/badge.svg)](https://github.com/davy39/xeus-ocaml/actions/workflows/ci.yml)
[![Release and Deploy](https://github.com/davy39/xeus-ocaml/actions/workflows/release.yml/badge.svg)](https://github.com/davy39/xeus-ocaml/actions/workflows/release.yml)
[![lite-badge](https://jupyterlite.rtfd.io/en/latest/_static/badge.svg)](https://davy39.github.io/xeus-ocaml/)

`xeus-ocaml` is a Jupyter kernel for the OCaml programming language that runs entirely in the web browser through WebAssembly. It is built on the `xeus-lite` library, a lightweight C++ implementation of the Jupyter protocol for WASM environments.

This kernel integrates the OCaml toplevel and the Merlin code analysis tool, providing an interactive and responsive development experience within JupyterLite without requiring a server-side backend.

## 🚀 Live Demo

Experience `xeus-ocaml` firsthand in your browser by visiting the JupyterLite deployment on GitHub Pages:

[**https://davy39.github.io/xeus-ocaml/**](https://davy39.github.io/xeus-ocaml/)

## ✨ Features

*   **Fully Browser-Based**: Runs entirely in the browser with no server-side installation, powered by WebAssembly.
*   **Interactive OCaml Toplevel**: Execute OCaml code interactively, with persistent state between cells.
*   **Rich Language Intelligence**: Provides code completion and inspection (tooltips on hover/Shift+Tab) through an integrated Merlin engine.
*   **Rich Display Support**: Render HTML, Markdown, SVG, JSON, and even complex plots like Vega-Lite directly from your OCaml code.

## 📊 Rich Display and Visualization

The kernel comes with a built-in `Xlib` library that is **automatically opened** on startup, so its functions are immediately available in the global scope. This library provides a simple API for rendering a wide variety of rich outputs in your notebook cells.

Here are some of the key functions available:

| Function                | Description                                                |
| ----------------------- | ---------------------------------------------------------- |
| `output_html s`         | Renders a raw HTML string `s`.                             |
| `output_markdown s`     | Renders a Markdown string `s`.                             |
| `output_svg s`          | Renders an SVG image from its XML string `s`.              |
| `output_json s`         | Renders a JSON string `s` as a collapsible tree view.      |
| `output_vegalite s`     | Renders an interactive Vega-Lite plot from a JSON spec `s`.|
| `output_png_base64 s`   | Displays a PNG image from a Base64-encoded string `s`.     |
| `output_jpeg_base64 s`  | Displays a JPEG image from a Base64-encoded string `s`.    |

#### Example Usage

You can call these functions directly in any cell to produce rich outputs.

```ocaml
(* Render an interactive Vega-Lite chart *)
let vega_spec = {|
  {
    "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
    "description": "A simple bar chart with embedded data.",
    "data": {
      "values": [
        {"a": "A", "b": 28}, {"a": "B", "b": 55}, {"a": "C", "b": 43},
        {"a": "D", "b": 91}, {"a": "E", "b": 81}, {"a": "F", "b": 53}
      ]
    },
    "mark": "bar",
    "encoding": {
      "x": {"field": "a", "type": "nominal", "axis": {"labelAngle": 0}},
      "y": {"field": "b", "type": "quantitative"}
    }
  }
|} in
output_vegalite vega_spec
```

## 🏗️ Architecture

`xeus-ocaml` utilizes a hybrid C++ and OCaml architecture, where both languages are compiled to run within a single browser execution context. This design avoids the overhead of web workers for communication, enabling fast and direct interaction between components.

1.  **C++ Kernel Core (`xocaml.wasm`)**: The kernel's foundation is a C++ application built with `xeus-lite`. It is compiled to a WebAssembly module (`xocaml.wasm`) and is responsible for handling the Jupyter messaging protocol. It acts as the central controller, receiving requests from the Jupyter frontend and dispatching them to the OCaml backend.

2.  **OCaml Backend (`xocaml.js`)**: The OCaml code, including the toplevel environment (`xtoplevel.ml`) and Merlin integration (`xmerlin.ml`), is compiled to a single JavaScript file (`xocaml.js`) using `js_of_ocaml`. This script exposes a clean API for executing code and performing code analysis.

3.  **Direct Communication via Embind**: The C++ kernel and OCaml backend communicate directly within the browser's main thread.
    *   The `xocaml.js` file is loaded before the WASM module, making its exported functions available globally.
    *   The C++ code uses Emscripten's `emscripten::val` API to make direct calls to the JavaScript functions provided by the OCaml backend.
    *   **Synchronous calls** (e.g., code completion) are handled with a simple function call and return.
    *   **Asynchronous calls** (e.g., code execution) are managed by passing a C++ callback function to the OCaml/JS side. The OCaml code, using its `Lwt` library for concurrency, executes the task and invokes the C++ callback upon completion.

4.  **Standard Library Management**: To balance startup performance and functionality, the kernel uses a hybrid approach for the OCaml standard library. A core set of modules is embedded directly into the `xocaml.js` bundle at compile time. Additional modules are fetched dynamically from the server on-demand when the kernel first initializes.

## 🛠️ Local Development

This project uses the `pixi` package and environment manager to streamline development for both OCaml and C++/WASM components.

### Prerequisites

*   Install `pixi` by following the official [installation guide](https://pixi.sh/latest/installation/).

### Build and Run Steps

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/davy39/xeus-ocaml.git
    cd xeus-ocaml
    ```

2.  **Set up the OCaml Environment**
    This command initializes an `opam` switch inside the project's `.pixi` directory, installs the OCaml compiler, and locks the project's OCaml dependencies.
    ```bash
    pixi run -e ocaml setup
    ```

3.  **Build the OCaml Backend to JavaScript**
    This compiles all the OCaml source code into the `ocaml/xocaml.js` file.
    ```bash
    pixi run -e ocaml build
    ```
4.  **Build the Kernel**
    This build the kernel and create a conda package.
    ```bash
    pixi run build-kernel
    ```
5.  **Install the kernel**
    This install the kernel to be used with Jupyterlite.
    ```bash
    pixi run install-kernel
    ```
6.  **Serve Jupyterlite**
    This build and serve the Jupyterlite interface.
    ```bash
    pixi run install-kernel
    ```
    You can now access the local JupyterLite instance in your browser, typically at `http://localhost:8000`.

7.  **All in one command**
    This is a convenience command that performs all steps:
    ```bash
    pixi run build-all-serve
    ```


## 🧪 Testing

The project includes a Jest test suite for the JavaScript API generated from the OCaml code. These tests verify the core functionality of code evaluation and Merlin integration in isolation.

The tests are located in the `ocaml/tests/` directory. To run them, first ensure the OCaml backend is built (`pixi run -e ocaml build`), then execute:
```bash
pixi run -e test test
```

## 🗺️ Roadmap

### Implemented
-   [x] Interactive code execution via the `js_of_ocaml` toplevel.
-   [x] Code completion powered by an in-browser Merlin instance.
-   [x] Code inspection for tooltips (Shift+Tab) and the inspector panel.
-   [x] **Rich Outputs**: Display HTML, Markdown, SVG, JSON, and Vega-Lite plots directly from OCaml code using the auto-opened `Xlib` module.

### Future Work
-   [ ] **Library Management**: Implement a mechanism to dynamically fetch and load pre-compiled OCaml libraries from within a notebook session (e.g., via `#require`).
-   [ ] **Virtual Filesystem**: Expose APIs to read and write to the Emscripten virtual filesystem from OCaml, enabling file manipulation and data loading.
-   [ ] **User Input**: Add support for Jupyter's `input_request` messages to allow interactive OCaml functions like `read_line()`.
-   [ ] **Custom Widgets**: Develop a communication bridge (`Comm`) to enable OCaml code to interact with Jupyter Widgets for creating rich, interactive outputs.

## 📦 Continuous Integration and Deployment

This project uses GitHub Actions for automated builds, testing, and deployment:

*   **`ci.yml`**: Triggered on pushes to `main`. This workflow builds the OCaml and C++ components and runs the Jest test suite. If the version in `recipe/recipe.yaml` has been updated, it automatically creates and pushes a corresponding Git tag (e.g., `v0.2.0`).
*   **`release.yml`**: Triggered when a version tag is pushed. This workflow builds the final conda package, uploads it to the `xeus-ocaml` channel on prefix.dev, creates a GitHub Release with the package as an asset, and deploys the latest JupyterLite site to GitHub Pages.
*   **`page.yml`**: A manually triggered workflow to deploy the JupyterLite site to GitHub Pages on-demand.

## 🙏 Acknowledgements

This project is made possible by the outstanding work of several open-source communities:

*   **The `xeus` Project**: The core architecture relies on **[xeus](https://github.com/jupyter-xeus/xeus)** for its robust implementation of the Jupyter protocol and **[xeus-lite](https://github.com/jupyter-xeus/xeus-lite)** for the ability to compile to WebAssembly.
*   **The OCaml Toolchain**: The in-browser OCaml experience is powered by **[js_of_ocaml](https://github.com/ocsigen/js_of_ocaml)**, which compiles OCaml bytecode to efficient JavaScript, and the **[Merlin](https://github.com/ocaml/merlin)** project for code analysis.

## 📜 License

This project is distributed under the terms of the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.