# Contributing to xeus-ocaml

First off, thank you for considering contributing to `xeus-ocaml`! This project is a community effort, and we welcome any form of contribution, from bug reports and documentation improvements to new features.

This document provides a detailed guide for developers who want to understand the project's internals and contribute to its development. If you have questions, please feel free to open an issue on our [GitHub issue tracker](https://github.com/davy39/xeus-ocaml/issues).

## 📖 API Documentation

For a detailed reference of the project's C++ and OCaml APIs, please see our hosted documentation, which is automatically generated from the source code comments.

[**View the full API Documentation**](https://davy39.github.io/xeus-ocaml/docs/)

## 🏗️ High-Level Architecture

`xeus-ocaml` is a hybrid C++/OCaml kernel designed to run entirely in the browser using WebAssembly (WASM). This architecture provides a fast, serverless Jupyter experience by executing all components—the Jupyter protocol handler and the OCaml language engine—within the same browser execution context.

1.  **C++ Kernel Core (`xocaml.wasm`)**: The kernel's foundation is a C++ application built with **`xeus-lite`**, a lightweight version of the `xeus` library specifically for WASM. This C++ layer is compiled to a WebAssembly module (`xocaml.wasm`). Its primary responsibility is to handle the Jupyter Messaging Protocol, acting as the bridge between the Jupyter frontend (like JupyterLab or Notebook) and the OCaml backend.

2.  **OCaml Backend (`xocaml.js`)**: All the OCaml logic—the toplevel (REPL), Merlin for code intelligence, and helper libraries—is compiled into a single JavaScript file (`xocaml.js`) using **`js_of_ocaml`**. This script exposes a clean JavaScript API that the C++ core can call into.

3.  **Direct Communication Bridge**: The C++ (WASM) and OCaml (JS) components communicate directly and efficiently within the browser's main thread:
    *   The C++ code uses Emscripten's **`emscripten::val` API** to make direct, type-safe calls to the JavaScript functions exported by the OCaml backend. This is the primary way C++ gives commands to OCaml.
    *   For asynchronous operations (like code execution), the C++ side passes C++ callback functions (bound via `EMSCRIPTEN_BINDINGS`) to the OCaml/JS side. The OCaml code, using its `Lwt` library for concurrency, performs the long-running task and invokes the C++ callback with the result when finished.

4.  **JupyterLab Mime Renderer Extension**: A small TypeScript-based extension, located in the `extension/` directory, enhances the frontend by adding support for custom MIME types, such as rendering Graphviz DOT strings into SVG images.

This in-process model avoids the complexity and latency of Web Workers, enabling near-instantaneous communication for features like code completion.

### C++ Component Breakdown

The C++ source code is organized into a clear, modular structure.

-   `include/xinterpreter.hpp`, `src/xinterpreter.cpp`: This is the core of the kernel. The `interpreter` class inherits from `xeus::xinterpreter` and implements the main handlers for Jupyter messages (`execute_request_impl`, `complete_request_impl`, etc.). It manages the lifecycle of asynchronous execution requests.
-   `include/xocaml_engine.hpp`, `src/xocaml_engine.cpp`: This is the crucial C++-to-JavaScript bridge. It abstracts away the Emscripten binding details, providing clean functions like `call_merlin_sync` and `call_toplevel_async` that the rest of the C++ code can use without directly touching `emscripten::val`.
-   `include/xcompletion.hpp`, `src/xcompletion.cpp`: Contains the logic specifically for handling `complete_request` messages. It constructs the appropriate JSON request for Merlin, calls the OCaml engine, and formats the response into a valid Jupyter `complete_reply`.
-   `include/xinspection.hpp`, `src/xinspection.cpp`: Similar to completion, this file handles `inspect_request` messages, calling Merlin for type and documentation information and formatting it for display in tooltips.
-   `src/main_emscripten_kernel.cpp`: The main entry point for the WebAssembly build. It uses `EMSCRIPTEN_BINDINGS` to export the `xeus_ocaml::interpreter` to JavaScript, making it accessible to the `xeus-lite` frontend loader.

## 🚀 Deep Dive into Features

### 1. Interactive Toplevel Execution

This is the kernel's core feature: running OCaml code.

-   **Logic Flow**:
    1.  A user runs a cell. The Jupyter frontend sends an `execute_request` message.
    2.  `xinterpreter.cpp`: The `execute_request_impl` method is called. It creates a unique ID for the request and stores the reply callback.
    3.  `xocaml_engine.cpp`: It calls `call_toplevel_async`, passing the code and a C++ callback function that is bound to the request ID.
    4.  `ocaml/src/xocaml/xocaml.ml`: The exported `processToplevelAction` JavaScript function receives the call. It invokes `Xtoplevel.eval`.
    5.  `ocaml/src/xtoplevel/xtoplevel.ml`: The `eval` function is the heart of the OCaml REPL. It uses `js_of_ocaml-toplevel` to parse and execute the code phrase by phrase. It captures all outputs (stdout, stderr, the final value, and any rich display data) into a structured list.
    6.  The result list is returned asynchronously via an `Lwt` promise. When it resolves, the JavaScript callback provided by C++ is invoked.
    7.  `src/xinterpreter.cpp`: The `handle_eval_callback` C++ function is triggered. It parses the JSON result, publishes the various outputs (stdout, results, display data) back to the frontend, and sends the final `execute_reply` to signal completion.

-   **Key Files**: `src/xinterpreter.cpp`, `ocaml/src/xtoplevel/xtoplevel.ml`, `ocaml/src/xocaml/xocaml.ml`.

### 2. Merlin Integration (Completion & Inspection)

This feature provides IDE-like assistance. To function, Merlin needs access to compiled interface (`.cmi`), implementation (`.cmt`), and interface-implementation (`.cmti`) files. We use a sophisticated hybrid approach to load these files:

-   **Logic Flow**:
    1.  A user presses `Tab` (completion) or `Shift+Tab` (inspection).
    2.  `xinterpreter.cpp`: The `complete_request_impl` or `inspect_request_impl` method is called, delegating to `xcompletion.cpp` or `xinspection.cpp`.
    3.  `xcompletion.cpp` / `xinspection.cpp`: The handler builds a JSON request that matches the OCaml `Protocol.t` definition.
    4.  `xocaml_engine.cpp`: It calls `call_merlin_sync`. This is a **synchronous** call that blocks until the JavaScript function returns.
    5.  `ocaml/src/xocaml/xocaml.ml`: The `processMerlinAction` function receives the request and calls `Xmerlin.process_merlin_action`.
    6.  `ocaml/src/xmerlin/xmerlin.ml`: This module uses the `merlin-lib` library to process the request against the current source code buffer.
    7.  The result is converted to JSON and returned synchronously all the way back to C++, where it's formatted into a Jupyter reply.

-   **Standard Library Loading Strategy**:
    -   **Static (Core Requirement)**: The single most important file, `stdlib.cmi`, is embedded directly into the main `xocaml.js` bundle at compile time using `ppx_blob`. This is critical because the OCaml toplevel requires it to initialize its environment (`Compmisc.initial_env()`). Loading it statically guarantees the kernel can always start correctly.
    -   **Dynamic (On Startup)**: The rest of the standard library's artifacts (all other `.cmi`, `.cmt`, and `.cmti` files) are fetched asynchronously from the server when the kernel first starts. This keeps the initial bundle size small while ensuring full standard library support for completion and documentation is available shortly after launch.

-   **Key Files**: `src/xcompletion.cpp`, `src/xinspection.cpp`, `ocaml/src/xmerlin/xmerlin.ml`, `ocaml/src/xlibloader/xlibloader.ml`, `ocaml/src/xlibloader/static/`, `ocaml/src/xlibloader/dynamic/`.

### 3. Virtual Filesystem

-   **Logic Flow**:
    1.  During kernel initialization, the C++ `interpreter::configure_impl` triggers the OCaml setup. After the OCaml setup completes, it calls `ocaml_engine::mount_fs`.
    2.  `ocaml/src/xfs/xfs.ml`: The `mount_drive` function is called. It uses `js_of_ocaml`'s FFI to access Emscripten's global `Module.FS` object. It creates and registers a new device that maps OCaml `Sys` calls (like `open`, `read`, `readdir`) to corresponding `FS` calls (`FS.open`, `FS.read`, `FS.readdir`).
    3.  The kernel's current working directory is changed to the root of this new device (`/drive/`).
    4.  When a user runs OCaml code like `open_in "file.txt"`, the `js_of_ocaml` runtime intercepts the `Sys` call and routes it through the device implementation in `xfs.ml`, which in turn manipulates the in-memory Emscripten filesystem.

-   **Key Files**: `ocaml/src/xfs/xfs.ml`, `src/xinterpreter.cpp`, `src/xocaml_engine.cpp`.

### 4. Dynamic Library Loading (`#require`)

The kernel supports loading third-party libraries through an automated build-time and run-time process.

-   **Build-Time (`xbundle` tool)**:
    1.  A developer adds a library name (e.g., `ocamlgraph`) to `ocaml/src/xbundle/libs.txt`.
    2.  During the `dune build` process, our custom `xbundle` tool is executed.
    3.  For each library in `libs.txt`, `xbundle` uses `ocamlfind` to resolve its entire dependency tree.
    4.  It then compiles all required OCaml modules into a single JavaScript bundle (`ocamlgraph.js`).
    5.  Crucially, it also finds and collects all associated Merlin artifacts (`.cmi`, `.cmt`, `.cmti`) for the entire dependency tree.
    6.  Finally, it generates a metadata module (`external_libs.ml`) that maps the library name to its JS bundle and list of artifact files.

-   **Run-Time (in the Notebook)**:
    1.  A user executes a cell with `#require "ocamlgraph";;`.
    2.  `ocaml/src/xtoplevel/xtoplevel.ml`: The `eval` function's parser detects the `#require` directive and calls `Xlibloader.load_on_demand`.
    3.  `ocaml/src/xlibloader/xlibloader.ml`: This function looks up "ocamlgraph" in the `External_libs` metadata generated at build time.
    4.  It asynchronously fetches `ocamlgraph.js` and executes it using `Js.Unsafe.eval_string`. This loads the library's code into the `js_of_ocaml` runtime.
    5.  It then asynchronously fetches all the artifact files associated with `ocamlgraph` and writes them to the virtual filesystem (e.g., `/static/cmis/graph.cmi`, `/static/cmis/dot.cmti`, etc.).
    6.  Finally, it calls `Topdirs.dir_directory` to tell the toplevel to rescan its paths, making the new modules available for use and visible to Merlin.

-   **Key Files**: `ocaml/src/xtoplevel/xtoplevel.ml`, `ocaml/src/xlibloader/xlibloader.ml`, `ocaml/src/xbundle/xbundle.ml` (the CLI tool), `ocaml/src/xbundle/libs.txt` (the library list).

### 5. Rich Display (`Xlib`)

-   **Logic Flow**:
    1.  `ocaml/src/xtoplevel/xtoplevel.ml`: During `setup`, the code `open Xlib;;` is executed, making all its functions available globally.
    2.  `ocaml/src/xlib/xlib.ml`: This module defines functions like `output_html`. Each function creates a `Protocol.DisplayData` value and adds it to a global, mutable list named `extra_outputs`.
    3.  `ocaml/src/xtoplevel/xtoplevel.ml`: After each phrase is executed, the `eval` function calls `Xlib.get_and_clear_outputs()` to drain this list.
    4.  The retrieved display data objects are included in the list of outputs sent back to the C++ side, which then publishes them as `display_data` messages.

-   **Key Files**: `ocaml/src/xlib/xlib.ml`, `ocaml/src/xtoplevel/xtoplevel.ml`.

### 6. Graphviz/DOT Visualization (Frontend Extension)

This feature enables the rendering of Graphviz DOT language strings into SVG images, powered by a custom JupyterLab MIME renderer extension.

-   **Logic Flow**:
    1.  A user calls the `output_dot` function from the `Xlib` module with a string containing DOT syntax.
    2.  `ocaml/src/xlib/xlib.ml`: The `output_dot` function creates a `DisplayData` object with the custom MIME type `application/vnd.graphviz.dot` and adds it to the output queue.
    3.  The C++ kernel publishes this `display_data` message to the frontend.
    4.  **Frontend Extension**: The JupyterLab frontend finds the custom MIME renderer extension located in the `extension/` directory, which has registered itself to handle this specific MIME type.
    5.  `extension/src/index.ts`: The TypeScript code for the extension receives the DOT string. It calls the **`@viz-js/viz`** library, which is a WebAssembly port of the Graphviz layout engine.
    6.  The `viz.js` library parses the DOT string and generates a complete SVG element.
    7.  The extension then appends this SVG element directly into the cell's output area, displaying the rendered graph.

-   **Key Files**: `ocaml/src/xlib/xlib.ml`, `extension/src/index.ts`, `extension/package.json`.

## 🛠️ Local Development & Build Process

This project uses **pixi** to manage all dependencies and build tasks, providing a consistent environment for both OCaml and C++/WASM development.

### Prerequisites

-   Install `pixi` by following the official [installation guide](https://pixi.sh/latest/installation/).
-   An internet connection is required for the initial setup to download dependencies.

### Build Steps

The entire build process is orchestrated by `rattler-build` via the `recipe/recipe.yaml` file. The `pixi run build-kernel` command is the main entry point.

The build happens in two main phases within the recipe:

1.  **Phase 1: Build OCaml to JavaScript**
    -   An `opam` switch is initialized, and all OCaml dependencies from `dune-project` are installed.
    -   `dune build` is executed. This compiles all OCaml source code in `ocaml/src/` into various artifacts, most importantly the final JavaScript bundle: `_build/default/src/xocaml/xocaml.bc.js`.
    -   This phase also builds the `xbundle` utility and uses it to read `ocaml/src/xbundle/libs.txt`, automatically packaging the specified third-party libraries (e.g., `ocamlgraph`) and their artifacts into JavaScript bundles.
    -   The build artifacts are cached in a `dune_cache` directory to speed up subsequent builds.

2.  **Phase 2: Build C++ Kernel to WebAssembly**
    -   `cmake` is configured for an `emscripten-wasm32` target.
    -   The C++ source code in `src/` is compiled into object files.
    -   Finally, the C++ objects are linked together. Critically, the `xocaml.bc.js` file from Phase 1 is included in this linking step via the `--pre-js` flag. This bundles the OCaml backend directly with the WASM module's JavaScript loader.
    -   The final outputs (`xocaml.wasm`, `xocaml.js`, and all static assets) are packaged into a `.conda` file in the `output/` directory.



To build and run a local JupyterLite instance for testing:

1.  **Build the Frontend Extension**: `pixi run -e extension build-extension`
2.  **Build the Kernel Package**: `pixi run build-kernel`
3.  **Install the Kernel for JupyterLite**: `pixi run install-kernel`
4.  **Serve JupyterLite**: `pixi run serve-jupyterlite`

You can now access the local JupyterLite instance in your browser, typically at `http://localhost:8000`.

## 🧪 Testing

The project includes a Jest test suite for the JavaScript API exported by the OCaml code. These tests verify the core functionality of both the toplevel and Merlin in isolation.

-   **Location**: `ocaml/tests/`
-   **Setup**: `ocaml/tests/jest.setup.js` is a crucial file. It loads the compiled `xocaml.bc.js`, exposes its API to the global scope for tests to use, and mocks browser APIs like `XMLHttpRequest` to allow fetching of dynamic Merlin files from the local disk during tests.
-   **Running Tests**:
    1.  First, ensure the OCaml backend is built: `pixi run -e ocaml build`.
    2.  Then, run the Jest suite: `pixi run -e test test`.

## 📦 Submitting Changes

We follow the standard GitHub flow for contributions:

1.  **Fork** the repository.
2.  Create a new **branch** for your feature or bug fix.
3.  Make your changes and **commit** them with clear, descriptive messages.
4.  Push your branch to your fork.
5.  Open a **Pull Request** against the `main` branch of the `davy39/xeus-ocaml` repository.

We will review your PR as soon as possible. Thank you for your contribution