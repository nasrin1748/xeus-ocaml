open Merlin_utils
open Std
open Merlin_kernel
open Merlin_commands
open Lwt.Syntax
module Location = Ocaml_parsing.Location

let stdlib_path = "/static/cmis2"

let config =
  let initial = Mconfig.initial in
  { initial with
    merlin = { initial.merlin with
      stdlib = Some stdlib_path }}

let async_get url : string option Lwt.t =
  let open Js_of_ocaml in
  try%lwt
    let promise, resolver = Lwt.task () in
    let req = XmlHttpRequest.create () in
    req##.responseType := Js.string "arraybuffer";
    req##_open (Js.string "GET") (Js.string url) Js._true;
    req##.onload := Dom.handler (fun _ ->
      if req##.status = 200 then (
        Js.Opt.case (File.CoerceTo.arrayBuffer req##.response)
          (fun () ->
            Lwt.wakeup_later resolver None)
          (fun response_buf ->
            let str = Typed_array.String.of_arrayBuffer response_buf in
            Lwt.wakeup_later resolver (Some str))
      ) else (
        Lwt.wakeup_later resolver None
      );
      Js._true);
    req##.onerror := Dom.handler (fun _ ->
        Lwt.wakeup_later resolver None;
        Js._true);
    req##send Js.null;
    promise
  with exn ->
    Console.console##log (Js.string ("Exception in async_get: " ^ Printexc.to_string exn));
    Lwt.return_none

let filename_of_module_base mod_name =
  if mod_name = "Stdlib" then "stdlib"
  else "stdlib__" ^ mod_name


let setup ~url =
  List.iter Static_files.files ~f:(fun (name, content) ->
    let path = Filename.concat stdlib_path name in
    Js_of_ocaml.Sys_js.create_file ~name:path ~content);
  
  let fetch_module mod_name =
    let filename_base = filename_of_module_base mod_name in
    let fetch_one ext =
      let filename = Printf.sprintf "%s.%s" filename_base ext in
      let fetch_url = Filename.concat url filename in
      let* content_opt = async_get fetch_url in
      Option.iter content_opt ~f:(fun content ->
        let name = Filename.(concat stdlib_path filename) in
        Js_of_ocaml.Sys_js.create_file ~name ~content);
        (* reset_dirs (); *)
      Lwt.return_unit
    in
    Lwt.join (List.map ~f:fetch_one ["cmi"; "cmt"; "cmti"])
  in
  let* () = Lwt.join (List.map ~f:fetch_module Dynamic_modules.modules) in
  Lwt.return_unit

let make_pipeline source =
  Mpipeline.make config source

let dispatch source query  =
  let pipeline = make_pipeline source in
  Mpipeline.with_pipeline pipeline @@ fun () -> (
    Query_commands.dispatch pipeline query
  )

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
let process_merlin_action (action : Protocol.action) : Yojson.Basic.t option =
  match action with
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
  | Type_enclosing { source; position } ->
    let source = Msource.make source in
    let position = Protocol.to_msource_position position in
    let query = Query_protocol.Type_enclosing (None, position, None) in
    let response = dispatch source query in
    Some (Query_json.json_of_response query response)
  | All_errors { source } ->
    let source = Msource.make source in
    let query = Query_protocol.Errors { lexing = true; parsing = true; typing = true } in
    let errors = dispatch source query in
    Some (Query_json.json_of_response query errors)
  | Document { source; position } ->
    let source = Msource.make source in
    let position = Protocol.to_msource_position position in
    let query = Query_protocol.Document (None, position) in
    let response = dispatch source query in
    Some (Query_json.json_of_response query response)
  | List_files  { path } ->
    let files =
      try Sys.readdir path |> Array.to_list
      with _ -> []
    in
    Some (`List (List.map ~f:(fun s -> `String s) files))
  | _ -> None