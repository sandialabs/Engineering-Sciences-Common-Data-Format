import datetime as dt
from datetime import timezone

import h5py
import numpy as np
import pytest

import escdf


def _make_minimal_scalar_group(parent_group, name="data1", dataset_type="scalar", descriptive_name="Scalar"):
    group = parent_group.create_group(name)
    group.attrs["_specification_name"] = dataset_type
    group.attrs["_descriptive_name"] = descriptive_name
    group.attrs["_version"] = (0, 1, 0)

    value = group.create_dataset("value", shape=(), dtype="f8")
    value.attrs["data_type"] = "f8"
    value[()] = 1.25

    unit = group.create_dataset("unit", shape=(), dtype=h5py.string_dtype())
    unit.attrs["data_type"] = "str"
    unit[()] = "g"

    return group


def test_load_missing_created_by_warns_and_defaults(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "missing_created_by.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"
        f.create_group("activities")

    with pytest.warns(UserWarning, match="Unable to read created_by"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.created_by == "UNKNOWN"
    assert loaded.created_date == dt.datetime(
        2024, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc
    )


def test_load_missing_created_date_warns_and_defaults(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "missing_created_date.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.create_group("activities")

    with pytest.warns(UserWarning, match="Unable to read created_date"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.created_by == "someone"
    # Recommend making this UTC-aware in library code if not already
    assert loaded.created_date.year == 1900
    assert loaded.created_date.month == 1
    assert loaded.created_date.day == 1


def test_load_missing_activity_parameters_warns_and_assumes_no_links(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "missing_parameters.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"

        activities = f.create_group("activities")
        activity = activities.create_group("act1")
        activity.attrs["activity_name"] = "Activity one"
        activity.attrs["activity_date"] = "2024-01-02T03:04:05.123456Z"

    with pytest.warns(UserWarning, match="missing parameters dataset"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.activities.names == ["act1"]
    assert loaded.activities["act1"].metadata_links == []


def test_load_missing_activity_date_warns_and_defaults(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "missing_activity_date.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"

        activities = f.create_group("activities")
        activity = activities.create_group("act1")
        activity.attrs["activity_name"] = "Activity one"

        parameters = activity.create_dataset("parameters", shape=(0,), dtype=h5py.string_dtype())
        parameters.attrs["data_type"] = "str"

    with pytest.warns(UserWarning, match="Unable to convert|Unable to find|activity_date"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.activities.names == ["act1"]
    assert loaded.activities["act1"].activity_date.year == 1900
    assert loaded.activities["act1"].activity_date.month == 1
    assert loaded.activities["act1"].activity_date.day == 1


def test_load_unknown_dataset_type_warns_and_maps_to_unknown(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "unknown_dataset_type.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"
        f.create_group("activities")

        md = f.create_group("mystery_metadata")
        md.attrs["_specification_name"] = "totally_unknown_type"
        md.attrs["_descriptive_name"] = "Mystery metadata"
        md.attrs["_version"] = (9, 9, 9)

        original = md.create_dataset("original_type_name", shape=(), dtype=h5py.string_dtype())
        original.attrs["data_type"] = "str"
        original[()] = "totally_unknown_type"

    with pytest.warns(UserWarning, match="undefined type"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.metadata.names == ["mystery_metadata"]
    loaded_md = loaded.metadata["mystery_metadata"]
    assert loaded_md.dataset_type == "unknown"
    assert loaded_md.original_type_name[...] == "totally_unknown_type"


def test_load_missing_descriptive_name_defaults_to_group_name(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "missing_descriptive_name.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"
        f.create_group("activities")

        md = f.create_group("meta1")
        md.attrs["_specification_name"] = "scalar"
        md.attrs["_version"] = (0, 1, 0)

        value = md.create_dataset("value", shape=(), dtype="f8")
        value.attrs["data_type"] = "f8"
        value[()] = 2.0

    loaded = escdf.ESCDF.load(str(file_path))
    assert loaded.metadata["meta1"].descriptive_name == "meta1"


def test_load_extra_unknown_property_marks_dataset_modified(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "extra_property.h5"
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

        extra = md.create_dataset("unexpected_field", shape=(3,), dtype="f8")
        extra.attrs["data_type"] = "f8"
        extra[...] = np.array([1.0, 2.0, 3.0])

    with pytest.warns(UserWarning, match="unknown extra property"):
        loaded = escdf.ESCDF.load(str(file_path))

    md = loaded.metadata["meta1"]
    assert md.has_modified_properties is True
    assert "unexpected_field" in md.property_names
    np.testing.assert_array_equal(md.unexpected_field[...], np.array([1.0, 2.0, 3.0]))


def test_load_malformed_version_warns(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "malformed_version.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"
        f.create_group("activities")

        md = f.create_group("meta1")
        md.attrs["_specification_name"] = "scalar"
        md.attrs["_descriptive_name"] = "Scalar metadata"
        md.attrs["_version"] = (123, 456)  # malformed length

        value = md.create_dataset("value", shape=(), dtype="f8")
        value.attrs["data_type"] = "f8"
        value[()] = 2.0

    # Current Python code may not warn yet; this test may initially fail
    # until malformed version handling is improved.
    with pytest.warns(UserWarning):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.metadata["meta1"].dataset_type == "scalar"


def test_load_missing_activities_group_fails_cleanly(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "missing_activities_group.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"

    with pytest.raises(KeyError):
        escdf.ESCDF.load(str(file_path))