# Contributing to xeus-ocaml

First off, thank you for considering contributing to `xeus-ocaml`! This project is a community effort, and we welcome any form of contribution, from bug reports and documentation improvements to new features.

This document provides a detailed guide for developers who want to understand the project's internals and contribute to its development. If you have questions, please feel free to open an issue on our [GitHub issue tracker](https://github.com/davy39/xeus-ocaml/issues).

## 🏗️ High-Level Architecture

`xeus-ocaml` is a hybrid C++/OCaml kernel designed to run entirely in the browser using WebAssembly (WASM). This architecture provides a fast, serverless Jupyter experience by executing all components—the Jupyter protocol handler and the OCaml language engine—within the same browser execution context.

1.  **C++ Kernel Core (`xocaml.wasm`)**: The kernel's foundation is a C++ application built with **`xeus-lite`**, a lightweight version of the `xeus` library specifically for WASM. This C++ layer is compiled to a WebAssembly module (`xocaml.wasm`). Its primary responsibility is to handle the Jupyter Messaging Protocol, acting as the bridge between the Jupyter frontend (like JupyterLab or Notebook) and the OCaml backend.

2.  **OCaml Backend (`xocaml.js`)**: All the OCaml logic—the toplevel (REPL), Merlin for code intelligence, and helper libraries—is compiled into a single JavaScript file (`xocaml.js`) using **`js_of_ocaml`**. This script exposes a clean JavaScript API that the C++ core can call into.

3.  **Direct Communication Bridge**: The C++ (WASM) and OCaml (JS) components communicate directly and efficiently within the browser's main thread:
    *   The C++ code uses Emscripten's **`emscripten::val` API** to make direct, type-safe calls to the JavaScript functions exported by the OCaml backend. This is the primary way C++ gives commands to OCaml.
    *   For asynchronous operations (like code execution), the C++ side passes C++ callback functions (bound via `EMSCRIPTEN_BINDINGS`) to the OCaml/JS side. The OCaml code, using its `Lwt` library for concurrency, performs the long-running task and invokes the C++ callback with the result when finished.

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

This feature provides IDE-like assistance.

-   **Logic Flow**:
    1.  A user presses `Tab` (completion) or `Shift+Tab` (inspection).
    2.  `xinterpreter.cpp`: The `complete_request_impl` or `inspect_request_impl` method is called. It delegates to the logic in `xcompletion.cpp` or `xinspection.cpp`.
    3.  `xcompletion.cpp` / `xinspection.cpp`: The handler function builds a JSON request that matches the OCaml `Protocol.t` definition.
    4.  `xocaml_engine.cpp`: It calls `call_merlin_sync`. This is a **synchronous** call that blocks until the JavaScript function returns.
    5.  `ocaml/src/xocaml/xocaml.ml`: The `processMerlinAction` function receives the request. It calls `Xmerlin.process_merlin_action`.
    6.  `ocaml/src/xmerlin/xmerlin.ml`: This module uses the `merlin-lib` library to process the request (e.g., `Query_protocol.Complete_prefix`) against the current source code buffer.
    7.  The result is converted to JSON and returned synchronously all the way back to C++, where it's formatted into a Jupyter reply and sent to the frontend.

-   **Subtleties**: To provide completions for the standard library, Merlin needs access to its compiled interface (`.cmi`) files. We use a hybrid approach:
    -   **Static (`ocaml/src/xmerlin/static`)**: A core set of stdlib modules are embedded directly into the `xocaml.js` bundle at compile time using `ppx_blob`. This ensures basic functionality is always available offline.
    -   **Dynamic (`ocaml/src/xmerlin/dynamic`)**: Other modules are fetched from the server when the kernel first initializes to keep the initial bundle size reasonable.

-   **Key Files**: `src/xcompletion.cpp`, `src/xinspection.cpp`, `ocaml/src/xmerlin/xmerlin.ml`, `ocaml/src/xmerlin/static/`, `ocaml/src/xmerlin/dynamic/`.

### 3. Virtual Filesystem

-   **Logic Flow**:
    1.  During kernel initialization, the C++ `interpreter::configure_impl` triggers the OCaml setup. After the OCaml setup completes, it calls `ocaml_engine::mount_fs`.
    2.  `ocaml/src/xfs/xfs.ml`: The `mount_drive` function is called. It uses `js_of_ocaml`'s FFI to access Emscripten's global `Module.FS` object. It creates and registers a new device that maps OCaml `Sys` calls (like `open`, `read`, `readdir`) to corresponding `FS` calls (`FS.open`, `FS.read`, `FS.readdir`).
    3.  The kernel's current working directory is changed to the root of this new device (`/drive/`).
    4.  When a user runs OCaml code like `open_in "file.txt"`, the `js_of_ocaml` runtime intercepts the `Sys` call and routes it through the device implementation in `xfs.ml`, which in turn manipulates the in-memory Emscripten filesystem.

-   **Key Files**: `ocaml/src/xfs/xfs.ml`, `src/xinterpreter.cpp`, `src/xocaml_engine.cpp`.

### 4. Dynamic Library Loading (`#require`)

-   **Logic Flow**:
    1.  `ocaml/src/xtoplevel/xtoplevel.ml`: The `eval` function's parser specifically looks for the `Ptop_dir` AST node corresponding to `#require "lib_name"`.
    2.  If found, it calls `Library_loader.load`.
    3.  `ocaml/src/xtoplevel/library_loader.ml`: This module fetches the corresponding `lib_name.js` file from a pre-configured URL.
    4.  The fetched JavaScript text is executed directly using `Js.Unsafe.eval_string`.
    5.  This JS bundle, created by our `xbundle` tool, contains the compiled OCaml library code and its `.cmi` files. When executed, it registers its modules with the `jsoo_runtime` and writes its `.cmi` files to the virtual filesystem.
    6.  Finally, `Library_loader` calls `Topdirs.dir_directory` to tell the toplevel to rescan its paths, making it aware of the new modules.

-   **Key Files**: `ocaml/src/xtoplevel/xtoplevel.ml`, `ocaml/src/xtoplevel/library_loader.ml`, `ocaml/src/xbundle/xbundle.ml` (the CLI tool for creating the bundles).

### 5. Rich Display (`Xlib`)

-   **Logic Flow**:
    1.  `ocaml/src/xtoplevel/xtoplevel.ml`: During `setup`, the code `open Xlib;;` is executed, making all its functions available globally.
    2.  `ocaml/src/xlib/xlib.ml`: This module defines functions like `output_html`. Each function creates a `Protocol.DisplayData` value and adds it to a global, mutable list named `extra_outputs`.
    3.  `ocaml/src/xtoplevel/xtoplevel.ml`: After each phrase is executed, the `eval` function calls `Xlib.get_and_clear_outputs()` to drain this list.
    4.  The retrieved display data objects are included in the list of outputs sent back to the C++ side, which then publishes them as `display_data` messages.

-   **Key Files**: `ocaml/src/xlib/xlib.ml`, `ocaml/src/xtoplevel/xtoplevel.ml`.

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
    -   This phase also builds the `xbundle` utility and uses it to package libraries like `ocamlgraph`.
    -   The build artifacts are cached in a `dune_cache` directory to speed up subsequent builds.

2.  **Phase 2: Build C++ Kernel to WebAssembly**
    -   `cmake` is configured for an `emscripten-wasm32` target.
    -   The C++ source code in `src/` is compiled into object files.
    -   Finally, the C++ objects are linked together. Critically, the `xocaml.bc.js` file from Phase 1 is included in this linking step via the `--pre-js` flag. This bundles the OCaml backend directly with the WASM module's JavaScript loader.
    -   The final outputs (`xocaml.wasm`, `xocaml.js`, and all static assets) are packaged into a `.conda` file in the `output/` directory.

To build and run a local JupyterLite instance for testing:

1.  **Set up the OCaml Environment**: `pixi run -e ocaml setup`
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