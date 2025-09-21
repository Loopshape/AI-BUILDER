#!/usr/bin/env bash
# ~/bin/ai
# AI/AGI/AIM Unified Processing Tool v6.5 - High-Entropy Planning Edition
# Uses a multi-model approach for planning and a mandatory model for execution.

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
BUILD_DIR="${BUILD_DIR:-$HOME/.ai_builder}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/ai_projects}"
MODEL="2244-1" # The mandatory project manager and execution model
BRAINSTORM_MODELS=("gemma3:1b" "deepseek-r1:1.5b") # The creative planning models
OLLAMA_BIN="${OLLAMA_BIN:-$(command -v ollama || true)}"
TMP_DIR="$BUILD_DIR/tmp"
MAX_ITERATIONS=15

# --- COLORS & LOGGING ---
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'; C_MAGENTA='\033[0;35m'
log() { printf "${C_BLUE}[%s]${C_RESET} %s\n" "$(date '+%T')" "$*"; }
log_success() { log "${C_GREEN}$*${C_RESET}"; }
log_warn() { log "${C_YELLOW}WARN: $*${C_RESET}"; }
log_error() { log "${C_RED}ERROR: $*${C_RESET}"; exit 1; }
log_phase() { log "${C_BOLD}${C_MAGENTA}--- $1 ---${C_RESET}"; }

# --- BOOTSTRAP ---
mkdir -p "$BUILD_DIR" "$TMP_DIR" "$PROJECTS_DIR"

# --- CORE UTILITIES ---
check_dependencies() { for cmd in "$@"; do if ! command -v "$cmd" >/dev/null; then log_warn "Required command '$cmd' not found. Run 'ai --setup'."; fi; done; }
ensure_ollama_server() { if ! pgrep -f "ollama serve" >/dev/null; then log "Ollama server starting..."; nohup "$OLLAMA_BIN" serve >/dev/null 2>&1 & sleep 3; fi; }
confirm_action() { echo -e "${C_YELLOW}PROPOSED ACTION:${C_RESET} ${C_BOLD}$1${C_RESET}"; read -p "Do you approve? [y/N] " -n 1 -r c; echo; if [[ "${c-n}" =~ ^[Yy]$ ]]; then return 0; else return 1; fi; }
generate_task_id() { echo -n "$1" | sha256sum | awk '{print $1}'; }

# --- AGENT TOOLS (Unchanged) ---
tool_read_file() { if [[ -f "$1" ]]; then cat "$1"; else echo "Error: File not found: $1"; fi; }
tool_list_directory() { local p="${1:-.}"; if [[ -d "$p" ]]; then tree -L 2 "$p"; else echo "Error: Dir not found: $p"; fi; }
tool_web_search() { local q="$*"; local enc_q; enc_q=$(jq -nr --arg q "$q" '$q|@uri'); local s; s=$(curl -sL "https://html.duckduckgo.com/html/?q=${enc_q}"|lynx -dump -stdin -nolist); echo "Search results for '$q':\n$s"; }
tool_write_file() { local p="$1" c="$2"; if confirm_action "Write to file: $p"; then mkdir -p "$(dirname "$p")"; echo -e "$c" > "$p"; echo "Success: File written."; else echo "User aborted."; fi; }
tool_run_command() { local cmd="$*"; if confirm_action "Run shell command: ${C_CYAN}$cmd${C_RESET}"; then (cd "$PROJECTS_DIR/$(cat $TMP_DIR/current_task_id)" && eval "$cmd") 2>&1; else echo "User aborted."; fi; }

# --- AGENT CORE (Re-architected) ---
run_and_capture() { local p="$1" m="$2"; ensure_ollama_server; "$OLLAMA_BIN" run "$m" "$p"; }

execute_plan() {
    local plan_json="$1"; local task_id="$2"; local user_prompt="$3"
    local conversation_history="You are an expert AI developer agent executing a pre-approved plan.
--- INITIAL USER PROMPT ---
$user_prompt
--- FINAL EXECUTION PLAN ---
$(echo "$plan_json" | jq .)
---
Begin execution now. For each step, provide your reasoning and then the tool call."

    for (( i=1; i<=MAX_ITERATIONS; i++ )); do
        log "Execution Step $i/$MAX_ITERATIONS"; echo -e "${C_YELLOW}--- AI Thought Process ---${C_RESET}"
        local ai_response; ai_response=$(echo "$conversation_history" | run_and_capture - "$MODEL" | tee /dev/tty)
        echo -e "${C_YELLOW}--- End of Thought ---${C_RESET}"

        if [[ "$ai_response" == *"[FINAL_ANSWER]"* ]]; then log_success "Task complete."; echo "$ai_response"|awk 'BEGIN{p=0} /\[FINAL_ANSWER\]/{p=1; next} p'; return; fi
        local tool_line; tool_line=$(echo "$ai_response"|grep '\[TOOL\]'|sed 's/\[TOOL\] *//'|head -n 1); if [[ -z "$tool_line" ]]; then log_warn "No tool chosen. Assuming final answer."; echo "$ai_response"; return; fi
        local tool_name; tool_name=$(echo "$tool_line"|awk '{print $1}'); local tool_args; tool_args=$(echo "$tool_line"|cut -d' ' -f2-); log "Executing tool: ${C_CYAN}$tool_name${C_RESET} ${C_YELLOW}$tool_args${C_RESET}"; local tool_result=""
        
        # Save current task ID for tool context
        echo "$task_id" > "$TMP_DIR/current_task_id"

        if [[ "$tool_name" == "write_file" ]]; then local p="$tool_args"; local c; c=$(echo "$ai_response"|awk '/\[CONTENT\]/{f=1;next} /\[\/CONTENT\]/{f=0} f'); tool_result=$(tool_write_file "$PROJECTS_DIR/$task_id/$p" "$c");
        else case "$tool_name" in read_file) tool_result=$(tool_read_file "$PROJECTS_DIR/$task_id/$tool_args");; list_directory) tool_result=$(tool_list_directory "$PROJECTS_DIR/$task_id/$tool_args");; web_search|run_command) tool_result=$(tool_"$tool_name" "$tool_args");; *) tool_result="Error: Unknown tool '$tool_name'.";; esac; fi
        
        echo -e "${C_MAGENTA}--- TOOL RESULT ---${C_RESET}\n${tool_result}\n"; conversation_history+="\n${ai_response}\n[TOOL_RESULT]\n${tool_result}"
    done
    log_error "Max iterations reached."
}

# --- MAIN WORKFLOW ---
run_full_cycle() {
    local user_prompt="$*"
    
    # PHASE 0: HASHING & SETUP
    log_phase "PHASE 0: Initializing Task"
    local task_id; task_id=$(generate_task_id "$user_prompt")
    local task_dir="$PROJECTS_DIR/$task_id"
    mkdir -p "$task_dir"
    log_success "Task ID: $task_id"
    log_success "Workspace created: $task_dir"

    # PHASE 1: HIGH-ENTROPY BRAINSTORMING
    log_phase "PHASE 1: High-Entropy Brainstorming"
    local brainstorm_prompt="You are a creative AI assistant. Your goal is to generate a detailed, step-by-step plan to solve the user's request. Be imaginative and thorough. The plan should be a list of actions.
User Request: ${user_prompt}"
    local raw_plans=""
    for brain_model in "${BRAINSTORM_MODELS[@]}"; do
        log "Querying brainstorming model: ${C_CYAN}$brain_model${C_RESET}"
        local plan; plan=$(run_and_capture "$brainstorm_prompt" "$brain_model")
        raw_plans+="\n--- PLAN FROM ${brain_model} ---\n${plan}\n"
    done
    echo -e "$raw_plans" > "$task_dir/01_brainstorming_output.log"
    log_success "Brainstorming complete."

    # PHASE 2: PLAN SYNTHESIS
    log_phase "PHASE 2: Synthesizing Final Plan"
    local synthesis_prompt="You are a logical project manager. You have received two creative plans from your team. Your job is to analyze them, discard unfeasible ideas, and synthesize them into a single, robust, and actionable JSON execution plan.
The plan must be a JSON object with a 'steps' array. Each step must have a 'tool' and 'arguments'.
Available Tools: \`read_file\`, \`list_directory\`, \`web_search\`, \`write_file\`, \`run_command\`.
All file paths in your plan must be relative to the project root.

--- RAW PLANS ---
${raw_plans}
---
Generate the final, consolidated JSON plan now."
    
    local final_plan_json; final_plan_json=$(run_and_capture "$synthesis_prompt" "$MODEL" | sed -n '/^{/,/}$/p' | jq -c .)
    
    if ! echo "$final_plan_json" | jq . > /dev/null 2>&1; then log_error "Failed to synthesize a valid JSON plan. Halting."; fi
    echo "$final_plan_json" | jq . > "$task_dir/02_final_plan.json"
    log_success "Final execution plan synthesized and saved."

    # PHASE 3: EXECUTION
    log_phase "PHASE 3: Executing Plan"
    execute_plan "$final_plan_json" "$task_id" "$user_prompt"
}


# --- HELP & MAIN DISPATCHER ---
show_help() {
    printf "${C_BOLD}${C_CYAN}AI Agent v6.5 - High-Entropy Planning Edition${C_RESET}\n\n"
    printf "An agent that uses a creative team of AI models to plan and a logical AI to execute.\n\n"
    printf "${C_BOLD}${C_YELLOW}PRIMARY USAGE:${C_RESET}\n"
    printf "  ${C_GREEN}ai${C_RESET} \"Your high-level goal or project idea\"\n"
    printf "  The agent will: 1. Brainstorm plans with creative models.\n"
    printf "                  2. Synthesize a final plan with a logical model.\n"
    printf "                  3. Execute the final plan with your approval for each step.\n\n"
    printf "${C_BOLD}${C_YELLOW}UTILITY:${C_RESET}\n"
    printf "  ${C_GREEN}ai --setup${C_RESET}              Install all required dependencies.\n"
    printf "  ${C_GREEN}ai --help${C_RESET}               Show this help message.\n\n"
    printf "${C_BOLD}${C_YELLOW}EXAMPLE:${C_RESET}\n"
    printf "  ${C_CYAN}ai \"Create a simple website that uses the Pokemon API to display data for Pikachu.\"${C_RESET}\n"
}
main() {
    check_dependencies ollama curl jq tree lynx
    if [[ $# -eq 0 ]]; then show_help; exit 0; fi
    case "$1" in
        --setup)
            log "Installing dependencies..."; if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y tree jq file lynx git;
            elif command -v brew &>/dev/null; then brew install tree jq file lynx git; fi
            log_success "Setup complete.";;
        --help) show_help ;;
        *) run_full_cycle "$@" ;;
    esac
}
main "$@"
