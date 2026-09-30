#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def run_command(cmd: list[str]) -> None:
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate API documentation sources and build doc/myst.yml."
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(".").resolve(),
        help="Repository root path.",
    )
    parser.add_argument(
        "--package",
        default="escdf",
        help="Top-level Python package name for API generation.",
    )
    parser.add_argument(
        "--python-only",
        action="store_true",
        help="Generate only Python API docs.",
    )
    parser.add_argument(
        "--matlab-only",
        action="store_true",
        help="Generate only MATLAB API docs.",
    )
    parser.add_argument(
        "--spec-only",
        action="store_true",
        help="Generate only specification reference docs.",
    )
    parser.add_argument(
        "--skip-python",
        action="store_true",
        help="Skip Python API generation.",
    )
    parser.add_argument(
        "--skip-matlab",
        action="store_true",
        help="Skip MATLAB API generation.",
    )
    parser.add_argument(
        "--skip-spec",
        action="store_true",
        help="Skip specification reference generation.",
    )
    parser.add_argument(
        "--skip-myst-yaml",
        action="store_true",
        help="Skip myst.yml generation.",
    )
    parser.add_argument(
        "--repo-url",
        default="https://github.com/sandialabs/Engineering-Sciences-Common-Data-Format",
        help="Repository URL for source links.",
    )
    parser.add_argument(
        "--ref",
        default="main",
        help="Git ref to use in generated source links.",
    )

    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    doc_dir = repo_root / "doc"

    only_python = args.python_only
    only_matlab = args.matlab_only
    only_spec = args.spec_only

    generate_python = not args.skip_python
    generate_matlab = not args.skip_matlab
    generate_spec = not args.skip_spec

    only_count = sum([only_python, only_matlab, only_spec])
    if only_count > 1:
        raise ValueError(
            "Use at most one of --python-only, --matlab-only, or --spec-only."
        )

    if only_python:
        generate_matlab = False
        generate_spec = False
    if only_matlab:
        generate_python = False
        generate_spec = False
    if only_spec:
        generate_python = False
        generate_matlab = False

    if generate_python:
        run_command(
            [
                sys.executable,
                str(doc_dir / "gen_myst_api.py"),
                "--package",
                args.package,
                "--out",
                str(doc_dir / "api" / "python"),
                "--repo",
                args.repo_url,
                "--repo-root",
                str(repo_root),
                "--ref",
                args.ref,
            ]
        )

    if generate_matlab:
        matlab_generator = doc_dir / "gen_myst_api_matlab.py"
        if not matlab_generator.is_file():
            raise FileNotFoundError(
                f"MATLAB API generator not found: {matlab_generator}"
            )
        run_command(
            [
                sys.executable,
                str(matlab_generator),
                "--src",
                str(repo_root / "escdf"),
                "--out",
                str(doc_dir / "api" / "matlab"),
                "--repo",
                args.repo_url,
                "--repo-root",
                str(repo_root),
                "--ref",
                args.ref,
            ]
        )

    if generate_spec:
        spec_generator = doc_dir / "gen_myst_spec_api.py"
        if not spec_generator.is_file():
            raise FileNotFoundError(
                f"Specification API generator not found: {spec_generator}"
            )
        run_command(
            [
                sys.executable,
                str(spec_generator),
                "--src",
                str(repo_root / "escdf" / "specifications"),
                "--out",
                str(doc_dir / "api" / "specifications"),
                "--repo",
                args.repo_url,
                "--repo-root",
                str(repo_root),
                "--ref",
                args.ref,
            ]
        )

    if not args.skip_myst_yaml:
        python_snippet = doc_dir / "api" / "python" / "_toc.yml.inc"
        matlab_snippet = doc_dir / "api" / "matlab" / "_toc.yml.inc"
        spec_snippet = doc_dir / "api" / "specifications" / "_toc.yml.inc"

        if python_snippet.is_file() and matlab_snippet.is_file() and spec_snippet.is_file():
            run_command(
                [
                    sys.executable,
                    str(doc_dir / "build_myst_yaml.py"),
                    "--template",
                    str(doc_dir / "myst.template.yml"),
                    "--python-snippet",
                    str(python_snippet),
                    "--matlab-snippet",
                    str(matlab_snippet),
                    "--spec-snippet",
                    str(spec_snippet),
                    "--output",
                    str(doc_dir / "myst.yml"),
                ]
            )
        else:
            print(
                "Skipping myst.yml generation because one or more TOC snippet files are missing:\n"
                f"  Python snippet exists: {python_snippet.is_file()}\n"
                f"  MATLAB snippet exists: {matlab_snippet.is_file()}\n"
                f"  Spec snippet exists: {spec_snippet.is_file()}\n"
                "Run a full documentation source build, or regenerate the missing docs first."
            )

    print("Documentation source generation complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())