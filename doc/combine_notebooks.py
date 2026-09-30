#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import copy
import json
import os
import re
from pathlib import Path
from typing import Any, Dict, List, Literal, Tuple


Notebook = Dict[str, Any]
Cell = Dict[str, Any]
Lang = Literal["python", "matlab"]

ATTACHMENT_REF_RE = re.compile(r"attachment:([A-Za-z0-9_.\-]+)")


def load_ipynb(path: Path) -> Notebook:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_ipynb(nb: Notebook, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(nb, f, indent=1, ensure_ascii=False)
        f.write("\n")


def derive_modified_path(ipynb_path: Path) -> Path:
    return ipynb_path.with_name(f"{ipynb_path.stem}_modified{ipynb_path.suffix}")


def is_markdown_cell(cell: Cell) -> bool:
    return cell.get("cell_type") == "markdown"


def is_code_cell(cell: Cell) -> bool:
    return cell.get("cell_type") == "code"


def count_code_cells(nb: Notebook) -> int:
    return sum(1 for c in nb.get("cells", []) if is_code_cell(c))


def cell_source_as_text(cell: Cell) -> str:
    src = cell.get("source", "")
    if isinstance(src, list):
        return "".join(src)
    return str(src)


def set_cell_source_from_text(cell: Cell, text: str) -> None:
    cell["source"] = text


def set_cell_label(cell: Cell, label: str) -> None:
    md = cell.setdefault("metadata", {})
    md["label"] = label


def label_code_cells(nb: Notebook, example_id: str, language: str) -> List[str]:
    labels: List[str] = []
    code_i = 0
    for cell in nb.get("cells", []):
        if is_code_cell(cell):
            code_i += 1
            label = f"{example_id}:{language}:{code_i}"
            set_cell_label(cell, label)
            labels.append(label)
    return labels


def split_into_md_runs_and_code_cells(nb: Notebook) -> Tuple[List[List[Cell]], List[Cell]]:
    md_runs: List[List[Cell]] = [[]]
    codes: List[Cell] = []
    for cell in nb.get("cells", []):
        if is_code_cell(cell):
            codes.append(cell)
            md_runs.append([])
        else:
            md_runs[-1].append(cell)
    return md_runs, codes


def rebuild_notebook_from_md_runs_and_code_cells(
    template_nb: Notebook,
    md_runs: List[List[Cell]],
    codes: List[Cell],
) -> Notebook:
    n_code = len(codes)
    if len(md_runs) != n_code + 1:
        raise ValueError(f"Expected len(md_runs)=n_code+1, got {len(md_runs)} vs {n_code+1}")

    new_nb = copy.deepcopy(template_nb)
    new_cells: List[Cell] = []
    for i in range(n_code):
        new_cells.extend(copy.deepcopy(md_runs[i]))
        new_cells.append(copy.deepcopy(codes[i]))
    new_cells.extend(copy.deepcopy(md_runs[n_code]))
    new_nb["cells"] = new_cells
    return new_nb


def update_nonsource_narrative_by_code_boundaries(
    narrative_source_nb: Notebook,
    nonsource_nb: Notebook,
) -> Notebook:
    src_md_runs, src_codes = split_into_md_runs_and_code_cells(narrative_source_nb)
    _, tgt_codes = split_into_md_runs_and_code_cells(nonsource_nb)

    if len(src_codes) != len(tgt_codes):
        raise RuntimeError(
            "Cannot align by code boundaries because code-cell counts differ: "
            f"source={len(src_codes)} target={len(tgt_codes)}"
        )

    return rebuild_notebook_from_md_runs_and_code_cells(
        template_nb=nonsource_nb,
        md_runs=src_md_runs,
        codes=tgt_codes,
    )


def sanitize_filename(name: str) -> str:
    name = name.replace("\\", "_").replace("/", "_")
    name = re.sub(r"[^A-Za-z0-9_.\-]", "_", name)
    return name or "attachment.bin"


def decode_attachment_data(data: str) -> bytes:
    if data.startswith("data:"):
        header, b64 = data.split(",", 1)
        return base64.b64decode(b64)
    return base64.b64decode(data)


def extract_and_rewrite_attachments_in_markdown_cell(
    cell: Cell,
    example_id: str,
    cell_seq_index: int,
    attachments_root: Path,
    md_output_dir: Path,
    *,
    remove_from_notebook: bool = True,
) -> None:
    if not is_markdown_cell(cell):
        return

    text = cell_source_as_text(cell)
    refs = sorted(set(ATTACHMENT_REF_RE.findall(text)))
    if not refs:
        return

    attachments = cell.get("attachments")
    if not isinstance(attachments, dict):
        return

    cell_dir = attachments_root / example_id / f"cell{cell_seq_index:03d}"
    cell_dir.mkdir(parents=True, exist_ok=True)

    extracted_names: List[str] = []

    for name in refs:
        att_entry = attachments.get(name)
        if not isinstance(att_entry, dict):
            continue

        mime_keys = sorted(k for k in att_entry.keys() if isinstance(k, str))
        if not mime_keys:
            continue

        mime = mime_keys[0]
        data = att_entry[mime]
        if not isinstance(data, str):
            continue

        out_name = sanitize_filename(name)
        out_path = cell_dir / out_name

        try:
            payload = decode_attachment_data(data)
        except Exception:
            continue

        out_path.write_bytes(payload)

        rel_path = os.path.relpath(out_path, start=md_output_dir).replace(os.sep, "/")
        text = text.replace(f"attachment:{name}", rel_path)
        extracted_names.append(name)

    set_cell_source_from_text(cell, text)

    if remove_from_notebook and extracted_names:
        for name in extracted_names:
            attachments.pop(name, None)
        if len(attachments) == 0:
            cell.pop("attachments", None)


def externalize_attachments_and_rewrite_notebook_markdown(
    narrative_nb: Notebook,
    example_id: str,
    output_md_path: Path,
    *,
    remove_from_notebook: bool = True,
) -> None:
    md_output_dir = output_md_path.parent
    attachments_root = md_output_dir / "_attachments"

    cell_seq = 0
    for cell in narrative_nb.get("cells", []):
        if is_markdown_cell(cell):
            cell_seq += 1
            extract_and_rewrite_attachments_in_markdown_cell(
                cell=cell,
                example_id=example_id,
                cell_seq_index=cell_seq,
                attachments_root=attachments_root,
                md_output_dir=md_output_dir,
                remove_from_notebook=remove_from_notebook,
            )


def build_tabset_embed_block(py_label: str, m_label: str) -> str:
    return (
        "::::{tab-set}\n"
        ":::{tab-item} Python\n"
        ":sync: python\n"
        f"```{{embed}} #{py_label}\n"
        ":remove-output: false\n"
        ":remove-input: false\n"
        "```\n"
        ":::\n"
        ":::{tab-item} Matlab\n"
        ":sync: matlab\n"
        f"```{{embed}} #{m_label}\n"
        ":remove-output: false\n"
        ":remove-input: false\n"
        "```\n"
        ":::\n"
        "::::\n"
    )


def build_output_markdown(narrative_nb: Notebook, py_labels: List[str], m_labels: List[str]) -> str:
    out_parts: List[str] = []
    code_i = 0
    for cell in narrative_nb.get("cells", []):
        if is_markdown_cell(cell):
            txt = cell_source_as_text(cell)
            if txt and not txt.endswith("\n"):
                txt += "\n"
            out_parts.append(txt + "\n")
        elif is_code_cell(cell):
            code_i += 1
            out_parts.append(build_tabset_embed_block(py_labels[code_i - 1], m_labels[code_i - 1]) + "\n")
        else:
            txt = cell_source_as_text(cell)
            if txt.strip():
                if not txt.endswith("\n"):
                    txt += "\n"
                out_parts.append(txt + "\n")
    return "".join(out_parts).rstrip() + "\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--matlab", required=True, type=Path)
    ap.add_argument("--python", required=True, type=Path)
    ap.add_argument("--example-id", required=True)
    ap.add_argument("--narrative-source", required=True, choices=["python", "matlab"])
    ap.add_argument("--output-md", required=True, type=Path)
    ap.add_argument("--in-place", action="store_true")

    # FIX: make it a real toggle; default on, allow turning off with --no-externalize-attachments
    ap.add_argument(
        "--no-externalize-attachments",
        action="store_true",
        help="Do not extract markdown attachments to files / rewrite attachment: links.",
    )
    ap.add_argument(
        "--keep-attachments-in-notebook",
        action="store_true",
        help="Do not delete extracted attachments from the narrative-source notebook.",
    )

    args = ap.parse_args()

    m_path: Path = args.matlab
    p_path: Path = args.python

    m_nb = load_ipynb(m_path)
    p_nb = load_ipynb(p_path)

    if count_code_cells(m_nb) != count_code_cells(p_nb):
        raise SystemExit("ERROR: Code cell count mismatch; expected 1:1 correspondence.")

    # Choose narrative source + non-source
    if args.narrative_source == "python":
        narrative_nb = p_nb
        nonsource_nb = m_nb
        nonsource_lang: Lang = "matlab"
    else:
        narrative_nb = m_nb
        nonsource_nb = p_nb
        nonsource_lang = "python"

    # FIX: externalize attachments FIRST (so copied narrative into non-source is already rewritten)
    if not args.no_externalize_attachments:
        externalize_attachments_and_rewrite_notebook_markdown(
            narrative_nb=narrative_nb,
            example_id=args.example_id,
            output_md_path=args.output_md,
            remove_from_notebook=not args.keep_attachments_in_notebook,
        )

    # Now update non-source narrative by code boundaries (copies rewritten narrative cells)
    updated_nonsource_nb = update_nonsource_narrative_by_code_boundaries(
        narrative_source_nb=narrative_nb,
        nonsource_nb=nonsource_nb,
    )
    if nonsource_lang == "matlab":
        m_nb = updated_nonsource_nb
    else:
        p_nb = updated_nonsource_nb

    # Label code cells (after narrative copy is fine)
    m_labels = label_code_cells(m_nb, args.example_id, "matlab")
    p_labels = label_code_cells(p_nb, args.example_id, "python")

    # Save notebooks
    if args.in_place:
        m_out, p_out = m_path, p_path
    else:
        m_out, p_out = derive_modified_path(m_path), derive_modified_path(p_path)

    save_ipynb(m_nb, m_out)
    save_ipynb(p_nb, p_out)

    # Build combined markdown (uses narrative_nb which already has rewritten image refs)
    args.output_md.parent.mkdir(parents=True, exist_ok=True)
    args.output_md.write_text(build_output_markdown(narrative_nb, p_labels, m_labels), encoding="utf-8")


if __name__ == "__main__":
    main()