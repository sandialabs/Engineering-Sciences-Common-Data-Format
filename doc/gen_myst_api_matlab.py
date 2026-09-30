#!/usr/bin/env python3
from __future__ import annotations

import argparse
import dataclasses
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse

#-----------------------------
# Numpydoc parsers
# ----------------------------

NUMPY_SECTION_UNDERLINE = re.compile(r"^[-=]{3,}\s*$")


@dataclasses.dataclass
class NumpyParam:
    name: str
    type: str
    desc: str


@dataclasses.dataclass
class NumpySection:
    title: str
    body: str = ""
    params: List[NumpyParam] = dataclasses.field(default_factory=list)


@dataclasses.dataclass
class NumpyDoc:
    summary: str = ""
    extended_summary: str = ""
    sections: Dict[str, NumpySection] = dataclasses.field(default_factory=dict)


def _split_numpydoc_sections(doc: str) -> List[Tuple[str, List[str]]]:
    lines = doc.splitlines()
    out: List[Tuple[str, List[str]]] = []
    cur_title = ""
    cur: List[str] = []

    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip() and (i + 1) < len(lines) and NUMPY_SECTION_UNDERLINE.match(lines[i + 1]):
            out.append((cur_title, cur))
            cur_title = line.strip()
            cur = []
            i += 2
            if i < len(lines) and not lines[i].strip():
                i += 1
            continue
        cur.append(line)
        i += 1

    out.append((cur_title, cur))
    return out


def _parse_param_block(lines: List[str]) -> List[NumpyParam]:
    params: List[NumpyParam] = []
    i = 0
    while i < len(lines):
        line = lines[i]

        if not line.strip():
            i += 1
            continue

        # Case 1: "name : type"
        m = re.match(r"^(\S.*?)(\s*:\s*)(.*\S)?\s*$", line)
        if m and (not line.startswith(" ")):
            name = m.group(1).strip()
            typ = (m.group(3) or "").strip()
            i += 1
            desc_lines: List[str] = []
            while i < len(lines):
                if not lines[i].strip():
                    desc_lines.append("")
                    i += 1
                    continue
                if lines[i].startswith(" " * 4) or lines[i].startswith("\t"):
                    desc_lines.append(lines[i].strip())
                    i += 1
                else:
                    break
            desc = "\n".join(desc_lines).strip()
            params.append(NumpyParam(name=name, type=typ, desc=desc))
            continue

        # Case 2: "ValueError" or similar item name without a type
        if not line.startswith(" "):
            name = line.strip()
            typ = ""
            i += 1
            desc_lines: List[str] = []
            while i < len(lines):
                if not lines[i].strip():
                    desc_lines.append("")
                    i += 1
                    continue
                if lines[i].startswith(" " * 4) or lines[i].startswith("\t"):
                    desc_lines.append(lines[i].strip())
                    i += 1
                else:
                    break
            desc = "\n".join(desc_lines).strip()
            params.append(NumpyParam(name=name, type=typ, desc=desc))
            continue

        # Fallback: consume indented or malformed line as plain text item
        params.append(NumpyParam(name=line.strip(), type="", desc=""))
        i += 1

    return params


def parse_numpydoc(doc: str) -> NumpyDoc:
    doc = (doc or "").strip("\n")
    nd = NumpyDoc()
    if not doc.strip():
        return nd

    parts = _split_numpydoc_sections(doc)
    lead_title, lead_lines = parts[0]
    lead_text = "\n".join(lead_lines).strip("\n")
    if lead_text:
        lead_paras = [p.strip() for p in re.split(r"\n\s*\n", lead_text) if p.strip()]
        if lead_paras:
            nd.summary = lead_paras[0].replace("\n", " ").strip()
            if len(lead_paras) > 1:
                nd.extended_summary = "\n\n".join(lead_paras[1:]).strip()

    for title, sec_lines in parts[1:]:
        body = "\n".join(sec_lines).rstrip()
        sec = NumpySection(title=title, body=body)

        if title in (
            "Parameters",
            "Other Parameters",
            "Returns",
            "Yields",
            "Raises",
            "Warns",
            "Attributes",
            "Methods",
            "See Also",
        ):
            sec.params = _parse_param_block(sec_lines)

        nd.sections[title] = sec

    return nd

# ----------------------------
# Repository source link helpers
# ----------------------------

def detect_repo_kind(repo_url: str) -> str:
    """
    Detect repository hosting provider from a repository URL.

    Parameters
    ----------
    repo_url : str
        Repository URL.

    Returns
    -------
    str
        Repository kind. One of ``"github"``, ``"gitlab"``, or
        ``"generic"``.
    """
    if not repo_url:
        return "generic"

    parsed = urlparse(repo_url)
    host = (parsed.netloc or "").lower()

    if "github" in host:
        return "github"
    if "gitlab" in host:
        return "gitlab"
    return "generic"


@dataclasses.dataclass
class SourceRef:
    file_abs: Path
    file_rel_repo: str
    start_line: int
    end_line: int


def source_link(repo_url: str, ref: str, src: SourceRef) -> str:
    """
    Build a source-code link for a repository-hosted file region.

    Parameters
    ----------
    repo_url : str
        Repository URL.
    ref : str
        Git ref, branch, tag, or commit hash.
    src : SourceRef
        Source-file location and line range.

    Returns
    -------
    str
        Provider-appropriate URL pointing at the requested file and line
        range.
    """
    repo_kind = detect_repo_kind(repo_url)
    base = repo_url.rstrip("/")

    if repo_kind == "github":
        return f"{base}/blob/{ref}/{src.file_rel_repo}#L{src.start_line}-L{src.end_line}"

    if repo_kind == "gitlab":
        return f"{base}/-/blob/{ref}/{src.file_rel_repo}#L{src.start_line}-{src.end_line}"

    return f"{base}/blob/{ref}/{src.file_rel_repo}#L{src.start_line}-L{src.end_line}"


def render_source_link(repo_url: str, ref: str, src: Optional[SourceRef]) -> str:
    """
    Render a Markdown source link bullet.

    Parameters
    ----------
    repo_url : str
        Repository URL.
    ref : str
        Git ref, branch, tag, or commit hash.
    src : SourceRef or None
        Source-file reference.

    Returns
    -------
    str
        Markdown bullet containing a source link, or an empty string if no
        source reference is available.
    """
    if not (repo_url and ref and src):
        return ""

    repo_kind = detect_repo_kind(repo_url)
    if repo_kind == "github":
        label = "GitHub"
    elif repo_kind == "gitlab":
        label = "GitLab"
    else:
        label = "Source"

    return f"- Source: [{label}]({source_link(repo_url, ref, src)})\n"


# ----------------------------
# Utilities
# ----------------------------

def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_file(path: Path, content: str) -> None:
    ensure_dir(path.parent)
    path.write_text(content, encoding="utf-8")


def slugify(name: str) -> str:
    return re.sub(r"[^0-9A-Za-z._-]+", "-", name)


def first_sentence_or_line(text: str) -> str:
    if not text:
        return ""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        return ""
    return lines[0]


def indent_md(text: str, spaces: int) -> str:
    pad = " " * spaces
    return "\n".join(pad + line if line else "" for line in text.splitlines())


def myst_target(full_name: str, source: bool) -> str:
    if source:
        return f"(api-m:{full_name})="
    return f"api-m:{full_name}"


def matlab_api_page_path(out_dir: Path) -> Path:
    return out_dir / "matlab_api.md"


def class_page_path(out_dir: Path, class_name: str) -> Path:
    return out_dir / "classes" / f"{slugify(class_name)}_m.md"


def toc_file_entry(path: Path, out_dir: Path) -> str:
    """
    Convert a generated page path into a MyST file entry path.

    Parameters
    ----------
    path : pathlib.Path
        Generated page path.
    out_dir : pathlib.Path
        Root output directory for this API section.

    Returns
    -------
    str
        Path relative to the ``doc`` directory, suitable for use in
        ``myst.yml``.
    """
    doc_dir = out_dir.parent.parent
    return path.relative_to(doc_dir).as_posix()


def render_summary_table(rows: List[Tuple[str, str, str]]) -> str:
    if not rows:
        return ""
    out = ["| Name | Summary |", "|---|---|"]
    for name, link, summary in rows:
        nm = f"[`{name}`]({link})" if link else f"`{name}`"
        out.append(f"| {nm} | {summary} |")
    return "\n".join(out) + "\n\n"

def render_numpydoc(nd: NumpyDoc, extra_title_depth: int = 0) -> str:
    out: List[str] = []

    if nd.summary:
        out.append(nd.summary + "\n\n")
    if nd.extended_summary:
        out.append(nd.extended_summary + "\n\n")

    preferred = [
        "Parameters",
        "Other Parameters",
        "Returns",
        "Yields",
        "Raises",
        "Warns",
        "See Also",
        "Notes",
        "References",
        "Examples",
    ]
    used = set()

    def render_param_section(title: str, sec: NumpySection) -> str:
        lines: List[str] = [("#" * extra_title_depth) + f"## {title}\n\n"]
        if sec.params:
            for p in sec.params:
                head = f"- **{p.name}**"
                if p.type:
                    head += f" : *{p.type}*"
                lines.append(head)
                if p.desc:
                    lines.append(indent_md(p.desc, 2))
            lines.append("")
            return "\n".join(lines) + "\n"
        body = sec.body.strip()
        if body:
            return ("#" * extra_title_depth) + f"## {title}\n\n{body}\n\n"
        return ""

    def render_text_section(title: str, sec: NumpySection) -> str:
        body = sec.body.strip()
        if not body:
            return ""
        return ("#" * extra_title_depth) + f"## {title}\n\n{body}\n\n"

    for t in preferred:
        sec = nd.sections.get(t)
        if not sec:
            continue
        used.add(t)
        if t in ("Parameters", "Other Parameters", "Returns", "Yields", "Raises", "Warns", "See Also"):
            out.append(render_param_section(t, sec))
        else:
            out.append(render_text_section(t, sec))

    for t, sec in nd.sections.items():
        if t in used:
            continue
        if sec.params:
            out.append(render_param_section(t, sec))
        else:
            out.append(render_text_section(t, sec))

    return "".join(out)

# ----------------------------
# MATLAB parsing
# ----------------------------

# BLOCK_START_RE = re.compile(
#     r"^\s*(function|if|for|while|switch|try|classdef|methods|properties|events|enumeration|parfor|spmd)\b"
# )
FUNCTION_BODY_BLOCK_START_RE = re.compile(
    r"^\s*(function|if|for|while|switch|try|parfor|spmd)\b"
)
CLASSDEF_RE = re.compile(r"^\s*classdef\s+([A-Za-z]\w*)")
METHOD_RE = re.compile(r"^\s*function\s+(?:\[[^\]]+\]\s*=\s*|[A-Za-z]\w*\s*=\s*)?([A-Za-z]\w*)\s*\((.*?)\)")
METHODS_BLOCK_RE = re.compile(r"^\s*methods(?:\s*\((.*?)\))?\s*$")
END_RE = re.compile(r"^\s*end\s*$")

def strip_matlab_comment(line: str) -> str:
    """
    Remove trailing MATLAB comment text from a source line.

    Parameters
    ----------
    line : str
        Source line.

    Returns
    -------
    str
        Code portion of the line before any ``%`` comment marker.
    """
    return line.split("%", 1)[0]

def count_block_closing_end_tokens(line: str) -> int:
    """
    Count MATLAB block-closing ``end`` tokens on a line.

    Parameters
    ----------
    line : str
        Source line.

    Returns
    -------
    int
        Number of block-closing ``end`` tokens on the line.

    Notes
    -----
    This intentionally does not count indexing expressions such as
    ``end+1`` or ``A(:,end)``.
    """
    code = strip_matlab_comment(line).strip()
    if not code:
        return 0

    # Entire line is exactly `end`
    if re.fullmatch(r"end", code):
        return 1

    # One-line constructs like:
    #   if nargin < 1, interactive = true; end
    #   try, foo(); catch, bar(); end
    #
    # Only count `end` if it appears as a terminal statement token.
    if re.search(r"(?:^|[;,]\s*)end\s*$", code):
        return 1

    return 0

def methods_block_is_private(attr_text: Optional[str]) -> bool:
    """
    Determine whether a MATLAB methods block is private.

    Parameters
    ----------
    attr_text : str or None
        Attribute text captured from a ``methods (...)`` declaration.

    Returns
    -------
    bool
        ``True`` if the block explicitly declares private access,
        otherwise ``False``.
    """
    if not attr_text:
        return False

    normalized = attr_text.lower()
    # Match things like:
    #   Access = private
    #   access=private
    # with optional commas/spaces around other attributes
    return re.search(r"\baccess\s*=\s*private\b", normalized) is not None

def build_function_depth_trace(
    lines: List[str],
    function_line_index: int,
    file_path: Optional[Path] = None,
    function_name: Optional[str] = None,
) -> str:
    """
    Build a line-by-line depth trace for MATLAB function parsing.

    Parameters
    ----------
    lines : list of str
        File lines.
    function_line_index : int
        Zero-based line index of the function declaration.
    file_path : pathlib.Path, optional
        Source file path.
    function_name : str, optional
        Function name.

    Returns
    -------
    str
        Multi-line trace showing parser depth before each line and how each
        line was classified.
    """
    depth = 0
    out: List[str] = []

    location = (
        f"{file_path}:{function_line_index + 1}"
        if file_path is not None
        else f"line {function_line_index + 1}"
    )
    header = "Depth trace for MATLAB function"
    if function_name:
        header += f" '{function_name}'"
    header += f" starting at {location}"
    out.append(header)
    out.append("-" * len(header))

    for i in range(function_line_index, len(lines)):
        raw_line = lines[i].rstrip("\n")
        code = strip_matlab_comment(raw_line).strip()

        if not code:
            out.append(f"[{i+1:04d}] depth={depth:<3d} BLANK            ")
            continue

        start_match = FUNCTION_BODY_BLOCK_START_RE.match(code)
        start_kind = start_match.group(1) if start_match else None
        end_count = count_block_closing_end_tokens(raw_line)

        label_parts = []
        if start_kind:
            label_parts.append(f"START({start_kind})")
        if end_count:
            label_parts.append(f"END x{end_count}")
        label = "/".join(label_parts) if label_parts else "TEXT"

        out.append(f"[{i+1:04d}] depth={depth:<3d} {label:<16} {raw_line}")

        delta = 0
        if start_kind:
            delta += 1
        delta -= end_count
        depth += delta

    return "\n".join(out)

def find_matching_end_for_function(
    lines: List[str],
    function_line_index: int,
    file_path: Optional[Path] = None,
    function_name: Optional[str] = None,
) -> int:
    """
    Find the line index of the matching ``end`` for a MATLAB function.

    Parameters
    ----------
    lines : list of str
        File lines.
    function_line_index : int
        Zero-based line index of the ``function`` declaration.
    file_path : pathlib.Path, optional
        Source file path.
    function_name : str, optional
        Function name.

    Returns
    -------
    int
        Zero-based line index of the matching block-closing ``end``.

    Raises
    ------
    RuntimeError
        If no matching ``end`` can be found.
    """
    depth = 0
    for i in range(function_line_index, len(lines)):
        raw_line = lines[i].rstrip("\n")
        code = strip_matlab_comment(raw_line).strip()

        if not code:
            continue

        delta = 0

        start_match = FUNCTION_BODY_BLOCK_START_RE.match(code)
        if start_match:
            delta += 1

        end_count = count_block_closing_end_tokens(raw_line)
        delta -= end_count

        depth += delta

        if depth == 0:
            # # For Debugging.
            # trace = build_function_depth_trace(
            #     lines=lines[:i+1],
            #     function_line_index=function_line_index,
            #     file_path=file_path,
            #     function_name=function_name,
            # )
            # print(f'Found exit for {file_path}:{function_name}')
            # print(trace)
            return i

    trace = build_function_depth_trace(
        lines=lines,
        function_line_index=function_line_index,
        file_path=file_path,
        function_name=function_name,
    )

    location = (
        f"{file_path}:{function_line_index + 1}"
        if file_path is not None
        else f"line {function_line_index + 1}"
    )
    if function_name:
        raise RuntimeError(
            f"Could not find matching 'end' for MATLAB function '{function_name}' starting at {location}.\n\n{trace}"
        )
    raise RuntimeError(
        f"Could not find matching 'end' for MATLAB function starting at {location}.\n\n{trace}"
    )


@dataclasses.dataclass
class MatlabMethodInfo:
    name: str
    signature: str
    help_text: str
    start_line: int
    end_line: int


@dataclasses.dataclass
class MatlabClassInfo:
    name: str
    file_abs: Path
    file_rel_repo: str
    class_help: str
    class_start_line: int
    class_end_line: int
    methods: List[MatlabMethodInfo]


def extract_help_block(lines: List[str], start_index: int) -> Tuple[str, int]:
    """
    Extract a contiguous MATLAB help block starting at a given line index.

    Parameters
    ----------
    lines : list of str
        File lines.
    start_index : int
        Zero-based line index from which help comments may begin.

    Returns
    -------
    tuple
        Pair ``(help_text, next_index)`` where ``help_text`` is the cleaned
        help block text and ``next_index`` is the first line index after the
        extracted block.
    """
    help_lines: List[str] = []
    i = start_index
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        if stripped.startswith("%"):
            # remove first % and one optional following space
            content = stripped[1:]
            if content.startswith(" "):
                content = content[1:]
            help_lines.append(content.rstrip("\n"))
            i += 1
        elif stripped.strip() == "":
            # allow blank line only if we're already inside help block
            if help_lines:
                help_lines.append("")
                i += 1
            else:
                break
        else:
            break

    # Trim leading/trailing blank lines
    while help_lines and help_lines[0] == "":
        help_lines.pop(0)
    while help_lines and help_lines[-1] == "":
        help_lines.pop()

    return "\n".join(help_lines), i


def parse_matlab_class_file(path: Path, repo_root: Path) -> Optional[MatlabClassInfo]:
    """
    Parse a MATLAB class file for class and method help text.

    Parameters
    ----------
    path : pathlib.Path
        MATLAB class file path.
    repo_root : pathlib.Path
        Repository root used to compute source-relative paths.

    Returns
    -------
    MatlabClassInfo or None
        Parsed class information, or ``None`` if the file does not contain
        a class definition.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    class_name = None
    class_line_index = None
    for i, line in enumerate(lines):
        m = CLASSDEF_RE.match(line)
        if m:
            class_name = m.group(1)
            class_line_index = i
            break

    if class_name is None or class_line_index is None:
        return None

    class_help, _ = extract_help_block(lines, class_line_index + 1)

    methods: List[MatlabMethodInfo] = []
    inside_methods_block = False
    current_methods_block_private = False

    i = class_line_index + 1
    while i < len(lines):
        line = lines[i]

        # Enter a methods block
        m_methods = METHODS_BLOCK_RE.match(line)
        if m_methods and not inside_methods_block:
            inside_methods_block = True
            attr_text = m_methods.group(1)
            current_methods_block_private = methods_block_is_private(attr_text)
            i += 1
            continue

        if inside_methods_block:
            # Top-level function within this methods block
            m_func = METHOD_RE.match(line)
            if m_func:
                method_name = m_func.group(1).strip()
                signature_args = m_func.group(2).strip()
                signature = f"{method_name}({signature_args})"
                help_text, _ = extract_help_block(lines, i + 1)
                function_end_index = find_matching_end_for_function(lines, i, path, method_name)

                if not current_methods_block_private:
                    methods.append(
                        MatlabMethodInfo(
                            name=method_name,
                            signature=signature,
                            help_text=help_text,
                            start_line=i + 1,
                            end_line=function_end_index + 1,
                        )
                    )

                i = function_end_index + 1
                continue

            # If we hit an end while not in a function body, this closes the methods block
            if END_RE.match(line):
                inside_methods_block = False
                current_methods_block_private = False
                i += 1
                continue

        i += 1

    file_abs = path.resolve()
    file_rel_repo = file_abs.relative_to(repo_root.resolve()).as_posix()

    return MatlabClassInfo(
        name=class_name,
        file_abs=file_abs,
        file_rel_repo=file_rel_repo,
        class_help=class_help,
        class_start_line=class_line_index + 1,
        class_end_line=class_line_index + 1,
        methods=methods,
    )


# ----------------------------
# Rendering
# ----------------------------

def render_object_header(full_name: str, title: str) -> str:
    return f"{myst_target(full_name, source=True)}\n# {title}\n\n"


def render_signature_block(signature: str) -> str:
    return f"```matlab\n{signature}\n```\n\n"


def render_help_text(help_text: str, extra_title_depth: int = 0) -> str:
    """
    Render MATLAB help text as structured Markdown.

    Parameters
    ----------
    help_text : str
        Extracted help text.
    extra_title_depth : int, optional
        Additional heading depth to apply when rendering section headers.

    Returns
    -------
    str
        Markdown-rendered help text.
    """
    if not help_text.strip():
        return ""
    nd = parse_numpydoc(help_text)
    return render_numpydoc(nd, extra_title_depth=extra_title_depth)


def render_class_page(
    out_dir: Path,
    cinfo: MatlabClassInfo,
    repo_url: str,
    ref: str,
) -> str:
    full_name = cinfo.name
    src = SourceRef(
        file_abs=cinfo.file_abs,
        file_rel_repo=cinfo.file_rel_repo,
        start_line=cinfo.class_start_line,
        end_line=max(cinfo.class_end_line, cinfo.class_start_line),
    )

    out: List[str] = []
    out.append("---\n")
    out.append(f"short_title: {cinfo.name}\n")
    out.append("---\n")
    out.append(render_object_header(full_name, full_name))
    out.append(render_source_link(repo_url, ref, src))
    out.append("\n")
    out.append(render_help_text(cinfo.class_help))

    if cinfo.methods:
        out.append("## Methods\n\n")
        rows: List[Tuple[str, str, str]] = []
        for m in cinfo.methods:
            method_full_name = f"{full_name}.{m.name}"
            rows.append(
                (
                    m.name,
                    f"#{myst_target(method_full_name, source=False)}",
                    first_sentence_or_line(m.help_text),
                )
            )
        out.append(render_summary_table(rows))

        for m in cinfo.methods:
            method_full_name = f"{full_name}.{m.name}"
            method_src = SourceRef(
                file_abs=cinfo.file_abs,
                file_rel_repo=cinfo.file_rel_repo,
                start_line=m.start_line,
                end_line=max(m.end_line, m.start_line),
            )
            out.append(f"{myst_target(method_full_name, source=True)}\n")
            out.append(f"### `{m.name}`\n\n")
            out.append(render_source_link(repo_url, ref, method_src))
            out.append("\n")
            out.append(render_signature_block(m.signature))
            out.append(render_help_text(m.help_text, extra_title_depth=2))

    return "".join(out)


def render_matlab_api_page(
    out_dir: Path,
    class_infos: List[MatlabClassInfo],
) -> str:
    out: List[str] = []
    out.append("---\n")
    out.append("short_title: Matlab API\n")
    out.append("---\n")
    out.append("# Matlab API Reference\n\n")
    out.append(
        "This section documents the MATLAB implementation of ESCDF,\n"
        "including the core user-facing classes and their public methods.\n\n"
    )

    preferred_order = [
        "escdf",
        "escdf_dataset",
        "escdf_activity",
        "escdf_property",
    ]

    class_map = {c.name: c for c in class_infos}

    out.append("## Core Classes\n\n")
    rows: List[Tuple[str, str, str]] = []
    emitted = set()

    for name in preferred_order:
        c = class_map.get(name)
        if c is None:
            continue
        rows.append(
            (
                c.name,
                f"#{myst_target(c.name, source=False)}",
                first_sentence_or_line(c.class_help),
            )
        )
        emitted.add(c.name)

    for c in sorted(class_infos, key=lambda x: x.name.lower()):
        if c.name in emitted:
            continue
        rows.append(
            (
                c.name,
                f"#{myst_target(c.name, source=False)}",
                first_sentence_or_line(c.class_help),
            )
        )

    out.append(render_summary_table(rows))
    return "".join(out)


def write_toc_snippet(out_dir: Path, class_infos: List[MatlabClassInfo]) -> None:
    """
    Write a MyST YAML snippet enumerating generated MATLAB API pages.

    Parameters
    ----------
    out_dir : pathlib.Path
        Output directory for generated MATLAB API pages.
    class_infos : list of MatlabClassInfo
        Parsed MATLAB class information.
    """
    lines: List[str] = []

    # Root of the MATLAB API subtree
    lines.append(f"        - file: {toc_file_entry(matlab_api_page_path(out_dir), out_dir)}")
    lines.append("          children:")

    preferred_order = [
        "escdf",
        "escdf_dataset",
        "escdf_activity",
        "escdf_property",
    ]

    class_map = {c.name: c for c in class_infos}
    emitted = set()

    for name in preferred_order:
        c = class_map.get(name)
        if c is None:
            continue
        lines.append(f"            - file: {toc_file_entry(class_page_path(out_dir, c.name), out_dir)}")
        emitted.add(c.name)

    for c in sorted(class_infos, key=lambda x: x.name.lower()):
        if c.name in emitted:
            continue
        lines.append(f"            - file: {toc_file_entry(class_page_path(out_dir, c.name), out_dir)}")

    write_file(out_dir / "_toc.yml.inc", "\n".join(lines) + "\n")


# ----------------------------
# Main
# ----------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate MyST Markdown API docs from MATLAB class files."
    )
    parser.add_argument(
        "--src",
        required=True,
        type=Path,
        help="Source directory containing MATLAB .m files.",
    )
    parser.add_argument(
        "--out",
        required=True,
        type=Path,
        help="Output directory for generated API pages.",
    )
    parser.add_argument(
        "--repo",
        default="",
        help="Repository URL for source links, e.g. GitHub or GitLab project URL.",
    )
    parser.add_argument(
        "--ref",
        default="main",
        help="Git ref for source links.",
    )
    parser.add_argument(
        "--repo-root",
        required=True,
        type=Path,
        help="Repository root path for source link mapping.",
    )
    parser.add_argument(
        "--no-index",
        action="store_true",
        help="Do not generate the MATLAB API landing page.",
    )

    args = parser.parse_args()

    src_dir = args.src.resolve()
    out_dir = args.out.resolve()
    repo_root = args.repo_root.resolve()
    repo_url = args.repo
    ref = args.ref

    ensure_dir(out_dir)
    ensure_dir(out_dir / "classes")

    class_infos: List[MatlabClassInfo] = []

    for path in sorted(src_dir.glob("*.m")):
        cinfo = parse_matlab_class_file(path, repo_root)
        if cinfo is None:
            continue
        class_infos.append(cinfo)

    for cinfo in class_infos:
        content = render_class_page(out_dir, cinfo, repo_url, ref)
        write_file(class_page_path(out_dir, cinfo.name), content)

    if not args.no_index:
        write_file(
            matlab_api_page_path(out_dir),
            render_matlab_api_page(out_dir, class_infos),
        )

    write_toc_snippet(out_dir, class_infos)

    print(f"Generated MATLAB API docs in {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())