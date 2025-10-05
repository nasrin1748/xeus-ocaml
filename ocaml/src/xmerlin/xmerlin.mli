(* File: /src/xmerlin/xmerlin.mli *)

(** Process Merlin-specific actions. *)

(** [process_merlin_action action] handles a protocol action if it is a Merlin
    command. It returns [Some json_result] on success, and [None] if the
    action is not a Merlin command (e.g., it's an Eval command). *)
val process_merlin_action : Protocol.action -> Yojson.Basic.t option
val setup : url:string -> unit Lwt.t