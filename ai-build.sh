#!/usr/bin/env bash
# ~/bin/ai
# AI/AGI/AIM Unified Processing Tool v4.0
# Rewritten with a unified, multimodal CLI that intelligently handles any input type.

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
BUILD_DIR="${BUILD_DIR:-$HOME/.ai_builder}"
MODEL="${MODEL:-deepseek-r1:1.5b}"
MULTIMODAL_MODEL="${MULTIMODAL_MODEL:-llava:latest}"
OLLAMA_BIN="${OLLAMA_BIN:-$(command -v ollama || true)}"
TMP_DIR="$BUILD_DIR/tmp"
LAST_RESPONSE_FILE="${BUILD_DIR}/last_response.txt"

# --- COLORS & LOGGING ---
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'
log() { printf "${C_BLUE}[%s]${C_RESET} %s\n" "$(date '+%T')" "$*"; }
log_success() { log "${C_GREEN}$*${C_RESET}"; }
log_warn() { log "${C_YELLOW}WARN: $*${C_RESET}"; }
log_error() { log "${C_RED}ERROR: $*${C_RESET}"; exit 1; }

# --- BOOTSTRAP ---
mkdir -p "$BUILD_DIR" "$TMP_DIR"

# --- CORE UTILITIES ---
check_dependencies() { for cmd in "$@"; do if ! command -v "$cmd" >/dev/null; then log_warn "Required command '$cmd' is not found. Run 'ai --setup'."; fi; done; }
is_url() { [[ "$1" =~ ^https?:// ]]; }
ensure_ollama_server() { if ! pgrep -f "ollama serve" >/dev/null; then log "Ollama server starting..."; nohup "$OLLAMA_BIN" serve >/dev/null 2>&1 & sleep 2; fi; }

# --- UNIFIED MULTIMODAL PROCESSING (The New Core) ---

run_unified_processing() {
    if [[ $# -eq 0 ]]; then show_help; return; fi

    local image_paths=()
    local text_context_parts=()
    local prompt_parts=()

    log "Parsing all inputs to build context..."

    for arg in "$@"; do
        # --- 1. Check for Local File ---
        if [[ -f "$arg" ]]; then
            local mime_type; mime_type=$(file --brief --mime-type "$arg")
            if [[ "$mime_type" == image/* ]]; then
                log "Identified local image: ${C_CYAN}$arg${C_RESET}"
                image_paths+=("$(realpath "$arg")")
            elif [[ "$mime_type" == text/* || "$mime_type" == application/* ]]; then
                log "Identified local text file: ${C_CYAN}$arg${C_RESET}"
                text_context_parts+=("--- START OF FILE: $arg ---\n$(<"$arg")\n--- END OF FILE: $arg ---")
            else
                log_warn "Skipping unsupported local file type ($mime_type): $arg"
            fi
        # --- 2. Check for URL ---
        elif is_url "$arg"; then
            local content_type
            content_type=$(curl -sILf "$arg" | grep -i '^Content-Type:' | awk '{print $2}' | tr -d ';')
            
            if [[ "$content_type" == image/* ]]; then
                log "Identified image URL: ${C_CYAN}$arg${C_RESET}"
                local tmp_img; tmp_img=$(mktemp --suffix=".img")
                curl -sL -o "$tmp_img" "$arg"
                image_paths+=("$tmp_img")
            elif [[ "$arg" =~ youtu\.be|youtube\.com ]]; then
                log "Identified video URL, extracting metadata: ${C_CYAN}$arg${C_RESET}"
                if command -v yt-dlp >/dev/null; then
                    local title; title=$(yt-dlp --get-title "$arg")
                    local desc; desc=$(yt-dlp --get-description "$arg")
                    text_context_parts+=("--- START VIDEO METADATA: $arg ---\nTitle: $title\nDescription: $desc\n--- END VIDEO METADATA ---")
                else
                    log_warn "yt-dlp not found. Cannot process video URL. Skipping."
                fi
            elif [[ "$content_type" == text/html* ]]; then
                 log "Identified web page, fetching content: ${C_CYAN}$arg${C_RESET}"
                 local page_content; page_content=$(curl -sL "$arg" | lynx -dump -stdin -nolist)
                 text_context_parts+=("--- START WEB PAGE CONTENT: $arg ---\n$page_content\n--- END WEB PAGE CONTENT ---")
            else
                log "Identified generic URL, fetching as text: ${C_CYAN}$arg${C_RESET}"
                local generic_content; generic_content=$(curl -sL "$arg")
                text_context_parts+=("--- START URL CONTENT: $arg ---\n$generic_content\n--- END URL CONTENT ---")
            fi
        # --- 3. Assume it's part of the text prompt ---
        else
            prompt_parts+=("$arg")
        fi
    done

    # --- 4. Assemble and Execute ---
    local final_prompt; final_prompt="${prompt_parts[*]}"
    local final_context; IFS=$'\n'; final_context="${text_context_parts[*]}"; unset IFS

    if [[ -z "$final_prompt" ]]; then
        final_prompt="Please provide a comprehensive analysis of the provided context. Summarize the key information, identify relationships between different pieces of context (including any images), and create a concise list of insights or action items."
    fi

    local full_task_prompt="USER PROMPT: \"${final_prompt}\"\n\n--- PROVIDED TEXT CONTEXT ---\n${final_context}"

    ensure_ollama_server

    if [[ ${#image_paths[@]} -gt 0 ]]; then
        log_success "Executing in MULTIMODAL mode with ${#image_paths[@]} image(s)..."
        local combined_output=""
        for img_path in "${image_paths[@]}"; do
            log "Processing with image: ${C_CYAN}$img_path${C_RESET}"
            local response
            response=$("$OLLAMA_BIN" run "$MULTIMODAL_MODEL" "$full_task_prompt" --image "$img_path")
            combined_output+="\n--- ANALYSIS FOR IMAGE: $(basename "$img_path") ---\n${response}\n"
            echo -e "$response" # Live output
        done
        echo -e "$combined_output" > "$LAST_RESPONSE_FILE"
    else
        log_success "Executing in TEXT-ONLY mode..."
        "$OLLAMA_BIN" run "$MODEL" "$full_task_prompt" | tee >(sed -e 's/.*\r//' -e '/^\s*$/d' > "$LAST_RESPONSE_FILE")
    fi
}

# --- OTHER MODES (Rebounce, Setup, Help) ---

run_rebounce() {
    if [[ ! -s "$LAST_RESPONSE_FILE" ]]; then log_error "No previous response to rebounce."; fi
    local prev; prev=$(<"$LAST_RESPONSE_FILE")
    local instruction="${*:-Critique your previous response and provide a better, more accurate alternative.}"
    local prompt="Feedback Loop: Improve the previous response based on this new instruction: \"$instruction\"\n\n--- PREVIOUS RESPONSE ---\n${prev}"
    ensure_ollama_server
    "$OLLAMA_BIN" run "$MODEL" "$prompt" | tee >(sed -e 's/.*\r//' -e '/^\s*$/d' > "$LAST_RESPONSE_FILE")
}

run_setup() {
    log "Running setup for dependencies..."
    if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y tree jq lynx file yt-dlp;
    elif command -v brew &>/dev/null; then brew install tree jq lynx file yt-dlp; fi
    log_warn "This script's multimodal features require a model like LLaVA. Please run: ${C_BOLD}ollama pull ${MULTIMODAL_MODEL}${C_RESET}"
    log_success "Setup check complete."
}

show_help() {
    printf "${C_BOLD}${C_CYAN}AI/AGI/AIM Unified Tool v4.0 - Unified Multimodal Input${C_RESET}\n\n"
    printf "A smart CLI that intelligently processes any combination of text, files, and URLs.\n\n"
    
    printf "${C_BOLD}${C_YELLOW}PRIMARY USAGE:${C_RESET}\n"
    printf "  ${C_GREEN}ai${C_RESET} [item1] [item2] ... \"your prompt\"\n"
    printf "  The script automatically identifies each 'item' as a local file, a URL (webpage,\n"
    printf "  image, video), or part of the text prompt itself.\n\n"

    printf "${C_BOLD}${C_YELLOW}SUPPORTED ITEMS:${C_RESET}\n"
    printf "  ${C_CYAN}Text/Prompt:${C_RESET}        Any string that is not a file or URL.\n"
    printf "  ${C_CYAN}Local File:${C_RESET}         Path to a local image or text file (e.g., './img.png', 'code.py').\n"
    printf "  ${C_CYAN}Image URL:${C_RESET}          Direct URL to an image (e.g., 'https://.../photo.jpg').\n"
    printf "  ${C_CYAN}Web Page URL:${C_RESET}       URL to an HTML page (e.g., 'https://example.com').\n"
    printf "  ${C_CYAN}Video URL:${C_RESET}          URL to a video (e.g., YouTube), metadata will be extracted.\n\n"

    printf "${C_BOLD}${C_YELLOW}OTHER MODES:${C_RESET}\n"
    printf "  ${C_GREEN}--rebounce${C_RESET} [prompt]   Feeds the last AI response back for refinement.\n"
    printf "  ${C_GREEN}--setup${C_RESET}              Install all required dependencies (like yt-dlp, lynx).\n"
    printf "  ${C_GREEN}--help${C_RESET}               Show this help message.\n\n"

    printf "${C_BOLD}${C_YELLOW}EXAMPLE:${C_RESET}\n"
    printf "  ${C_CYAN}ai ./diagram.png https://en.wikipedia.org/wiki/API \"Compare the diagram to the article\"${C_RESET}\n"
}

# --- MAIN DISPATCHER ---
main() {
    check_dependencies ollama curl file lynx
    if [[ $# -eq 0 ]]; then show_help; exit 0; fi

    case "$1" in
        --setup) run_setup ;;
        --help) show_help ;;
        --rebounce) shift; run_rebounce "$@" ;;
        -*) log_error "Unknown option $1. Use '--help' for usage." ;;
        *) run_unified_processing "$@" ;;
    esac
}

main "$@"
