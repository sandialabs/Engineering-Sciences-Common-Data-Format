from __future__ import annotations

from pathlib import Path

from .specification import (
    ACCEPTABLE_DATATYPES,
    Version,
    Dimension,
    PropertyDefinition,
    ConstraintRule,
    StorageHint,
    Specification,
)


class SpecificationParser:
    """
    Parser for converting ESCDF specification text into canonical
    ``Specification`` objects.

    Notes
    -----
    This parser targets the current human-authored ESCDF specification
    format and normalizes it into the canonical internal model.

    Parsing proceeds conceptually in stages:
    1. raw file parsing
    2. property normalization
    3. local ``Specification`` construction

    Inheritance resolution is intentionally handled elsewhere.
    """

    @staticmethod
    def parse_file(file_path: str) -> Specification:
        """
        Parse a specification file into a canonical local specification.

        Parameters
        ----------
        file_path : str
            Path to the specification file.

        Returns
        -------
        Specification
            Canonical local specification parsed from the file.

        Raises
        ------
        FileNotFoundError
            Raised if the file does not exist.
        ValueError
            Raised if the file contents do not conform to the expected
            specification format.
        """
        path = Path(file_path)
        if not path.is_file():
            raise FileNotFoundError(f"Specification file not found: {file_path}")

        text = path.read_text(encoding="utf-8")
        return SpecificationParser.parse_text(text, source_file=str(path))

    @staticmethod
    def parse_text(text: str, source_file: str | None = None) -> Specification:
        """
        Parse specification text into a canonical local specification.

        Parameters
        ----------
        text : str
            Specification text.
        source_file : str, optional
            Source file path for provenance and debugging.

        Returns
        -------
        Specification
            Canonical local specification object.

        Raises
        ------
        ValueError
            Raised if the specification text is malformed.
        """
        if not isinstance(text, str):
            raise ValueError("text must be a string.")

        lines = text.splitlines()
        if len(lines) < 1:
            raise ValueError("Specification text is empty.")

        lines = [line.rstrip() for line in lines]

        name, version = SpecificationParser._parse_header_line(lines[0])

        extends_line_index = SpecificationParser._find_extends_line_index(lines)
        extends = SpecificationParser._parse_extends_line(lines)

        properties_section_start = SpecificationParser._find_section_header(lines, "properties")
        enumerations_section_start = SpecificationParser._find_section_header(lines, "enumerations")
        constraints_section_start = SpecificationParser._find_section_header(lines, "constraints")
        chunking_section_start = SpecificationParser._find_section_header(lines, "chunking")
        storage_hints_section_start = SpecificationParser._find_section_header(
            lines, "storage_hints"
        )
        notes_section_start = SpecificationParser._find_section_header(lines, "notes")

        if properties_section_start is None:
            raise ValueError(f'Specification "{name}" is missing a required "properties" section.')

        documentation = SpecificationParser._extract_documentation_block(
            lines,
            extends_line_index=extends_line_index,
            properties_section_start=properties_section_start,
        )

        raw_property_lines = SpecificationParser._extract_section_body_lines(
            lines, properties_section_start
        )

        local_properties: list[PropertyDefinition] = []
        constraints: list[ConstraintRule] = []

        for raw_line in raw_property_lines:
            prop, prop_constraints = SpecificationParser._parse_property_line(
                raw_line,
                source_specification=name,
            )
            local_properties.append(prop)
            constraints.extend(prop_constraints)

        enumerations = {}
        if enumerations_section_start is not None:
            enumerations = SpecificationParser._parse_enumerations_section(
                lines,
                enumerations_section_start,
            )

        if constraints_section_start is not None:
            constraints.extend(
                SpecificationParser._parse_constraints_section(
                    lines,
                    constraints_section_start,
                    source_specification=name,
                )
            )

        storage_hints: list[StorageHint] = []
        if chunking_section_start is not None:
            storage_hints.extend(
                SpecificationParser._parse_chunking_section(
                    lines,
                    chunking_section_start,
                    source_specification=name,
                )
            )
        if storage_hints_section_start is not None:
            storage_hints.extend(
                SpecificationParser._parse_storage_hints_section(
                    lines,
                    storage_hints_section_start,
                    source_specification=name,
                )
            )

        notes = ""
        if notes_section_start is not None:
            notes = SpecificationParser._extract_notes_block(lines, notes_section_start)

        return Specification(
            name=name,
            version=version,
            extends=extends,
            documentation=documentation,
            notes=notes,
            local_properties=local_properties,
            enumerations=enumerations,
            constraints=constraints,
            storage_hints=storage_hints,
            source_file=source_file,
        )

    @staticmethod
    def _parse_header_line(header_line: str) -> tuple[str, Version]:
        """
        Parse the specification header line.

        Parameters
        ----------
        header_line : str
            Header line expected to contain the specification name and
            version.

        Returns
        -------
        tuple of (str, Version)
            Specification name and version object.

        Raises
        ------
        ValueError
            Raised if the header line is malformed.
        """
        parts = header_line.split("-")
        if len(parts) < 2:
            raise ValueError(
                f'Invalid specification header line: "{header_line}". '
                'Expected format "name - vX.Y.Z".'
            )

        name_part = parts[0].strip()
        version_part = "-".join(parts[1:]).strip()

        if not name_part:
            raise ValueError("Specification name in header cannot be empty.")

        if not version_part.startswith("v"):
            raise ValueError(f'Invalid version string "{version_part}". Expected format "vX.Y.Z".')

        version_numbers = version_part[1:].split(".")
        if len(version_numbers) != 3:
            raise ValueError(f'Invalid version string "{version_part}". Expected format "vX.Y.Z".')

        try:
            major, minor, patch = (int(v) for v in version_numbers)
        except ValueError as exc:
            raise ValueError(
                f'Invalid version string "{version_part}". Version components must be integers.'
            ) from exc

        name = name_part.replace(" ", "_")
        version = Version(major, minor, patch)
        return name, version

    @staticmethod
    def _find_extends_line_index(lines: list[str]) -> int:
        """
        Return the index of the ``extends:`` line.

        Parameters
        ----------
        lines : list of str
            Specification text lines.

        Returns
        -------
        int
            Index of the ``extends:`` line.

        Raises
        ------
        ValueError
            Raised if no ``extends:`` line is found.
        """
        for i, line in enumerate(lines):
            if line.strip().startswith("extends:"):
                return i
        raise ValueError('Specification is missing an "extends:" line.')

    @staticmethod
    def _parse_extends_line(lines: list[str]) -> str | None:
        """
        Parse the parent specification name from the ``extends:`` line.

        Parameters
        ----------
        lines : list of str
            Specification text lines.

        Returns
        -------
        str or None
            Parent specification name, or ``None`` if the specification
            extends ``none``.
        """
        index = SpecificationParser._find_extends_line_index(lines)
        line = lines[index].strip()
        _, value = line.split(":", 1)
        parent = value.strip()
        if parent.lower() == "none":
            return None
        return parent

    @staticmethod
    def _find_section_header(lines: list[str], section_name: str) -> int | None:
        """
        Find the index of a top-level section header.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        section_name : str
            Section name to locate.

        Returns
        -------
        int or None
            Index of the section header, or ``None`` if not found.
        """
        section_name = section_name.strip().lower()
        for i, line in enumerate(lines):
            if line.strip().lower() == section_name:
                return i
        return None

    @staticmethod
    def _extract_documentation_block(
        lines: list[str],
        extends_line_index: int,
        properties_section_start: int,
    ) -> str:
        """
        Extract the freeform documentation block preceding the properties
        section.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        extends_line_index : int
            Index of the ``extends:`` line.
        properties_section_start : int
            Index of the ``properties`` section header.

        Returns
        -------
        str
            Documentation block text.
        """
        start = extends_line_index + 1
        end = properties_section_start
        block_lines = lines[start:end]
        return SpecificationParser._trim_blank_lines(block_lines)

    @staticmethod
    def _extract_notes_block(lines: list[str], notes_section_start: int) -> str:
        """
        Extract the notes section body.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        notes_section_start : int
            Index of the ``notes`` section header.

        Returns
        -------
        str
            Notes block text.
        """
        body_lines = SpecificationParser._extract_section_body_lines(lines, notes_section_start)
        return "\n".join(body_lines).strip()

    @staticmethod
    def _extract_section_body_lines(lines: list[str], section_start_index: int) -> list[str]:
        """
        Extract the body lines following a top-level section header.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        section_start_index : int
            Index of the section header line.

        Returns
        -------
        list of str
            Section body lines, trimmed of leading and trailing blank lines.

        Notes
        -----
        This method assumes the current ESCDF section layout in which a
        section header is followed by an underline line.
        """
        start = section_start_index + 2
        if start > len(lines):
            return []

        known_section_names = {
            "properties",
            "enumerations",
            "constraints",
            "chunking",
            "storage_hints",
            "notes",
        }

        body = []
        i = start
        while i < len(lines):
            stripped = lines[i].strip()
            if stripped.lower() in known_section_names:
                break
            body.append(lines[i])
            i += 1

        return SpecificationParser._trim_blank_lines_list(body)

    @staticmethod
    def _trim_blank_lines(lines: list[str]) -> str:
        """
        Trim leading and trailing blank lines and return joined text.

        Parameters
        ----------
        lines : list of str
            Input lines.

        Returns
        -------
        str
            Trimmed joined text.
        """
        trimmed = SpecificationParser._trim_blank_lines_list(lines)
        return "\n".join(trimmed).strip()

    @staticmethod
    def _trim_blank_lines_list(lines: list[str]) -> list[str]:
        """
        Trim leading and trailing blank lines from a list of lines.

        Parameters
        ----------
        lines : list of str
            Input lines.

        Returns
        -------
        list of str
            Trimmed line list.
        """
        start = 0
        end = len(lines)

        while start < end and not lines[start].strip():
            start += 1
        while end > start and not lines[end - 1].strip():
            end -= 1

        return lines[start:end]

    @staticmethod
    def _parse_property_line(
        raw_line: str,
        *,
        source_specification: str,
    ) -> tuple[PropertyDefinition, list[ConstraintRule]]:
        """
        Parse one property line into a canonical property definition and
        any lifted constraint rules.

        Parameters
        ----------
        raw_line : str
            Raw property line from the specification.
        source_specification : str
            Name of the specification from which the line originated.

        Returns
        -------
        tuple of (PropertyDefinition, list of ConstraintRule)
            Parsed canonical property definition and any lifted relational
            constraints.

        Raises
        ------
        ValueError
            Raised if the property line is malformed.
        """
        line = raw_line.strip()
        if not line:
            raise ValueError("Encountered blank property line unexpectedly.")

        raw_parts = [part.strip() for part in line.split("-")]

        if len(raw_parts) < 2:
            raise ValueError(f'Invalid property line: "{raw_line}"')

        if len(raw_parts) > 4:
            raw_parts = raw_parts[:3] + ["-".join(raw_parts[3:]).strip()]

        name = raw_parts[0]
        datatype = raw_parts[1]

        if datatype not in ACCEPTABLE_DATATYPES:
            raise ValueError(
                f'Invalid datatype "{datatype}" for property "{name}" '
                f'in specification "{source_specification}".'
            )

        if len(raw_parts) >= 3 and raw_parts[2]:
            shape = SpecificationParser._parse_shape_field(raw_parts[2])
        else:
            shape = []

        option_tokens = []
        if len(raw_parts) >= 4 and raw_parts[3]:
            option_tokens = SpecificationParser._split_option_tokens(raw_parts[3])

        optional = False
        variable_length = False
        enumeration_name = None
        regex = None
        choice_group = None
        choice_branch = None
        value_constraints: list[str] = []
        constraints: list[ConstraintRule] = []

        for token in option_tokens:
            if token == "optional":
                optional = True
            elif token == "variable_length":
                variable_length = True
            elif token.startswith("enum:"):
                enumeration_name = token.split(":", 1)[1].strip()
            elif token.startswith("regex:"):
                regex = token.split(":", 1)[1].strip()
            elif token.startswith("or:"):
                choice_group, choice_branch = SpecificationParser._parse_choice_token(token)
            elif token.startswith("requires:"):
                target = token.split(":", 1)[1].strip()
                constraints.append(
                    ConstraintRule(
                        kind="requires",
                        subject_properties=[name],
                        target_properties=[target],
                        source_property=name,
                        source_choice_group=choice_group,
                        source_choice_branch=choice_branch,
                        source_specification=source_specification,
                    )
                )
            elif token in {
                "positive",
                "nonnegative",
                "finite",
                "increasing",
                "strictly_increasing",
                "unique",
                "nonempty",
            }:
                value_constraints.append(token)
            else:
                raise ValueError(
                    f'Unrecognized property option token "{token}" on property "{name}" '
                    f'in specification "{source_specification}".'
                )

        prop = PropertyDefinition(
            name=name,
            datatype=datatype,
            shape=shape,
            optional=optional,
            variable_length=variable_length,
            enumeration_name=enumeration_name,
            regex=regex,
            choice_group=choice_group,
            choice_branch=choice_branch,
            value_constraints=value_constraints,
            source_specification=source_specification,
        )

        return prop, constraints

    @staticmethod
    def _parse_shape_field(shape_field: str) -> list[Dimension]:
        """
        Parse a property shape field.

        Parameters
        ----------
        shape_field : str
            Raw shape field text.

        Returns
        -------
        list of Dimension
            Canonical property shape. Scalars are represented by an empty
            list.

        Raises
        ------
        ValueError
            Raised if the shape field contains invalid dimension tokens.
        """
        shape_field = shape_field.strip()
        if shape_field.lower() == "scalar":
            return []

        dims = []
        for token in shape_field.split(","):
            token = token.strip()
            if not token:
                raise ValueError(f'Invalid empty dimension token in shape "{shape_field}".')
            try:
                value = int(token)
                dims.append(Dimension.fixed(value))
            except ValueError:
                dims.append(Dimension.symbolic(token))
        return dims

    @staticmethod
    def _split_option_tokens(option_field: str) -> list[str]:
        """
        Split a property option field into option tokens.

        Parameters
        ----------
        option_field : str
            Raw options field text.

        Returns
        -------
        list of str
            Parsed option tokens.

        Notes
        -----
        Commas inside regex patterns are preserved by treating the first
        ``regex:`` token as consuming the remainder of the field.
        """
        parts = [part.strip() for part in option_field.split(",") if part.strip()]
        if not parts:
            return []

        regex_index = None
        for i, token in enumerate(parts):
            if token.startswith("regex:"):
                regex_index = i
                break

        if regex_index is not None:
            regex_token = ",".join(parts[regex_index:]).strip()
            parts = parts[:regex_index] + [regex_token]

        return parts

    @staticmethod
    def _parse_choice_token(token: str) -> tuple[str, str]:
        """
        Parse a choice token in ``or:group:branch`` form.

        Parameters
        ----------
        token : str
            Raw choice token.

        Returns
        -------
        tuple of (str, str)
            Choice group and choice branch.

        Raises
        ------
        ValueError
            Raised if the token is malformed.
        """
        parts = token.split(":")
        if len(parts) != 3:
            raise ValueError(f'Invalid choice token "{token}". Expected format "or:group:branch".')
        _, group, branch = parts
        group = group.strip()
        branch = branch.strip()
        if not group or not branch:
            raise ValueError(f'Invalid choice token "{token}". Group and branch must be nonempty.')
        return group, branch

    @staticmethod
    def _parse_enumerations_section(
        lines: list[str],
        enumerations_section_start: int,
    ) -> dict[str, list[str]]:
        """
        Parse the enumerations section.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        enumerations_section_start : int
            Index of the ``enumerations`` section header.

        Returns
        -------
        dict of {str: list of str}
            Parsed enumeration definitions.

        Raises
        ------
        ValueError
            Raised if an enumeration line is malformed.
        """
        body_lines = SpecificationParser._extract_section_body_lines(
            lines, enumerations_section_start
        )

        enumerations: dict[str, list[str]] = {}
        for raw_line in body_lines:
            line = raw_line.strip()
            if not line:
                continue

            parts = [part.strip() for part in line.split("-")]
            if len(parts) < 2:
                raise ValueError(f'Invalid enumeration line: "{raw_line}"')

            enum_name = parts[0]
            enum_values_str = "-".join(parts[1:]).strip()
            values = [v.strip() for v in enum_values_str.split(",")]
            values = [v for v in values if v != ""]

            if not enum_name:
                raise ValueError(f'Invalid enumeration line: "{raw_line}"')
            enumerations[enum_name] = values

        return enumerations

    @staticmethod
    def _parse_constraints_section(
        lines: list[str],
        constraints_section_start: int,
        *,
        source_specification: str,
    ) -> list[ConstraintRule]:
        """
        Parse an explicit constraints section.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        constraints_section_start : int
            Index of the ``constraints`` section header.
        source_specification : str
            Source specification name.

        Returns
        -------
        list of ConstraintRule
            Parsed explicit constraint rules.

        Notes
        -----
        This is currently a placeholder and returns an empty list until an
        explicit constraints-section syntax is designed and implemented.
        """
        _ = lines
        _ = constraints_section_start
        _ = source_specification
        return []

    @staticmethod
    def _parse_chunking_section(
        lines: list[str],
        chunking_section_start: int,
        *,
        source_specification: str,
    ) -> list[StorageHint]:
        """
        Parse an explicit chunking section.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        chunking_section_start : int
            Index of the ``chunking`` section header.
        source_specification : str
            Source specification name.

        Returns
        -------
        list of StorageHint
            Parsed chunking-related storage hints.

        Notes
        -----
        This is currently a placeholder and returns an empty list until a
        chunking-section syntax is designed and implemented.
        """
        _ = lines
        _ = chunking_section_start
        _ = source_specification
        return []

    @staticmethod
    def _parse_storage_hints_section(
        lines: list[str],
        storage_hints_section_start: int,
        *,
        source_specification: str,
    ) -> list[StorageHint]:
        """
        Parse an explicit storage-hints section.

        Parameters
        ----------
        lines : list of str
            Specification text lines.
        storage_hints_section_start : int
            Index of the ``storage_hints`` section header.
        source_specification : str
            Source specification name.

        Returns
        -------
        list of StorageHint
            Parsed storage hints.

        Notes
        -----
        This is currently a placeholder and returns an empty list until an
        explicit storage-hints-section syntax is designed and implemented.
        """
        _ = lines
        _ = storage_hints_section_start
        _ = source_specification
        return []
