import os
import sys

import numpy as np
import pytest
import gc

THIS_DIR = os.path.dirname(os.path.abspath(__file__))


@pytest.fixture
def validation_specs():
    spec_path = os.path.join(THIS_DIR, "..", "escdf", "specifications")

    choice_file = os.path.join(spec_path, "validation_choice_spec.txt")
    enum_file = os.path.join(spec_path, "validation_enum_spec.txt")
    regex_file = os.path.join(spec_path, "validation_regex_spec.txt")
    dims_file = os.path.join(spec_path, "validation_dims_spec.txt")
    ambig_file = os.path.join(spec_path, "validation_ambiguous_choice_spec.txt")

    with open(choice_file, "w") as f:
        f.write(
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
            "d - i8 - num_vals - or:choice:d_array\n"
        )

    with open(enum_file, "w") as f:
        f.write(
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
            "colors - red, green, blue\n"
        )

    with open(regex_file, "w") as f:
        f.write(
            "validation_regex_spec - v0.1.0\n"
            "-------------------------------\n"
            "extends: activity_result\n"
            "\n"
            "properties\n"
            "----------\n"
            r"channel - str - num_channels - regex:^\d+(R?[XYZ]{1,2}[+-])?$"
            "\n"
        )

    with open(dims_file, "w") as f:
        f.write(
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
            "n - f8 - num_rows,num_cols\n"
        )

    with open(ambig_file, "w") as f:
        f.write(
            "validation_ambiguous_choice_spec - v0.1.0\n"
            "------------------------------------------\n"
            "extends: activity_result\n"
            "\n"
            "properties\n"
            "----------\n"
            "same - i8 - scalar - or:ambig:first\n"
            "same - i8 - scalar - or:ambig:second\n"
        )

    for key in list(sys.modules.keys()):
        if key.startswith("escdf"):
            del sys.modules[key]

    import escdf

    yield escdf

    # Added this to circumvent permission errors in Windows.
    for key in list(sys.modules.keys()):
        if key.startswith("escdf"):
            del sys.modules[key]

    gc.collect()

    os.remove(choice_file)
    os.remove(enum_file)
    os.remove(regex_file)
    os.remove(dims_file)
    os.remove(ambig_file)

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

def test_explicit_ambiguous_choice_raises(validation_specs):
    escdf = validation_specs
    ds = escdf.Dataset("d1", "validation_ambiguous_choice_spec")
    ds.same = 1
    with pytest.raises(ValueError, match="Multiple valid choices"):
        ds.validate()

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