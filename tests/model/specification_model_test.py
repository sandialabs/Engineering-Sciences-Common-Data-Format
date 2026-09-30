import textwrap

import pytest

from escdf.model import (
    SpecificationRegistry,
    SpecificationParser,
    Specification,
    ResolvedSpecification,
    PropertyDefinition,
    ConstraintRule,
    Dimension,
    Version,
)


def test_build_default_registry_loads_packaged_specs():
    """
    Verify that the packaged ESCDF specification directory can be loaded
    into a registry and that key known specification names are present.
    """
    registry = SpecificationRegistry.build_default_registry()

    assert isinstance(registry, SpecificationRegistry)

    local_names = registry.list_local_names()
    assert len(local_names) > 0

    for expected_name in [
        "parameter_set",
        "activity_result",
        "scalar",
        "data",
        "geometry",
        "channel_table",
        "global_test_attributes",
    ]:
        assert expected_name in local_names


def test_resolve_parameter_set():
    """
    Verify that a base specification with no parent resolves correctly.
    """
    registry = SpecificationRegistry.build_default_registry()
    resolved = registry.resolve("parameter_set")

    assert isinstance(resolved, ResolvedSpecification)
    assert resolved.name == "parameter_set"
    assert isinstance(resolved.version, Version)

    # Inheritance application order: root ancestor first, child last.
    assert resolved.ancestry == ["parameter_set"]

    assert "notes" in resolved.property_names
    assert "attachments" in resolved.property_names
    assert "attachment_names" in resolved.property_names

    assert "notes" in resolved.properties_by_name
    assert "attachments" in resolved.properties_by_name
    assert "attachment_names" in resolved.properties_by_name


def test_resolve_activity_result_inherits_parameter_set():
    """
    Verify that activity_result inherits properties from parameter_set.
    """
    registry = SpecificationRegistry.build_default_registry()
    resolved = registry.resolve("activity_result")

    assert isinstance(resolved, ResolvedSpecification)
    assert resolved.name == "activity_result"

    assert resolved.ancestry == ["parameter_set", "activity_result"]

    # Inherited from parameter_set
    assert "notes" in resolved.property_names
    assert "attachments" in resolved.property_names
    assert "attachment_names" in resolved.property_names


def test_resolve_scalar_has_expected_choice_group():
    """
    Verify that a specification with alternative property declarations
    produces the expected eager choice-group view.
    """
    registry = SpecificationRegistry.build_default_registry()
    resolved = registry.resolve("scalar")

    assert "value" in resolved.choice_groups
    branches = resolved.choice_groups["value"]

    assert "real_single_precision" in branches
    assert "complex_single_precision" in branches
    assert "real_double_precision" in branches
    assert "complex_double_precision" in branches

    for branch_name, branch_properties in branches.items():
        assert isinstance(branch_properties, list)
        assert len(branch_properties) == 1
        assert branch_properties[0].name == "value"
        assert branch_properties[0].choice_group == "value"
        assert branch_properties[0].choice_branch == branch_name


def test_resolve_data_has_expected_dimension_names():
    """
    Verify that symbolic dimensions are collected eagerly in a resolved
    specification.
    """
    registry = SpecificationRegistry.build_default_registry()
    resolved = registry.resolve("data")

    for expected_dimension in ["num_data", "num_samples", "num_channels"]:
        assert expected_dimension in resolved.dimension_names


def test_resolve_geometry_has_variable_length_connectivity():
    """
    Verify that variable-length connectivity properties are normalized
    onto PropertyDefinition.variable_length.
    """
    registry = SpecificationRegistry.build_default_registry()
    resolved = registry.resolve("geometry")

    assert "line_connection" in resolved.properties_by_name
    line_connection_defs = resolved.properties_by_name["line_connection"]
    assert len(line_connection_defs) == 1

    line_connection = line_connection_defs[0]
    assert isinstance(line_connection, PropertyDefinition)
    assert line_connection.variable_length is True


def test_resolve_channel_table_preserves_enumerations():
    """
    Verify that enumerations are loaded and exposed on resolved
    specifications.
    """
    registry = SpecificationRegistry.build_default_registry()
    resolved = registry.resolve("channel_table")

    assert "data_types" in resolved.enumerations
    values = resolved.enumerations["data_types"]
    assert isinstance(values, list)
    assert "acceleration" in values
    assert "force" in values
    assert "temperature" in values


def test_parser_lifts_requires_constraint_from_property_option(tmp_path):
    """
    Verify that relational property modifiers such as requires:* are
    lifted into specification-level ConstraintRule objects.
    """
    spec_text = textwrap.dedent(
        """\
        mini_requires - v0.1.0
        ----------------------
        extends: none

        properties
        ----------
        attachments - bytes - num_attachments - optional,requires:attachment_names
        attachment_names - str - num_attachments - optional,requires:attachments
        """
    )

    spec_file = tmp_path / "mini_requires.txt"
    spec_file.write_text(spec_text, encoding="utf-8")

    spec = SpecificationParser.parse_file(str(spec_file))

    assert isinstance(spec, Specification)
    assert spec.name == "mini_requires"
    assert spec.extends is None
    assert isinstance(spec.version, Version)

    assert len(spec.local_properties) == 2
    assert {p.name for p in spec.local_properties} == {"attachments", "attachment_names"}

    attachments_prop = next(p for p in spec.local_properties if p.name == "attachments")
    attachment_names_prop = next(p for p in spec.local_properties if p.name == "attachment_names")

    assert attachments_prop.optional is True
    assert attachment_names_prop.optional is True

    assert attachments_prop.shape_repr() == "num_attachments"
    assert attachment_names_prop.shape_repr() == "num_attachments"

    assert len(spec.constraints) == 2
    assert all(isinstance(rule, ConstraintRule) for rule in spec.constraints)

    requires_pairs = {
        (tuple(rule.subject_properties), tuple(rule.target_properties)) for rule in spec.constraints
    }
    assert requires_pairs == {
        (("attachments",), ("attachment_names",)),
        (("attachment_names",), ("attachments",)),
    }

    source_properties = {rule.source_property for rule in spec.constraints}
    assert source_properties == {"attachments", "attachment_names"}


def test_parser_normalizes_scalar_shape():
    """
    Verify that scalar property declarations normalize to an empty shape.
    """
    spec_text = textwrap.dedent(
        """\
        mini_scalar - v0.1.0
        --------------------
        extends: none

        properties
        ----------
        value - f8 - scalar
        """
    )

    spec = SpecificationParser.parse_text(spec_text)

    assert len(spec.local_properties) == 1
    prop = spec.local_properties[0]
    assert isinstance(prop, PropertyDefinition)
    assert prop.name == "value"
    assert prop.is_scalar is True
    assert prop.shape == []


def test_parser_normalizes_fixed_and_symbolic_dimensions():
    """
    Verify that mixed symbolic and fixed dimensions normalize into
    Dimension objects.
    """
    spec_text = textwrap.dedent(
        """\
        mini_dims - v0.1.0
        ------------------
        extends: none

        properties
        ----------
        node_position - f8 - num_nodes,3
        """
    )

    spec = SpecificationParser.parse_text(spec_text)

    prop = spec.local_properties[0]
    assert len(prop.shape) == 2

    dim0, dim1 = prop.shape
    assert isinstance(dim0, Dimension)
    assert isinstance(dim1, Dimension)

    assert dim0.is_symbolic is True
    assert dim0.value == "num_nodes"

    assert dim1.is_fixed is True
    assert dim1.value == 3
