#!/usr/bin/env bash

set -euo pipefail

ENABLE_HARD_LINE_BREAKS=false
INPUT_FILE=""
PARSE_OPTIONS=true

while [ $# -gt 0 ]; do
    if [ "$PARSE_OPTIONS" = true ]; then
        case "$1" in
            -hlb|--hard-line-breaks)
                ENABLE_HARD_LINE_BREAKS=true
                ;;
            -h|--help)
                echo "Usage: $0 [-hlb] <markdown_file.md>"
                echo "  -hlb  Preserve single line breaks in Word output."
                exit 0
                ;;
            --)
                PARSE_OPTIONS=false
                shift
                continue
                ;;
            -*)
                echo "Error: Unknown option '$1'"
                echo "Usage: $0 [-hlb] <markdown_file.md>"
                exit 1
                ;;
            *)
                if [ -n "$INPUT_FILE" ]; then
                    echo "Error: Multiple input files are not supported."
                    echo "Usage: $0 [-hlb] <markdown_file.md>"
                    exit 1
                fi
                INPUT_FILE="$1"
                ;;
        esac
    else
        if [ -n "$INPUT_FILE" ]; then
            echo "Error: Multiple input files are not supported."
            echo "Usage: $0 [-hlb] <markdown_file.md>"
            exit 1
        fi
        INPUT_FILE="$1"
    fi
    shift
done

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 [-hlb] <markdown_file.md>"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found at '$INPUT_FILE'"
    exit 1
fi

DIR=$(dirname "$INPUT_FILE")
BASENAME=$(basename -- "$INPUT_FILE")
FILENAME="${BASENAME%.*}"

OUTPUT_FILE="$DIR/$FILENAME.docx"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTERS_DIR="$SCRIPT_DIR/filters"
CONFIG_DIR="$SCRIPT_DIR/config"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Ensure user-local installs (e.g. npm --prefix ~/.local) are discoverable.
if [[ -n "${HOME:-}" ]]; then
    case ":${PATH}:" in
        *":${HOME}/.local/bin:"*) ;;
        *) export PATH="${HOME}/.local/bin:${PATH}" ;;
    esac
fi

TMP_MERMAID_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_MERMAID_DIR"
}
trap cleanup EXIT

# High-resolution PNG defaults for better Word compatibility.
export MERMAID_FILTER_FORMAT="${MERMAID_FILTER_FORMAT:-png}"
export MERMAID_FILTER_LOC="${MERMAID_FILTER_LOC:-$TMP_MERMAID_DIR}"
export MERMAID_FILTER_WIDTH="${MERMAID_FILTER_WIDTH:-2400}"
export MERMAID_FILTER_SCALE="${MERMAID_FILTER_SCALE:-3}"
export MERMAID_FILTER_THEME="${MERMAID_FILTER_THEME:-default}"
export MERMAID_FILTER_BACKGROUND="${MERMAID_FILTER_BACKGROUND:-white}"

if [ -f "$CONFIG_DIR/mermaid-config.json" ]; then
    export MERMAID_FILTER_MERMAID_CONFIG="$CONFIG_DIR/mermaid-config.json"
elif [ -f "$SCRIPT_DIR/.mermaid-config.json" ]; then
    export MERMAID_FILTER_MERMAID_CONFIG="$SCRIPT_DIR/.mermaid-config.json"
fi

if [ -f "$SCRIPT_DIR/.puppeteer.json" ]; then
    export MERMAID_FILTER_PUPPETEER_CONFIG="$SCRIPT_DIR/.puppeteer.json"
fi

REFERENCE_DOC="$TEMPLATES_DIR/custom-reference.docx"
REMOVE_HEADING_FILTER="$FILTERS_DIR/normalize-headings.lua"

MERMAID_CAPTION_FILTER="$FILTERS_DIR/mermaid-caption-from-text.lua"

MERMAID_IMAGE_FILTER="$FILTERS_DIR/mermaid-image-to-figure.lua"

INPUT_FORMAT="markdown+lists_without_preceding_blankline"
if [ "$ENABLE_HARD_LINE_BREAKS" = true ]; then
    INPUT_FORMAT="$INPUT_FORMAT+hard_line_breaks"
fi

PANDOC_ARGS=(
    --from "$INPUT_FORMAT"
    --lua-filter="$REMOVE_HEADING_FILTER"
    --lua-filter="$MERMAID_CAPTION_FILTER"
    --filter mermaid-filter
    --lua-filter="$MERMAID_IMAGE_FILTER"
    --filter pandoc-crossref
    --syntax-highlighting=tango
    -M figPrefix="Figur"
    -M figureTitle="Figur"
    -o "$OUTPUT_FILE"
)

if [ -f "$REFERENCE_DOC" ]; then
    PANDOC_ARGS+=(--reference-doc="$REFERENCE_DOC")
else
    echo "Warning: custom-reference.docx not found; using pandoc default docx template."
fi

if ! command -v mermaid-filter >/dev/null 2>&1; then
    echo "Error: Could not find executable mermaid-filter in PATH."
    echo "Run ./install.sh or add ~/.local/bin to PATH."
    exit 1
fi

pandoc "$INPUT_FILE" "${PANDOC_ARGS[@]}"

echo "Successfully created '$OUTPUT_FILE'"
