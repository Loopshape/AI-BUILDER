#!/usr/bin/env bash
# ~/.ai_builder/ai_build.sh
# Local snippet assembly + URL ingestion + hashed builds + verbose Deepseek thinking + server auto-start + syntax highlighting
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
ROTATE_THRESHOLD_BYTES=${ROTATE_THRESHOLD_BYTES:-5242880} # 5MB

# --- bootstrap ---
mkdir -p "$BUILD_DIR" "$SNIPPET_DIR" "$TMP_DIR"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

rotate_think_log() {
  if [[ -f "$THINK_LOG" ]]; then
    local size
    size=$(stat -c%s "$THINK_LOG" 2>/dev/null || echo 0)
    if (( size > ROTATE_THRESHOLD_BYTES )); then
      local stamp
      stamp=$(date '+%Y%m%d%H%M%S')
      mv -f "$THINK_LOG" "$THINK_LOG.$stamp"
      log "Rotated thinking log -> $THINK_LOG.$stamp"
    fi
  fi
}

# --- load hash index ---
declare -A HASHES
if [[ -f "$HASH_INDEX" ]]; then
  while IFS= read -r line; do
    if [[ $line =~ \"([^\"]+)\":\ *\"([^\"]+)\" ]]; then
      HASHES["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done < "$HASH_INDEX"
fi

hash_file() {
  if [[ -f "$1" ]]; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo ""
  fi
}

is_url() { [[ "$1" =~ ^https?:// ]]; }

# --- fetch URL snippet ---
fetch_url_snippet() {
  local url="$1"
  local fname tmp newhash oldhash fpath
  fname="$(echo -n "$url" | sha256sum | awk '{print $1}').html"
  fpath="$SNIPPET_DIR/$fname"
  tmp="$TMP_DIR/$fname.tmp"

  log "Fetching URL: $url"
  if ! curl -fSLs --retry 2 --retry-delay 1 --output "$tmp" "$url"; then
    log "ERROR: Failed to fetch URL: $url"
    [[ -f "$tmp" ]] && rm -f "$tmp"
    return 1
  fi

  newhash=$(sha256sum "$tmp" | awk '{print $1}')
  oldhash=$(hash_file "$fpath")
  if [[ "$newhash" != "$oldhash" ]]; then
    mv -f "$tmp" "$fpath"
    HASHES["$fpath"]="$newhash"
    log "Saved URL snippet -> $fpath (hash: $newhash)"
  else
    rm -f "$tmp"
    log "URL snippet unchanged: $url"
  fi
  return 0
}

# --- assemble local snippets ---
assemble_local_snippets() {
  log "Starting mandatory assembly: $SNIPPET_DIR -> $OUTPUT_FILE"
  : > "$OUTPUT_FILE"
  while IFS= read -r -d '' f; do
    cat "$f" >> "$OUTPUT_FILE"
    printf "\n<!-- --- snippet: %s --- -->\n\n" "$(basename "$f")" >> "$OUTPUT_FILE"
    local h prev
    h="$(hash_file "$f")"
    prev="${HASHES["$f"]:-}"
    if [[ -n "$h" && "$h" != "$prev" ]]; then
      HASHES["$f"]="$h"
      log "Included updated snippet: $f (hash: $h)"
    else
      log "Included snippet: $f"
    fi
  done < <(find "$SNIPPET_DIR" -maxdepth 1 -type f \( -iname '*.html' -o -iname '*.htm' -o -iname '*.css' -o -iname '*.js' -o -iname '*.txt' \) -print0 | LC_ALL=C sort -z)
  log "Assembly complete -> $OUTPUT_FILE"
}

# --- syntax highlighting ---
add_syntax_highlighting() {
  local prism_css_url="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/themes/prism-tomorrow.css"
  local prism_js_url="https://cdn.jsdelivr.net/npm/prismjs@1.29.0/prism.js"

  if ! grep -q "Prism" "$OUTPUT_FILE"; then
    log "Adding Prism.js syntax highlighting to $OUTPUT_FILE"
    sed -i '1i\<link href="'"$prism_css_url"'" rel="stylesheet" />\n<script src="'"$prism_js_url"'"></script>\n<script>Prism.highlightAll();</script>' "$OUTPUT_FILE"
  fi

  while IFS= read -r -d '' f; do
    ext="${f##*.}"
    lang=""
    case "$ext" in
      js) lang="javascript";;
      html|htm) lang="html";;
      css) lang="css";;
      txt) lang="none";;
    esac
    if ! grep -q "<pre><code class=" "$f"; then
      tmpf="$TMP_DIR/$(basename "$f")"
      echo "<pre><code class=\"language-$lang\">" > "$tmpf"
      cat "$f" >> "$tmpf"
      echo "</code></pre>" >> "$tmpf"
      mv -f "$tmpf" "$f"
      log "Wrapped $f with syntax highlighting tags for $lang"
    fi
  done < <(find "$SNIPPET_DIR" -maxdepth 1 -type f \( -iname '*.html' -o -iname '*.htm' -o -iname '*.css' -o -iname '*.js' -o -iname '*.txt' \) -print0)
}

# --- run model with verbose thinking ---
run_model() {
  local prompt="$1"
  if [[ -z "$OLLAMA_BIN" ]]; then
    log "ERROR: ollama not found. Set OLLAMA_BIN or install ollama."
    return 2
  fi
  rotate_think_log
  log "Running model ${MODEL_ALIAS} ($MODEL) with thinking shown..."
  "$OLLAMA_BIN" run "$MODEL" --think "$prompt" 2>&1 | tee -a "$THINK_LOG"
}

# --- save hash index ---
save_hash_index() {
  local tmp="$BUILD_DIR/hash_index.json.tmp"
  {
    echo "{"
    for k in "${!HASHES[@]}"; do
      printf '  "%s": "%s",\n' "$k" "${HASHES[$k]}"
    done
  } > "$tmp"
  if [[ -s "$tmp" ]]; then
    sed -i '$ s/,$//' "$tmp" || true
  fi
  printf '\n}\n' >> "$tmp"
  mv -f "$tmp" "$HASH_INDEX"
  log "Saved hash index -> $HASH_INDEX"
}

# --- ensure Ollama server is running ---
ensure_ollama_server() {
  if ! pgrep -f "ollama serve" >/dev/null; then
    log "Ollama server not running. Starting in background..."
    nohup "$OLLAMA_BIN" serve >/dev/null 2>&1 &
    sleep 2
    log "Ollama server started."
  else
    log "Ollama server already running."
  fi
}

# --- main entry ---
main() {
  local url_args=()
  local prompt_parts=()

  for a in "$@"; do
    if is_url "$a"; then
      url_args+=("$a")
    else
      prompt_parts+=("$a")
    fi
  done

  if [[ ${#url_args[@]} -eq 0 && ${#prompt_parts[@]} -eq 0 ]]; then
    ensure_ollama_server
    log "No prompt given. Server ensured. Exiting."
    return 0
  fi

  for u in "${url_args[@]}"; do
    fetch_url_snippet "$u" || log "Warning: fetch failed for $u"
  done

  assemble_local_snippets
  add_syntax_highlighting
  save_hash_index

  local PROMPT
  if [[ ${#prompt_parts[@]} -gt 0 ]]; then
    PROMPT="${prompt_parts[*]}"
  else
    PROMPT="Please inspect and summarise the assembled webpage at path: $OUTPUT_FILE. Provide errors, suggestions, and an action list."
  fi

  ensure_ollama_server
  run_model "$PROMPT"
}

main "$@"
