from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

import numpy as np

from .specification import PropertyDefinition, ResolvedSpecification


@dataclass
class ValidationReport:
    """
    Structured validation result for one dataset.

    Parameters
    ----------
    checked_specification : str
        Name of the resolved specification used for validation.
    is_valid : bool, optional
        Overall validation result.
    missing_properties : list, optional
        Missing required properties.
    invalid_choices : list, optional
        Choice groups with zero valid branches.
    ambiguous_choices : list, optional
        Choice groups with multiple valid branches.
    bad_types : list, optional
        Property datatype mismatches.
    bad_ranks : list, optional
        Property rank mismatches.
    bad_sizes : list, optional
        Property fixed-dimension size mismatches.
    inconsistent_dimensions : list, optional
        Symbolic dimension consistency failures.
    invalid_enumerations : list, optional
        Enumeration membership failures.
    invalid_regexes : list, optional
        Regex conformance failures.
    invalid_value_constraints : list, optional
        Property-local value-constraint failures.
    constraint_failures : list, optional
        Cross-property constraint failures.
    modified_property_failures : list, optional
        Failures caused by modified or unknown properties.
    warnings : list, optional
        Non-fatal warnings.
    valid_choice_branches : dict, optional
        Valid branches detected for each choice group.
    bound_dimensions : dict, optional
        Realized symbolic dimension bindings.
    present_properties : list, optional
        Names of properties present on the dataset.

    Notes
    -----
    This report is intended to be both machine-readable and suitable for
    human-readable summarization.
    """

    checked_specification: str
    resolved_specification: ResolvedSpecification | None = None
    is_valid: bool = True
    missing_properties: list[dict[str, Any]] = field(default_factory=list)
    invalid_choices: list[dict[str, Any]] = field(default_factory=list)
    ambiguous_choices: list[dict[str, Any]] = field(default_factory=list)
    bad_types: list[dict[str, Any]] = field(default_factory=list)
    bad_ranks: list[dict[str, Any]] = field(default_factory=list)
    bad_sizes: list[dict[str, Any]] = field(default_factory=list)
    inconsistent_dimensions: list[dict[str, Any]] = field(default_factory=list)
    invalid_enumerations: list[dict[str, Any]] = field(default_factory=list)
    invalid_regexes: list[dict[str, Any]] = field(default_factory=list)
    invalid_value_constraints: list[dict[str, Any]] = field(default_factory=list)
    constraint_failures: list[dict[str, Any]] = field(default_factory=list)
    modified_property_failures: list[dict[str, Any]] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    valid_choice_branches: dict[str, list[str]] = field(default_factory=dict)
    bound_dimensions: dict[str, int] = field(default_factory=dict)
    present_properties: list[str] = field(default_factory=list)

    def __bool__(self) -> bool:
        """
        Return overall validation validity.

        Returns
        -------
        bool
            ``True`` if the dataset is valid, otherwise ``False``.
        """
        return self.is_valid

    def summary_lines(self) -> list[str]:
        """
        Build a human-readable summary of validation failures.

        Returns
        -------
        list of str
            Human-readable summary lines.
        """
        lines: list[str] = []

        for item in self.missing_properties:
            lines.append(f"Required property {item['property_name']} is missing.")

        for item in self.bad_types:
            lines.append(
                f"Property {item['property_name']} has datatype "
                f"{item['actual_type']} but expected {item['expected_type']}."
            )

        for item in self.bad_ranks:
            lines.append(
                f"Property {item['property_name']} has rank "
                f"{item['actual_rank']} but expected rank {item['expected_rank']}."
            )

        for item in self.bad_sizes:
            lines.append(
                f"Property {item['property_name']} dimension {item['dimension_index']} "
                f"has size {item['actual_size']} but expected {item['expected_size']}."
            )

        for item in self.invalid_choices:
            lines.append(f"Choice group {item['choice_group']} has no valid branch.")

        for item in self.ambiguous_choices:
            lines.append(
                f"Choice group {item['choice_group']} has multiple valid branches: "
                f"{', '.join(item['valid_branches'])}."
            )

        for item in self.invalid_enumerations:
            lines.append(
                f"Property {item['property_name']} has invalid values "
                f"{', '.join(str(v) for v in item['bad_values'])}. "
                f"Allowed values are {', '.join(str(v) for v in item['valid_values'])}."
            )

        for item in self.invalid_regexes:
            lines.append(
                f"Property {item['property_name']} has invalid values "
                f"{', '.join(str(v) for v in item['bad_values'])}."
            )

        for item in self.inconsistent_dimensions:
            lines.append(f"Dimension {item['dimension_name']} is inconsistent across properties.")
            for binding in item["bindings"]:
                lines.append(f"  {binding['property_name']}: {binding['size']}")

        for item in self.modified_property_failures:
            lines.append(item["message"])

        for item in self.invalid_value_constraints:
            lines.append(item["message"])

        for item in self.constraint_failures:
            lines.append(item["message"])

        for warning in self.warnings:
            lines.append(f"Warning: {warning}")

        return lines

    def summary(self) -> str:
        """
        Build a human-readable summary string.

        Returns
        -------
        str
            Human-readable summary text.
        """
        return "\n".join(self.summary_lines())


def validate_dataset_against_resolved_specification(
    dataset,
    resolved_specification: ResolvedSpecification,
    *,
    hide_issues: bool = False,
) -> ValidationReport:
    """
    Validate a dataset against a resolved canonical specification.

    Parameters
    ----------
    dataset : ESCDFDataset
        Dataset object to validate.
    resolved_specification : ResolvedSpecification
        Effective canonical specification used for validation.
    hide_issues : bool, optional
        If ``True``, suppress printed issue summaries.

    Returns
    -------
    ValidationReport
        Structured validation result.

    Notes
    -----
    This first-pass canonical validator currently checks:

    - required standalone property presence
    - property datatype compatibility
    - property rank compatibility
    - fixed-dimension size compatibility
    - symbolic dimension consistency
    - choice-group validity
    - enumeration membership
    - regex conformance
    - modified-property invalidation

    Cross-property `ConstraintRule` evaluation and value-constraint
    evaluation are reserved for later passes.
    """

    report = ValidationReport(
        checked_specification=resolved_specification.name,
        resolved_specification=resolved_specification,
    )

    present_properties = _get_present_property_names(dataset)
    report.present_properties = sorted(present_properties)

    # Track symbolic dimension bindings as we validate compatible declarations.
    dimension_bindings: dict[str, list[dict[str, Any]]] = {}

    # ------------------------------------------------------------------
    # Standalone properties
    # ------------------------------------------------------------------
    for property_definition in resolved_specification.standalone_properties:
        property_name = property_definition.name
        property_value = getattr(dataset, property_name)

        if property_value is None:
            if not property_definition.optional:
                report.missing_properties.append({"property_name": property_name})
                report.is_valid = False
            continue

        declaration_valid = _validate_present_property_against_definition(
            property_value,
            property_definition,
            report,
            dimension_bindings,
        )

        if not declaration_valid:
            report.is_valid = False

    # ------------------------------------------------------------------
    # Choice groups
    # ------------------------------------------------------------------
    for choice_group_name, branch_map in resolved_specification.choice_groups.items():
        valid_branches: list[str] = []

        for branch_name, branch_definitions in branch_map.items():
            branch_ok, branch_dimension_updates = _validate_choice_branch(
                dataset,
                branch_definitions,
                report,
                collect_failures=False,
            )
            if branch_ok:
                valid_branches.append(branch_name)
                # Tentatively record branch dimension bindings if exactly one
                # branch becomes valid later.
                report.valid_choice_branches.setdefault(choice_group_name, [])
                report.valid_choice_branches[choice_group_name].append(branch_name)

        if len(valid_branches) == 0:
            report.invalid_choices.append(
                {
                    "choice_group": choice_group_name,
                    "valid_branches": [],
                }
            )
            report.is_valid = False

        elif len(valid_branches) > 1:
            report.ambiguous_choices.append(
                {
                    "choice_group": choice_group_name,
                    "valid_branches": valid_branches,
                }
            )
            report.is_valid = False

        else:
            # Exactly one valid branch. Re-run with recording enabled so
            # dimension bindings and property-local errors contribute
            # consistently.
            chosen_branch_name = valid_branches[0]
            chosen_branch_definitions = branch_map[chosen_branch_name]
            branch_ok, branch_dimension_updates = _validate_choice_branch(
                dataset,
                chosen_branch_definitions,
                report,
                collect_failures=True,
            )
            if not branch_ok:
                report.is_valid = False
            _merge_dimension_bindings(dimension_bindings, branch_dimension_updates)

    # ------------------------------------------------------------------
    # Dimension consistency
    # ------------------------------------------------------------------
    inconsistent_dimensions = _find_inconsistent_dimensions(dimension_bindings)
    if inconsistent_dimensions:
        report.inconsistent_dimensions.extend(inconsistent_dimensions)
        report.is_valid = False

    report.bound_dimensions = _collapse_dimension_bindings(dimension_bindings)

    # ------------------------------------------------------------------
    # Cross-property relational constraints
    # ------------------------------------------------------------------
    constraint_failures = _evaluate_constraint_rules(
        dataset,
        resolved_specification,
        present_properties,
    )
    if constraint_failures:
        report.constraint_failures.extend(constraint_failures)
        report.is_valid = False

    # ------------------------------------------------------------------
    # Dataset-level policy checks
    # ------------------------------------------------------------------
    if getattr(dataset, "has_modified_properties", False):
        report.modified_property_failures.append(
            {"message": "Dataset has modified properties and therefore cannot be valid."}
        )
        report.is_valid = False

    if (not hide_issues) and (not report.is_valid):
        summary = report.summary()
        if summary:
            print(summary)

    return report


def _get_present_property_names(dataset) -> set[str]:
    """
    Return names of properties that are present on a dataset.

    Parameters
    ----------
    dataset : ESCDFDataset
        Dataset object.

    Returns
    -------
    set of str
        Property names whose values are not ``None``.
    """
    present = set()
    for property_name in dataset.property_names:
        if getattr(dataset, property_name) is not None:
            present.add(property_name)
    return present


def _validate_present_property_against_definition(
    property_value,
    property_definition: PropertyDefinition,
    report: ValidationReport,
    dimension_bindings: dict[str, list[dict[str, Any]]],
) -> bool:
    """
    Validate one present property against one canonical property
    definition.

    Parameters
    ----------
    property_value : ESCDFProperty
        Present dataset property object.
    property_definition : PropertyDefinition
        Canonical property definition to validate against.
    report : ValidationReport
        Validation report to update.
    dimension_bindings : dict
        Symbolic-dimension binding accumulator.

    Returns
    -------
    bool
        ``True`` if the property is locally compatible with the definition,
        otherwise ``False``.
    """
    property_name = property_definition.name

    if property_value.datatype != property_definition.datatype:
        report.bad_types.append(
            {
                "property_name": property_name,
                "actual_type": property_value.datatype,
                "expected_type": property_definition.datatype,
            }
        )
        return False

    actual_shape = tuple(property_value.shape)
    expected_rank = len(property_definition.shape)
    actual_rank = len(actual_shape)

    if actual_rank != expected_rank:
        report.bad_ranks.append(
            {
                "property_name": property_name,
                "actual_rank": actual_rank,
                "expected_rank": expected_rank,
            }
        )
        return False

    for dimension_index, (dimension_definition, actual_size) in enumerate(
        zip(property_definition.shape, actual_shape)
    ):
        if dimension_definition.is_fixed:
            if actual_size != dimension_definition.value:
                report.bad_sizes.append(
                    {
                        "property_name": property_name,
                        "dimension_index": dimension_index,
                        "actual_size": actual_size,
                        "expected_size": dimension_definition.value,
                    }
                )
                return False
        else:
            dimension_bindings.setdefault(dimension_definition.value, []).append(
                {
                    "property_name": property_name,
                    "size": actual_size,
                }
            )

    if property_definition.enumeration_name is not None:
        valid_values = report_lookup_enumeration_values(
            report,
            property_definition.enumeration_name,
        )
        property_data = property_value[...]
        invalid_values = _find_invalid_enumeration_values(property_data, valid_values)
        if invalid_values:
            report.invalid_enumerations.append(
                {
                    "property_name": property_name,
                    "valid_values": valid_values,
                    "bad_values": invalid_values,
                }
            )
            return False

    if property_definition.regex is not None:
        property_data = property_value[...]
        invalid_values = _find_invalid_regex_values(property_data, property_definition.regex)
        if invalid_values:
            report.invalid_regexes.append(
                {
                    "property_name": property_name,
                    "bad_values": invalid_values,
                    "pattern": property_definition.regex,
                }
            )
            return False

    if property_definition.value_constraints:
        property_data = property_value[...]
        for constraint_name in property_definition.value_constraints:
            message = _check_value_constraint(property_data, constraint_name, property_name)
            if message is not None:
                report.invalid_value_constraints.append(
                    {
                        "property_name": property_name,
                        "constraint": constraint_name,
                        "message": message,
                    }
                )
                return False

    return True


def _validate_choice_branch(
    dataset,
    branch_definitions: list[PropertyDefinition],
    report: ValidationReport,
    *,
    collect_failures: bool,
) -> tuple[bool, dict[str, list[dict[str, Any]]]]:
    """
    Validate one choice branch as a semantic unit.

    Parameters
    ----------
    dataset : ESCDFDataset
        Dataset object.
    branch_definitions : list of PropertyDefinition
        Canonical property definitions belonging to the branch.
    report : ValidationReport
        Validation report.
    collect_failures : bool
        If ``True``, record failures into the report. If ``False``, test
        branch validity quietly.

    Returns
    -------
    branch_ok : bool
        ``True`` if the branch is valid.
    branch_dimension_bindings : dict
        Symbolic-dimension bindings collected from compatible properties in
        the branch.
    """
    branch_ok = True
    branch_dimension_bindings: dict[str, list[dict[str, Any]]] = {}

    for property_definition in branch_definitions:
        property_name = property_definition.name
        property_value = getattr(dataset, property_name)

        if property_value is None:
            if not property_definition.optional:
                if collect_failures:
                    report.missing_properties.append({"property_name": property_name})
                branch_ok = False
            continue

        local_report = ValidationReport(checked_specification=report.checked_specification)
        property_ok = _validate_present_property_against_definition(
            property_value,
            property_definition,
            local_report,
            branch_dimension_bindings,
        )

        if not property_ok:
            branch_ok = False
            if collect_failures:
                report.bad_types.extend(local_report.bad_types)
                report.bad_ranks.extend(local_report.bad_ranks)
                report.bad_sizes.extend(local_report.bad_sizes)
                report.invalid_enumerations.extend(local_report.invalid_enumerations)
                report.invalid_regexes.extend(local_report.invalid_regexes)

    return branch_ok, branch_dimension_bindings


def _merge_dimension_bindings(
    destination: dict[str, list[dict[str, Any]]],
    source: dict[str, list[dict[str, Any]]],
) -> None:
    """
    Merge symbolic-dimension binding dictionaries in place.

    Parameters
    ----------
    destination : dict
        Destination binding dictionary.
    source : dict
        Source binding dictionary.
    """
    for dimension_name, bindings in source.items():
        destination.setdefault(dimension_name, []).extend(bindings)


def _find_inconsistent_dimensions(
    dimension_bindings: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    """
    Identify symbolic dimensions with inconsistent concrete sizes.

    Parameters
    ----------
    dimension_bindings : dict
        Symbolic-dimension binding dictionary.

    Returns
    -------
    list of dict
        Inconsistent dimension records.
    """
    inconsistent = []

    for dimension_name, bindings in dimension_bindings.items():
        sizes = [binding["size"] for binding in bindings]
        if len(set(sizes)) > 1:
            inconsistent.append(
                {
                    "dimension_name": dimension_name,
                    "bindings": bindings,
                }
            )

    return inconsistent


def _collapse_dimension_bindings(
    dimension_bindings: dict[str, list[dict[str, Any]]],
) -> dict[str, int]:
    """
    Collapse consistent symbolic-dimension bindings to one size value.

    Parameters
    ----------
    dimension_bindings : dict
        Symbolic-dimension binding dictionary.

    Returns
    -------
    dict of {str: int}
        Collapsed dimension bindings for dimensions that are consistent.
    """
    collapsed: dict[str, int] = {}

    for dimension_name, bindings in dimension_bindings.items():
        sizes = [binding["size"] for binding in bindings]
        if sizes and len(set(sizes)) == 1:
            collapsed[dimension_name] = sizes[0]

    return collapsed


def _find_invalid_enumeration_values(
    property_data,
    valid_values: list[str],
) -> list[Any]:
    """
    Return values that violate an enumeration constraint.

    Parameters
    ----------
    property_data : object
        Property data array or scalar.
    valid_values : list of str
        Allowed enumeration values.

    Returns
    -------
    list
        Sorted unique invalid values.
    """
    array = np.asarray(property_data, dtype=object)
    invalid_values = []
    for value in array.flat:
        normalized = _normalize_scalar_value(value)
        if normalized not in valid_values:
            invalid_values.append(normalized)
    return sorted(set(invalid_values), key=str)


def _find_invalid_regex_values(
    property_data,
    pattern: str,
) -> list[Any]:
    """
    Return values that violate a regex constraint.

    Parameters
    ----------
    property_data : object
        Property data array or scalar.
    pattern : str
        Regex pattern.

    Returns
    -------
    list
        Sorted unique invalid values.
    """
    array = np.asarray(property_data, dtype=object)
    invalid_values = []
    for value in array.flat:
        normalized = _normalize_scalar_value(value)
        if not re.match(pattern, normalized):
            invalid_values.append(normalized)
    return sorted(set(invalid_values), key=str)


def _normalize_scalar_value(value):
    """
    Normalize a scalar-like value for validation checks.

    Parameters
    ----------
    value : object
        Scalar-like value from property data.

    Returns
    -------
    object
        Normalized scalar value suitable for comparison and display.
    """
    if isinstance(value, np.ndarray):
        if value.shape == ():
            return value.item()
        return value
    if isinstance(value, np.generic):
        return value.item()
    return value


def _check_value_constraint(
    property_data,
    constraint_name: str,
    property_name: str,
) -> str | None:
    """
    Evaluate one value constraint against property data.

    Parameters
    ----------
    property_data : object
        Property data array or scalar.
    constraint_name : str
        Value-constraint name.
    property_name : str
        Property name for diagnostic messages.

    Returns
    -------
    str or None
        Human-readable failure message if the constraint is violated, or
        ``None`` if the constraint is satisfied.

    Raises
    ------
    ValueError
        If the constraint name is not recognized.
    """
    if constraint_name == "positive":
        if not _all_numeric_values_satisfy(property_data, lambda x: x > 0):
            return f"Property {property_name} violates the positive constraint."
        return None

    if constraint_name == "nonnegative":
        if not _all_numeric_values_satisfy(property_data, lambda x: x >= 0):
            return f"Property {property_name} violates the nonnegative constraint."
        return None

    if constraint_name == "finite":
        if not _all_numeric_values_satisfy(property_data, np.isfinite):
            return f"Property {property_name} violates the finite constraint."
        return None

    if constraint_name == "increasing":
        values = _flatten_numeric_values(property_data)
        if len(values) > 1 and not np.all(values[1:] >= values[:-1]):
            return f"Property {property_name} violates the increasing constraint."
        return None

    if constraint_name == "strictly_increasing":
        values = _flatten_numeric_values(property_data)
        if len(values) > 1 and not np.all(values[1:] > values[:-1]):
            return f"Property {property_name} violates the strictly_increasing constraint."
        return None

    if constraint_name == "unique":
        values = _flatten_comparable_values(property_data)
        if len(values) != len(set(values)):
            return f"Property {property_name} violates the unique constraint."
        return None

    if constraint_name == "nonempty":
        if not _is_nonempty_value(property_data):
            return f"Property {property_name} violates the nonempty constraint."
        return None

    raise ValueError(f'Unknown value constraint "{constraint_name}".')


def _all_numeric_values_satisfy(property_data, predicate) -> bool:
    """
    Return whether all numeric values satisfy a predicate.

    Parameters
    ----------
    property_data : object
        Property data array or scalar.
    predicate : callable
        Predicate applied elementwise to numeric values.

    Returns
    -------
    bool
        ``True`` if all numeric values satisfy the predicate.
    """
    values = _flatten_numeric_values(property_data)
    if values.size == 0:
        return True
    result = predicate(values)
    return bool(np.all(result))


def _flatten_numeric_values(property_data) -> np.ndarray:
    """
    Flatten property data into a numeric NumPy array.

    Parameters
    ----------
    property_data : object
        Property data array or scalar.

    Returns
    -------
    numpy.ndarray
        One-dimensional numeric array.

    Notes
    -----
    Object arrays are flattened by normalizing each scalar-like value.
    """
    array = np.asarray(property_data)
    if array.dtype != object:
        return np.ravel(array)

    values = [_normalize_scalar_value(value) for value in array.flat]
    return np.asarray(values)


def _flatten_comparable_values(property_data) -> list:
    """
    Flatten property data into a list of comparable scalar values.

    Parameters
    ----------
    property_data : object
        Property data array or scalar.

    Returns
    -------
    list
        Flattened list of normalized scalar values.
    """
    array = np.asarray(property_data, dtype=object)
    return [_normalize_scalar_value(value) for value in array.flat]


def _is_nonempty_value(property_data) -> bool:
    """
    Return whether property data satisfies the nonempty constraint.

    Parameters
    ----------
    property_data : object
        Property data array or scalar.

    Returns
    -------
    bool
        ``True`` if the value should be considered nonempty.
    """
    array = np.asarray(property_data, dtype=object)

    if array.size == 0:
        return False

    for value in array.flat:
        normalized = _normalize_scalar_value(value)

        if isinstance(normalized, str):
            if normalized == "":
                return False
        elif isinstance(normalized, np.ndarray):
            if normalized.size == 0:
                return False

    return True


def _evaluate_constraint_rules(
    dataset,
    resolved_specification: ResolvedSpecification,
    present_properties: set[str],
) -> list[dict[str, Any]]:
    """
    Evaluate cross-property constraint rules.

    Parameters
    ----------
    dataset : ESCDFDataset
        Dataset object being validated.
    resolved_specification : ResolvedSpecification
        Effective resolved specification.
    present_properties : set of str
        Names of properties currently present on the dataset.

    Returns
    -------
    list of dict
        Constraint-failure records.
    """
    failures: list[dict[str, Any]] = []

    for rule in resolved_specification.constraints:
        if rule.kind == "requires":
            failure = _evaluate_requires_rule(rule, present_properties)
            if failure is not None:
                failures.append(failure)
        else:
            # Future constraint kinds will be implemented later.
            continue

    return failures


def _evaluate_requires_rule(
    rule,
    present_properties: set[str],
) -> dict[str, Any] | None:
    """
    Evaluate one requires constraint rule.

    Parameters
    ----------
    rule : ConstraintRule
        Requires rule to evaluate.
    present_properties : set of str
        Names of properties currently present on the dataset.

    Returns
    -------
    dict or None
        Constraint-failure record if violated, otherwise ``None``.
    """
    subjects_present = [name for name in rule.subject_properties if name in present_properties]

    if not subjects_present:
        return None

    missing_targets = [name for name in rule.target_properties if name not in present_properties]

    if not missing_targets:
        return None

    return {
        "constraint_kind": "requires",
        "subject_properties": list(rule.subject_properties),
        "target_properties": list(rule.target_properties),
        "missing_target_properties": missing_targets,
        "message": (
            f"Constraint requires failed: "
            f"present subject properties {subjects_present} require "
            f"target properties {missing_targets}."
        ),
    }


def report_lookup_enumeration_values(
    report: ValidationReport,
    enumeration_name: str,
) -> list[str]:
    """
    Return allowed values for an enumeration used during validation.

    Parameters
    ----------
    report : ValidationReport
        Validation report.
    enumeration_name : str
        Enumeration name to resolve.

    Returns
    -------
    list of str
        Allowed enumeration values.
    """
    if report.resolved_specification is None:
        raise RuntimeError("ValidationReport does not carry a resolved specification.")
    return report.resolved_specification.enumerations[enumeration_name]
