
(** Toplevel evaluation for OCaml code. *)

(** [eval code] executes the given OCaml code string in a persistent
    toplevel environment and returns a list of outputs (stdout, stderr,
    and evaluation results). *)
val eval : string -> Protocol.output list

(** [setup ()] initializes the toplevel environment. Must be called once before [eval]. *)
val setup : unit -> unit