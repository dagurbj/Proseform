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

The installer also keeps `pandoc` aligned with the `pandoc-crossref` build it finds, which avoids runtime version-mismatch warnings.

## Usage

Convert a Markdown file:

```bash
./todocx.sh path/to/file.md
```

Preserve single line breaks in Word output when needed:

```bash
./todocx.sh -hlb path/to/file.md
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
- Use `-hlb` when you want single line breaks in the Markdown source to stay as line breaks in the DOCX output.
