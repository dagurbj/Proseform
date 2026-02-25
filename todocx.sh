#!/usr/bin/env bash

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <markdown_file.md>"
    exit 1
fi

INPUT_FILE="$1"

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
REMOVE_HEADING_FILTER="$FILTERS_DIR/remove-heading-numbers.lua"

MERMAID_CAPTION_FILTER="$FILTERS_DIR/mermaid-caption-from-text.lua"

MERMAID_IMAGE_FILTER="$FILTERS_DIR/mermaid-image-to-figure.lua"

PANDOC_ARGS=(
    --from markdown+lists_without_preceding_blankline
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

pandoc "$INPUT_FILE" "${PANDOC_ARGS[@]}"

echo "Successfully created '$OUTPUT_FILE'"
