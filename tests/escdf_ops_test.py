import datetime as dt
from datetime import timezone

import h5py
import numpy as np
import pytest

import escdf


def make_minimal_metadata(name="meta1"):
    ds = escdf.Dataset(name, "global_test_attributes", "Global test metadata")
    ds.test_name = "test program name"
    ds.program = "program abc"
    ds.hardware_list = ["hardware_a", "hardware_b"]
    ds.point_of_contact = ["person_1", "person_2"]
    assert ds.validate()
    return ds


def make_minimal_data(name="data1"):
    ds = escdf.Dataset(name, "scalar", "Scalar result")
    ds.value = 1.25
    ds.unit = "g"
    assert ds.validate()
    return ds


def test_empty_escdf_initialization(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    assert f.created_by == "unit_test_user"
    assert len(f.activities.activities) == 0
    assert len(f.metadata.datasets) == 0
    assert f.created_date.tzinfo is not None


def test_add_metadata(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    assert f.metadata.names == ["meta1"]
    assert f.metadata["meta1"] is md


def test_add_duplicate_metadata_raises(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    f.add_metadata(make_minimal_metadata("meta1"))

    with pytest.raises(ValueError):
        f.add_metadata(make_minimal_metadata("meta1"))


def test_add_activity(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)

    f.add_activity("act1", "Activity one", when)

    assert f.activities.names == ["act1"]
    assert f.activities["act1"].descriptive_name == "Activity one"
    assert f.activities["act1"].activity_date == when


def test_add_duplicate_activity_raises(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)

    f.add_activity("act1", "Activity one", when)

    with pytest.raises(ValueError):
        f.add_activity("act1", "Activity duplicate", when)


def test_add_activity_with_missing_metadata_link_raises(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)

    with pytest.raises(ValueError):
        f.add_activity("act1", "Activity one", when, metadata_links=["missing_meta"])


def test_link_and_unlink_metadata(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    f.link_activity_to_metadata("act1", "meta1")
    assert f.activities["act1"].metadata_links == ["meta1"]

    f.unlink_activity_from_metadata("act1", "meta1")
    assert f.activities["act1"].metadata_links == []


def test_link_missing_metadata_raises(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    with pytest.raises(ValueError):
        f.link_activity_to_metadata("act1", "missing_meta")


def test_add_and_remove_data_from_activity(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    data = make_minimal_data("data1")
    f.add_data_to_activity("act1", data)

    assert f.activities["act1"].data_names == ["data1"]
    assert f.get_activity_data("act1", "data1").name == "data1"

    f.remove_data_from_activity("act1", "data1")
    assert f.activities["act1"].data_names == []


def test_add_non_activity_result_to_activity_raises(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    md = make_minimal_metadata("meta1")
    with pytest.raises(ValueError):
        f.add_data_to_activity("act1", md)


def test_get_activity_metadata(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    f = escdf.ESCDF()

    md1 = make_minimal_metadata("meta1")
    md2 = make_minimal_metadata("meta2")
    f.add_metadata(md1)
    f.add_metadata(md2)

    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)
    f.link_activity_to_metadata("act1", "meta1")
    f.link_activity_to_metadata("act1", "meta2")

    linked = f.get_activity_metadata("act1")
    assert linked.names == ["meta1", "meta2"]


def test_simple_file_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )
    file_path = tmp_path / "roundtrip.h5"

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    data = make_minimal_data("data1")
    when = dt.datetime(2024, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)

    f.add_metadata(md)
    f.add_activity("act1", "Activity one", when)
    f.link_activity_to_metadata("act1", "meta1")
    f.add_data_to_activity("act1", data)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.created_by == "unit_test_user"
    assert loaded.metadata.names == ["meta1"]
    assert loaded.activities.names == ["act1"]
    assert loaded.activities["act1"].metadata_links == ["meta1"]
    assert loaded.activities["act1"].data_names == ["data1"]
    assert loaded.activities["act1"].activity_date == when