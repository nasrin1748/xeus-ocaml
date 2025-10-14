(**
    @author Davy Cottet
   
    This module provides general-purpose, shared utility functions used throughout
    the OCaml side of the kernel.
   
    Its most prominent feature is a conditional logging utility that is automatically
    enabled or disabled based on the Dune build profile.
 *)

(**
    A simple logging utility that prints messages to the browser's JavaScript console.
   
    **This function is conditional.** It is only active when the project is
    compiled with the `dev` profile (e.g., `dune build`), which defines the
    `JS_LOG` preprocessor flag.
   
    When compiling with the `release` profile (`dune build --profile release`),
    all calls to this function are completely removed from the code, resulting
    in zero performance overhead in production builds.
   
    @param s The string message to log to the console.
 *)
#ifndef JS_LOG
  let log (_str : string) : unit = ()
#else
let log (str : string) : unit =
  Js_of_ocaml.Console.console##log (Js_of_ocaml.Js.string str)
#endif
;;