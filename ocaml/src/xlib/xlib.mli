(**
 * @module Xlib
 * @description A library of helper functions automatically opened in the
 *              toplevel for producing rich output and interacting with the
 *              Jupyter environment.
 *)


(**
 * Internal function for the toplevel to retrieve and clear outputs.
 * This is not intended for direct use by end-users.
 *)
val get_and_clear_outputs : unit -> Protocol.output list

(**
 * Renders a full MIME bundle as a cell output. This is the most flexible
 * function for creating rich output.
 * The data should be a Yojson.Safe.t object, e.g.,
 * `Assoc [("text/plain", `String "plain"); ("text/html", `String "<b>html</b>")]
 *)
val output_display_data : Yojson.Safe.t -> unit

(** Renders a raw HTML string as a cell output. *)
val output_html : string -> unit

(** Renders a raw Markdown string as a cell output. *)
val output_markdown : string -> unit

(** Renders a raw LaTeX string as a cell output (for equations). *)
val output_latex : string -> unit

(** Renders a raw SVG image string as a cell output. *)
val output_svg : string -> unit

(** Renders a JSON string as a collapsible tree view in the output. *)
val output_json : string -> unit

(** Renders a PNG image from a Base64-encoded string. *)
val output_png_base64 : string -> unit

(** Renders a JPEG image from a Base64-encoded string. *)
val output_jpeg_base64 : string -> unit

(** Renders a GIF image from a Base64-encoded string. *)
val output_gif_base64 : string -> unit

(** Renders an inline PDF document from a Base64-encoded string. *)
val output_pdf_base64 : string -> unit

(** Renders an interactive Vega-Lite plot from a JSON spec string. *)
val output_vegalite : string -> unit

(** Renders an interactive Vega plot from a JSON spec string. *)
val output_vega : string -> unit
