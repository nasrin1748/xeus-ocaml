(**
 * @module Xtoplevel
 * @description Provides the core functionality for an OCaml toplevel environment.
 * This module handles the setup and evaluation of OCaml code, capturing all
 * standard and rich outputs for display.
 *)

(**
 * @name eval
 * @description Executes a string of OCaml code and captures all resulting outputs.
 *              This function implements a robust phrase-by-phrase evaluation
 *              strategy to correctly handle multi-statement inputs.
 * @param code The OCaml source code to execute.
 * @return [Protocol.output list] A list of all captured outputs, ordered
 *         chronologically.
 *)
val eval : string -> Protocol.output list

(**
 * @name setup
 * @description Initializes the OCaml toplevel environment. This function must be
 *              called once before any code evaluation. It configures the
 *              toplevel and automatically opens the `Xlib` module to make
 *              rich display functions globally available.
 * @return [unit]
 *)
val setup : unit -> unit