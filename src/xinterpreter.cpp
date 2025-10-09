/***************************************************************************
 * Copyright (c) 2025, Davy Cottet
 * Copyright (c) 2024, The xeus-ocaml Authors
 *
 * Distributed under the terms of the BSD 3-Clause License.
 *
 * The full license is in the file LICENSE, distributed with this software.
 ****************************************************************************/

#define DEBUG_XOCAML

#include <iostream>
#include <sstream>
#include <stdexcept>
#include <utility>
#include <vector>
#include <string>
#include <regex> // Include the regex header

#include "xeus-ocaml/xinterpreter.hpp"
#include "xeus/xhelper.hpp"

#include <emscripten/bind.h>
#include <emscripten/val.h>

#ifdef DEBUG_XOCAML
#define XOCAML_LOG(channel, message) std::cout << "[xeus-ocaml][" << channel << "] " << message << std::endl
#else
#define XOCAML_LOG(channel, message)
#endif

namespace xeus_ocaml
{
    namespace
    {
        interpreter *g_interpreter_instance = nullptr;

        /**
         * @brief Parses and reformats a raw Merlin docstring for Markdown display.
         * @param doc The raw docstring from Merlin.
         * @return The parsed and cleaned docstring.
         */
        std::string parse_merlin_docstring(std::string doc)
        {
            // Handle the {!...} to `...` conversion
            const std::regex merlin_bold_regex("\\{\\!(.*?)\\}");
            doc = std::regex_replace(doc, merlin_bold_regex, "`$1`");
            
            // Replace newline followed by spaces with a single space.
            // This "unwraps" paragraphs that are indented in the source code.
            const std::regex indent_regex("\n +");
            doc = std::regex_replace(doc, indent_regex, " ");

            // Replace remaining single newlines with double newlines.
            // This creates proper paragraph breaks in Markdown.
            const std::regex newline_regex("\n");
            doc = std::regex_replace(doc, newline_regex, "\n\n");
            
            return doc;
        }

        nl::json call_merlin_sync(const nl::json &request)
        {
            XOCAML_LOG("Merlin Sync Request", request.dump(2));
            try
            {
                emscripten::val xocaml = emscripten::val::global("xocaml");
                std::string response_str = xocaml.call<std::string>("processMerlinAction", request.dump());
                XOCAML_LOG("Merlin Sync Response", response_str);
                return nl::json::parse(response_str);
            }
            catch (const std::exception &e)
            {
                std::cerr << "[xeus-ocaml] Exception in call_merlin_sync: " << e.what() << std::endl;
                return {{"class", "error"}, {"value", "C++ exception during Merlin sync call."}};
            }
        }

        void call_toplevel_async(const nl::json &request, emscripten::val callback)
        {
            XOCAML_LOG("Toplevel Async Request", request.dump(2));
            try
            {
                emscripten::val xocaml = emscripten::val::global("xocaml");
                xocaml.call<void>("processToplevelAction", request.dump(), callback);
            }
            catch (const std::exception &e)
            {
                std::cerr << "[xeus-ocaml] Exception in call_toplevel_async: " << e.what() << std::endl;
            }
        }
    }

    void global_eval_callback(int request_id, const std::string &result_str)
    {
        if (g_interpreter_instance)
        {
            g_interpreter_instance->handle_eval_callback(request_id, result_str);
        }
    }

    EMSCRIPTEN_BINDINGS(xocaml_kernel_callbacks)
    {
        emscripten::function("global_eval_callback", &global_eval_callback);
    }

    interpreter::interpreter() : m_request_id_counter(0)
    {
        xeus::register_interpreter(this);
        g_interpreter_instance = this;
    }

    void interpreter::configure_impl()
    {
        XOCAML_LOG("configure_impl", "Initializing OCaml environment...");
        nl::json setup_request = {
            "Setup",
            {{"dsc_url", "../../../../xeus/kernel/xocaml/"}}};

        auto on_setup_complete = emscripten::val::global("Function").new_<std::string, std::string>("resultStr", "const result = JSON.parse(resultStr);"
                                                                                                                 "if (result.class === 'return') {"
                                                                                                                 "  console.log('[xeus-ocaml][configure_impl] OCaml environment ready!');"
                                                                                                                 "} else {"
                                                                                                                 "  console.error('[xeus-ocaml][configure_impl] OCaml setup failed:', result.value);"
                                                                                                                 "}");

        call_toplevel_async(setup_request, on_setup_complete);
    }

    void interpreter::execute_request_impl(
        send_reply_callback cb,
        int execution_counter,
        const std::string &code,
        xeus::execute_request_config,
        nl::json)
    {
        int request_id = ++m_request_id_counter;
        m_pending_requests[request_id] = {std::move(cb), execution_counter};

        nl::json eval_request = {"Eval", {{"source", code}}};

        emscripten::val callback_handler = emscripten::val::module_property("global_eval_callback");
        emscripten::val bound_callback = callback_handler.call<emscripten::val>("bind", emscripten::val::null(), request_id);

        call_toplevel_async(eval_request, bound_callback);
    }

    void interpreter::handle_eval_callback(int request_id, const std::string &result_str)
    {
        try
        {
            nl::json response = nl::json::parse(result_str);
            if (response.value("class", "") == "return")
            {
                handle_execution_output(request_id, response.value("value", nl::json::array()));
                handle_final_response(request_id, "");
            }
            else
            {
                handle_final_response(request_id, response.value("value", "Unknown execution error."));
            }
        }
        catch (const std::exception &e)
        {
            std::string error_msg = "Failed to parse execution response: ";
            error_msg += e.what();
            handle_final_response(request_id, error_msg);
        }
    }

     void interpreter::handle_execution_output(int request_id, const nl::json &outputs)
    {
        auto it = m_pending_requests.find(request_id);
        if (it == m_pending_requests.end()) return;

        int execution_count = it->second.m_execution_count;

        for (const auto &output_item : outputs)
        {
            if (!output_item.is_array() || output_item.size() != 2) continue;
            const std::string &output_type = output_item[0].get<std::string>();
            XOCAML_LOG("handle_execution_output", "Output type: " + output_type);

            if (output_type == "Stdout")
            {
                const std::string &content = output_item[1].get<std::string>();
                publish_stream("stdout", content);
            }
            else if (output_type == "Stderr")
            {
                const std::string &content = output_item[1].get<std::string>();
                publish_stream("stderr", content);
            }
            else if (output_type == "Value")
            {
                const std::string &content = output_item[1].get<std::string>();
                publish_execution_result(execution_count, {{"text/plain", content}}, {});
            }
            else if (output_type == "DisplayData")
            {
                const nl::json& data_bundle = output_item[1];
                XOCAML_LOG("handle_execution_output", "Publishing DisplayData bundle: " + data_bundle.dump());
                this->display_data(data_bundle, {}, {});
            }
        }
    }

    void interpreter::handle_final_response(int request_id, const std::string &error_summary)
    {
        auto it = m_pending_requests.find(request_id);
        if (it == m_pending_requests.end()) return;

        auto &cb = it->second.m_callback;
        if (!error_summary.empty())
        {
            cb(xeus::create_error_reply("OCaml Execution Error", error_summary, {}));
        }
        else
        {
            cb(xeus::create_successful_reply());
        }
        m_pending_requests.erase(it);
    }

    nl::json interpreter::complete_request_impl(const std::string &code, int cursor_pos)
    {
        nl::json request = { "Complete_prefix", {{"source", code}, {"position", {"Offset", cursor_pos}}}};
        nl::json response = call_merlin_sync(request);

        if (response.value("class", "") != "return")
        {
            return xeus::create_complete_reply({}, cursor_pos, cursor_pos);
        }

        const nl::json &value = response["value"];
        int start = value.value("from", cursor_pos);
        int end = value.value("to_", cursor_pos);
        nl::json matches = nl::json::array();
        nl::json rich_items = nl::json::array();

        for (const auto &entry : value.value("entries", nl::json::array()))
        {
            std::string name = entry.value("name", "");
            matches.push_back(name);
            nl::json rich_item;
            rich_item["text"] = name;
            rich_item["type"] = map_ocaml_kind_to_icon(entry.value("kind", ""));
            rich_item["signature"] = entry.value("desc", "");
            rich_item["documentation"] = entry.value("info", "");
            rich_items.push_back(rich_item);
        }

        nl::json reply = xeus::create_complete_reply(matches, start, end);
        reply["metadata"]["_jupyter_types_experimental"] = rich_items;
        XOCAML_LOG("complete_request_impl", "Sending complete_reply : " + reply.dump(2));
        return reply;
    }

    nl::json interpreter::inspect_request_impl(const std::string& code, int cursor_pos, int level)
    {
        XOCAML_LOG("inspect_request_impl", "Handling inspection request of level : " + std::to_string(level));
        std::string type_string, doc_string;

        nl::json type_request = {"Type_enclosing", {{"source", code}, {"position", {"Offset", cursor_pos}}}};
        nl::json type_response = call_merlin_sync(type_request);
        if (type_response.value("class", "") == "return")
        {
            const auto& value = type_response["value"];
            if (value.is_array() && !value.empty())
            {
                const auto& type_info = value[0];
                if (type_info.contains("type") && type_info["type"].is_string())
                {
                    type_string = type_info["type"].get<std::string>();
                }
            }
        }

        nl::json doc_request = {"Document", {{"source", code}, {"position", {"Offset", cursor_pos}}}};
        nl::json doc_response = call_merlin_sync(doc_request);
        if (doc_response.value("class", "") == "return")
        {
            std::string temp_doc = doc_response["value"].get<std::string>();
            if (!temp_doc.empty() && temp_doc != "No documentation available" && temp_doc != "Not a valid identifier" && temp_doc.rfind("Not in environment", 0) != 0)
            {
                doc_string = parse_merlin_docstring(temp_doc);
                XOCAML_LOG("inspect_request_impl", "Parsed documentation.");
            }
        }

        if (type_string.empty() && doc_string.empty())
        {
            nl::json reply = xeus::create_inspect_reply(false, {}, {});
            XOCAML_LOG("inspect_request_impl", "Sending inspect_reply (not found): " + reply.dump(2));
            return reply;
        }

        std::stringstream md_content, plain_content;
        if (!type_string.empty())
        {
            md_content << "```ocaml\n" << type_string << "\n```\n";
            plain_content << type_string << "\n";
        }
        if (!type_string.empty() && !doc_string.empty())
        {
            md_content << "\n---\n\n";
            plain_content << "\n-----------------\n\n";
        }
        if (!doc_string.empty())
        {
            md_content << doc_string;
            plain_content << doc_string;
        }

        nl::json data;
        data["text/plain"] = plain_content.str();
        data["text/markdown"] = md_content.str();
        nl::json reply = xeus::create_inspect_reply(true, data, {});
        XOCAML_LOG("inspect_request_impl", "Sending inspect_reply (found): " + reply.dump(2));
        return reply;
    }

    std::string interpreter::map_ocaml_kind_to_icon(const nl::json &kind_json)
    {
        if (!kind_json.is_string()) return "text";
        const std::string &kind = kind_json.get<std::string>();
        if (kind == "Value") return "function";
        if (kind == "Module" || kind == "Modtype") return "module";
        if (kind == "Constructor" || kind == "Variant") return "class";
        if (kind == "Type") return "interface";
        if (kind == "Method" || kind == "MethodCall") return "method";
        if (kind == "Keyword") return "keyword";
        if (kind == "Label") return "field";
        if (kind == "Exn") return "event";
        return "text";
    }

    nl::json interpreter::is_complete_request_impl(const std::string &code)
    {
        auto first_char = code.find_first_not_of(" \t\n\r");
        if (first_char == std::string::npos) return xeus::create_is_complete_reply("complete");
        auto last_char = code.find_last_not_of(" \t\n\r");
        if (last_char == std::string::npos || last_char < 1) return xeus::create_is_complete_reply("incomplete", "  ");
        if (code[last_char] == ';' && code[last_char - 1] == ';') return xeus::create_is_complete_reply("complete");
        return xeus::create_is_complete_reply("incomplete", "  ");
    }

    void interpreter::shutdown_request_impl() {}

    nl::json interpreter::kernel_info_request_impl()
    {
        return xeus::create_info_reply(
            "5.3", "xocaml", "0.1.0", "ocaml", "5.2.0", "text/x-ocaml", ".ml",
            "ocaml", "ocaml", "", "xeus-ocaml - A WebAssembly OCaml kernel for Jupyter",
            false, nl::json::array());
    }
}