open Js_of_ocaml_toplevel


let is_setup = ref false

let setup () =
  if not !is_setup then (
    JsooTop.initialize ();
    Toploop.toplevel_env := Compmisc.initial_env ();
    Sys.interactive := false;
    is_setup := true
  )

let eval code =
  if not !is_setup then failwith "Toplevel not initialized. Call Xtoplevel.setup first.";
  let outputs = ref [] in
  let add_output o = outputs := o :: !outputs in

  (* Redirect standard outputs using the correct API *)
  Js_of_ocaml.Sys_js.set_channel_flusher stdout (fun s -> add_output (Protocol.Stdout s));
  Js_of_ocaml.Sys_js.set_channel_flusher stderr (fun s -> add_output (Protocol.Stderr s));

  (* Redirect toplevel formatter *)
  let buffer = Buffer.create 1024 in
  let formatter = Format.formatter_of_buffer buffer in

  let get_formatter_output () =
    Format.pp_print_flush formatter ();
    let content = Buffer.contents buffer in
    Buffer.clear buffer;
    if content <> "" then add_output (Protocol.Value content)
  in

  let lexbuf = Lexing.from_string (code ^ ";;") in
  let rec loop () =
    match !Toploop.parse_toplevel_phrase lexbuf with
    | phrase ->
        if Toploop.execute_phrase true formatter phrase then
          get_formatter_output ();
        loop ()
    | exception End_of_file -> ()
  in

  (try loop () with exn ->
    (* When an exception occurs, capture the formatted error message
       and add it to the outputs list as a Stderr event. *)
    let err_buffer = Buffer.create 256 in
    let err_formatter = Format.formatter_of_buffer err_buffer in
    Errors.report_error err_formatter exn;
    Format.pp_print_flush err_formatter ();
    let content = Buffer.contents err_buffer in
    if content <> "" then add_output (Protocol.Stderr content));

  List.rev !outputs