# -----------------------
# AI Subcommand: Generate Dynamic README
# -----------------------
ai_readme_dynamic() {
    local readme_file="README.md"
    local script_file="$HOME/bin/ai"

    if [[ ! -f "$script_file" ]]; then
        log_error "Script $script_file not found."
        return 1
    fi

    # Extract function names
    local functions
    functions=$(grep -E '^[a-zA-Z0-9_]+\(\)\s*\{' "$script_file" | sed 's/() {//')

    # Extract modes from case statement
    local modes
    modes=$(grep -E '^\s*"[^"]+"\)' "$script_file" | sed 's/[[:space:]]*"//;s/")//')

    cat > "$readme_file" <<EOF
# 🧠 AI / AGI / AIM Unified Processing Tool

**Author:** Aris Arjuna Noorsanto <exe.opcode@gmail.com>  
**License:** Private / Inhouse Use Only  

---

## 📜 Overview

This project provides a **single-file automation tool** (\`~/bin/ai\`) for unified AI processing.  
All functionality is embedded in one script. No additional files are required.

---

## ⚙️ Core Modes

The script dynamically supports the following modes:

EOF

    for mode in $modes; do
        echo "- \`$mode\`" >> "$readme_file"
    done

    echo -e "\n## 🔧 Available Functions\n" >> "$readme_file"
    for func in $functions; do
        echo "- \`$func\`" >> "$readme_file"
    done

    cat >> "$readme_file" <<EOF

---

## 📜 Universal Law

A string embedded in the script (:BOF: … :EOF:) defines layout, symmetry, golden ratio handling, and context-aware guidance.

---

## 🛠 Features

- Single-file and pipeline processing
- Script-aware optimization
- Regex batch processing
- Environment scanning
- Backup system (\$HOME/.ai_backups)
- JS/DOM enhancements, CSS themes, ARIA roles
- Event listener monitoring
- Web scraping, respecting robots.txt
- Screenshots and virtual ratios
- Watch mode for automatic file changes
- Prompt processing: URLs, local files, or direct strings
- Integrated Ollama AI support (gemma3:1b)
- Modular, reusable routines

---

## 🚀 Usage Examples

\`\`\`bash
~/bin/ai - index.html
~/bin/ai + script.js
~/bin/ai * "*.html"
~/bin/ai : index.html:style.css
~/bin/ai . 
~/bin/ai agi + ./project
~/bin/ai agi - index.html
~/bin/ai https://example.com
~/bin/ai readme
\`\`\`

EOF

    log_success "Dynamic README.md generated successfully."
}