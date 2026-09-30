from __future__ import annotations

from typing import Optional


ACCEPTABLE_DATATYPES = {
    "u1",
    "u2",
    "u4",
    "u8",
    "i1",
    "i2",
    "i4",
    "i8",
    "f4",
    "f8",
    "c8",
    "c16",
    "str",
    "bytes",
}


class Version:
    """
    Version number for an ESCDF specification.

    Parameters
    ----------
    major : int
        Major version number.
    minor : int
        Minor version number.
    patch : int
        Patch version number.

    Raises
    ------
    ValueError
        Raised if any version component is not an integer or is negative.

    Notes
    -----
    A version is associated with a specification itself, not with an
    inherited ancestry as a composite object.
    """

    __slots__ = ("major", "minor", "patch")

    def __init__(self, major: int, minor: int, patch: int):
        for name, value in (("major", major), ("minor", minor), ("patch", patch)):
            if not isinstance(value, int):
                raise ValueError(f"{name} must be an integer.")
            if value < 0:
                raise ValueError(f"{name} must be nonnegative.")
        self.major = major
        self.minor = minor
        self.patch = patch

    def as_tuple(self) -> tuple[int, int, int]:
        """
        Return the version as a tuple.

        Returns
        -------
        tuple of int
            Tuple in the form ``(major, minor, patch)``.
        """
        return (self.major, self.minor, self.patch)

    def __repr__(self) -> str:
        return f"Version({self.major}, {self.minor}, {self.patch})"

    def __str__(self) -> str:
        return f"v{self.major}.{self.minor}.{self.patch}"


class Dimension:
    """
    One dimension token in a property shape.

    Parameters
    ----------
    kind : {'fixed', 'symbolic'}
        Dimension kind.
    value : int or str
        Dimension value. For fixed dimensions this must be a positive
        integer. For symbolic dimensions this must be a nonempty string.

    Raises
    ------
    ValueError
        Raised if the dimension kind is invalid or the supplied value is
        inconsistent with the kind.

    Notes
    -----
    Shapes are represented as ordered lists of ``Dimension`` objects.
    Scalar properties are represented by an empty shape list.
    """

    __slots__ = ("kind", "value")

    def __init__(self, kind: str, value):
        if kind not in {"fixed", "symbolic"}:
            raise ValueError('Dimension kind must be either "fixed" or "symbolic".')

        if kind == "fixed":
            if not isinstance(value, int):
                raise ValueError("Fixed dimension value must be an integer.")
            if value <= 0:
                raise ValueError("Fixed dimension value must be positive.")
        else:
            if not isinstance(value, str):
                raise ValueError("Symbolic dimension value must be a string.")
            if not value.strip():
                raise ValueError("Symbolic dimension value must be nonempty.")
            value = value.strip()

        self.kind = kind
        self.value = value

    @classmethod
    def fixed(cls, value: int) -> "Dimension":
        """
        Construct a fixed dimension.

        Parameters
        ----------
        value : int
            Positive integer dimension size.

        Returns
        -------
        Dimension
            Fixed-dimension object.
        """
        return cls("fixed", value)

    @classmethod
    def symbolic(cls, value: str) -> "Dimension":
        """
        Construct a symbolic dimension.

        Parameters
        ----------
        value : str
            Symbolic dimension name.

        Returns
        -------
        Dimension
            Symbolic-dimension object.
        """
        return cls("symbolic", value)

    @property
    def is_fixed(self) -> bool:
        """
        Return whether this dimension is fixed-size.

        Returns
        -------
        bool
            ``True`` if the dimension is fixed-size.
        """
        return self.kind == "fixed"

    @property
    def is_symbolic(self) -> bool:
        """
        Return whether this dimension is symbolic.

        Returns
        -------
        bool
            ``True`` if the dimension is symbolic.
        """
        return self.kind == "symbolic"

    def __repr__(self) -> str:
        return f"Dimension(kind={self.kind!r}, value={self.value!r})"

    def __str__(self) -> str:
        return str(self.value)


class PropertyDefinition:
    """
    Canonical normalized representation of one property declaration.

    Parameters
    ----------
    name : str
        Property name.
    datatype : str
        ESCDF datatype string.
    shape : list of Dimension
        Ordered property shape definition. Scalars are represented by an
        empty list.
    optional : bool, default=False
        Whether the property is unconditionally optional in the schema.
    variable_length : bool, default=False
        Whether the property is declared as variable-length / ragged.
    enumeration_name : str, optional
        Name of the enumeration constraining the property's values.
    regex : str, optional
        Regular expression constraining the property's values.
    choice_group : str, optional
        Name of the choice group to which this property declaration
        belongs.
    choice_branch : str, optional
        Name of the branch within the choice group.
    value_constraints : list of str, optional
        Intrinsic value constraints such as ``positive`` or
        ``increasing``.
    source_specification : str, optional
        Name of the specification file from which this declaration
        originated.

    Raises
    ------
    ValueError
        Raised if any field is malformed or internally inconsistent.

    Notes
    -----
    This object represents exactly one canonical property declaration.
    If a specification declares multiple alternatives for a single
    logical property name, those alternatives are represented as
    multiple ``PropertyDefinition`` objects.

    Relational modifiers such as ``requires:*`` must not remain attached
    to this object after normalization; they are lifted into
    ``ConstraintRule`` objects.
    """

    __slots__ = (
        "name",
        "datatype",
        "shape",
        "optional",
        "variable_length",
        "enumeration_name",
        "regex",
        "choice_group",
        "choice_branch",
        "value_constraints",
        "source_specification",
    )

    def __init__(
        self,
        name: str,
        datatype: str,
        shape: list[Dimension],
        *,
        optional: bool = False,
        variable_length: bool = False,
        enumeration_name: Optional[str] = None,
        regex: Optional[str] = None,
        choice_group: Optional[str] = None,
        choice_branch: Optional[str] = None,
        value_constraints: Optional[list[str]] = None,
        source_specification: Optional[str] = None,
    ):
        if not isinstance(name, str) or not name.strip():
            raise ValueError("PropertyDefinition name must be a nonempty string.")
        name = name.strip()

        if datatype not in ACCEPTABLE_DATATYPES:
            raise ValueError(
                f'PropertyDefinition datatype "{datatype}" is not valid. '
                f"Must be one of {sorted(ACCEPTABLE_DATATYPES)}."
            )

        if not isinstance(shape, list):
            raise ValueError("PropertyDefinition shape must be a list of Dimension.")
        if not all(isinstance(dim, Dimension) for dim in shape):
            raise ValueError("PropertyDefinition shape entries must all be Dimension.")

        if not isinstance(optional, bool):
            raise ValueError("optional must be boolean.")
        if not isinstance(variable_length, bool):
            raise ValueError("variable_length must be boolean.")

        if enumeration_name is not None:
            if not isinstance(enumeration_name, str) or not enumeration_name.strip():
                raise ValueError("enumeration_name must be a nonempty string or None.")
            enumeration_name = enumeration_name.strip()

        if regex is not None:
            if not isinstance(regex, str) or not regex:
                raise ValueError("regex must be a nonempty string or None.")

        if (choice_group is None) != (choice_branch is None):
            raise ValueError(
                "choice_group and choice_branch must either both be set or both be None."
            )

        if choice_group is not None:
            if not isinstance(choice_group, str) or not choice_group.strip():
                raise ValueError("choice_group must be a nonempty string.")
            if not isinstance(choice_branch, str) or not choice_branch.strip():
                raise ValueError("choice_branch must be a nonempty string.")
            choice_group = choice_group.strip()
            choice_branch = choice_branch.strip()

        if value_constraints is None:
            value_constraints = []
        if not isinstance(value_constraints, list):
            raise ValueError("value_constraints must be a list of strings.")
        if not all(isinstance(v, str) and v.strip() for v in value_constraints):
            raise ValueError("All value_constraints must be nonempty strings.")
        value_constraints = [v.strip() for v in value_constraints]

        if source_specification is not None:
            if not isinstance(source_specification, str) or not source_specification.strip():
                raise ValueError("source_specification must be a nonempty string or None.")
            source_specification = source_specification.strip()

        self.name = name
        self.datatype = datatype
        self.shape = shape
        self.optional = optional
        self.variable_length = variable_length
        self.enumeration_name = enumeration_name
        self.regex = regex
        self.choice_group = choice_group
        self.choice_branch = choice_branch
        self.value_constraints = value_constraints
        self.source_specification = source_specification

    @property
    def is_scalar(self) -> bool:
        """
        Return whether this property is scalar.

        Returns
        -------
        bool
            ``True`` if the property shape is scalar.
        """
        return len(self.shape) == 0

    @property
    def is_choice_member(self) -> bool:
        """
        Return whether this property belongs to a choice group.

        Returns
        -------
        bool
            ``True`` if the property belongs to a choice group.
        """
        return self.choice_group is not None

    def shape_repr(self) -> str:
        """
        Return a compact string representation of the property shape.

        Returns
        -------
        str
            Shape representation. Scalars are returned as ``"scalar"``.
        """
        if self.is_scalar:
            return "scalar"
        return ",".join(str(dim) for dim in self.shape)

    def __repr__(self) -> str:
        return (
            "PropertyDefinition("
            f"name={self.name!r}, datatype={self.datatype!r}, "
            f"shape={self.shape!r}, optional={self.optional!r}, "
            f"variable_length={self.variable_length!r}, "
            f"enumeration_name={self.enumeration_name!r}, regex={self.regex!r}, "
            f"choice_group={self.choice_group!r}, choice_branch={self.choice_branch!r}, "
            f"value_constraints={self.value_constraints!r}, "
            f"source_specification={self.source_specification!r})"
        )


class ConstraintRule:
    """
    Canonical specification-level cross-property constraint.

    Parameters
    ----------
    kind : {'requires', 'paired', 'all_or_none', 'exactly_one_of'}
        Constraint kind.
    subject_properties : list of str
        Property names that define or trigger the rule.
    target_properties : list of str
        Property names referenced by the rule.
    source_property : str, optional
        Property name from which the rule originated during parse or
        normalization.
    source_choice_group : str, optional
        Choice group context from which the rule originated.
    source_choice_branch : str, optional
        Choice branch context from which the rule originated.
    source_specification : str, optional
        Specification from which the rule originated.

    Raises
    ------
    ValueError
        Raised if the rule kind is invalid or the property-name fields are
        malformed.

    Notes
    -----
    Constraint rules represent relational semantics between properties.
    They should not duplicate intrinsic property semantics already stored
    on ``PropertyDefinition``.
    """

    __slots__ = (
        "kind",
        "subject_properties",
        "target_properties",
        "source_property",
        "source_choice_group",
        "source_choice_branch",
        "source_specification",
    )

    VALID_KINDS = {
        "requires",
        "paired",
        "all_or_none",
        "exactly_one_of",
    }

    def __init__(
        self,
        kind: str,
        subject_properties: list[str],
        target_properties: list[str],
        *,
        source_property: Optional[str] = None,
        source_choice_group: Optional[str] = None,
        source_choice_branch: Optional[str] = None,
        source_specification: Optional[str] = None,
    ):
        if kind not in self.VALID_KINDS:
            raise ValueError(
                f'ConstraintRule kind "{kind}" is not valid. '
                f"Must be one of {sorted(self.VALID_KINDS)}."
            )

        for field_name, value in (
            ("subject_properties", subject_properties),
            ("target_properties", target_properties),
        ):
            if not isinstance(value, list):
                raise ValueError(f"{field_name} must be a list of strings.")
            if not all(isinstance(v, str) and v.strip() for v in value):
                raise ValueError(f"All {field_name} entries must be nonempty strings.")

        self.kind = kind
        self.subject_properties = [v.strip() for v in subject_properties]
        self.target_properties = [v.strip() for v in target_properties]
        self.source_property = source_property
        self.source_choice_group = source_choice_group
        self.source_choice_branch = source_choice_branch
        self.source_specification = source_specification

    def __repr__(self) -> str:
        return (
            "ConstraintRule("
            f"kind={self.kind!r}, "
            f"subject_properties={self.subject_properties!r}, "
            f"target_properties={self.target_properties!r}, "
            f"source_property={self.source_property!r}, "
            f"source_choice_group={self.source_choice_group!r}, "
            f"source_choice_branch={self.source_choice_branch!r}, "
            f"source_specification={self.source_specification!r})"
        )


class StorageHint:
    """
    Canonical storage-related advisory hint for a property.

    Parameters
    ----------
    property_name : str
        Name of the property to which this hint applies.
    kind : str
        Storage-hint kind, such as ``chunking`` or ``strategy``.
    value : object
        Associated storage-hint value.
    overridable : bool, default=True
        Whether user code may override this hint.
    source_specification : str, optional
        Specification from which this hint originated.

    Raises
    ------
    ValueError
        Raised if the supplied fields are malformed.

    Notes
    -----
    Storage hints are advisory defaults, not schema-validity requirements.
    """

    __slots__ = (
        "property_name",
        "kind",
        "value",
        "overridable",
        "source_specification",
    )

    def __init__(
        self,
        property_name: str,
        kind: str,
        value,
        *,
        overridable: bool = True,
        source_specification: Optional[str] = None,
    ):
        if not isinstance(property_name, str) or not property_name.strip():
            raise ValueError("property_name must be a nonempty string.")
        if not isinstance(kind, str) or not kind.strip():
            raise ValueError("kind must be a nonempty string.")
        if not isinstance(overridable, bool):
            raise ValueError("overridable must be boolean.")

        self.property_name = property_name.strip()
        self.kind = kind.strip()
        self.value = value
        self.overridable = overridable
        self.source_specification = source_specification

    def __repr__(self) -> str:
        return (
            "StorageHint("
            f"property_name={self.property_name!r}, "
            f"kind={self.kind!r}, value={self.value!r}, "
            f"overridable={self.overridable!r}, "
            f"source_specification={self.source_specification!r})"
        )


class Specification:
    """
    Canonical local parsed specification from a single specification file.

    Parameters
    ----------
    name : str
        Specification name.
    version : Version
        Specification version.
    extends : str, optional
        Parent specification name, or ``None`` if the specification has no
        parent.
    documentation : str
        Freeform descriptive text associated with the specification.
    notes : str
        Freeform notes text associated with the specification.
    local_properties : list of PropertyDefinition
        Canonical property declarations defined directly in this file.
    enumerations : dict of {str: list of str}
        Local enumeration definitions.
    constraints : list of ConstraintRule, optional
        Local constraint rules, including rules lifted from inline
        property modifiers during normalization.
    storage_hints : list of StorageHint, optional
        Local storage hints.
    source_file : str, optional
        Path to the specification source file.

    Raises
    ------
    ValueError
        Raised if the supplied fields are malformed or internally
        inconsistent.

    Notes
    -----
    A ``Specification`` contains only the content directly declared in one
    specification file. It does not contain inherited parent properties.
    """

    __slots__ = (
        "name",
        "version",
        "extends",
        "documentation",
        "notes",
        "local_properties",
        "enumerations",
        "constraints",
        "storage_hints",
        "source_file",
    )

    def __init__(
        self,
        name: str,
        version: Version,
        extends: Optional[str],
        documentation: str,
        notes: str,
        local_properties: list[PropertyDefinition],
        enumerations: dict[str, list[str]],
        *,
        constraints: Optional[list[ConstraintRule]] = None,
        storage_hints: Optional[list[StorageHint]] = None,
        source_file: Optional[str] = None,
    ):
        if not isinstance(name, str) or not name.strip():
            raise ValueError("Specification name must be a nonempty string.")
        if not isinstance(version, Version):
            raise ValueError("version must be a Version object.")
        if extends is not None and (not isinstance(extends, str) or not extends.strip()):
            raise ValueError("extends must be a nonempty string or None.")
        if not isinstance(documentation, str):
            raise ValueError("documentation must be a string.")
        if not isinstance(notes, str):
            raise ValueError("notes must be a string.")
        if not isinstance(local_properties, list):
            raise ValueError("local_properties must be a list of PropertyDefinition.")
        if not all(isinstance(p, PropertyDefinition) for p in local_properties):
            raise ValueError("All local_properties must be PropertyDefinition objects.")
        if not isinstance(enumerations, dict):
            raise ValueError("enumerations must be a dict[str, list[str]].")

        for key, values in enumerations.items():
            if not isinstance(key, str) or not key.strip():
                raise ValueError("Enumeration names must be nonempty strings.")
            if not isinstance(values, list):
                raise ValueError("Enumeration values must be lists of strings.")
            if not all(isinstance(v, str) for v in values):
                raise ValueError("Enumeration values must all be strings.")

        if constraints is None:
            constraints = []
        if storage_hints is None:
            storage_hints = []

        if not all(isinstance(c, ConstraintRule) for c in constraints):
            raise ValueError("All constraints must be ConstraintRule objects.")
        if not all(isinstance(h, StorageHint) for h in storage_hints):
            raise ValueError("All storage_hints must be StorageHint objects.")

        self.name = name.strip()
        self.version = version
        self.extends = None if extends is None else extends.strip()
        self.documentation = documentation
        self.notes = notes
        self.local_properties = local_properties
        self.enumerations = enumerations
        self.constraints = constraints
        self.storage_hints = storage_hints
        self.source_file = source_file

    @property
    def property_names(self) -> list[str]:
        """
        Return local property names.

        Returns
        -------
        list of str
            Sorted unique local property names.
        """
        return sorted({prop.name for prop in self.local_properties})

    def __repr__(self) -> str:
        return (
            "Specification("
            f"name={self.name!r}, version={self.version!r}, extends={self.extends!r}, "
            f"local_properties={len(self.local_properties)}, "
            f"enumerations={list(self.enumerations.keys())!r}, "
            f"constraints={len(self.constraints)}, "
            f"storage_hints={len(self.storage_hints)}, "
            f"source_file={self.source_file!r})"
        )


class ResolvedSpecification:
    """
    Fully resolved effective specification after inheritance resolution.

    Parameters
    ----------
    name : str
        Resolved specification name.
    version : Version
        Version of the resolved specification.
    ancestry : list of str
        Ordered ancestry chain from this specification through its parent
        chain.
    property_definitions : list of PropertyDefinition
        Effective property declarations after inheritance resolution.
    enumerations : dict of {str: list of str}
        Effective enumeration definitions after inheritance resolution.
    constraints : list of ConstraintRule
        Effective constraint rules after inheritance resolution.
    storage_hints : list of StorageHint
        Effective storage hints after inheritance resolution.

    Raises
    ------
    ValueError
        Raised if the supplied fields are malformed or internally
        inconsistent.

    Notes
    -----
    ``ResolvedSpecification`` eagerly builds derived indexes used for
    validation, debugging, and documentation generation.
    """

    __slots__ = (
        "name",
        "version",
        "ancestry",
        "property_definitions",
        "enumerations",
        "constraints",
        "storage_hints",
        "properties_by_name",
        "choice_groups",
        "standalone_properties",
        "required_properties",
        "optional_properties",
        "property_names",
        "dimension_names",
    )

    def __init__(
        self,
        name: str,
        version: Version,
        ancestry: list[str],
        property_definitions: list[PropertyDefinition],
        enumerations: dict[str, list[str]],
        constraints: list[ConstraintRule],
        storage_hints: list[StorageHint],
    ):
        if not isinstance(name, str) or not name.strip():
            raise ValueError("ResolvedSpecification name must be a nonempty string.")
        if not isinstance(version, Version):
            raise ValueError("version must be a Version object.")
        if not isinstance(ancestry, list) or not all(
            isinstance(v, str) and v.strip() for v in ancestry
        ):
            raise ValueError("ancestry must be a list of nonempty strings.")
        if not isinstance(property_definitions, list) or not all(
            isinstance(p, PropertyDefinition) for p in property_definitions
        ):
            raise ValueError("property_definitions must be a list of PropertyDefinition.")
        if not isinstance(enumerations, dict):
            raise ValueError("enumerations must be a dict.")
        if not all(isinstance(c, ConstraintRule) for c in constraints):
            raise ValueError("constraints must all be ConstraintRule objects.")
        if not all(isinstance(h, StorageHint) for h in storage_hints):
            raise ValueError("storage_hints must all be StorageHint objects.")

        self.name = name.strip()
        self.version = version
        self.ancestry = [v.strip() for v in ancestry]
        self.property_definitions = property_definitions
        self.enumerations = enumerations
        self.constraints = constraints
        self.storage_hints = storage_hints

        # Eager derived indexes
        self.properties_by_name = self._build_properties_by_name()
        self.choice_groups = self._build_choice_groups()
        self.standalone_properties = [
            p for p in self.property_definitions if p.choice_group is None
        ]
        self.required_properties = [p for p in self.standalone_properties if not p.optional]
        self.optional_properties = [p for p in self.standalone_properties if p.optional]
        self.property_names = sorted(self.properties_by_name.keys())
        self.dimension_names = self._build_dimension_names()

    def _build_properties_by_name(self) -> dict[str, list[PropertyDefinition]]:
        """
        Build the eager property-name index.

        Returns
        -------
        dict of {str: list of PropertyDefinition}
            Mapping from property name to all effective definitions having
            that name.
        """
        output: dict[str, list[PropertyDefinition]] = {}
        for prop in self.property_definitions:
            output.setdefault(prop.name, []).append(prop)
        return output

    def _build_choice_groups(self) -> dict[str, dict[str, list[PropertyDefinition]]]:
        """
        Build the eager choice-group index.

        Returns
        -------
        dict
            Mapping from choice-group name to branch map, where each branch
            map contains lists of ``PropertyDefinition`` objects.
        """
        output: dict[str, dict[str, list[PropertyDefinition]]] = {}
        for prop in self.property_definitions:
            if prop.choice_group is None:
                continue
            output.setdefault(prop.choice_group, {})
            output[prop.choice_group].setdefault(prop.choice_branch, [])
            output[prop.choice_group][prop.choice_branch].append(prop)
        return output

    def _build_dimension_names(self) -> list[str]:
        """
        Build the eager symbolic-dimension index.

        Returns
        -------
        list of str
            Sorted unique symbolic dimension names used by the effective
            property definitions.
        """
        names = set()
        for prop in self.property_definitions:
            for dim in prop.shape:
                if dim.is_symbolic:
                    names.add(dim.value)
        return sorted(names)

    def __repr__(self) -> str:
        return (
            "ResolvedSpecification("
            f"name={self.name!r}, version={self.version!r}, "
            f"ancestry={self.ancestry!r}, property_definitions={len(self.property_definitions)}, "
            f"enumerations={list(self.enumerations.keys())!r}, "
            f"constraints={len(self.constraints)}, "
            f"storage_hints={len(self.storage_hints)}, "
            f"choice_groups={list(self.choice_groups.keys())!r})"
        )
