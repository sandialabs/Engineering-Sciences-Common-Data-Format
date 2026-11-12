import os
import sys

import numpy as np
import pytest
import gc

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
GROUP_CONSTRAINT_CASES = (
    ("all_or_none", (), True),
    ("all_or_none", ("a",), False),
    ("all_or_none", ("a", "b"), False),
    ("all_or_none", ("a", "b", "c"), True),
    ("exactly_one_of", (), False),
    ("exactly_one_of", ("a",), True),
    ("exactly_one_of", ("a", "b"), False),
    ("exactly_one_of", ("a", "b", "c"), False),
    ("at_most_one_of", (), True),
    ("at_most_one_of", ("a",), True),
    ("at_most_one_of", ("a", "b"), False),
    ("at_most_one_of", ("a", "b", "c"), False),
    ("at_least_one_of", (), False),
    ("at_least_one_of", ("a",), True),
    ("at_least_one_of", ("a", "b"), True),
    ("at_least_one_of", ("a", "b", "c"), True),
)
MALFORMED_GROUP_RULES = (
    "unknown_rule: a, b",
    "paired: a, b",
    "all_or_none a, b",
    "all_or_none: a",
    "all_or_none: a, a",
    "all_or_none: a, , c",
    "all_or_none: a, b,",
)


@pytest.fixture
def validation_specs(tmp_path):
    temp_spec_dir = tmp_path / "validation_specs"
    temp_spec_dir.mkdir()

    choice_file = temp_spec_dir / "validation_choice_spec.txt"
    enum_file = temp_spec_dir / "validation_enum_spec.txt"
    regex_file = temp_spec_dir / "validation_regex_spec.txt"
    dims_file = temp_spec_dir / "validation_dims_spec.txt"
    ambig_file = temp_spec_dir / "validation_ambiguous_choice_spec.txt"
    value_constraints_file = temp_spec_dir / "validation_value_constraints_spec.txt"
    requires_file = temp_spec_dir / "validation_requires_spec.txt"

    choice_file.write_text(
        "validation_choice_spec - v0.1.0\n"
        "--------------------------------\n"
        "extends: activity_result\n"
        "\n"
        "properties\n"
        "----------\n"
        "a - i8 - scalar - or:choice:ab\n"
        "b - i8 - scalar - or:choice:ab\n"
        "a - i8 - scalar - or:choice:ac\n"
        "c - i8 - scalar - or:choice:ac\n"
        "d - i8 - scalar - or:choice:d_scalar\n"
        "d - i8 - num_vals - or:choice:d_array\n",
        encoding="utf-8",
    )

    enum_file.write_text(
        "validation_enum_spec - v0.1.0\n"
        "------------------------------\n"
        "extends: activity_result\n"
        "\n"
        "properties\n"
        "----------\n"
        "required_name - str - scalar\n"
        "optional_name - str - scalar - optional\n"
        "color - str - scalar - enum:colors\n"
        "color_array - str - num_vals - enum:colors\n"
        "\n"
        "enumerations\n"
        "------------\n"
        "colors - red, green, blue\n",
        encoding="utf-8",
    )

    regex_file.write_text(
        "validation_regex_spec - v0.1.0\n"
        "-------------------------------\n"
        "extends: activity_result\n"
        "\n"
        "properties\n"
        "----------\n"
        r"channel - str - num_channels - regex:^\d+(R?[XYZ]{1,2}[+-])?$"
        "\n",
        encoding="utf-8",
    )

    dims_file.write_text(
        "validation_dims_spec - v0.1.0\n"
        "------------------------------\n"
        "extends: activity_result\n"
        "\n"
        "properties\n"
        "----------\n"
        "x - f8 - num_points\n"
        "y - f8 - num_points\n"
        "z - f8 - num_other_points - optional\n"
        "m - f8 - num_rows,num_cols\n"
        "n - f8 - num_rows,num_cols\n",
        encoding="utf-8",
    )

    ambig_file.write_text(
        "validation_ambiguous_choice_spec - v0.1.0\n"
        "------------------------------------------\n"
        "extends: activity_result\n"
        "\n"
        "properties\n"
        "----------\n"
        "same - i8 - scalar - or:ambig:first\n"
        "same - i8 - scalar - or:ambig:second\n",
        encoding="utf-8",
    )

    value_constraints_file.write_text(
        "validation_value_constraints_spec - v0.1.0\n"
        "------------------------------------------\n"
        "extends: activity_result\n"
        "\n"
        "properties\n"
        "----------\n"
        "positive_scalar - f8 - scalar - positive\n"
        "nonnegative_vector - f8 - num_vals - nonnegative\n"
        "finite_vector - f8 - num_vals - finite\n"
        "increasing_vector - f8 - num_vals - increasing\n"
        "strictly_increasing_vector - f8 - num_vals - strictly_increasing\n"
        "unique_ids - u8 - num_ids - unique\n"
        "nonempty_name - str - scalar - nonempty\n",
        encoding="utf-8",
    )

    requires_file.write_text(
        "validation_requires_spec - v0.1.0\n"
        "---------------------------------\n"
        "extends: parameter_set\n"
        "\n"
        "properties\n"
        "----------\n"
        "attachments - bytes - num_attachments - optional,requires:attachment_names\n"
        "attachment_names - str - num_attachments - optional,requires:attachments\n",
        encoding="utf-8",
    )

    group_constraint_kinds = (
        "all_or_none",
        "exactly_one_of",
        "at_most_one_of",
        "at_least_one_of",
    )

    for kind in group_constraint_kinds:
        spec_name = f"validation_{kind}_spec"
        spec_text = (
            f"{spec_name} - v0.1.0\n"
            "----------------------\n"
            "extends: none\n"
            "\n"
            "properties\n"
            "----------\n"
            "a - f8 - scalar - optional\n"
            "b - f8 - scalar - optional\n"
            "c - f8 - scalar - optional\n"
            "\n"
            "constraints\n"
            "-----------\n"
            f"{kind}: a, b, c\n"
        )
        (temp_spec_dir / f"{spec_name}.txt").write_text(spec_text, encoding="utf-8")

    for key in list(sys.modules.keys()):
        if key.startswith("escdf"):
            del sys.modules[key]

    import escdf

    escdf.reload_specification_cache()
    escdf.load_specification_directory(str(temp_spec_dir))

    yield escdf

    escdf.reload_specification_cache()

    for key in list(sys.modules.keys()):
        if key.startswith("escdf"):
            del sys.modules[key]

    gc.collect()


def test_missing_required_property_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_enum_spec")
    ds.color = "red"
    ds.color_array = ["red", "green"]
    assert ds.validate() is False


def test_optional_property_can_be_omitted(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_enum_spec")
    ds.required_name = "example"
    ds.color = "red"
    ds.color_array = ["red", "green"]
    assert ds.optional_name is None
    assert ds.validate() is True


def test_enum_scalar_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_enum_spec")
    ds.required_name = "example"
    ds.color = "yellow"
    ds.color_array = ["red", "green"]
    assert ds.validate() is False


def test_enum_array_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_enum_spec")
    ds.required_name = "example"
    ds.color = "red"
    ds.color_array = ["red", "orange"]
    assert ds.validate() is False


def test_enum_values_valid_pass(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_enum_spec")
    ds.required_name = "example"
    ds.color = "blue"
    ds.color_array = ["red", "green", "blue"]
    assert ds.validate() is True


def test_regex_valid_passes(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_regex_spec")
    ds.channel = ["1X+", "25RY-", "100", "32ZX-"]
    assert ds.validate() is True


def test_regex_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_regex_spec")
    ds.channel = ["1X+", "BAD_CHANNEL"]
    assert ds.validate() is False


def test_variable_dimension_consistency_passes(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_dims_spec")
    ds.x = np.array([1.0, 2.0, 3.0], dtype=np.float64)
    ds.y = np.array([4.0, 5.0, 6.0], dtype=np.float64)
    ds.m = np.array([[1.0, 2.0], [3.0, 4.0]], dtype=np.float64)
    ds.n = np.array([[5.0, 6.0], [7.0, 8.0]], dtype=np.float64)
    assert ds.validate() is True


def test_variable_dimension_mismatch_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_dims_spec")
    ds.x = np.array([1.0, 2.0, 3.0], dtype=np.float64)
    ds.y = np.array([4.0, 5.0], dtype=np.float64)
    ds.m = np.array([[1.0, 2.0], [3.0, 4.0]], dtype=np.float64)
    ds.n = np.array([[5.0, 6.0], [7.0, 8.0]], dtype=np.float64)
    assert ds.validate() is False


def test_matrix_dimension_mismatch_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_dims_spec")
    ds.x = np.array([1.0, 2.0], dtype=np.float64)
    ds.y = np.array([3.0, 4.0], dtype=np.float64)
    ds.m = np.array([[1.0, 2.0], [3.0, 4.0]], dtype=np.float64)
    ds.n = np.array([[5.0, 6.0, 7.0], [8.0, 9.0, 10.0]], dtype=np.float64)
    assert ds.validate() is False


def test_choice_ab_valid(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_choice_spec")
    ds.a = 1
    ds.b = 2
    assert ds.validate() is True


def test_choice_ac_valid(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_choice_spec")
    ds.a = 1
    ds.c = 3
    assert ds.validate() is True


def test_choice_missing_pair_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_choice_spec")
    ds.a = 1
    assert ds.validate() is False


def test_choice_d_scalar_valid(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_choice_spec")
    ds.d = 1
    assert ds.validate() is True


def test_choice_d_array_valid(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_choice_spec")
    ds.d = [1, 2, 3]
    assert ds.validate() is True


def test_explicit_ambiguous_choice_reports_invalid(validation_specs):
    """
    Verify that a specification with multiple simultaneously valid choice
    branches is reported as invalid and captured in the validation report.
    """
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_ambiguous_choice_spec")
    ds.same = 1

    assert ds.validate() is False

    report = ds.validate(report=True)
    assert report.is_valid is False
    assert len(report.ambiguous_choices) > 0


def test_modified_property_invalidates_dataset(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_enum_spec")
    ds.required_name = "example"
    ds.color = "red"
    ds.color_array = ["red", "green"]
    assert ds.validate() is True

    ds._valid_properties.add("extra_field")
    ds._modified_properties.add("extra_field")
    ds.has_modified_properties = True
    ds.extra_field = escdf.Property("extra_field", "f8", (2,))
    ds.extra_field[...] = [1.0, 2.0]

    assert ds.validate() is False


def test_wrong_shape_rejected_by_assignment_or_validation(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_dims_spec")
    ds.x = np.array([1.0, 2.0, 3.0], dtype=np.float64)
    ds.m = np.array([[1.0, 2.0], [3.0, 4.0]], dtype=np.float64)
    ds.n = np.array([[5.0, 6.0], [7.0, 8.0]], dtype=np.float64)

    try:
        ds.y = np.array([[4.0, 5.0, 6.0]], dtype=np.float64)
    except ValueError:
        return

    assert ds.validate() is False


def test_positive_scalar_valid(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.25
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is True


def test_positive_scalar_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 0.0
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is False


def test_nonnegative_vector_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.0
    ds.nonnegative_vector = [0.0, -1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is False


def test_nonnegative_vector_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.0
    ds.nonnegative_vector = [0.0, -1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is False


def test_finite_vector_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.0
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, np.inf, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is False


def test_increasing_vector_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.0
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 0.5, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is False


def test_strictly_increasing_vector_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.0
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 1.0, 2.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is False


def test_unique_ids_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.0
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 2], dtype=np.uint64)
    ds.nonempty_name = "example"
    assert ds.validate() is False


def test_nonempty_name_invalid_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = 1.0
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = ""
    assert ds.validate() is False


def test_value_constraint_failure_appears_in_report(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_value_constraints_spec")
    ds.positive_scalar = -1.0
    ds.nonnegative_vector = [0.0, 1.0, 2.0]
    ds.finite_vector = [1.0, 2.0, 3.0]
    ds.increasing_vector = [1.0, 1.0, 2.0]
    ds.strictly_increasing_vector = [1.0, 2.0, 3.0]
    ds.unique_ids = np.array([1, 2, 3], dtype=np.uint64)
    ds.nonempty_name = "example"

    report = ds.validate(report=True)
    assert report.is_valid is False
    assert len(report.invalid_value_constraints) > 0


def test_requires_constraint_neither_present_is_valid(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_requires_spec")
    assert ds.validate() is True


def test_requires_constraint_both_present_is_valid(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_requires_spec")
    ds.attachment_names = ["a.bin", "b.bin"]
    ds.attachments = np.array(
        [
            np.array([1, 2, 3], dtype=np.uint8),
            np.array([4, 5], dtype=np.uint8),
        ],
        dtype=object,
    )
    assert ds.validate() is True


def test_requires_constraint_missing_attachment_names_fails(validation_specs, tmp_path):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_requires_spec")

    attachment_file = tmp_path / "a.bin"
    attachment_file.write_bytes(bytes([1, 2, 3]))

    ds.set_attachments([str(attachment_file)])
    ds.attachment_names = None

    assert ds.validate() is False


def test_requires_constraint_missing_attachments_fails(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_requires_spec")
    ds.attachment_names = ["a.bin"]
    assert ds.validate() is False


def test_requires_constraint_failure_appears_in_report(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_requires_spec")
    ds.attachment_names = ["a.bin"]

    report = ds.validate(report=True)
    assert report.is_valid is False
    assert len(report.constraint_failures) > 0


@pytest.mark.parametrize("kind,present_names,expected_valid", GROUP_CONSTRAINT_CASES)
def test_group_constraint_presence_semantics(
    validation_specs, kind, present_names, expected_valid
):
    """Validate the presence truth table for a section-authored rule."""
    ds = validation_specs.Dataset(f"dataset_{kind}", f"validation_{kind}_spec")

    for index, name in enumerate(present_names, start=1):
        setattr(ds, name, float(index))

    report = ds.validate(hide_issues=True, report=True)

    assert report.is_valid is expected_valid
    if not expected_valid:
        assert report.constraint_failures
        assert any(
            failure["constraint_kind"] == kind for failure in report.constraint_failures
        )
    else:
        assert report.constraint_failures == []


@pytest.mark.parametrize(
    "kind",
    ("all_or_none", "exactly_one_of", "at_most_one_of", "at_least_one_of"),
)
def test_group_constraint_is_parsed_and_resolved(validation_specs, tmp_path, kind):
    """Retain a section-authored constraint through registry resolution."""
    from escdf.model import SpecificationRegistry

    spec_name = f"validation_{kind}_spec"
    registry = SpecificationRegistry.build_default_registry()
    registry.load_from_directory(str(tmp_path / "validation_specs"))

    local = registry.get_local(spec_name)
    resolved = registry.resolve(spec_name)

    assert len(local.constraints) == 1
    assert len(resolved.constraints) == 1

    rule = resolved.constraints[0]
    assert rule.kind == kind
    assert rule.subject_properties == ["a", "b", "c"]
    assert rule.target_properties == []
    assert rule.source_specification == spec_name


@pytest.mark.parametrize("single_name", ("a", "b", "c"))
def test_exactly_one_accepts_each_individual_property(validation_specs, single_name):
    """No listed property receives special treatment based on its order."""
    ds = validation_specs.Dataset("one_source", "validation_exactly_one_of_spec")
    setattr(ds, single_name, 1.0)

    assert ds.validate(hide_issues=True) is True


def _constraint_spec_text(
    name,
    *,
    extends="none",
    properties=("a - f8 - scalar - optional", "b - f8 - scalar - optional"),
    constraints=("all_or_none: a, b",),
):
    """Build a small test-only specification."""
    return (
        f"{name} - v0.1.0\n"
        "----------------------\n"
        f"extends: {extends}\n\n"
        "properties\n"
        "----------\n"
        + "\n".join(properties)
        + "\n\nconstraints\n-----------\n"
        + "\n".join(constraints)
        + "\n"
    )


@pytest.mark.parametrize("rule_line", MALFORMED_GROUP_RULES)
def test_rejects_malformed_group_constraint_lines(tmp_path, rule_line):
    """Reject unsupported kinds and malformed section rules."""
    from escdf.model import SpecificationParser

    path = tmp_path / "malformed_constraint.txt"
    path.write_text(
        _constraint_spec_text("malformed_constraint", constraints=(rule_line,)),
        encoding="utf-8",
    )

    with pytest.raises(ValueError):
        SpecificationParser.parse_file(str(path))


def test_paired_is_not_a_supported_constraint_kind():
    """Do not accept a rule kind for which no validator exists."""
    from escdf.model import ConstraintRule

    with pytest.raises(ValueError):
        ConstraintRule(
            kind="paired",
            subject_properties=["a", "b"],
            target_properties=[],
        )


def test_group_rule_can_reference_inherited_property(tmp_path):
    """Resolve group-rule names against inherited as well as local fields."""
    from escdf.model import SpecificationRegistry

    (tmp_path / "contract_parent.txt").write_text(
        "contract_parent - v0.1.0\n"
        "----------------------\n"
        "extends: none\n\n"
        "properties\n----------\n"
        "a - f8 - scalar - optional\n",
        encoding="utf-8",
    )
    (tmp_path / "contract_child.txt").write_text(
        _constraint_spec_text(
            "contract_child",
            extends="contract_parent",
            properties=("b - f8 - scalar - optional",),
        ),
        encoding="utf-8",
    )

    registry = SpecificationRegistry()
    registry.load_from_directory(str(tmp_path))
    resolved = registry.resolve("contract_child")

    assert resolved.ancestry == ["contract_parent", "contract_child"]
    assert resolved.constraints[0].subject_properties == ["a", "b"]


def test_group_rule_rejects_unknown_property_after_resolution(tmp_path):
    """An unresolved name must fail rather than become a no-op rule."""
    from escdf.model import SpecificationRegistry

    path = tmp_path / "unknown_constraint_name.txt"
    path.write_text(
        _constraint_spec_text(
            "unknown_constraint_name",
            constraints=("all_or_none: a, nonexistent",),
        ),
        encoding="utf-8",
    )

    registry = SpecificationRegistry()
    registry.load_from_directory(str(tmp_path))

    with pytest.raises(ValueError, match="nonexistent"):
        registry.resolve("unknown_constraint_name")


@pytest.mark.parametrize(
    "choice_in_parent",
    (False, True),
    ids=("local-choice", "inherited-choice"),
)
def test_choice_and_constraints_cannot_coexist(tmp_path, choice_in_parent):
    """Reject choices and relational rules together in the resolved spec."""
    from escdf.model import SpecificationRegistry

    choice_properties = (
        "a - f8 - scalar - or:mode:first",
        "b - f8 - scalar - or:mode:second",
    )

    if choice_in_parent:
        (tmp_path / "choice_parent.txt").write_text(
            "choice_parent - v0.1.0\n"
            "----------------------\n"
            "extends: none\n\n"
            "properties\n----------\n" + "\n".join(choice_properties) + "\n",
            encoding="utf-8",
        )
        name = "constraint_child"
        text = _constraint_spec_text(
            name,
            extends="choice_parent",
            properties=("c - f8 - scalar - optional",),
            constraints=("at_least_one_of: a, c",),
        )
    else:
        name = "choice_and_constraint"
        text = _constraint_spec_text(
            name,
            properties=choice_properties,
            constraints=("at_least_one_of: a, b",),
        )

    (tmp_path / f"{name}.txt").write_text(text, encoding="utf-8")

    registry = SpecificationRegistry()
    registry.load_from_directory(str(tmp_path))

    with pytest.raises(ValueError, match=r"(?i)choice.*constraint|constraint.*choice"):
        registry.resolve(name)


def test_inline_requires_and_choice_cannot_coexist(tmp_path):
    """The exclusion also covers property-authored relational rules."""
    from escdf.model import SpecificationRegistry

    path = tmp_path / "choice_and_requires.txt"
    path.write_text(
        "choice_and_requires - v0.1.0\n"
        "---------------------------\n"
        "extends: none\n\n"
        "properties\n----------\n"
        "a - f8 - scalar - or:mode:first,requires:c\n"
        "b - f8 - scalar - or:mode:second\n"
        "c - f8 - scalar - optional\n",
        encoding="utf-8",
    )

    registry = SpecificationRegistry()
    registry.load_from_directory(str(tmp_path))

    with pytest.raises(ValueError, match=r"(?i)choice.*constraint|constraint.*choice"):
        registry.resolve("choice_and_requires")


@pytest.mark.parametrize(
    "choice_in_parent",
    (False, True),
    ids=("local-choice", "inherited-choice"),
)
def test_choice_and_unrelated_constraint_can_coexist(tmp_path, choice_in_parent):
    """A constraint may use standalone properties alongside choices."""
    from escdf.model import SpecificationRegistry

    choice_properties = (
        "a - f8 - scalar - or:mode:first",
        "b - f8 - scalar - or:mode:second",
    )
    standalone_properties = (
        "c - f8 - scalar - optional",
        "d - f8 - scalar - optional",
    )

    if choice_in_parent:
        (tmp_path / "choice_parent.txt").write_text(
            "choice_parent - v0.1.0\n"
            "----------------------\n"
            "extends: none\n\n"
            "properties\n----------\n" + "\n".join(choice_properties) + "\n",
            encoding="utf-8",
        )
        spec_name = "independent_constraint_child"
        text = _constraint_spec_text(
            spec_name,
            extends="choice_parent",
            properties=standalone_properties,
            constraints=("all_or_none: c, d",),
        )
    else:
        spec_name = "independent_choice_and_constraint"
        text = _constraint_spec_text(
            spec_name,
            properties=choice_properties + standalone_properties,
            constraints=("all_or_none: c, d",),
        )

    (tmp_path / f"{spec_name}.txt").write_text(text, encoding="utf-8")

    registry = SpecificationRegistry()
    registry.load_from_directory(str(tmp_path))
    resolved = registry.resolve(spec_name)

    assert "mode" in resolved.choice_groups
    assert len(resolved.constraints) == 1
    assert resolved.constraints[0].subject_properties == ["c", "d"]


def test_requires_cannot_target_choice_property(tmp_path):
    """The target, not just the subject, must be checked for overlap."""
    from escdf.model import SpecificationRegistry

    path = tmp_path / "requires_choice_target.txt"
    path.write_text(
        "requires_choice_target - v0.1.0\n"
        "--------------------------------\n"
        "extends: none\n\n"
        "properties\n----------\n"
        "a - f8 - scalar - or:mode:first\n"
        "b - f8 - scalar - or:mode:second\n"
        "c - f8 - scalar - optional,requires:a\n",
        encoding="utf-8",
    )

    registry = SpecificationRegistry()
    registry.load_from_directory(str(tmp_path))

    with pytest.raises(ValueError, match="choice-group properties.*a"):
        registry.resolve("requires_choice_target")
