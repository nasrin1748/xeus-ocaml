/***************************************************************************
 * Copyright (c) 2025, Davy Cottet
 * Copyright (c) 2024, The xeus-ocaml Authors
 *
 * Distributed under the terms of the BSD 3-Clause License.
 *
 * The full license is in the file LICENSE, distributed with this software.
 ****************************************************************************/

/**
 * @file xinterpreter.hpp
 * @brief Contains the declaration of the xeus-ocaml interpreter.
 */

#ifndef XEUS_OCAML_INTERPRETER_HPP
#define XEUS_OCAML_INTERPRETER_HPP

#include <map>
#include <string>

#include "nlohmann/json.hpp"
#include "xeus/xinterpreter.hpp"

namespace xeus_ocaml
{
    namespace nl = nlohmann;

    class interpreter : public xeus::xinterpreter
    {
    public:
        interpreter();
        virtual ~interpreter() = default;

        // =================================================================
        // FIX: Explicitly define or delete all special member functions
        // This resolves the compiler error by making the class non-copyable
        // and non-movable, which is correct for a unique kernel interpreter.
        // =================================================================
        interpreter(const interpreter&) = delete;
        interpreter& operator=(const interpreter&) = delete;
        interpreter(interpreter&&) = delete;
        interpreter& operator=(interpreter&&) = delete;

        /**
         * @brief Public callback handler for asynchronous execution results.
         *
         * This method is called by the global C-style callback function when a
         * response from an asynchronous 'Eval' action is received from JavaScript.
         *
         * @param request_id The unique ID of the original execution request.
         * @param result_str The JSON string result from the JavaScript backend.
         */
        void handle_eval_callback(int request_id, const std::string& result_str);

    private:

        // ... (The rest of the private declarations remain the same)

        void configure_impl() override;
        void execute_request_impl(send_reply_callback cb, int execution_counter, const std::string& code, xeus::execute_request_config config, nl::json user_expressions) override;
        nl::json complete_request_impl(const std::string& code, int cursor_pos) override;
        nl::json inspect_request_impl(const std::string& code, int cursor_pos, int detail_level) override;
        nl::json is_complete_request_impl(const std::string& code) override;
        nl::json kernel_info_request_impl() override;
        void shutdown_request_impl() override;

        void handle_execution_output(int request_id, const nl::json& outputs);
        void handle_final_response(int request_id, const std::string& error_summary);
        std::string map_ocaml_kind_to_icon(const nl::json& kind_json);

        struct pending_request
        {
            send_reply_callback m_callback;
            int m_execution_count;
        };

        std::map<int, pending_request> m_pending_requests;
        int m_request_id_counter;
    };
}

#endif // XEUS_OCAML_INTERPRETER_HPP