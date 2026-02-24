# DocConverter Markdown to DOCX (PNG Mermaid)

This release package converts a Markdown file to `.docx` using `todocx.sh`, including Mermaid diagrams rendered as high-resolution PNG images.

## Included files

- `todocx.sh`
- `install.sh`
- `remove-heading-numbers.lua`
- `mermaid-caption-from-text.lua`
- `mermaid-image-to-figure.lua`
- `mermaid-config.json`
- `custom-reference.docx`

Keep these files in the same directory.

## Linux installation

Run:

```bash
./install.sh
```

The installer sets up the required tools:

- `pandoc`
- `pandoc-crossref`
- `nodejs` and `npm`
- npm package `mermaid-filter` (includes Mermaid CLI)
- common Chromium runtime libraries used by Mermaid rendering

## Usage

Convert a Markdown file:

```bash
./todocx.sh path/to/file.md
```

This creates:

- `path/to/file.docx`

## Notes

- `custom-reference.docx` controls Word styling/template output.
- If you remove `custom-reference.docx`, conversion still works, but Pandoc uses its default DOCX template.
