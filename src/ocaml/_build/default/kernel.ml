(* kernel.ml *)
open Js_of_ocaml
open Js_of_ocaml_toplevel

let () = Js_of_ocaml.Console.console##log (Js.string "OCAML SCRIPT IS RUNNING - VERSION 2")


(* An object to dynamically set std streams callbacks *)
let io = object%js
  val stdout = (Js.Unsafe.pure_js_expr "console")##.log
  val stderr = (Js.Unsafe.pure_js_expr "console")##.error
end

(* Buffer to capture the output of the toplevel *)
let buffer = Buffer.create 100
let formatter = Format.formatter_of_buffer buffer

(* The main execution function that will be called from C++/JavaScript *)
let exec code =
  Buffer.clear buffer;
  let code_string = Js.to_string code in
  JsooTop.execute true formatter (code_string ^ ";;");
  Js.string (Buffer.contents buffer)

(* Initialize the toplevel and export the 'exec' function *)
let init () =
  JsooTop.initialize ();
  Sys.interactive := false;
  Sys_js.set_channel_flusher stdout (fun str -> Js.Unsafe.meth_call io "stdout" [|Js.Unsafe.inject (Js.string str)|]);
  Sys_js.set_channel_flusher stderr (fun str -> Js.Unsafe.meth_call io "stderr" [|Js.Unsafe.inject (Js.string str)|]);
  Sys.interactive := true

(* Export the kernel object to JavaScript *)
let () =
  try
    Js.export "ocaml_kernel"
      (object%js
        val init = init
        val exec = exec
        val io = io
      end)
  with exn ->
    (* If anything goes wrong during setup, log the exception to the console. *)
    let msg = Printexc.to_string exn in
    Js_of_ocaml.Console.console##error (Js.string ("OCaml kernel failed to initialize: " ^ msg))