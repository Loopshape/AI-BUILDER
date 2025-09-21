#!/usr/bin/env bash
# ~/bin/ai
# AI/AGI/AIM Unified Processing Tool v5.4
# Enhanced with a built-in web search tool for live internet research.

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
BUILD_DIR="${BUILD_DIR:-$HOME/.ai_builder}"
MODEL="2244-1" # The mandatory text/reasoning model
MULTIMODAL_MODEL="${MULTIMODAL_MODEL:-llava:latest}"
OLLAMA_BIN="${OLLAMA_BIN:-$(command -v ollama || true)}"
TMP_DIR="$BUILD_DIR/tmp"
MAX_ITERATIONS=10

# --- COLORS & LOGGING ---
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'; C_MAGENTA='\033[0;35m'
log() { printf "${C_BLUE}[%s]${C_RESET} %s\n" "$(date '+%T')" "$*"; }
log_success() { log "${C_GREEN}$*${C_RESET}"; }
log_warn() { log "${C_YELLOW}WARN: $*${C_RESET}"; }
log_error() { log "${C_RED}ERROR: $*${C_RESET}"; exit 1; }

# --- BOOTSTRAP ---
mkdir -p "$BUILD_DIR" "$TMP_DIR"

# --- CORE UTILITIES ---
check_dependencies() { for cmd in "$@"; do if ! command -v "$cmd" >/dev/null; then log_warn "Required command '$cmd' not found. Run 'ai --setup'."; fi; done; }
ensure_ollama_server() { if ! pgrep -f "ollama serve" >/dev/null; then log "Ollama server starting..."; nohup "$OLLAMA_BIN" serve >/dev/null 2>&1 & sleep 2; fi; }

# --- AGENT TOOLS (WITH NEW WEB SEARCH) ---
tool_read_file() { cat "$1" 2>/dev/null || echo "Error: File not found."; }
tool_list_directory() { tree -L 2 "$1" 2>/dev/null || ls -l "$1" 2>/dev/null || echo "Error: Directory not found."; }

# NEW: The web research tool
tool_web_search() {
    local query="$*"
    log "  TOOL: Searching the web for: ${C_CYAN}$query${C_RESET}"
    
    # URL-encode the query for safety
    local encoded_query; encoded_query=$(jq -nr --arg q "$query" '$q|@uri')
    
    # Fetch and parse search results into a clean summary
    local search_summary
    search_summary=$(curl -sL "https://html.duckduckgo.com/html/?q=${encoded_query}" \
        | lynx -dump -stdin -nolist \
        | awk '/1\./, /5\./' \
        | sed 's/^[0-9]\+\.//' \
        | sed '/^$/d' \
        | head -n 20)

    if [[ -z "$search_summary" ]]; then
        echo "Error: Could not retrieve or parse search results."
    else
        echo "Search results summary:\n${search_summary}"
    fi
}

tool_write_file() {
    local path="$1"; local content="$2"
    log "AGENT ACTION: Proposing to write to file ${C_YELLOW}$path${C_RESET}"
    echo -e "${C_BOLD}--- PROPOSED CHANGE ---${C_RESET}"
    if [[ -f "$path" ]]; then diff --color=always -u <(cat "$path") <(echo -e "$content") || true
    else echo -e "${C_GREEN}${content}${C_RESET}"; fi
    echo -e "${C_BOLD}-----------------------${C_RESET}"
    read -p "Do you approve this write operation? [y/N] " -n 1 -r confirm; echo
    if [[ "${confirm-n}" =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$path")"; echo -e "$content" > "$path"
        log_success "File written successfully."; echo "Success: The file '$path' has been written."
    else
        log_warn "Write operation aborted by user."; echo "User aborted the write operation."
    fi
}

# --- AGENT CORE ---
run_and_capture_thought_stream() {
    local full_prompt="$1"; ensure_ollama_server
    local ai_response; ai_response=$("$OLLAMA_BIN" run "$MODEL" "$full_prompt" 2>&1 | tee /dev/tty)
    echo "$ai_response"
}

run_interactive_agent() {
    local context_files=(); local user_prompt_parts=()
    for arg in "$@"; do if [[ -e "$arg" ]]; then context_files+=("$arg"); else user_prompt_parts+=("$arg"); fi; done
    
    local initial_context=""
    if [[ ${#context_files[@]} -gt 0 ]]; then
        initial_context+="The user provided these files/paths as initial context:\n"
        for file in "${context_files[@]}"; do initial_context+="- $(realpath "$file")\n"; done
    fi

    local initial_prompt="${user_prompt_parts[*]}"
    
    # NEW: Upgraded system prompt teaching the AI how to use web_search
    local system_prompt="You are an expert AI developer and research assistant. Your goal is to solve the user's request by thinking step-by-step.
If you need information that cannot be found in the local files, you MUST use the \`web_search\` tool.

Your thinking process MUST follow this format:
[REASONING] Your analysis and justification for the next step.
[TOOL] command <argument>

To write a file, use this specific format:
[REASONING] I will now write the corrected code to the file.
[TOOL] write_file /path/to/file.js
[CONTENT]
// all of my new, multi-line
// javascript code goes here
[/CONTENT]

Available Tools:
- \`read_file <path>\`
- \`list_directory <path>\`
- \`web_search <query>\`: Searches the internet for up-to-date information.
- \`write_file <path>\`

When you have solved the problem, provide the final answer with the \`[FINAL_ANSWER]\` tag.

Begin now.
---
${initial_context}
User Request: ${initial_prompt}"

    local conversation_history="$system_prompt"
    
    for (( i=1; i<=MAX_ITERATIONS; i++ )); do
        log "Agent Iteration $i/$MAX_ITERATIONS. AI is thinking..."
        echo -e "${C_YELLOW}--- AI Thought Process ---${C_RESET}"
        local ai_response; ai_response=$(run_and_capture_thought_stream "$conversation_history")
        echo -e "${C_YELLOW}--- End of Thought ---${C_RESET}"
        
        if [[ "$ai_response" == *"[FINAL_ANSWER]"* ]]; then log_success "AI has completed the task."; echo "$ai_response" | awk 'BEGIN{p=0} /\[FINAL_ANSWER\]/{p=1; next} p'; return; fi
        local tool_line; tool_line=$(echo "$ai_response" | grep '\[TOOL\]' | sed 's/\[TOOL\] *//' | head -n 1)
        if [[ -z "$tool_line" ]]; then log_warn "AI did not choose a tool. Assuming final answer."; echo -e "${C_GREEN}${ai_response}${C_RESET}"; return; fi

        local tool_name; tool_name=$(echo "$tool_line" | awk '{print $1}')
        local tool_args; tool_args=$(echo "$tool_line" | cut -d' ' -f2-)
        
        log "Agent is taking action..."; echo -e "${C_CYAN}[ACTION]${C_RESET} Executing tool: ${tool_name} ${tool_args}"
        local tool_result=""
        if [[ "$tool_name" == "write_file" ]]; then
            local content_to_write; content_to_write=$(echo "$ai_response" | awk '/\[CONTENT\]/{flag=1; next} /\[\/CONTENT\]/{flag=0} flag')
            tool_result=$(tool_write_file "$tool_args" "$content_to_write")
        else
            case "$tool_name" in
                read_file) tool_result=$(tool_read_file "$tool_args") ;;
                list_directory) tool_result=$(tool_list_directory "$tool_args") ;;
                web_search) tool_result=$(tool_web_search "$tool_args") ;;
                *) tool_result="Error: AI chose an unknown tool '$tool_name'." ;;
            esac
        fi
        echo -e "${C_MAGENTA}--- TOOL RESULT ---${C_RESET}\n${tool_result}\n"
        conversation_history+="\n${ai_response}\n[TOOL_RESULT]\n${tool_result}"
    done
    
    log_error "Agent exceeded maximum iterations ($MAX_ITERATIONS). Halting."
}

# --- HELP & MAIN DISPATCHER ---
show_help() {
    printf "${C_BOLD}${C_CYAN}AI/AGI/AIM Unified Tool v5.4 - Research Agent Edition${C_RESET}\n\n"
    printf "An interactive agent that can read/write files and research the internet.\n\n"
    printf "${C_BOLD}${C_YELLOW}PRIMARY USAGE:${C_RESET}\n"
    printf "  ${C_GREEN}ai${C_RESET} [file context]... \"Your development or research goal\"\n"
    printf "  The agent will use its tools, including web search, to solve your request.\n\n"
    printf "${C_BOLD}${C_YELLOW}UTILITY:${C_RESET}\n"
    printf "  ${C_GREEN}--setup${C_RESET}              Install all required dependencies (lynx, tree, etc.).\n"
    printf "  ${C_GREEN}--help${C_RESET}               Show this help message.\n\n"
    printf "${C_BOLD}${C_YELLOW}EXAMPLE:${C_RESET}\n"
    printf "  ${C_CYAN}ai \"I'm getting a 'CORS error' in my Javascript app. Research what that is and then add the necessary headers to my server.js file.\"${C_RESET}\n"
}

main() {
    check_dependencies ollama curl file jq tree lynx
    if [[ $# -eq 0 ]]; then show_help; exit 0; fi

    case "$1" in
        --setup)
            log "Installing dependencies..."; if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y tree jq file poppler-utils unzip lynx; elif command -v brew &>/dev/null; then brew install tree jq file poppler-utils lynx; fi; log_success "Setup complete.";;
        --help) show_help ;;
        *)
            run_interactive_agent "$@"
            ;;
    esac
}

main "$@"
