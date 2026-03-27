#!/bin/bash
# Compile standalone Typst diagram wrappers to PDF
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DIAGRAMS_DIR="$SCRIPT_DIR/diagrams"
OUTPUT_DIR="$REPO_DIR/figures/diagrams"

mkdir -p "$OUTPUT_DIR"

for typ_file in "$DIAGRAMS_DIR"/*.typ; do
    name="$(basename "$typ_file" .typ)"
    echo "Compiling $name.typ -> $name.pdf"
    typst compile "$typ_file" "$OUTPUT_DIR/$name.pdf"
done

echo "Diagrams exported to $OUTPUT_DIR"
