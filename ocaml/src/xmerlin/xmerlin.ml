(**
  @author Davy Cottet
 
  This module serves as the primary bridge between the `xeus-ocaml` kernel's
  protocol and the Merlin code analysis library. It is responsible for handling
  all synchronous code intelligence requests, such as code completion, type
  inspection, and error checking.
 
  It operates on a virtual filesystem (VFS) that must be populated with the
  necessary Merlin artifacts (`.cmi`, `.cmt`, `.cmti`) by the {!Xlibloader}
  module before this module is initialized. It uses Merlin "pipelines" to process
  queries against a given source code buffer.
 *)

open Merlin_utils
open Std
open Merlin_kernel
open Merlin_commands
open Xutil
module Location = Ocaml_parsing.Location

(** The designated path within the VFS where all Merlin artifacts are stored. *)
let stdlib_path = "/static/cmis"

(**
 * The main Merlin configuration object.
 * It is configured to look for the standard library in the {!stdlib_path}
 * within the virtual filesystem.
 *)
let config =
  let initial = Mconfig.initial in
  { initial with
    merlin = { initial.merlin with
      stdlib = Some stdlib_path }}

(**
  Initializes the Merlin configuration.
 
  This function should be called exactly once during kernel startup, immediately
  after the {!Xlibloader.setup} function has successfully completed. It finalizes
  the configuration Merlin will use to find standard library modules in the
  virtual filesystem.
 *)
let initialize () =
  log "[Xmerlin] Merlin configuration initialized.";
  (* The main work of loading files is now done by the library loader.
     This function is a placeholder in case any Merlin-specific, non-VFS
     setup is needed in the future. The config is already defined. *)
  ()

(**
  Creates a Merlin processing pipeline for a given source code buffer.
  @param source The {!Msource.t} containing the code to be analyzed.
  @return A new {!Mpipeline.t} instance.
 *)
let make_pipeline source =
  Mpipeline.make config source

(**
  A helper function to create a pipeline, run a single query against it,
  and return the result.
  @param source The source code buffer.
  @param query The Merlin query to execute.
  @return The result of the query.
 *)
let dispatch source query  =
  let pipeline = make_pipeline source in
  Mpipeline.with_pipeline pipeline @@ fun () -> (
    Query_commands.dispatch pipeline query
  )

(**
  Internal helper module for code completion logic.
  This code is adapted from Merlin's frontend tools to correctly identify
  the identifier prefix at the cursor's position.
 *)
module Completion = struct
  let rfindi =
    let rec loop s ~f i =
      if i < 0 then
        None
      else if f (String.unsafe_get s i) then
        Some i
      else
        loop s ~f (i - 1)
    in
    fun ?from s ~f ->
      let from =
        let len = String.length s in
        match from with
        | None -> len - 1
        | Some i ->
          if i > len - 1 then
            raise @@ Invalid_argument "rfindi: invalid from"
          else
            i
      in
      loop s ~f from

  let lsplit2 s ~on =
    match String.index_opt s on with
    | None -> None
    | Some i ->
      let open String in
      Some (sub s ~pos:0 ~len:i, sub s ~pos:(i + 1) ~len:(length s - i - 1))

  let prefix_of_position ?(short_path = false) source position =
    match Msource.text source with
    | "" -> ""
    | text ->
      let from =
        let (`Offset index) = Msource.get_offset source position in
        min (String.length text - 1) (index - 1)
      in
      let pos =
        let should_terminate = ref false in
        let has_seen_dot = ref false in
        let is_prefix_char c =
          if !should_terminate then
            false
          else
            match c with
            | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '\'' | '_'
            | '$' | '&' | '*' | '+' | '-' | '/' | '=' | '>'
            | '@' | '^' | '!' | '?' | '%' | '<' | ':' | '~' | '#' ->
              true
            | '`' ->
              if !has_seen_dot then
                false
              else (
                should_terminate := true;
                true
              ) | '.' ->
              has_seen_dot := true;
              not short_path
            | _ -> false
        in
        rfindi text ~from ~f:(fun c -> not (is_prefix_char c))
      in
      let pos =
        match pos with
        | None -> 0
        | Some pos -> pos + 1
      in
      let len = from - pos + 1 in
      let reconstructed_prefix = String.sub text ~pos ~len in
      if
        String.is_prefixed ~by:"~" reconstructed_prefix
        || String.is_prefixed ~by:"?" reconstructed_prefix
      then
        match lsplit2 reconstructed_prefix ~on:':' with
        | Some (_, s) -> s
        | None -> reconstructed_prefix
      else
        reconstructed_prefix
end

(**
  Processes a synchronous, Merlin-related action from the kernel protocol.
 
  This is the main entry point for handling code intelligence requests. It takes
  a protocol action, determines if it's a command intended for Merlin, and if so,
  executes the corresponding Merlin query (e.g., `Complete_prefix`, `Type_enclosing`).
 
  @param action The {!Protocol.action} to be processed.
  @return It returns [`Some json_result`] if the action was a Merlin command and was
          processed successfully. It returns [`None`] if the action is not a Merlin
          command (e.g., `Eval`), indicating that another part of the system
          should handle it.
 *)
let process_merlin_action (action : Protocol.action) : Yojson.Basic.t option =
  match action with
  (** Handle a code completion request. *)
  | Protocol.Complete_prefix { source; position } ->
    let source = Msource.make source in
    let position = Protocol.to_msource_position position in
    let prefix = Completion.prefix_of_position source position in
    let result =
      if prefix = "" then
        `Assoc [("from", `Int 0); ("to_", `Int 0); ("entries", `List []); ("context", `Null)]
      else
        let `Offset to_ = Msource.get_offset source position in
        let from =
          to_ - String.length (Completion.prefix_of_position ~short_path:true source position)
        in
        let query = Query_protocol.Complete_prefix (prefix, position, [], true, true) in
        let result : Query_protocol.completions = dispatch source query in
        let json_result = Query_json.json_of_response query result in
        begin match json_result with
        | `Assoc fields -> `Assoc (("from", `Int from) :: ("to_", `Int to_) :: fields)
        | _ -> assert false
        end
    in
    Some result

  (** Handle a type inspection request. *)
  | Type_enclosing { source; position } ->
    let source = Msource.make source in
    let position = Protocol.to_msource_position position in
    let query = Query_protocol.Type_enclosing (None, position, None) in
    let response = dispatch source query in
    Some (Query_json.json_of_response query response)

  (** Handle a request to get all syntax/type errors in the buffer. *)
  | All_errors { source } ->
    let source = Msource.make source in
    let query = Query_protocol.Errors { lexing = true; parsing = true; typing = true } in
    let errors = dispatch source query in
    Some (Query_json.json_of_response query errors)

  (** Handle a documentation look-up request. *)
  | Document { source; position } ->
    let source = Msource.make source in
    let position = Protocol.to_msource_position position in
    let query = Query_protocol.Document (None, position) in
    let response = dispatch source query in
    Some (Query_json.json_of_response query response)

  (** Handle a request to list files in the VFS (for debugging). *)
  | List_files  { path } ->
    let files =
      try Sys.readdir path |> Array.to_list
      with _ -> []
    in
    Some (`List (List.map ~f:(fun s -> `String s) files))

  (** If the action is not for Merlin (e.g., Eval), return None. *)
  | _ -> None