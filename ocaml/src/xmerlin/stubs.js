//Provides: caml_ml_merlin_fs_exact_case
function caml_ml_merlin_fs_exact_case(path) {
  // In a browser/JS environment, we assume the filesystem is case-sensitive
  // and we don't have tools to check for exact casing.
  // The non-Apple implementation of this function is identity.
  return path;
}

//Provides: caml_ml_merlin_fs_exact_case_basename
function caml_ml_merlin_fs_exact_case_basename(path) {
  // In a browser/JS environment, we can't check for exact file casing.
  // We'll behave like the non-Windows implementation and return None (0 in OCaml).
  return 0;
}

//Provides: ml_merlin_fs_exact_case
function ml_merlin_fs_exact_case(path) {
  // In a browser/JS environment, we assume the filesystem is case-sensitive
  // and we don't have tools to check for exact casing.
  // The non-Apple implementation of this function is identity.
  return path;
}

//Provides: ml_merlin_fs_exact_case_basename
function ml_merlin_fs_exact_case_basename(path) {
  // In a browser/JS environment, we can't check for exact file casing.
  // We'll behave like the non-Windows implementation and return None (0 in OCaml).
  return 0;
}