# Proseform

Proseform turns Markdown into polished Word (`.docx`) using `todocx.sh`, with Mermaid diagrams rendered as crisp, high-resolution PNGs. Use it when you want docs that read well in Word without giving up Markdown authoring.

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

Try it: after installing, test Proseform's capabilities by converting `DEMO.md`:

```bash
./todocx.sh DEMO.md
```

This creates:

- `path/to/file.docx`
- `DEMO.docx`

## Notes

- `custom-reference.docx` controls Word styling/template output.
- If you remove `custom-reference.docx`, conversion still works, but Pandoc uses its default DOCX template.
