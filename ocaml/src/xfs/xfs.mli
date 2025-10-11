(**
 * @module Xfs
 * @description Provides a comprehensive OCaml interface to the Emscripten Filesystem (FS). based on https://github.com/ocsigen/js_of_ocaml/blob/master/runtime/js/fs.js and
https://github.com/ocsigen/js_of_ocaml/blob/master/runtime/js/fs_fake.js *)

(**
 * Initializes the connection to the Emscripten FS and mounts it as a device
 * at `/drive/` in the js_of_ocaml VFS. This is the single setup function
 * required for all filesystem functionality.
 *)
val mount_drive : unit -> unit