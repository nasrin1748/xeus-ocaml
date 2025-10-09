open Merlin_kernel
module Location = Ocaml_parsing.Location

type source = string [@@deriving yojson]

type position =
  [ `Offset of int ]
[@@deriving yojson]

let to_msource_position : position -> Msource.position = function
  | `Offset i -> `Offset i

type dynamic_setup_config = {
  dsc_url: string;
} [@@deriving yojson]

type action =
  | Complete_prefix of { source : source; position : position }
  | Type_enclosing of { source : source; position : position }
  | Document of { source : source; position : position }
  | Eval of { source : source }
  | All_errors of { source : source }
  | Setup of dynamic_setup_config
  | List_files of { path: string }
  [@@deriving yojson { strict = false }]

type error = {
  kind : Location.report_kind;
  loc: Location.t;
  main : string;
  sub : string list;
  source : Location.error_source;
}

type output =
  | Stdout of string
  | Stderr of string
  | Value of string
  | DisplayData of Yojson.Safe.t

[@@deriving yojson]

type completions = {
  from: int;
  to_: int;
  entries : Query_protocol.Compl.entry list
}

type is_tail_position =
  [`No | `Tail_position | `Tail_call]

let report_source_to_string = function
  | Location.Lexer   -> "lexer"
  | Location.Parser  -> "parser"
  | Location.Typer   -> "typer"
  | Location.Warning -> "warning"
  | Location.Unknown -> "unknown"
  | Location.Env     -> "env"
  | Location.Config  -> "config"