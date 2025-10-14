/***************************************************************************
* Copyright (c) 2025, Davy Cottet
*
* Distributed under the terms of the GNU General Public License v3.
*
* The full license is in the file LICENSE, distributed with this software.
****************************************************************************/

#ifndef XEUS_OCAML_CALLBACKS_HPP
#define XEUS_OCAML_CALLBACKS_HPP

#include <string>
#include <emscripten/bind.h>

/**
 * @brief Global C-style callback for the asynchronous OCaml setup (Phase 1).
 *
 * This function is bound and exported to JavaScript via Emscripten. It is
 * invoked by the OCaml backend when the initial setup, including fetching
 * standard library files, is complete. It then triggers the C++-side setup
 * (Phase 2), such as mounting the virtual filesystem.
 *
 * @param result_str A JSON string from the OCaml backend indicating the result
 *                   of the setup operation.
 */
void global_setup_callback(const std::string& result_str);

/**
 * @brief Global C-style callback for asynchronous OCaml code execution.
 *
 * This function is bound and exported to JavaScript via Emscripten. It is
 * invoked by the OCaml backend when an `Eval` action completes. It acts as
 * the bridge to pass the execution result back to the correct `interpreter`
 * instance.
 *
 * @param request_id The unique ID of the original execution request, used to
 *                   route the result to the correct pending callback.
 * @param result_str A JSON string from the OCaml backend containing the
 *                   execution outputs or an error message.
 */
void global_eval_callback(int request_id, const std::string& result_str);

#endif // XEUS_OCAML_CALLBACKS_HPP