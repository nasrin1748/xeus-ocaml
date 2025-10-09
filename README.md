# ![xeus-logo](https://raw.githubusercontent.com/jupyter-xeus/xeus/refs/heads/main/docs/source/xeus.svg) OCAML ![xeus-ocaml logo](https://raw.githubusercontent.com/davy39/xeus-ocaml/refs/heads/main/share/jupyter/kernels/xocaml/logo-svg.svg)

[![CI and Auto-Tagging](https://github.com/davy39/xeus-ocaml/actions/workflows/ci.yml/badge.svg)](https://github.com/davy39/xeus-ocaml/actions/workflows/ci.yml)
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
*   **Dynamic Library Loading**: Load pre-compiled OCaml libraries dynamically using the `#require` directive.
*   **Rich Display Support**: Render HTML, Markdown, SVG, JSON, and even complex plots like Vega-Lite directly from your OCaml code.

## 📦 Dynamic Libraries with `#require`

You can dynamically load additional OCaml libraries that have been pre-compiled to JavaScript. Use the standard toplevel directive `#require` followed by the library name.


```ocaml
(* Load the ocamlgraph library *)
#require "ocamlgraph";;
```

```text
Library 'ocamlgraph' loaded. New modules available: Graph, Graph, Graph__Bitv, Graph__Blocks, Graph__Builder, Graph__ChaoticIteration, Graph__Classic, Graph__Clique, Graph__Cliquetree, Graph__Coloring, Graph__Components, Graph__Contraction, Graph__Cycles, Graph__DGraphModel, Graph__DGraphRandModel, Graph__DGraphSubTree, Graph__DGraphTreeLayout, Graph__DGraphTreeModel, Graph__Delaunay, Graph__Deque, Graph__Dominator, Graph__Dot, Graph__Dot_lexer, Graph__Dot_parser, Graph__Eulerian, Graph__Fixpoint, Graph__Flow, Graph__Gmap, Graph__Gml, Graph__Graphml, Graph__Graphviz, Graph__Heap, Graph__Imperative, Graph__Kruskal, Graph__Leaderlist, Graph__Mcs_m, Graph__Md, Graph__Merge, Graph__Mincut, Graph__Minsep, Graph__Nonnegative, Graph__Oper, Graph__Pack, Graph__Path, Graph__Persistent, Graph__PersistentQueue, Graph__Prim, Graph__Rand, Graph__Strat, Graph__Topological, Graph__Traverse, Graph__Unionfind, Graph__Util, Graph__WeakTopological, Graph__XDot, Graph__XDotDraw
```

```ocaml
(* Now you can use modules from the library *)
open Graph
```

This feature relies on the library being available as a `.js` file at a URL accessible to the kernel.

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

## 🛠️ Contributing and Development

We welcome contributions! If you're interested in the project's architecture, setting up a local development environment, or contributing code, please see our **[CONTRIBUTING.md](CONTRIBUTING.md)** guide for detailed information.

## 🗺️ Roadmap

### Implemented
-   [x] Interactive code execution via the `js_of_ocaml` toplevel.
-   [x] Code completion powered by an in-browser Merlin instance.
-   [x] Code inspection for tooltips (Shift+Tab) and the inspector panel.
-   [x] **Rich Outputs**: Display HTML, Markdown, SVG, JSON, and Vega-Lite plots directly from OCaml code using the auto-opened `Xlib` module.
-   [x] **Library Management**: Dynamically fetch and load pre-compiled OCaml libraries from within a notebook session via the `#require "my_lib";;` directive.

### Future Work
-   [ ] **Virtual Filesystem**: Expose APIs to read and write to the Emscripten virtual filesystem from OCaml, enabling file manipulation and data loading.
-   [ ] **User Input**: Add support for Jupyter's `input_request` messages to allow interactive OCaml functions like `read_line()`.
-   [ ] **Custom Widgets**: Develop a communication bridge (`Comm`) to enable OCaml code to interact with Jupyter Widgets for creating rich, interactive outputs.

## 🙏 Acknowledgements

This project is made possible by the outstanding work of several open-source communities:

*   **The `xeus` Project**: The core architecture relies on **[xeus](https://github.com/jupyter-xeus/xeus)** for its robust implementation of the Jupyter protocol and **[xeus-lite](https://github.com/jupyter-xeus/xeus-lite)** for the ability to compile to WebAssembly.
*   **The OCaml Toolchain**: The in-browser OCaml experience is powered by **[js_of_ocaml](https://github.com/ocsigen/js_of_ocaml)**, which compiles OCaml bytecode to efficient JavaScript, and the **[Merlin](https://github.com/ocaml/merlin)** project for code analysis.

## 📜 License

This project is distributed under the terms of the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.