open Js_of_ocaml_toplevel

let is_setup = ref false

let setup () =
  if not !is_setup
  then (
    JsooTop.initialize ();
    Toploop.toplevel_env := Compmisc.initial_env ();
    Sys.interactive := false;
    let init_code = "open Xlib;;" in
    let silent_formatter = Format.formatter_of_buffer (Buffer.create 16) in
    let success = JsooTop.use silent_formatter init_code in
    if not success
    then
      Js_of_ocaml.Console.console##warn
        (Js_of_ocaml.Js.string
           "Warning: Could not auto-open Xlib module in toplevel.");
    is_setup := true)
;;

(* Helper to recursively parse a string into a list of toplevel phrases. *)
let rec parse_all_phrases lexbuf =
  match !Toploop.parse_toplevel_phrase lexbuf with
  | phrase -> Ok phrase :: parse_all_phrases lexbuf
  | exception End_of_file -> []
  | exception err -> [ Error err ]
;;

let eval code =
  if not !is_setup
  then failwith "Toplevel not initialized. Call Xtoplevel.setup first.";

  (* --- Phase 1: Setup Output Collection --- *)
  let outputs = ref [] in
  let add_output o = outputs := o :: !outputs in

  Js_of_ocaml.Sys_js.set_channel_flusher stdout (fun s ->
    add_output (Protocol.Stdout s));
  Js_of_ocaml.Sys_js.set_channel_flusher stderr (fun s ->
    add_output (Protocol.Stderr s));

  (* Formatter for standard output *)
  let buffer = Buffer.create 1024 in
  let formatter = Format.formatter_of_buffer buffer in
  let get_formatter_output () =
    Format.pp_print_flush formatter ();
    let content = Buffer.contents buffer in
    Buffer.clear buffer;
    if content <> "" then add_output (Protocol.Value content)
  in

  (* --- NEW: Formatter for standard error --- *)
  let err_buffer = Buffer.create 1024 in
  let err_formatter = Format.formatter_of_buffer err_buffer in
  let get_err_formatter_output () =
    Format.pp_print_flush err_formatter ();
    let content = Buffer.contents err_buffer in
    Buffer.clear err_buffer;
    if content <> "" then add_output (Protocol.Stderr content)
  in

  let get_xlib_outputs () =
    let rich_outputs = Xlib.get_and_clear_outputs () in
    (* Add outputs in their original order. *)
    outputs := List.rev_append rich_outputs !outputs
  in
  ignore (Xlib.get_and_clear_outputs ());

  (* --- Phase 2: Parse Code into Phrases --- *)
  let lexbuf = Lexing.from_string (code ^ ";;") in
  let phrases = parse_all_phrases lexbuf in

  (* --- Phase 3: Execute Phrases Sequentially --- *)
  List.iter
    (function
      | Error err ->
        (* A syntax error was found during parsing. *)
        (* MODIFIED: Use the error formatter *)
        Errors.report_error err_formatter err;
        get_err_formatter_output ()
      | Ok phrase ->
        (* Split multi-definition structures for individual execution. *)
        let sub_phrases =
          match phrase with
          | Parsetree.Ptop_def s ->
            List.map (fun si -> Parsetree.Ptop_def [ si ]) s
          | Parsetree.Ptop_dir _ as p -> [ p ]
        in
        List.iter
          (fun sub_phrase ->
            try
              if Toploop.execute_phrase true formatter sub_phrase
              then (
                (* Phrase executed and produced a value; capture all outputs. *)
                get_xlib_outputs ();
                get_formatter_output ())
              else (* Phrase was silent; still check for rich display side-effects. *)
                get_xlib_outputs ()
            with
            | exn ->
              (* A runtime error occurred. *)
              (* MODIFIED: Use the error formatter *)
              Errors.report_error err_formatter exn;
              get_err_formatter_output ())
          sub_phrases)
    phrases;

  (* --- Phase 4: Finalize and Return --- *)
  List.rev !outputs
;;