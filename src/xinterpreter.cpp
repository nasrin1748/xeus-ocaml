/***************************************************************************
* Copyright (c) 2025, Davy Cottet
*
* Distributed under the terms of the GNU General Public License v3.
*
* The full license is in the file LICENSE, distributed with this software.
****************************************************************************/

#include "xinterpreter.hpp"
#include "xocaml_engine.hpp"
#include "xcompletion.hpp"
#include "xinspection.hpp"

#include <iostream>
#include <sstream>
#include <stdexcept>
#include <utility>
#include <vector>

#include "xeus/xhelper.hpp"
#include <emscripten/bind.h>
#include <emscripten/val.h>

namespace xeus_ocaml
{
    namespace
    {
        // Global pointer to the interpreter instance for C-style callbacks.
        interpreter* g_interpreter_instance = nullptr;
    }

    /**
     * @brief Global C-style callback for the asynchronous OCaml setup (Phase 1).
     *
     * This function is invoked by the OCaml backend when the initial setup, including
     * fetching standard library files, is complete. It then triggers the C++-side
     * setup (Phase 2), such as mounting the virtual filesystem.
     *
     * @param result_str A JSON string from the OCaml backend indicating the result
     *                   of the setup operation.
     */
    void global_setup_callback(const std::string& result_str)
    {
        if (g_interpreter_instance)
        {
            g_interpreter_instance->handle_setup_callback(result_str);
        }
    }

    /**
     * @brief Global C-style callback for asynchronous OCaml code execution.
     *
     * This function is invoked by the OCaml backend when an `Eval` action completes.
     * It acts as the bridge to pass the execution result back to the correct
     * `interpreter` instance.
     *
     * @param request_id The unique ID of the original execution request, used to
     *                   route the result to the correct pending callback.
     * @param result_str A JSON string from the OCaml backend containing the
     *                   execution outputs or an error message.
     */
    void global_eval_callback(int request_id, const std::string& result_str)
    {
        if (g_interpreter_instance)
        {
            g_interpreter_instance->handle_eval_callback(request_id, result_str);
        }
    }

    /**
     * @brief Emscripten bindings to export global callbacks to JavaScript.
     *
     * This block makes the C++ `global_setup_callback` and `global_eval_callback`
     * functions callable from the JavaScript environment, allowing the OCaml
     * backend to trigger them.
     */
    EMSCRIPTEN_BINDINGS(xocaml_kernel_callbacks)
    {
        emscripten::function("global_setup_callback", &global_setup_callback);
        emscripten::function("global_eval_callback", &global_eval_callback);
    }

    // Constructor: registers this instance as the main interpreter and sets the global pointer.
    interpreter::interpreter() : m_request_id_counter(0)
    {
        g_interpreter_instance = this;
        xeus::register_interpreter(this);
    }

    // Handles the setup result from OCaml (Phase 1) and triggers C++-side setup (Phase 2).
    void interpreter::handle_setup_callback(const std::string& result_str)
    {
        nl::json result = nl::json::parse(result_str);
        if (result.value("class", "") == "return")
        {
            ocaml_engine::mount_fs();
        }
        else
        {
            std::cerr << "[xeus-ocaml] OCaml setup failed: " << result.value("value", "Unknown error") << std::endl;
        }
    }

    // Called once at kernel startup to configure the interpreter by calling the OCaml setup.
    void interpreter::configure_impl()
    {
        nl::json setup_request = {
            "Setup",
            {{"dsc_url", "../../../../xeus/kernel/xocaml/"}}
        };

        emscripten::val on_setup_complete = emscripten::val::module_property("global_setup_callback");
        ocaml_engine::call_toplevel_async(setup_request, on_setup_complete);
    }

    // Handles an `execute_request` message from the frontend.
    void interpreter::execute_request_impl(
        send_reply_callback cb,
        int execution_counter,
        const std::string& code,
        xeus::execute_request_config,
        nl::json)
    {
        // Store the request details and send the code to OCaml for asynchronous execution.
        int request_id = ++m_request_id_counter;
        m_pending_requests[request_id] = {std::move(cb), execution_counter};

        nl::json eval_request = {"Eval", {{"source", code}}};

        emscripten::val callback_handler = emscripten::val::module_property("global_eval_callback");
        emscripten::val bound_callback = callback_handler.call<emscripten::val>("bind", emscripten::val::null(), request_id);

        ocaml_engine::call_toplevel_async(eval_request, bound_callback);
    }

    // Processes the result from an asynchronous OCaml execution.
    void interpreter::handle_eval_callback(int request_id, const std::string& result_str)
    {
        try {
            nl::json response = nl::json::parse(result_str);
            if (response.value("class", "") == "return") {
                handle_execution_output(request_id, response.value("value", nl::json::array()));
                handle_final_response(request_id, ""); // Signal success
            } else {
                handle_final_response(request_id, response.value("value", "Unknown execution error."));
            }
        } catch (const std::exception& e) {
            std::string error_msg = "Failed to parse execution response: " + std::string(e.what());
            handle_final_response(request_id, error_msg);
        }
    }

    // Iterates through execution results and publishes them to the frontend.
    void interpreter::handle_execution_output(int request_id, const nl::json& outputs)
    {
        auto it = m_pending_requests.find(request_id);
        if (it == m_pending_requests.end()) return;

        int execution_count = it->second.m_execution_count;
        for (const auto& output_item : outputs) {
            if (!output_item.is_array() || output_item.size() != 2) continue;
            
            const std::string& output_type = output_item[0].get<std::string>();
            if (output_type == "Stdout") {
                publish_stream("stdout", output_item[1].get<std::string>());
            } else if (output_type == "Stderr") {
                publish_stream("stderr", output_item[1].get<std::string>());
            } else if (output_type == "Value") {
                publish_execution_result(execution_count, {{"text/plain", output_item[1].get<std::string>()}}, {});
            } else if (output_type == "DisplayData") {
                this->display_data(output_item[1], {}, {});
            }
        }
    }

    // Sends the final `execute_reply` (either success or error) to the frontend.
    void interpreter::handle_final_response(int request_id, const std::string& error_summary)
    {
        auto it = m_pending_requests.find(request_id);
        if (it == m_pending_requests.end()) return;

        auto& cb = it->second.m_callback;
        if (!error_summary.empty()) {
            cb(xeus::create_error_reply("OCaml Execution Error", error_summary, {}));
        } else {
            cb(xeus::create_successful_reply());
        }
        m_pending_requests.erase(it);
    }

    // Handles a `complete_request` by delegating to the completion handler.
    nl::json interpreter::complete_request_impl(const std::string& code, int cursor_pos) {
        return handle_completion_request(code, cursor_pos);
    }

    // Handles an `inspect_request` by delegating to the inspection handler.
    nl::json interpreter::inspect_request_impl(const std::string& code, int cursor_pos, int detail_level) {
        return handle_inspection_request(code, cursor_pos, detail_level);
    }

    // Checks if a block of code is complete (e.g., ends with `;;`).
    nl::json interpreter::is_complete_request_impl(const std::string& code) {
        if (code.find_first_not_of(" \t\n\r") == std::string::npos) {
            return xeus::create_is_complete_reply("complete");
        }
        auto last_char = code.find_last_not_of(" \t\n\r");
        if (last_char == std::string::npos || last_char < 1) {
            return xeus::create_is_complete_reply("incomplete", "  ");
        }
        if (code[last_char] == ';' && code[last_char - 1] == ';') {
            return xeus::create_is_complete_reply("complete");
        }
        return xeus::create_is_complete_reply("incomplete", "  ");
    }

    // Handles a `shutdown_request`.
    void interpreter::shutdown_request_impl() {}

    // Provides information about the kernel.
    nl::json interpreter::kernel_info_request_impl() {
        return xeus::create_info_reply(
            "5.3", "xocaml", XEUS_OCAML_VERSION,
            "ocaml", "5.2.0", "text/x-ocaml", ".ml",
            "ocaml", "ocaml", "",
            "xeus-ocaml - A WebAssembly OCaml kernel for Jupyter",
            false, nl::json::array()
        );
    }
}