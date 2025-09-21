#!/usr/bin/env bash
# ===============================
# Termux-ready Fully Enhanced AI Builder (with watch mode)
# ===============================

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG ---
BUILD_DIR="${BUILD_DIR:-$HOME/.ai_builder}"
SNIPPET_DIR="${SNIPPET_DIR:-$HOME/snippets}"
OUTPUT_FILE="${OUTPUT_FILE:-$BUILD_DIR/index.html}"
MODEL="${MODEL:-deepseek-r1:1.5b}"
MODEL_ALIAS="${MODEL_ALIAS:-2244-1}"
OLLAMA_BIN="${OLLAMA_BIN:-$(command -v ollama || true)}"
THINK_LOG="$BUILD_DIR/thinking.log"
HASH_INDEX="$BUILD_DIR/hash_index.json"
TMP_DIR="$BUILD_DIR/tmp"
AI_OUTPUT_JSON="$BUILD_DIR/ai_output.json"
ROTATE_THRESHOLD_BYTES=${ROTATE_THRESHOLD_BYTES:-5242880} # 5MB
PARALLEL_JOBS=${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 2)}

mkdir -p "$BUILD_DIR" "$SNIPPET_DIR" "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"/hs_* "$TMP_DIR"/urls_* 2>/dev/null || true' EXIT

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# --- HTML escape function ---
html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&#39;}"
  printf '%s' "$s"
}

# --- Log rotation ---
rotate_think_log() {
  if [[ -f "$THINK_LOG" ]]; then
    local size
    size=$(stat -c%s "$THINK_LOG" 2>/dev/null || echo 0)
    (( size > ROTATE_THRESHOLD_BYTES )) && mv -f "$THINK_LOG" "$THINK_LOG.$(date '+%Y%m%d%H%M%S')" && log "Rotated thinking log"
  fi
}

# --- Load hash index ---
declare -A HASHES
[[ -f "$HASH_INDEX" ]] && while IFS= read -r line; do
  [[ $line =~ \"([^\"]+)\":\ *\"([^\"]+)\" ]] && HASHES["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
done < "$HASH_INDEX"

hash_file() { [[ -f "$1" ]] && sha256sum "$1" | awk '{print $1}' || echo ""; }
is_url() { [[ "$1" =~ ^https?:// ]]; }
throttle_jobs() { while (( $(jobs -p | wc -l) >= PARALLEL_JOBS )); do sleep 0.08; done; }

# --- Extract URLs from prompt text ---
extract_urls_from_text() {
  local text="$1"
  grep -oE 'https?://[a-zA-Z0-9./?&=_-]+' <<< "$text" || true
}

# --- Fetch URL snippet ---
fetch_url_snippet() {
  local url="$1" fname tmp newhash oldhash fpath
  fname="$(echo -n "$url" | sha256sum | awk '{print $1}').html"
  fpath="$SNIPPET_DIR/$fname"
  tmp="$TMP_DIR/urls_$fname.tmp"
  curl -fSLs --retry 2 --retry-delay 1 --output "$tmp" "$url" || { log "Failed URL: $url"; return 1; }
  newhash=$(sha256sum "$tmp" | awk '{print $1}'); oldhash=$(hash_file "$fpath")
  [[ "$newhash" != "$oldhash" ]] && mv -f "$tmp" "$fpath" && HASHES["$fpath"]="$newhash" && log "Fetched URL -> $fpath" || rm -f "$tmp" && log "URL unchanged: $url"
}

fetch_urls_parallel() { local u; for u in "$@"; do throttle_jobs; fetch_url_snippet "$u" & done; wait; }

# --- Compute snippet hashes ---
compute_current_hashes() {
  local idx=0 f
  while IFS= read -r -d '' f; do
    idx=$((idx+1)); throttle_jobs
    ( sha256sum "$f" | awk '{print $1 "\t" FILENAME}' FILENAME="$f" > "$TMP_DIR/hs_$(printf '%05d' "$idx")" ) &
  done < <(find "$SNIPPET_DIR" -maxdepth 1 -type f \( -iname '*.html' -o -iname '*.htm' -o -iname '*.css' -o -iname '*.js' -o -iname '*.txt' \) -print0)
  wait
  : > "$TMP_DIR/current_hashes.txt"
  cat "$TMP_DIR"/hs_* 2>/dev/null | sort >> "$TMP_DIR/current_hashes.txt" || true
}

# --- Incremental snippet assembly ---
assemble_snippets_incremental() {
  compute_current_hashes
  local changed=0 prev h f
  while IFS=$'\t' read -r h f; do prev="${HASHES["$f"]:-}"; [[ "$h" != "$prev" ]] && changed=1 && break; done < "$TMP_DIR/current_hashes.txt"
  [[ $changed -eq 0 && -f "$OUTPUT_FILE" && $FORCE_REBUILD -eq 0 ]] && { log "No changes. Skipping assembly"; return 0; }
  : > "$OUTPUT_FILE"
  while IFS= read -r -d '' f; do
    cat "$f" >> "$OUTPUT_FILE"
    printf "\n<!-- --- snippet: %s --- -->\n\n" "$(basename "$f")" >> "$OUTPUT_FILE"
  done < <(find "$SNIPPET_DIR" -maxdepth 1 -type f \( -iname '*.html' -o -iname '*.htm' -o -iname '*.css' -o -iname '*.js' -o -iname '*.txt' \) -print0 | LC_ALL=C sort -z)
  log "Assembly complete -> $OUTPUT_FILE"
  while IFS=$'\t' read -r h f; do HASHES["$f"]="$h"; done < "$TMP_DIR/current_hashes.txt"
}

# --- Save hash index ---
save_hash_index() {
  local tmp="$BUILD_DIR/hash_index.json.tmp"
  { echo "{"; for k in "${!HASHES[@]}"; do printf '  "%s": "%s",\n' "$k" "${HASHES[$k]}"; done; } > "$tmp"
  [[ -s "$tmp" ]] && sed -i '$ s/,$//' "$tmp" || true
  printf '\n}\n' >> "$tmp"; mv -f "$tmp" "$HASH_INDEX"
  log "Saved hash index -> $HASH_INDEX"
}

# --- Ensure Ollama server (Termux) ---
ensure_ollama_server() {
    export OLLAMA_DEBUG=1
    if ! pgrep -f "ollama serve" >/dev/null; then
        nohup "$OLLAMA_BIN" serve >/dev/null 2>&1 &
        sleep 2
        log "Ollama server started (Termux auto-start)"
    else
        log "Ollama server already running"
    fi
}

# --- JSON validation ---
validate_json() { command -v jq >/dev/null && jq empty "$1" >/dev/null 2>&1 || grep -q '^{.*}$' "$1"; }

# --- Run AI async with live-tail in Termux ---
run_model_async() {
    local raw_prompt="$1"
    rotate_think_log

    local ALL_SNIPPETS
    ALL_SNIPPETS=$(cat "$SNIPPET_DIR"/* 2>/dev/null | sed 's/"/\\"/g' | tr '\n' ' ')

    local PROMPT_JSON="You are generating a Bitcoin info page. Respond STRICTLY in valid JSON:
{
  \"title\": \"<page title>\",
  \"sections\": [
    {\"heading\": \"<heading>\", \"content\": \"$ALL_SNIPPETS\"}
  ]
}
Actual content request: $raw_prompt"

    log "Launching model ${MODEL_ALIAS} ($MODEL) with mandatory verbose thinking"

    setsid "$OLLAMA_BIN" run "$MODEL" --format json --think "$PROMPT_JSON" --verbose \
        2>&1 | tee -a "$THINK_LOG" | tee "$AI_OUTPUT_JSON" &

    local pid=$!
    disown "$pid" 2>/dev/null || true
    log "Model started (PID: $pid). Thinking log live-tailed -> $THINK_LOG"

    # Termux live-tail
    tail -f "$THINK_LOG" 2>/dev/null &
}

# --- Watch snippet folder for changes ---
watch_snippets() {
    log "Entering WATCH MODE: monitoring $SNIPPET_DIR for changes..."
    command -v inotifywait >/dev/null || { log "inotifywait not installed. Install via 'pkg install inotify-tools'"; return 1; }

    while true; do
        inotifywait -q -e create -e modify -e delete -r "$SNIPPET_DIR" >/dev/null 2>&1
        log "Change detected in $SNIPPET_DIR. Rebuilding..."
        
        assemble_snippets_incremental
        save_hash_index
        ensure_ollama_server

        local PROMPT="Auto-build triggered by snippet folder change."
        run_model_async "$PROMPT"

        sleep 1
    done
}

# --- Dark Monokai CSS ---
MONOKAI_CSS=$(cat <<'EOF'
<style>
body { background-color: #272822; color: #f8f8f2; font-family: 'Fira Code', monospace; padding: 2rem; }
h1 { color: #f92672; }
h2 { color: #a6e22e; }
p  { color: #f8f8f2; line-height: 1.6; }
a  { color: #66d9ef; text-decoration: underline; }
pre, code { background-color: #3e3d32; padding: 0.2rem 0.4rem; border-radius: 4px; }
</style>
EOF
)

# --- MAIN ---
main() {
  FORCE_REBUILD=0
  WATCH_MODE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --watch) WATCH_MODE=1; shift ;;
      status) status_console; return 0 ;;
      *) break ;;
    esac
  done

  [[ $# -gt 0 ]] && FORCE_REBUILD=1

  local url_args=() prompt_parts=()
  for a in "$@"; do
    if is_url "$a"; then
      url_args+=("$a")
    else
      prompt_parts+=("$a")
      while IFS= read -r u; do url_args+=("$u"); done < <(extract_urls_from_text "$a")
    fi
  done

  [[ ${#url_args[@]} -gt 0 ]] && { 
    log "Fetching URLs for mandatory internet research in parallel..."
    fetch_urls_parallel "${url_args[@]}" 
  }

  assemble_snippets_incremental
  save_hash_index
  ensure_ollama_server

  if [[ $WATCH_MODE -eq 1 ]]; then
      watch_snippets
  else
      local PROMPT="${prompt_parts[*]:-Please summarise the assembled webpage at $OUTPUT_FILE.}"
      run_model_async "$PROMPT"
  fi
}

main "$@"
