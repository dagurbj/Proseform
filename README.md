# Proseform

Proseform turns Markdown into polished Word (`.docx`) using `todocx.sh`, with Mermaid diagrams rendered as crisp, high-resolution PNGs. Use it when you want docs that read well in Word without giving up Markdown authoring.

## Project layout

- `install.sh` and `todocx.sh` in the project root (user-facing entrypoints)
- `filters/` for Lua filters used by Pandoc
- `config/` for Mermaid rendering configuration
- `templates/` for Word reference templates
- `docs/` for demo and project documentation

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

Try it: after installing, test Proseform's capabilities by converting `docs/DEMO.md`:

```bash
./todocx.sh docs/DEMO.md
```

This creates:

- `path/to/file.docx`
- `docs/DEMO.docx`

## Notes

- `templates/custom-reference.docx` controls Word styling/template output.
- If you remove `templates/custom-reference.docx`, conversion still works, but Pandoc uses its default DOCX template.
