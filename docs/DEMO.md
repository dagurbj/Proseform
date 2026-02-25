# Demo Document

## Purpose

This document is a small demonstration input for `todocx.sh`.
It includes standard headings, normal paragraph text, a code block, and a Mermaid diagram with caption metadata for cross-references.

## Background

The goal is to verify that:

1. Markdown text converts correctly to Word.
2. Syntax-highlighted C# code renders as expected.
3. Mermaid diagrams are exported as images and treated as figures.

## Example C# Code

```csharp
using System;
using System.Collections.Generic;

namespace DemoApp
{
    public static class Program
    {
        public static void Main()
        {
            var users = new List<string> { "Alice", "Bob", "Charlie" };
            foreach (var user in users)
            {
                Console.WriteLine($"Hello, {user}!");
            }
        }
    }
}
```

## System Flow

The diagram below shows a simple document conversion flow.

```mermaid {caption="Document conversion flow from Markdown to DOCX #fig:doc-flow"}
flowchart LR
    A[Markdown File] --> B[todocx.sh]
    B --> C[Pandoc + Filters]
    C --> D[DOCX Output]
```

As shown in @fig:doc-flow, the script coordinates the conversion pipeline and writes a `.docx` file next to the source markdown.
