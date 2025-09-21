#!/usr/bin/env bash
# ~/bin/ai - Full AGI Agent CLI with WebKit prompt & multi-step reasoning
# Version: 7.1 - Enhanced with safety protocols, live streaming, and multi-tool execution.

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
BUILD_DIR="${BUILD_DIR:-$HOME/.ai_builder}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/ai_projects}"
MODEL="llama3.1:8b"
OLLAMA_BIN="${OLLAMA_BIN:-$(command -v ollama || true)}"
TMP_DIR="$BUILD_DIR/tmp"
MAX_ITERATIONS=20
TOKEN_LOG="$BUILD_DIR/token_count.log"

# --- COLORS & LOGGING ---
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'; C_MAGENTA='\033[0;35m'
log() { printf "${C_BLUE}[%s]${C_RESET} %s\n" "$(date '+%T')" "$*"; }
log_success() { log "${C_GREEN}$*${C_RESET}"; }
log_warn() { log "${C_YELLOW}WARN: $*${C_RESET}"; }
log_error() { log "${C_RED}ERROR: $*${C_RESET}"; exit 1; }
log_info() { log "${C_CYAN}$*${C_RESET}"; }

# --- BOOTSTRAP ---
mkdir -p "$BUILD_DIR" "$TMP_DIR" "$PROJECTS_DIR"

# --- CORE UTILITIES ---
check_dependencies() { for cmd in "$@"; do if ! command -v "$cmd" >/dev/null; then log_warn "Required command '$cmd' not found. Run 'ai --setup'."; fi; done; }
ensure_ollama_server() { if ! pgrep -f "ollama serve" >/dev/null; then log "Ollama server starting..."; nohup "$OLLAMA_BIN" serve >/dev/null 2>&1 & sleep 3; fi; }
confirm_action() { echo -e "${C_YELLOW}PROPOSED ACTION:${C_RESET} ${C_BOLD}$1${C_RESET}"; read -p "Approve? [y/N] " -n 1 -r confirm; echo; [[ "$confirm" =~ ^[Yy]$ ]]; }

# --- ENHANCED AGENT TOOLS ---
tool_read_file() { [[ -f "$1" ]] && cat "$1" || echo "Error: File not found: $1"; }
tool_list_directory() { local p="${1:-.}"; [[ -d "$p" ]] && tree -L 2 "$p" || echo "Error: Dir not found: $p"; }
tool_web_search() { local q="$*"; curl -sL "https://html.duckduckgo.com/html/?q=$(jq -nr --arg q "$q" '$q|@uri')" | lynx -dump -stdin -nolist; }
tool_write_file() { local path="$1"; local content="$2"; if confirm_action "Write file: $path"; then mkdir -p "$(dirname "$path")"; echo -e "$content" > "$path"; echo "Success: File written."; else echo "User aborted."; fi; }
tool_create_directory() { if confirm_action "Create dir: $1"; then mkdir -p "$1"; echo "Success"; else echo "User aborted."; fi; }
tool_copy_file() { if confirm_action "Copy $1 -> $2"; then cp -r "$1" "$2"; echo "Success"; else echo "User aborted."; fi; }
tool_move_file() { if confirm_action "Move $1 -> $2"; then mv "$1" "$2"; echo "Success"; else echo "User aborted."; fi; }
tool_delete_file() { if confirm_action "${C_RED}Delete $1${C_RESET}"; then rm -rf "$1"; echo "Success"; else echo "User aborted."; fi; }
tool_run_command() { if confirm_action "Run: $*"; then eval "$*" 2>&1; else echo "User aborted"; fi; }

# --- Rehashed token tracking ---
increment_tokens() {
    local t="${1:-1}"; local c=0
    if [ -f "$TOKEN_LOG" ]; then c=$(cat "$TOKEN_LOG"); fi
    echo $((c + t)) > "$TOKEN_LOG"
}

# --- AGENT CORE (ROBUST MULTI-TOOL LOOP) ---
run_and_capture_thought_stream() {
    ensure_ollama_server; log_info "AI is thinking..."
    echo -e "${C_YELLOW}--- AI Thought Process ---${C_RESET}"
    local ai_response; ai_response=$(timeout 180s "$OLLAMA_BIN" run "$MODEL" "$1" 2>&1 | tee /dev/tty)
    echo -e "${C_YELLOW}--- End of Thought ---${C_RESET}"
    echo "$ai_response"
}

run_interactive_agent() {
    local user_prompt="$*"
    local system_prompt="You are a powerful AI agent with supervised filesystem & shell access. Your goal is to solve the user's request by thinking step-by-step.
TOOLS: read_file, list_directory, web_search, write_file, create_directory, copy_file, move_file, delete_file, run_command
RULES: Propose actions to the user. You can and should use multiple tools in one response to be efficient. Use a [CONTENT] block for multi-line file content. When done, use [FINAL_ANSWER].

Begin. User Request: $user_prompt"
    local conversation_history="$system_prompt"

    for ((i=1; i<=MAX_ITERATIONS; i++)); do
        log "Agent Iteration $i/$MAX_ITERATIONS"
        local ai_response; ai_response=$(run_and_capture_thought_stream "$conversation_history")

        local token_count; token_count=$(echo "$ai_response" | wc -w); increment_tokens "$token_count"

        if [[ "$ai_response" == *"[FINAL_ANSWER]"* ]]; then
            log_success "Task complete."
            echo "$ai_response" | awk 'BEGIN{p=0} /\[FINAL_ANSWER\]/{p=1;next} p'
            return
        fi

        local tool_lines; tool_lines=$(echo "$ai_response" | grep '\[TOOL\]')
        if [[ -z "$tool_lines" ]]; then
            log_warn "AI did not choose a tool. Assuming this is the final answer."
            echo -e "${C_GREEN}${ai_response}${C_RESET}"
            return
        fi

        local all_results=""
        while IFS= read -r line; do
            local clean_line="${line#\[TOOL\] }"; local name=$(echo "$clean_line" | awk '{print $1}'); local args=$(echo "$clean_line" | cut -d' ' -f2-); local result=""
            log_info "Executing tool: ${C_CYAN}$name${C_RESET} ${C_YELLOW}$args${C_RESET}"
            if [[ "$name" == "write_file" ]]; then
                local path="$args"; local content=$(echo "$ai_response" | awk '/\[CONTENT\]/{f=1;next}/\[\/CONTENT\]/{f=0} f')
                result=$(tool_write_file "$path" "$content")
            else
                case "$name" in read_file|list_directory|web_search|create_directory|copy_file|move_file|delete_file|run_command) result=$(tool_"$name" "$args") ;; *) result="Error: Unknown tool '$name'.";; esac
            fi
            all_results+="\n--- Result for '$name $args' ---\n$result"
        done <<< "$tool_lines"

        echo -e "${C_MAGENTA}--- ALL TOOL RESULTS ---${C_RESET}\n$all_results\n"
        conversation_history+="\n$ai_response\n[TOOL_RESULT]\n$all_results"
    done
    log_error "Max iterations reached."
}

# --- HELP & MAIN ---
show_help() {
    printf "${C_BOLD}${C_CYAN}AI CLI Agent v7.1${C_RESET}\n\n"
    printf "A fully supervised filesystem & shell agent with multi-tool execution capabilities.\n\n"
    printf "${C_BOLD}${C_YELLOW}USAGE:${C_RESET}\n"
    printf "  ${C_GREEN}ai${C_RESET} \"Your high-level development or system task\"\n\n"
    printf "${C_BOLD}${C_YELLOW}UTILITY:${C_RESET}\n"
    printf "  ${C_GREEN}ai --setup${C_RESET}              Install all required dependencies.\n"
    printf "  ${C_GREEN}ai --help${C_RESET}               Show this help message.\n\n"
    printf "${C_BOLD}${C_YELLOW}EXAMPLE:${C_RESET}\n"
    printf "  ${C_CYAN}ai \"Create a new project 'my-app' in ~/ai_projects, cd into it, and initialize a git repository.\"${C_RESET}\n"
}

main() {
    check_dependencies ollama curl jq tree lynx
    if [[ $# -eq 0 ]]; then show_help && exit 0; fi
    case "$1" in
        --setup)
            log "Installing dependencies..."; if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y tree jq lynx nodejs npm python3 git;
            elif command -v brew &>/dev/null; then brew install tree jq lynx node python git; fi
            log_success "Setup complete.";;
        --help) show_help ;;
        *) run_interactive_agent "$@" ;;
    esac
}
main "$@"
