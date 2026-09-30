#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import re


PYTHON_PLACEHOLDER = "# <<PYTHON_API_TOC>>"
MATLAB_PLACEHOLDER = "# <<MATLAB_API_TOC>>"
SPEC_PLACEHOLDER = "# <<SPEC_API_TOC>>"


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def save_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def replace_placeholder(template_text: str, placeholder: str, replacement: str) -> str:
    """
    Replace a placeholder line in the MyST template with generated content.

    Parameters
    ----------
    template_text : str
        Full template YAML text.
    placeholder : str
        Placeholder token to replace.
    replacement : str
        Replacement block text, including any desired indentation.

    Returns
    -------
    str
        Updated YAML text.

    Raises
    ------
    RuntimeError
        If the placeholder line is not found.
    """
    placeholder_line_pattern = rf"^[ \t]*{re.escape(placeholder)}[ \t]*\r?\n?"
    if not re.search(placeholder_line_pattern, template_text, flags=re.MULTILINE):
        raise RuntimeError(f"Placeholder not found in template: {placeholder}")
    return re.sub(
        placeholder_line_pattern,
        replacement.rstrip() + "\n",
        template_text,
        count=1,
        flags=re.MULTILINE,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build myst.yml from myst.template.yml and generated TOC snippets."
    )
    parser.add_argument(
        "--template",
        type=Path,
        default=Path("doc/myst.template.yml"),
        help="Path to myst template file.",
    )
    parser.add_argument(
        "--python-snippet",
        type=Path,
        default=Path("doc/api/python/_toc.yml.inc"),
        help="Path to generated Python API TOC snippet.",
    )
    parser.add_argument(
        "--matlab-snippet",
        type=Path,
        default=Path("doc/api/matlab/_toc.yml.inc"),
        help="Path to generated MATLAB API TOC snippet.",
    )
    parser.add_argument(
        "--spec-snippet",
        type=Path,
        default=Path("doc/api/specifications/_toc.yml.inc"),
        help="Path to generated specification API TOC snippet.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("doc/myst.yml"),
        help="Path to generated myst.yml output.",
    )

    args = parser.parse_args()

    template_text = load_text(args.template)

    if not args.python_snippet.is_file():
        raise FileNotFoundError(f"Python TOC snippet not found: {args.python_snippet}")
    if not args.matlab_snippet.is_file():
        raise FileNotFoundError(f"MATLAB TOC snippet not found: {args.matlab_snippet}")
    if not args.spec_snippet.is_file():
        raise FileNotFoundError(f"Specification TOC snippet not found: {args.spec_snippet}")
    
    python_snippet = load_text(args.python_snippet)
    matlab_snippet = load_text(args.matlab_snippet)
    spec_snippet = load_text(args.spec_snippet)

    output_text = template_text
    output_text = replace_placeholder(output_text, PYTHON_PLACEHOLDER, python_snippet)
    output_text = replace_placeholder(output_text, MATLAB_PLACEHOLDER, matlab_snippet)
    output_text = replace_placeholder(output_text, SPEC_PLACEHOLDER, spec_snippet)

    save_text(args.output, output_text)
    print(f"Wrote {args.output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())