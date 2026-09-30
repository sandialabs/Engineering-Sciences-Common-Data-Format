import datetime as dt
from datetime import timezone
import os

import numpy as np
import escdf

import pytest
pytestmark = pytest.mark.interop

def assert_datetimes_nearly_equal(actual, expected, tol_seconds=1e-5):
    delta = abs((actual - expected).total_seconds())
    assert delta < tol_seconds, (
        f"Datetimes differ by {delta} seconds; "
        f"actual={actual!r}, expected={expected!r}"
    )

def test_read_matlab_simple_scalar_fixture(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "simple_scalar_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == ["global_meta"]
    md = loaded.metadata["global_meta"]
    assert md.dataset_type == "global_test_attributes"
    assert md.descriptive_name == "Global test metadata"
    assert md.test_name[...] == "Qualification Test"
    assert md.program[...] == "Program ABC"
    np.testing.assert_array_equal(
        md.hardware_list[...],
        np.array(["hardware_1", "hardware_2"], dtype=object),
    )
    np.testing.assert_array_equal(
        md.point_of_contact[...],
        np.array(["person_1", "person_2"], dtype=object),
    )

    assert loaded.activities.names == ["act1"]
    act = loaded.activities["act1"]
    assert act.descriptive_name == "Activity One"
    assert_datetimes_nearly_equal(
        act.activity_date,
        dt.datetime(2025, 6, 7, 8, 9, 10, 654321, tzinfo=timezone.utc),
    )
    assert act.metadata_links == ["global_meta"]
    assert act.data_names == ["scalar_result"]

    data = act["scalar_result"]
    assert data.dataset_type == "scalar"
    assert data.descriptive_name == "Scalar activity result"
    assert data.value[...] == np.float64(9.81)
    assert data.unit[...] == "m/s^2"


def test_read_matlab_numeric_arrays_fixture(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "numeric_arrays_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 3, 4, 5, 6, 7, 234567, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == ["geometry_meta"]
    md = loaded.metadata["geometry_meta"]
    assert md.dataset_type == "geometry"
    assert md.descriptive_name == "Geometry metadata"

    np.testing.assert_array_equal(
        md.node_id[...],
        np.array([10, 20, 30], dtype=np.uint64),
    )
    np.testing.assert_allclose(
        md.node_position[...],
        np.array(
            [
                [0.0, 0.0, 0.0],
                [1.0, 0.0, 0.0],
                [0.0, 1.0, 0.0],
            ],
            dtype=np.float64,
        ),
    )
    np.testing.assert_allclose(
        md.node_x_direction[...],
        np.array(
            [
                [1.0, 0.0, 0.0],
                [1.0, 0.0, 0.0],
                [1.0, 0.0, 0.0],
            ],
            dtype=np.float64,
        ),
    )
    np.testing.assert_allclose(
        md.node_y_direction[...],
        np.array(
            [
                [0.0, 1.0, 0.0],
                [0.0, 1.0, 0.0],
                [0.0, 1.0, 0.0],
            ],
            dtype=np.float64,
        ),
    )
    np.testing.assert_allclose(
        md.node_z_direction[...],
        np.array(
            [
                [0.0, 0.0, 1.0],
                [0.0, 0.0, 1.0],
                [0.0, 0.0, 1.0],
            ],
            dtype=np.float64,
        ),
    )
    assert md.position_units[...] == "m"

    assert loaded.activities.names == ["act_arrays"]
    act = loaded.activities["act_arrays"]
    assert act.descriptive_name == "Array activity"
    assert_datetimes_nearly_equal(
        act.activity_date,
        dt.datetime(2025, 8, 9, 10, 11, 12, 345678, tzinfo=timezone.utc),
    )
    assert act.metadata_links == ["geometry_meta"]
    assert sorted(act.data_names) == ["matrix_result", "vector_result"]

    vector_result = act["vector_result"]
    assert vector_result.dataset_type == "vector"
    np.testing.assert_allclose(
        np.asarray(vector_result.value[...], dtype=np.float64),
        np.array([1.0, 2.0, 3.5, 4.5], dtype=np.float64),
    )
    assert vector_result.unit[...] == "m/s^2"

    matrix_result = act["matrix_result"]
    assert matrix_result.dataset_type == "matrix"
    np.testing.assert_allclose(
        np.asarray(matrix_result.value[...], dtype=np.float64),
        np.array(
            [
                [1.0, 2.0],
                [3.0, 4.5],
                [6.0, 7.0],
            ],
            dtype=np.float64,
        ),
    )
    assert matrix_result.unit[...] == "N"

def test_read_matlab_invalid_names_fixture(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "invalid_names_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 4, 5, 6, 7, 8, 111111, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == ["dataset_1_badmeta"]
    md = loaded.metadata["dataset_1_badmeta"]
    assert md.dataset_type == "scalar"
    assert md.descriptive_name == "Bad metadata"
    assert md.value[...] == np.float64(1.23)
    assert md.unit[...] == "g"

    assert loaded.activities.names == ["activity_1_badactivity"]
    act = loaded.activities["activity_1_badactivity"]
    assert act.descriptive_name == "Bad activity"
    assert_datetimes_nearly_equal(
        act.activity_date,
        dt.datetime(2025, 9, 10, 11, 12, 13, 222222, tzinfo=timezone.utc),
    )
    assert act.metadata_links == ["dataset_1_badmeta"]


def test_read_matlab_unknown_type_fixture(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "unknown_type_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 4, 5, 6, 7, 8, 333333, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == ["mystery_metadata"]
    md = loaded.metadata["mystery_metadata"]
    assert md.dataset_type == "unknown"
    assert md.descriptive_name == "Mystery metadata"
    assert md.original_type_name[...] == "totally_unknown_type"

    assert loaded.activities.names == []

def test_read_matlab_attachments_bytes_fixture(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "attachments_bytes_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 5, 6, 7, 8, 9, 444444, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == ["global_meta_with_attachments"]
    md = loaded.metadata["global_meta_with_attachments"]

    assert md.dataset_type == "global_test_attributes"
    assert md.descriptive_name == "Global metadata with attachments"
    assert md.test_name[...] == "Attachment Test"
    assert md.program[...] == "Program Bytes"
    np.testing.assert_array_equal(
        md.hardware_list[...],
        np.array(["hardware_1"], dtype=object),
    )
    np.testing.assert_array_equal(
        md.point_of_contact[...],
        np.array(["person_1"], dtype=object),
    )

    np.testing.assert_array_equal(
        md.attachment_names[...],
        np.array(["hello.bin", "numbers.bin"], dtype=object),
    )

    attachments = md.attachments[...]
    assert attachments.shape == (2,)

    np.testing.assert_array_equal(
        attachments[0],
        np.frombuffer(b"hello world", dtype=np.uint8),
    )
    np.testing.assert_array_equal(
        attachments[1],
        np.array([1, 2, 3, 4, 5, 255], dtype=np.uint8),
    )

    assert loaded.activities.names == []

def test_read_matlab_complex_data_fixture(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "complex_data_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 10, 11, 12, 13, 14, 555555, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == []
    assert loaded.activities.names == ["act_complex"]

    act = loaded.activities["act_complex"]
    assert act.descriptive_name == "Complex activity"
    assert_datetimes_nearly_equal(
        act.activity_date,
        dt.datetime(2025, 10, 12, 13, 14, 15, 666666, tzinfo=timezone.utc),
    )
    assert sorted(act.data_names) == [
        "complex_matrix_result",
        "complex_scalar_result",
        "complex_vector_result",
    ]

    scalar_result = act["complex_scalar_result"]
    assert scalar_result.dataset_type == "scalar"
    assert scalar_result.descriptive_name == "Complex scalar activity result"
    np.testing.assert_allclose(
        np.asarray(scalar_result.value[...], dtype=np.complex128),
        np.complex128(1.5 - 2.25j),
    )
    assert scalar_result.unit[...] == "V"

    vector_result = act["complex_vector_result"]
    assert vector_result.dataset_type == "vector"
    np.testing.assert_allclose(
        np.asarray(vector_result.value[...], dtype=np.complex128),
        np.array(
            [1.0 + 2.0j, -3.0 + 0.5j, -1.0j, 4.25 + 3.0j],
            dtype=np.complex128,
        ),
    )
    assert vector_result.unit[...] == "m/s"

    matrix_result = act["complex_matrix_result"]
    assert matrix_result.dataset_type == "matrix"
    np.testing.assert_allclose(
        np.asarray(matrix_result.value[...], dtype=np.complex128),
        np.array(
            [
                [1.0 + 1.0j, 2.0 - 2.0j],
                [-3.0 + 0.5j, 4.0 + 4.0j],
                [-1.0j, 6.0 + 0.0j],
            ],
            dtype=np.complex128,
        ),
    )
    assert matrix_result.unit[...] == "N"

def test_read_matlab_ragged_numeric_fixture(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "ragged_numeric_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 11, 1, 2, 3, 4, 777777, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == ["geometry_ragged_meta"]
    md = loaded.metadata["geometry_ragged_meta"]

    assert md.dataset_type == "geometry"
    assert md.descriptive_name == "Geometry with ragged connectivity"

    np.testing.assert_array_equal(
        md.node_id[...],
        np.array([10, 20, 30, 40, 50], dtype=np.uint64),
    )
    np.testing.assert_allclose(
        md.node_position[...],
        np.array(
            [
                [0.0, 0.0, 0.0],
                [1.0, 0.0, 0.0],
                [2.0, 0.5, 0.0],
                [3.0, 1.0, 0.0],
                [4.0, 1.5, 0.0],
            ],
            dtype=np.float64,
        ),
    )

    line_connection = np.ravel(md.line_connection[...])
    assert len(line_connection) == 3
    np.testing.assert_array_equal(line_connection[0], np.array([10, 20], dtype=np.uint64))
    np.testing.assert_array_equal(line_connection[1], np.array([20, 30, 40], dtype=np.uint64))
    np.testing.assert_array_equal(line_connection[2], np.array([40, 50], dtype=np.uint64))

    element_connection = np.ravel(md.element_connection[...])
    assert len(element_connection) == 2
    np.testing.assert_array_equal(
        element_connection[0], np.array([10, 20, 30], dtype=np.uint64)
    )
    np.testing.assert_array_equal(
        element_connection[1], np.array([20, 30, 40, 50], dtype=np.uint64)
    )

    np.testing.assert_array_equal(
        md.element_type[...],
        np.array(["tri3", "quad4"], dtype=object),
    )
    assert md.position_units[...] == "m"

    assert loaded.activities.names == []

def test_read_matlab_extra_property_fixture(monkeypatch, tmp_path):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "extra_property_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)

    assert loaded.created_by == "interop_test_user"
    assert_datetimes_nearly_equal(
        loaded.created_date,
        dt.datetime(2025, 12, 1, 1, 2, 3, 888888, tzinfo=timezone.utc),
    )

    assert loaded.metadata.names == ["meta_with_extra"]
    md = loaded.metadata["meta_with_extra"]

    assert md.dataset_type == "scalar"
    assert md.descriptive_name == "Scalar metadata with extra field"
    assert md.has_modified_properties is True
    assert md.validate() is False

    assert "unexpected_field" in md.property_names
    np.testing.assert_allclose(
        md.unexpected_field[...],
        np.array([10.0, 20.0, 30.0], dtype=np.float64),
    )

    with pytest.raises(ValueError):
        loaded.write_to_disk(str(tmp_path / "should_fail.h5"))

def test_extract_attachments_from_matlab_fixture(monkeypatch, tmp_path):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = os.path.join(
        "ci_artifacts",
        "interop",
        "matlab_written",
        "attachments_bytes_matlab_written.h5",
    )

    loaded = escdf.ESCDF.load(file_path)
    md = loaded.metadata["global_meta_with_attachments"]

    output_dir = tmp_path / "extracted_attachments"
    output_dir.mkdir()

    md.dump_attachments_to_disk(str(output_dir))

    hello_path = output_dir / "hello.bin"
    numbers_path = output_dir / "numbers.bin"

    assert hello_path.exists()
    assert numbers_path.exists()

    assert hello_path.read_bytes() == b"hello world"
    assert numbers_path.read_bytes() == bytes([1, 2, 3, 4, 5, 255])