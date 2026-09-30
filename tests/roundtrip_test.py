import datetime as dt
from datetime import timezone

import h5py
import numpy as np
import pytest

import escdf


def make_global_test_attributes(name="global_meta"):
    ds = escdf.Dataset(name, "global_test_attributes", "Global test metadata")
    ds.test_name = "Qualification Test"
    ds.program = "Program ABC"
    ds.hardware_list = ["hardware_1", "hardware_2"]
    ds.point_of_contact = ["person_1", "person_2"]
    assert ds.validate()
    return ds


def make_geometry(name="geometry_meta"):
    ds = escdf.Dataset(name, "geometry", "Geometry metadata")
    ds.node_id = np.array([10, 20, 30], dtype=np.uint64)
    ds.node_position = np.array(
        [
            [0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
        ],
        dtype=np.float64,
    )
    ds.node_x_direction = np.array(
        [
            [1.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
            [1.0, 0.0, 0.0],
        ],
        dtype=np.float64,
    )
    ds.node_y_direction = np.array(
        [
            [0.0, 1.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 1.0, 0.0],
        ],
        dtype=np.float64,
    )
    ds.node_z_direction = np.array(
        [
            [0.0, 0.0, 1.0],
            [0.0, 0.0, 1.0],
            [0.0, 0.0, 1.0],
        ],
        dtype=np.float64,
    )
    ds.position_units = "m"
    assert ds.validate()
    return ds


def make_scalar_data(name="scalar_result", value=1.25, unit="g"):
    ds = escdf.Dataset(name, "scalar", "Scalar activity result")
    ds.value = value
    ds.unit = unit
    assert ds.validate()
    return ds


def make_vector_data(name="vector_result"):
    ds = escdf.Dataset(name, "vector", "Vector activity result")
    ds.value = np.array([1.0, 2.0, 3.5, 4.5], dtype=np.float64)
    ds.unit = "m/s^2"
    assert ds.validate()
    return ds


def make_matrix_data(name="matrix_result"):
    ds = escdf.Dataset(name, "matrix", "Matrix activity result")
    ds.value = np.array([[1.0, 2.0], [3.0, 4.5], [6.0, 7.0]], dtype=np.float64)
    ds.unit = "N"
    assert ds.validate()
    return ds

def test_full_roundtrip_multiple_metadata_and_activities(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "full_roundtrip.h5"

    original = escdf.ESCDF()

    md_global = make_global_test_attributes("global_meta")
    md_geometry = make_geometry("geometry_meta")

    original.add_metadata(md_global)
    original.add_metadata(md_geometry)

    time1 = dt.datetime(2024, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)
    time2 = dt.datetime(2024, 6, 7, 8, 9, 10, 654321, tzinfo=timezone.utc)

    original.add_activity("act1", "First activity", time1)
    original.add_activity("act2", "Second activity", time2)

    original.link_activity_to_metadata("act1", "global_meta")
    original.link_activity_to_metadata("act1", "geometry_meta")
    original.link_activity_to_metadata("act2", "global_meta")

    original.add_data_to_activity("act1", make_scalar_data("scalar_result", 9.81, "m/s^2"))
    original.add_data_to_activity("act1", make_vector_data("vector_result"))
    original.add_data_to_activity("act2", make_matrix_data("matrix_result"))

    original.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.created_by == "unit_test_user"
    assert loaded.created_date.tzinfo is not None

    # Metadata
    assert sorted(loaded.metadata.names) == ["geometry_meta", "global_meta"]

    loaded_global = loaded.metadata["global_meta"]
    assert loaded_global.dataset_type == "global_test_attributes"
    assert loaded_global.descriptive_name == "Global test metadata"
    np.testing.assert_array_equal(
        loaded_global.hardware_list[...],
        np.array(["hardware_1", "hardware_2"], dtype=object),
    )
    np.testing.assert_array_equal(
        loaded_global.point_of_contact[...],
        np.array(["person_1", "person_2"], dtype=object),
    )
    assert loaded_global.test_name[...] == "Qualification Test"
    assert loaded_global.program[...] == "Program ABC"

    loaded_geometry = loaded.metadata["geometry_meta"]
    assert loaded_geometry.dataset_type == "geometry"
    np.testing.assert_array_equal(
        loaded_geometry.node_id[...],
        np.array([10, 20, 30], dtype=np.uint64),
    )
    np.testing.assert_allclose(
        loaded_geometry.node_position[...],
        np.array(
            [
                [0.0, 0.0, 0.0],
                [1.0, 0.0, 0.0],
                [0.0, 1.0, 0.0],
            ],
            dtype=np.float64,
        ),
    )
    assert loaded_geometry.position_units[...] == "m"

    # Activities
    assert sorted(loaded.activities.names) == ["act1", "act2"]

    act1 = loaded.activities["act1"]
    act2 = loaded.activities["act2"]

    assert act1.descriptive_name == "First activity"
    assert act2.descriptive_name == "Second activity"
    assert act1.activity_date == time1
    assert act2.activity_date == time2

    assert sorted(act1.metadata_links) == ["geometry_meta", "global_meta"]
    assert sorted(act2.metadata_links) == ["global_meta"]

    assert sorted(act1.data_names) == ["scalar_result", "vector_result"]
    assert sorted(act2.data_names) == ["matrix_result"]

    scalar_result = act1["scalar_result"]
    assert scalar_result.dataset_type == "scalar"
    assert scalar_result.value[...] == np.float64(9.81)
    assert scalar_result.unit[...] == "m/s^2"

    vector_result = act1["vector_result"]
    np.testing.assert_allclose(
        vector_result.value[...],
        np.array([1.0, 2.0, 3.5, 4.5], dtype=np.float64),
    )
    assert vector_result.unit[...] == "m/s^2"

    matrix_result = act2["matrix_result"]
    np.testing.assert_allclose(
        matrix_result.value[...],
        np.array([[1.0, 2.0], [3.0, 4.5], [6.0, 7.0]], dtype=np.float64),
    )
    assert matrix_result.unit[...] == "N"


def test_roundtrip_preserves_created_and_activity_timestamps(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "timestamps_roundtrip.h5"

    f = escdf.ESCDF()
    created_time = dt.datetime(2025, 2, 3, 4, 5, 6, 789123, tzinfo=timezone.utc)
    activity_time = dt.datetime(2025, 7, 8, 9, 10, 11, 456789, tzinfo=timezone.utc)

    f.set_created_properties("unit_test_user", created_time)
    f.add_activity("act1", "Activity", activity_time)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.created_by == "unit_test_user"
    assert loaded.created_date == created_time
    assert loaded.activities["act1"].activity_date == activity_time

def test_roundtrip_loaded_dataset_with_extra_property_is_marked_modified(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "modified_dataset.h5"

    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"
        f.create_group("activities")

        md = f.create_group("meta1")
        md.attrs["_specification_name"] = "scalar"
        md.attrs["_descriptive_name"] = "Scalar metadata"
        md.attrs["_version"] = (0, 1, 0)

        value = md.create_dataset("value", shape=(), dtype="f8")
        value.attrs["data_type"] = "f8"
        value[()] = 2.0

        extra = md.create_dataset("unexpected_field", shape=(2,), dtype="f8")
        extra.attrs["data_type"] = "f8"
        extra[...] = [10.0, 20.0]

    loaded = escdf.ESCDF.load(str(file_path))
    md = loaded.metadata["meta1"]

    assert md.has_modified_properties is True
    assert md.validate() is False

    with pytest.raises(ValueError, match="cannot be written|Cannot write|Incomplete"):
        loaded.write_to_disk(str(tmp_path / "should_fail.h5"))


def test_roundtrip_writes_expected_root_and_activity_timestamp_strings(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "schema_check.h5"

    f = escdf.ESCDF()
    created_time = dt.datetime(2025, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)
    activity_time = dt.datetime(2025, 6, 7, 8, 9, 10, 654321, tzinfo=timezone.utc)

    f.set_created_properties("unit_test_user", created_time)
    f.add_activity("act1", "Activity", activity_time)
    f.write_to_disk(str(file_path))

    with h5py.File(file_path, "r") as h5f:
        assert h5f.attrs["created_by"] == "unit_test_user"
        assert h5f.attrs["created_date"] == "2025-01-02T03:04:05.123456Z"
        assert h5f["activities"]["act1"].attrs["activity_date"] == "2025-06-07T08:09:10.654321Z"