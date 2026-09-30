#!/usr/bin/env python3
from __future__ import annotations

import argparse
import dataclasses
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse


# ----------------------------
# Repository source link helpers
# ----------------------------

def detect_repo_kind(repo_url: str) -> str:
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
    repo_kind = detect_repo_kind(repo_url)
    base = repo_url.rstrip("/")

    if repo_kind == "github":
        return f"{base}/blob/{ref}/{src.file_rel_repo}#L{src.start_line}-L{src.end_line}"
    if repo_kind == "gitlab":
        return f"{base}/-/blob/{ref}/{src.file_rel_repo}#L{src.start_line}-{src.end_line}"
    return f"{base}/blob/{ref}/{src.file_rel_repo}#L{src.start_line}-L{src.end_line}"


def render_source_link(repo_url: str, ref: str, src: Optional[SourceRef]) -> str:
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


def first_paragraph(text: str) -> str:
    text = (text or "").strip()
    if not text:
        return ""
    return re.split(r"\n\s*\n", text)[0].strip().replace("\n", " ")


def indent_md(text: str, spaces: int) -> str:
    pad = " " * spaces
    return "\n".join(pad + line if line else "" for line in text.splitlines())


def toc_file_entry(path: Path, out_dir: Path) -> str:
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


def spec_api_page_path(out_dir: Path) -> Path:
    return out_dir / "specifications_api.md"


def spec_page_path(out_dir: Path, spec_name: str) -> Path:
    return out_dir / "specs" / f"{slugify(spec_name)}_spec.md"


def myst_target(spec_name: str, source: bool) -> str:
    target = f"spec:{spec_name}"
    if source:
        return f"({target})="
    return target


def link_to_spec(spec_name: str) -> str:
    return "#" + myst_target(spec_name, source=False)


# ----------------------------
# Specification parsing
# ----------------------------

ACCEPTABLE_DTYPES = {
    "i1", "i2", "i4", "i8",
    "u1", "u2", "u4", "u8",
    "f4", "f8",
    "c8", "c16",
    "str", "bytes",
}

TYPE_LABELS = {
    "i1": "8-bit signed integer",
    "i2": "16-bit signed integer",
    "i4": "32-bit signed integer",
    "i8": "64-bit signed integer",
    "u1": "8-bit unsigned integer",
    "u2": "16-bit unsigned integer",
    "u4": "32-bit unsigned integer",
    "u8": "64-bit unsigned integer",
    "f4": "32-bit floating point",
    "f8": "64-bit floating point",
    "c8": "64-bit complex floating point",
    "c16": "128-bit complex floating point",
    "str": "string",
    "bytes": "bytes",
}


@dataclasses.dataclass
class SpecProperty:
    name: str
    dtype: str
    shape: Tuple[object, ...]
    options: Tuple[str, ...]


@dataclasses.dataclass
class SpecInfo:
    name: str
    version: Tuple[int, int, int]
    parent: str
    documentation: str
    properties: List[SpecProperty]
    enumerations: Dict[str, List[str]]
    extra_documentation: str
    raw_text: str
    source_ref: SourceRef

@dataclasses.dataclass
class ChoiceGroupInfo:
    name: str
    choices: Dict[str, List[SpecProperty]]

@dataclasses.dataclass
class OriginInfo:
    defining_spec: str
    inherited: bool
    overridden_parent: Optional[str] = None


@dataclasses.dataclass
class ResolvedSpecProperty:
    prop: SpecProperty
    origin: OriginInfo


@dataclasses.dataclass
class ResolvedChoiceGroupInfo:
    name: str
    choices: Dict[str, List["ResolvedSpecProperty"]]


@dataclasses.dataclass
class ResolvedEnumeration:
    name: str
    values: List[str]
    origin: OriginInfo

def split_property_options(options: Tuple[str, ...]) -> Tuple[List[str], Optional[Tuple[str, str]]]:
    """
    Separate normal options from an ``or:`` choice-group option.

    Parameters
    ----------
    options : tuple of str
        Raw property options.

    Returns
    -------
    normal_options : list of str
        Options other than ``or:``.
    choice_info : tuple of (group_name, choice_name) or None
        Parsed ``or:`` group information if present.
    """
    normal_options: List[str] = []
    choice_info: Optional[Tuple[str, str]] = None

    for opt in options:
        if opt.startswith("or:"):
            parts = opt.split(":")
            if len(parts) >= 3:
                choice_info = (parts[1].strip(), parts[2].strip())
        else:
            normal_options.append(opt)

    return normal_options, choice_info


def classify_properties(
    properties: List[SpecProperty],
) -> Tuple[List[SpecProperty], List[ChoiceGroupInfo]]:
    """
    Split specification properties into regular properties and choice groups.

    Parameters
    ----------
    properties : list of SpecProperty
        Properties parsed from a specification file.

    Returns
    -------
    regular_properties : list of SpecProperty
        Properties not belonging to any ``or:`` choice group.
    choice_groups : list of ChoiceGroupInfo
        Choice-group structures preserving specification order.
    """
    regular_properties: List[SpecProperty] = []

    choice_group_order: List[str] = []
    choice_order_by_group: Dict[str, List[str]] = {}
    grouped: Dict[str, Dict[str, List[SpecProperty]]] = {}

    for prop in properties:
        normal_options, choice_info = split_property_options(prop.options)
        if choice_info is None:
            regular_properties.append(
                SpecProperty(prop.name, prop.dtype, prop.shape, tuple(normal_options))
            )
            continue

        group_name, choice_name = choice_info
        if group_name not in grouped:
            grouped[group_name] = {}
            choice_group_order.append(group_name)
            choice_order_by_group[group_name] = []

        if choice_name not in grouped[group_name]:
            grouped[group_name][choice_name] = []
            choice_order_by_group[group_name].append(choice_name)

        grouped[group_name][choice_name].append(
            SpecProperty(prop.name, prop.dtype, prop.shape, tuple(normal_options))
        )

    choice_groups: List[ChoiceGroupInfo] = []
    for group_name in choice_group_order:
        ordered_choices: Dict[str, List[SpecProperty]] = {}
        for choice_name in choice_order_by_group[group_name]:
            ordered_choices[choice_name] = grouped[group_name][choice_name]
        choice_groups.append(ChoiceGroupInfo(group_name, ordered_choices))

    return regular_properties, choice_groups

def parse_specification_file(path: Path, repo_root: Path) -> SpecInfo:
    lines = path.read_text(encoding="utf-8").splitlines()
    raw_text = "\n".join(lines) + "\n"

    # Header line
    line_parts = lines[0].split("-")
    name_part = line_parts[0].strip()
    version_part = line_parts[1].strip()
    spec_name = name_part.replace(" ", "_")
    version_numbers = version_part.replace("v", "").split(".")
    version = tuple(int(v) for v in version_numbers)

    # extends:
    extends_line_idx = next(
        i for i, line in enumerate(lines) if line.strip().startswith("extends:")
    )
    parent = lines[extends_line_idx].split(":", 1)[1].strip()

    # properties section
    properties_header_idx = next(
        i for i, line in enumerate(lines) if line.strip() == "properties"
    )
    properties: List[SpecProperty] = []
    i = properties_header_idx + 2
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            break
        parts = [p.strip() for p in line.split("-")]
        if len(parts) > 4:
            parts[3] = "-".join(parts[3:]).strip()
            parts = parts[:4]

        prop_name = parts[0]
        dtype = parts[1]
        if dtype not in ACCEPTABLE_DTYPES:
            raise ValueError(f"Invalid datatype {dtype!r} in {path} for property {prop_name!r}")

        if len(parts) >= 3 and parts[2]:
            if parts[2] == "scalar":
                shape = ()
            else:
                shape_list: List[object] = []
                for entry in parts[2].split(","):
                    entry = entry.strip()
                    try:
                        shape_list.append(int(entry))
                    except ValueError:
                        shape_list.append(entry)
                shape = tuple(shape_list)
        else:
            shape = ()

        if len(parts) >= 4 and parts[3]:
            options = tuple(v.strip() for v in parts[3].split(","))
            regex_idx = next((idx for idx, opt in enumerate(options) if opt.startswith("regex:")), None)
            if regex_idx is not None:
                options = options[:regex_idx] + (",".join(options[regex_idx:]),)
        else:
            options = ()

        properties.append(SpecProperty(prop_name, dtype, shape, options))
        i += 1

    # enumerations section
    enumerations: Dict[str, List[str]] = {}
    enumeration_header_idx = next(
        (j for j, line in enumerate(lines) if line.strip() == "enumerations"),
        None,
    )
    if enumeration_header_idx is not None:
        j = enumeration_header_idx + 2
        while j < len(lines):
            line = lines[j].strip()
            if not line:
                break
            enum_name, *enum_rest = [p.strip() for p in line.split("-")]
            enum_values = ",".join(enum_rest)
            enumerations[enum_name] = [v.strip() for v in enum_values.split(",")]
            j += 1
        enum_end_idx = j
    else:
        enum_end_idx = i

    documentation = "\n".join(lines[extends_line_idx + 1 : properties_header_idx]).strip()

    if enumeration_header_idx is not None:
        extra_start = enum_end_idx + 1
    else:
        extra_start = i + 1

    extra_documentation = "\n".join(lines[extra_start:]).strip()

    file_abs = path.resolve()
    file_rel_repo = file_abs.relative_to(repo_root.resolve()).as_posix()
    src = SourceRef(
        file_abs=file_abs,
        file_rel_repo=file_rel_repo,
        start_line=1,
        end_line=len(lines),
    )

    return SpecInfo(
        name=spec_name,
        version=version,
        parent=parent,
        documentation=documentation,
        properties=properties,
        enumerations=enumerations,
        extra_documentation=extra_documentation,
        raw_text=raw_text,
        source_ref=src,
    )


# ----------------------------
# Spec rendering helpers
# ----------------------------

EXTRA_DOC_SECTION_UNDERLINE = re.compile(r"^[-=]{3,}\s*$")

def get_inheritance_chain(spec_name: str, specs: Dict[str, SpecInfo]) -> List[str]:
    """
    Return the inheritance chain from root to the requested specification.

    Parameters
    ----------
    spec_name : str
        Specification name.
    specs : dict
        Mapping from specification name to parsed specification info.

    Returns
    -------
    list of str
        Inheritance chain from root specification to the requested
        specification, inclusive.
    """
    chain = []
    current = spec_name
    while True:
        chain.append(current)
        parent = specs[current].parent
        if parent.lower() == "none":
            break
        current = parent
    chain.reverse()
    return chain

def resolve_effective_spec(
    spec_name: str,
    specs: Dict[str, SpecInfo],
) -> Tuple[List[ResolvedSpecProperty], List[ResolvedChoiceGroupInfo], Dict[str, ResolvedEnumeration]]:
    """
    Resolve inherited properties and enumerations for a specification.

    Parameters
    ----------
    spec_name : str
        Specification name to resolve.
    specs : dict
        Mapping from specification name to parsed specification info.

    Returns
    -------
    resolved_regular_properties : list of ResolvedSpecProperty
        Effective non-choice properties with provenance.
    resolved_choice_groups : list of ResolvedChoiceGroupInfo
        Effective choice groups with provenance.
    resolved_enumerations : dict
        Effective enumerations with provenance.
    """
    chain = get_inheritance_chain(spec_name, specs)

    # Regular properties keyed by property name
    regular_map: Dict[str, ResolvedSpecProperty] = {}
    regular_order: List[str] = []

    # Choice groups keyed by group -> choice -> property name
    choice_map: Dict[str, Dict[str, Dict[str, ResolvedSpecProperty]]] = {}
    choice_group_order: List[str] = []
    choice_order_by_group: Dict[str, List[str]] = {}
    prop_order_by_choice: Dict[Tuple[str, str], List[str]] = {}

    # Enumerations keyed by enum name
    enum_map: Dict[str, ResolvedEnumeration] = {}
    enum_order: List[str] = []

    for current_spec in chain:
        spec = specs[current_spec]
        local_regular, local_choice_groups = classify_properties(spec.properties)

        # Regular properties
        for prop in local_regular:
            if prop.name not in regular_map:
                regular_map[prop.name] = ResolvedSpecProperty(
                    prop=prop,
                    origin=OriginInfo(
                        defining_spec=current_spec,
                        inherited=(current_spec != spec_name),
                        overridden_parent=None,
                    ),
                )
                regular_order.append(prop.name)
            else:
                previous_origin = regular_map[prop.name].origin.defining_spec
                regular_map[prop.name] = ResolvedSpecProperty(
                    prop=prop,
                    origin=OriginInfo(
                        defining_spec=current_spec,
                        inherited=(current_spec != spec_name),
                        overridden_parent=previous_origin,
                    ),
                )

        # Choice groups
        for group in local_choice_groups:
            if group.name not in choice_map:
                choice_map[group.name] = {}
                choice_group_order.append(group.name)
                choice_order_by_group[group.name] = []

            for choice_name, props in group.choices.items():
                if choice_name not in choice_map[group.name]:
                    choice_map[group.name][choice_name] = {}
                    choice_order_by_group[group.name].append(choice_name)
                    prop_order_by_choice[(group.name, choice_name)] = []

                for prop in props:
                    prop_key = prop.name
                    if prop_key not in choice_map[group.name][choice_name]:
                        choice_map[group.name][choice_name][prop_key] = ResolvedSpecProperty(
                            prop=prop,
                            origin=OriginInfo(
                                defining_spec=current_spec,
                                inherited=(current_spec != spec_name),
                                overridden_parent=None,
                            ),
                        )
                        prop_order_by_choice[(group.name, choice_name)].append(prop_key)
                    else:
                        previous_origin = choice_map[group.name][choice_name][prop_key].origin.defining_spec
                        choice_map[group.name][choice_name][prop_key] = ResolvedSpecProperty(
                            prop=prop,
                            origin=OriginInfo(
                                defining_spec=current_spec,
                                inherited=(current_spec != spec_name),
                                overridden_parent=previous_origin,
                            ),
                        )

        # Enumerations
        for enum_name, enum_values in spec.enumerations.items():
            if enum_name not in enum_map:
                enum_map[enum_name] = ResolvedEnumeration(
                    name=enum_name,
                    values=list(enum_values),
                    origin=OriginInfo(
                        defining_spec=current_spec,
                        inherited=(current_spec != spec_name),
                        overridden_parent=None,
                    ),
                )
                enum_order.append(enum_name)
            else:
                previous_origin = enum_map[enum_name].origin.defining_spec
                enum_map[enum_name] = ResolvedEnumeration(
                    name=enum_name,
                    values=list(enum_values),
                    origin=OriginInfo(
                        defining_spec=current_spec,
                        inherited=(current_spec != spec_name),
                        overridden_parent=previous_origin,
                    ),
                )

    resolved_regular_properties = [regular_map[name] for name in regular_order]

    resolved_choice_groups: List[ResolvedChoiceGroupInfo] = []
    for group_name in choice_group_order:
        ordered_choices: Dict[str, List[ResolvedSpecProperty]] = {}
        for choice_name in choice_order_by_group[group_name]:
            prop_names = prop_order_by_choice[(group_name, choice_name)]
            ordered_choices[choice_name] = [
                choice_map[group_name][choice_name][pname] for pname in prop_names
            ]
        resolved_choice_groups.append(
            ResolvedChoiceGroupInfo(name=group_name, choices=ordered_choices)
        )

    resolved_enumerations = {name: enum_map[name] for name in enum_order}
    return resolved_regular_properties, resolved_choice_groups, resolved_enumerations

def render_origin_text(origin: OriginInfo) -> str:
    """
    Convert origin metadata into human-readable text.

    Parameters
    ----------
    origin : OriginInfo
        Origin metadata.

    Returns
    -------
    str
        Human-readable origin description.
    """
    if origin.overridden_parent:
        return (
            f"defined in `{origin.defining_spec}` "
            f"(overrides inherited definition from `{origin.overridden_parent}`)"
        )
    if origin.inherited:
        return f"inherited from `{origin.defining_spec}`"
    return f"defined in `{origin.defining_spec}`"

def render_inheritance_mermaid(spec_name: str, specs: Dict[str, SpecInfo]) -> str:
    edges: List[Tuple[str, str]] = []
    current = spec_name
    while True:
        parent = specs[current].parent
        if parent.lower() == "none":
            break
        edges.append((parent, current))
        current = parent

    lines = ["```{mermaid}", "flowchart TB"]
    nodes = set()
    for a, b in edges:
        nodes.add(a)
        nodes.add(b)
    for name in sorted(nodes):
        lines.append(f'  {slugify(name)}["{name}"]')
    for a, b in edges:
        lines.append(f"  {slugify(a)} --> {slugify(b)}")
    lines.append("```")
    return "\n".join(lines) + "\n\n"


def render_construction_examples(spec_name: str) -> str:
    dataset_var = f"my_{spec_name}"
    short_name = f"my_{spec_name}"
    descriptive = spec_name.replace("_", " ").title()

    out: List[str] = []
    out.append("## Construction\n\n")

    out.append("### Python\n\n")
    out.append("```python\n")
    out.append(
        f'{dataset_var} = escdf.Dataset("{short_name}", "{spec_name}", "{descriptive}")\n'
    )
    out.append("```\n\n")

    out.append("### Python Dynamic Class\n\n")
    out.append("```python\n")
    out.append(
        f'{dataset_var} = escdf.classes.{spec_name}("{short_name}", "{descriptive}")\n'
    )
    out.append("```\n\n")

    out.append("### Matlab\n\n")
    out.append("```matlab\n")
    out.append(
        f'{dataset_var} = escdf_dataset("{short_name}", "{spec_name}", "{descriptive}");\n'
    )
    out.append("```\n\n")

    out.append(
        "In these examples:\n\n"
        f'- `"{short_name}"` is the short ESCDF dataset identifier used as the on-disk group name\n'
        f'- `"{spec_name}"` is the specification type name\n'
        f'- `"{descriptive}"` is the human-readable descriptive name\n\n'
    )

    return "".join(out)


def shape_to_text(shape: Tuple[object, ...]) -> str:
    if len(shape) == 0:
        return "scalar"
    return " × ".join(str(v) for v in shape)

def shape_to_prose(shape: Tuple[object, ...]) -> str:
    """
    Convert a specification shape tuple into human-readable prose.

    Parameters
    ----------
    shape : tuple
        Specification shape.

    Returns
    -------
    str
        Human-readable description of the shape.
    """
    if len(shape) == 0:
        return "scalar"
    if len(shape) == 1:
        return f"one-dimensional array with shape {shape_to_text(shape)}"
    return f"array with shape {shape_to_text(shape)}"

def option_to_human_text(option: str) -> str:
    """
    Convert a raw specification option token into human-readable text.

    Parameters
    ----------
    option : str
        Raw option token.

    Returns
    -------
    str
        Human-readable option description.
    """
    if option == "optional":
        return "optional"
    if option == "variable_length":
        return "variable-length"
    if option.startswith("enum:"):
        return f"enumeration: {option.split(':', 1)[1].strip()}"
    if option.startswith("regex:"):
        return "regex constraint"
    return option

def option_to_prose(option: str) -> str:
    """
    Convert a raw specification option token into explanatory prose.

    Parameters
    ----------
    option : str
        Raw option token.

    Returns
    -------
    str
        Human-readable explanatory text.
    """
    if option == "optional":
        return "This property is optional."
    if option == "variable_length":
        return "This property stores variable-length (ragged) values."
    if option.startswith("enum:"):
        return f"This property must use values from the enumeration `{option.split(':', 1)[1].strip()}`."
    if option.startswith("regex:"):
        return "This property is constrained by a regular-expression rule."
    return f"Option: `{option}`."

def options_to_text(options: Tuple[str, ...]) -> str:
    if not options:
        return ""
    return ", ".join(option_to_human_text(opt) for opt in options)


def render_property_summary_table(properties: List[ResolvedSpecProperty]) -> str:
    rows = ["| Property | Type | Shape | Options | Origin |", "|---|---|---|---|---|"]
    for item in properties:
        prop = item.prop
        rows.append(
            f"| `{prop.name}` | {TYPE_LABELS.get(prop.dtype, prop.dtype)} | "
            f"`{shape_to_text(prop.shape)}` | {options_to_text(prop.options)} | "
            f"{render_origin_text(item.origin)} |"
        )
    return "\n".join(rows) + "\n\n"

def render_choice_group_summary_table(choice_groups: List[ResolvedChoiceGroupInfo]) -> str:
    rows = ["| Choice Group | Choices | Properties | Origin |", "|---|---|---|---|"]
    for group in choice_groups:
        choice_names = list(group.choices.keys())
        prop_names = []
        seen = set()
        origins = []
        seen_origins = set()

        for props in group.choices.values():
            for item in props:
                prop = item.prop
                if prop.name not in seen:
                    seen.add(prop.name)
                    prop_names.append(prop.name)
                origin_text = render_origin_text(item.origin)
                if origin_text not in seen_origins:
                    seen_origins.add(origin_text)
                    origins.append(origin_text)

        rows.append(
            f"| `{group.name}` | "
            f"{', '.join(f'`{c}`' for c in choice_names)} | "
            f"{', '.join(f'`{p}`' for p in prop_names)} | "
            f"{'; '.join(origins)} |"
        )
    return "\n".join(rows) + "\n\n"

def render_property_details(properties: List[ResolvedSpecProperty]) -> str:
    out: List[str] = []
    out.append("## Property Details\n\n")

    for item in properties:
        prop = item.prop
        out.append(f"### `{prop.name}`\n\n")
        out.append(f"- **Origin**: {render_origin_text(item.origin)}\n")
        out.append(f"- **Type**: {TYPE_LABELS.get(prop.dtype, prop.dtype)}\n")
        out.append(f"- **Shape**: `{shape_to_text(prop.shape)}` ({shape_to_prose(prop.shape)})\n")
        if prop.options:
            out.append("- **Options**:\n")
            for opt in prop.options:
                out.append(f"  - {option_to_prose(opt)}\n")
        out.append("\n")

    return "".join(out)

def render_choice_group_details(choice_groups: List[ResolvedChoiceGroupInfo]) -> str:
    if not choice_groups:
        return ""

    out: List[str] = []
    out.append("## Choice Group Details\n\n")

    for idx, group in enumerate(choice_groups):
        if idx > 0:
            out.append("---\n\n")

        out.append(f"### `{group.name}`\n\n")
        out.append(
            f"This choice group defines alternative valid representations for "
            f"`{group.name}`. Exactly one of the choices below should be used.\n\n"
        )

        # Visible summary for the whole choice group
        out.append(
            render_choice_group_summary_table(
                [group]
            )
        )

        # One dropdown per branch
        for choice_name, items in group.choices.items():
            out.append(f":::{{dropdown}} `{choice_name}`\n\n")

            # Summary table for just this branch
            out.append(render_property_summary_table(items))

            for item in items:
                prop = item.prop
                out.append(f"**Property:** `{prop.name}`\n\n")
                out.append(f"- **Origin**: {render_origin_text(item.origin)}\n")
                out.append(f"- **Type**: {TYPE_LABELS.get(prop.dtype, prop.dtype)}\n")
                out.append(
                    f"- **Shape**: `{shape_to_text(prop.shape)}` "
                    f"({shape_to_prose(prop.shape)})\n"
                )
                if prop.options:
                    out.append("- **Options**:\n")
                    for opt in prop.options:
                        out.append(f"  - {option_to_prose(opt)}\n")
                out.append("\n")

            out.append(":::\n\n")

    return "".join(out)

def render_enumerations(enumerations: Dict[str, ResolvedEnumeration]) -> str:
    if not enumerations:
        return ""

    out: List[str] = []
    out.append("## Enumerations\n\n")
    for enum_name, enum_info in enumerations.items():
        out.append(f"### `{enum_name}`\n\n")
        out.append(f"- **Origin**: {render_origin_text(enum_info.origin)}\n\n")
        for value in enum_info.values:
            out.append(f"- `{value}`\n")
        out.append("\n")
    return "".join(out)


def render_parent_and_children(spec: SpecInfo, child_map: Dict[str, List[str]]) -> str:
    out: List[str] = []
    out.append(f"- Version: `v{spec.version[0]}.{spec.version[1]}.{spec.version[2]}`\n")
    if spec.parent.lower() == "none":
        out.append("- Extends: `none`\n")
    else:
        out.append(f"- Extends: [`{spec.parent}`]({link_to_spec(spec.parent)})\n")

    children = sorted(child_map.get(spec.name, []))
    if children:
        out.append("- Derived Specifications:\n")
        for child in children:
            out.append(f"  - [`{child}`]({link_to_spec(child)})\n")
    return "".join(out) + "\n"

def split_extra_doc_sections(text: str) -> List[Tuple[str, str]]:
    """
    Split trailing specification documentation into optional titled sections.

    Parameters
    ----------
    text : str
        Extra documentation text.

    Returns
    -------
    list of tuple
        Ordered list of ``(title, body)`` pairs. An empty title indicates
        leading prose that appeared before the first heading-like section.
    """
    text = (text or "").strip("\n")
    if not text.strip():
        return []

    lines = text.splitlines()
    sections: List[Tuple[str, List[str]]] = []

    current_title = ""
    current_body: List[str] = []
    found_heading = False

    i = 0
    while i < len(lines):
        line = lines[i]
        if (
            line.strip()
            and (i + 1) < len(lines)
            and EXTRA_DOC_SECTION_UNDERLINE.match(lines[i + 1].strip())
        ):
            found_heading = True
            sections.append((current_title, current_body))
            current_title = line.strip()
            current_body = []
            i += 2
            if i < len(lines) and not lines[i].strip():
                i += 1
            continue

        current_body.append(line)
        i += 1

    sections.append((current_title, current_body))

    if not found_heading:
        return [("", text.strip())]

    out: List[Tuple[str, str]] = []
    for title, body_lines in sections:
        body = "\n".join(body_lines).strip()
        if title or body:
            out.append((title, body))
    return out

def render_extra_documentation(text: str) -> str:
    """
    Render trailing specification documentation as structured Markdown.

    Parameters
    ----------
    text : str
        Extra documentation text parsed from a specification file.

    Returns
    -------
    str
        Rendered Markdown.
    """
    sections = split_extra_doc_sections(text)
    if not sections:
        return ""

    out: List[str] = []
    out.append("## Additional Documentation\n\n")

    # If there is only plain prose and no headings
    if len(sections) == 1 and sections[0][0] == "":
        out.append(sections[0][1].strip() + "\n\n")
        return "".join(out)

    for title, body in sections:
        if title:
            out.append(f"### {title}\n\n")
        if body:
            out.append(body.strip() + "\n\n")

    return "".join(out)

def render_spec_page(
    out_dir: Path,
    spec: SpecInfo,
    specs: Dict[str, SpecInfo],
    child_map: Dict[str, List[str]],
    repo_url: str,
    ref: str,
) -> str:
    out: List[str] = []
    out.append("---\n")
    out.append(f"short_title: {spec.name}\n")
    out.append("---\n")
    out.append(f"{myst_target(spec.name, source=True)}\n")
    out.append(f"# {spec.name}\n\n")
    out.append(render_source_link(repo_url, ref, spec.source_ref))
    out.append("\n")
    out.append(render_parent_and_children(spec, child_map))
    out.append(render_inheritance_mermaid(spec.name, specs))
    out.append(render_construction_examples(spec.name))

    if spec.documentation:
        out.append("## Summary\n\n")
        out.append(spec.documentation.strip() + "\n\n")

    resolved_regular_properties, resolved_choice_groups, resolved_enumerations = resolve_effective_spec(
        spec.name, specs
    )

    if resolved_regular_properties:
        out.append("## Properties\n\n")
        out.append(render_property_summary_table(resolved_regular_properties))

    if resolved_choice_groups:
        out.append("## Choice Groups\n\n")
        out.append(render_choice_group_summary_table(resolved_choice_groups))

    if resolved_regular_properties:
        out.append(render_property_details(resolved_regular_properties))

    if resolved_choice_groups:
        out.append(render_choice_group_details(resolved_choice_groups))

    out.append(render_enumerations(resolved_enumerations))

    out.append(render_extra_documentation(spec.extra_documentation))

    out.append("## Raw Specification\n\n")
    out.append("```text\n")
    out.append(spec.raw_text.rstrip("\n"))
    out.append("\n```\n")

    return "".join(out)


def render_specifications_api_page(
    out_dir: Path,
    specs: Dict[str, SpecInfo],
) -> str:
    out: List[str] = []
    out.append("---\n")
    out.append("short_title: Specification Reference\n")
    out.append("---\n")
    out.append("# Specification Reference\n\n")
    out.append(
        "This section documents the ESCDF specification files that define\n"
        "the schema for metadata and activity-result datasets.\n\n"
    )

    rows: List[Tuple[str, str, str]] = []
    preferred_order = [
        "parameter_set",
        "activity_result",
        "unknown",
        "data",
        "channel_table",
        "geometry",
        "point_cloud",
        "mode",
        "scalar",
        "vector",
        "matrix",
    ]

    emitted = set()
    for name in preferred_order:
        if name in specs:
            rows.append(
                (
                    name,
                    link_to_spec(name),
                    first_paragraph(specs[name].documentation or specs[name].extra_documentation),
                )
            )
            emitted.add(name)

    for name in sorted(specs.keys()):
        if name in emitted:
            continue
        rows.append(
            (
                name,
                link_to_spec(name),
                first_paragraph(specs[name].documentation or specs[name].extra_documentation),
            )
        )

    out.append(render_summary_table(rows))
    return "".join(out)


def write_toc_snippet(out_dir: Path, specs: Dict[str, SpecInfo]) -> None:
    lines: List[str] = []
    lines.append(f"        - file: {toc_file_entry(spec_api_page_path(out_dir), out_dir)}")
    lines.append("          children:")

    preferred_order = [
        "parameter_set",
        "activity_result",
        "unknown",
        "data",
        "channel_table",
        "geometry",
        "point_cloud",
        "mode",
        "scalar",
        "vector",
        "matrix",
    ]

    emitted = set()
    for name in preferred_order:
        if name in specs:
            lines.append(f"            - file: {toc_file_entry(spec_page_path(out_dir, name), out_dir)}")
            emitted.add(name)

    for name in sorted(specs.keys()):
        if name in emitted:
            continue
        lines.append(f"            - file: {toc_file_entry(spec_page_path(out_dir, name), out_dir)}")

    write_file(out_dir / "_toc.yml.inc", "\n".join(lines) + "\n")


# ----------------------------
# Main
# ----------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate MyST Markdown documentation for ESCDF specification files."
    )
    parser.add_argument(
        "--src",
        required=True,
        type=Path,
        help="Directory containing ESCDF specification .txt files.",
    )
    parser.add_argument(
        "--out",
        required=True,
        type=Path,
        help="Output directory for generated specification docs.",
    )
    parser.add_argument(
        "--repo",
        default="",
        help="Repository URL for source links.",
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
        help="Do not generate the specification landing page.",
    )

    args = parser.parse_args()

    src_dir = args.src.resolve()
    out_dir = args.out.resolve()
    repo_root = args.repo_root.resolve()
    repo_url = args.repo
    ref = args.ref

    ensure_dir(out_dir)
    ensure_dir(out_dir / "specs")

    specs: Dict[str, SpecInfo] = {}
    for path in sorted(src_dir.glob("*.txt")):
        spec = parse_specification_file(path, repo_root)
        specs[spec.name] = spec

    child_map: Dict[str, List[str]] = {}
    for spec in specs.values():
        if spec.parent.lower() == "none":
            continue
        child_map.setdefault(spec.parent, []).append(spec.name)

    for spec in specs.values():
        content = render_spec_page(out_dir, spec, specs, child_map, repo_url, ref)
        write_file(spec_page_path(out_dir, spec.name), content)

    if not args.no_index:
        write_file(
            spec_api_page_path(out_dir),
            render_specifications_api_page(out_dir, specs),
        )

    write_toc_snippet(out_dir, specs)

    print(f"Generated specification docs in {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())