import datetime as dt
from datetime import timezone

import h5py
import pytest
import warnings

import escdf
from escdf.valid_names import is_valid_identifier, make_valid_identifier


def test_is_valid_identifier():
    assert is_valid_identifier("abc")
    assert is_valid_identifier("a1_b2")
    assert not is_valid_identifier("1abc")
    assert not is_valid_identifier("a-b")
    assert not is_valid_identifier("a b")
    assert not is_valid_identifier("")


def test_make_valid_identifier_warns_and_replaces():
    with pytest.warns(UserWarning, match="Replaced name"):
        out = make_valid_identifier("1 bad-name", "dataset_")
    assert out == "dataset_1_badname"
    assert is_valid_identifier(out)


def test_make_valid_identifier_no_warning_if_unchanged():
    with warnings.catch_warnings(record=True) as record:
        warnings.simplefilter("always")
        out = make_valid_identifier("valid_name", "dataset_")
    assert out == "valid_name"
    assert len(record) == 0


def test_dataset_replace_invalid_name():
    with pytest.warns(UserWarning, match="Replaced name"):
        ds = escdf.Dataset(
            "1 bad-name",
            "scalar",
            "Example dataset",
            replace_invalid_names=True,
        )
    assert ds.name == "dataset_1_badname"


def test_dataset_invalid_name_raises_without_replacement():
    with pytest.raises(ValueError, match="Invalid name"):
        escdf.Dataset(
            "1 bad-name",
            "scalar",
            "Example dataset",
            replace_invalid_names=False,
        )


def test_activity_replace_invalid_name():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    with pytest.warns(UserWarning, match="Replaced name"):
        activity = escdf.Activity(
            "1 bad-name",
            "Example activity",
            when,
            replace_invalid_names=True,
        )
    assert activity.name == "activity_1_badname"


def test_activity_invalid_name_raises_without_replacement():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    with pytest.raises(ValueError, match="Invalid name"):
        escdf.Activity(
            "1 bad-name",
            "Example activity",
            when,
            replace_invalid_names=False,
        )


def test_load_invalid_activity_name_repairs_name(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "invalid_activity_name.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"

        activities = f.create_group("activities")
        activity = activities.create_group("1 bad-name")
        activity.attrs["activity_name"] = "Example activity"
        activity.attrs["activity_date"] = "2024-01-02T03:04:05.123456Z"

        parameters = activity.create_dataset("parameters", shape=(0,), dtype=h5py.string_dtype())
        parameters.attrs["data_type"] = "str"

    with pytest.warns(UserWarning, match="Replaced name"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.activities.names == ["activity_1_badname"]
    assert loaded.activities["activity_1_badname"].descriptive_name == "Example activity"

def test_load_invalid_metadata_name_repairs_name(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "invalid_metadata_name.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"
        f.create_group("activities")

        md = f.create_group("1 bad-name")
        md.attrs["_specification_name"] = "scalar"
        md.attrs["_descriptive_name"] = "Bad metadata"
        md.attrs["_version"] = (0, 1, 0)

        value = md.create_dataset("value", shape=(), dtype="f8")
        value.attrs["data_type"] = "f8"
        value[()] = 1.23

    with pytest.warns(UserWarning, match="Replaced name"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.metadata.names == ["dataset_1_badname"]
    assert loaded.metadata["dataset_1_badname"].descriptive_name == "Bad metadata"

def test_load_invalid_metadata_link_repairs_name(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "invalid_metadata_link.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"

        md = f.create_group("1 bad-meta")
        md.attrs["_specification_name"] = "scalar"
        md.attrs["_descriptive_name"] = "Bad metadata"
        md.attrs["_version"] = (0, 1, 0)

        value = md.create_dataset("value", shape=(), dtype="f8")
        value.attrs["data_type"] = "f8"
        value[()] = 1.23

        activities = f.create_group("activities")
        activity = activities.create_group("act1")
        activity.attrs["activity_name"] = "Example activity"
        activity.attrs["activity_date"] = "2024-01-02T03:04:05.123456Z"

        parameters = activity.create_dataset("parameters", shape=(1,), dtype=h5py.string_dtype())
        parameters.attrs["data_type"] = "str"
        parameters[0] = "1 bad-meta"

    with pytest.warns(UserWarning, match="Replaced name"):
        loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.metadata.names == ["dataset_1_badmeta"]
    assert loaded.activities["act1"].metadata_links == ["dataset_1_badmeta"]

def test_load_sanitized_name_collision_raises(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "sanitized_collision.h5"
    with h5py.File(file_path, "w") as f:
        f.attrs["created_by"] = "someone"
        f.attrs["created_date"] = "2024-01-02T03:04:05.123456Z"
        f.create_group("activities")

        for group_name in ["a-b", "a%b"]:
            md = f.create_group(group_name)
            md.attrs["_specification_name"] = "scalar"
            md.attrs["_descriptive_name"] = group_name
            md.attrs["_version"] = (0, 1, 0)

            value = md.create_dataset("value", shape=(), dtype="f8")
            value.attrs["data_type"] = "f8"
            value[()] = 1.23

    with pytest.raises(ValueError):
        escdf.ESCDF.load(str(file_path))