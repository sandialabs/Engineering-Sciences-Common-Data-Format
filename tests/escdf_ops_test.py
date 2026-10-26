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

    attached_md = f.metadata["meta1"]

    assert f.metadata.names == ["meta1"]
    assert attached_md is not md
    assert attached_md == md


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


def test_new_escdf_container_starts_in_expected_state(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()

    assert f.lifecycle_state == "draft"
    assert f.mutability_state == "editable"
    assert f.hdf5_location is None
    assert f.has_pending_changes is False
    assert f.created_by == "unit_test_user"
    assert f.created_date.tzinfo is not None


def test_mutating_container_sets_pending_changes(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    assert f.has_pending_changes is False

    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    assert f.has_pending_changes is True


def test_write_to_disk_sets_hdf5_native_and_clears_pending_changes(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "state_roundtrip.h5"

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    assert f.has_pending_changes is True
    assert f.hdf5_location is None

    f.write_to_disk(str(file_path))

    assert f.hdf5_location is not None
    assert f.has_pending_changes is False


def test_loaded_escdf_container_starts_in_expected_state_readonly(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "loaded_state_readonly.h5"

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=True)

    assert loaded.hdf5_location is not None
    assert loaded.lifecycle_state == "draft"
    assert loaded.mutability_state == "read_only"
    assert loaded.has_pending_changes is False


def test_loaded_escdf_container_starts_in_expected_state_editable(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "loaded_state_editable.h5"

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=False)

    assert loaded.hdf5_location is not None
    assert loaded.lifecycle_state == "draft"
    assert loaded.mutability_state == "editable"
    assert loaded.has_pending_changes is False


def test_set_created_properties_marks_pending_changes(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    assert f.has_pending_changes is False

    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.set_created_properties("someone_else", when)

    assert f.created_by == "someone_else"
    assert f.created_date == when
    assert f.has_pending_changes is True


def test_add_metadata_clones_in_memory_dataset_wrapper(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    source_md = make_minimal_metadata("meta1")
    source_md.test_name = "Original Test Name"

    f = escdf.ESCDF()
    f.add_metadata(source_md)

    attached_md = f.metadata["meta1"]

    # The attached dataset should be a different wrapper object.
    assert attached_md is not source_md

    # In-memory properties should remain memory-backed in the clone.
    assert attached_md.test_name.hdf5_location is None
    assert attached_md.program.hdf5_location is None
    assert attached_md.hardware_list.hdf5_location is None
    assert attached_md.point_of_contact.hdf5_location is None

    # Values should match.
    assert attached_md.test_name[...] == "Original Test Name"
    assert attached_md.program[...] == "program abc"


def test_add_metadata_clones_hdf5_properties_with_same_backing_location(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "source_metadata.h5"

    source_file = escdf.ESCDF()
    source_md = make_minimal_metadata("meta1")
    source_file.add_metadata(source_md)
    source_file.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=True)
    loaded_md = loaded.metadata["meta1"]

    target = escdf.ESCDF()
    target.add_metadata(loaded_md)

    attached_md = target.metadata["meta1"]

    assert attached_md is not loaded_md

    assert attached_md.test_name is not loaded_md.test_name
    assert attached_md.test_name.same_backing_location_as(loaded_md.test_name)

    assert attached_md.program is not loaded_md.program
    assert attached_md.program.same_backing_location_as(loaded_md.program)

    assert attached_md.hardware_list is not loaded_md.hardware_list
    assert attached_md.hardware_list.same_backing_location_as(loaded_md.hardware_list)

    assert attached_md.point_of_contact is not loaded_md.point_of_contact
    assert attached_md.point_of_contact.same_backing_location_as(
        loaded_md.point_of_contact
    )

    assert attached_md.test_name[...] == "test program name"
    assert attached_md.program[...] == "program abc"


def test_mutating_attached_hdf5_backed_metadata_materializes_clone_only(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    source_path = tmp_path / "source_metadata_for_mutation.h5"

    source_file = escdf.ESCDF()
    source_md = make_minimal_metadata("meta1")
    source_file.add_metadata(source_md)
    source_file.write_to_disk(str(source_path))

    loaded = escdf.ESCDF.load(str(source_path), readonly=False)
    loaded_md = loaded.metadata["meta1"]

    target = escdf.ESCDF()
    target.add_metadata(loaded_md)
    attached_md = target.metadata["meta1"]

    assert attached_md.test_name.same_backing_location_as(loaded_md.test_name)
    assert not attached_md.test_name.can_write_through_current_hdf5_backing()

    attached_md.test_name = "Modified In Clone"

    assert attached_md.test_name.in_memory
    assert attached_md.test_name.hdf5_location is None
    assert attached_md.test_name[...] == "Modified In Clone"

    assert not loaded_md.test_name.in_memory
    assert loaded_md.test_name[...] == "test program name"

    with h5py.File(source_path, "r") as h5_file:
        assert h5_file["meta1"]["test_name"][()] in (
            b"test program name",
            "test program name",
        )


def test_add_data_to_activity_clones_dataset_wrapper(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    source_data = make_minimal_data("data1")
    source_data.value = 9.81
    source_data.unit = "m/s^2"
    assert source_data.validate()

    f.add_data_to_activity("act1", source_data)

    attached_data = f.activities["act1"]["data1"]

    # Dataset wrapper should be cloned rather than reused directly.
    assert attached_data is not source_data

    # In-memory property remains memory-backed.
    assert attached_data.value.hdf5_location is None
    assert attached_data.unit.hdf5_location is None

    assert attached_data.value[...] == np.float64(9.81)
    assert attached_data.unit[...] == "m/s^2"


def test_add_hdf5_native_data_to_activity_creates_external_backed_clone(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "source_activity_data.h5"

    source_file = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    source_file.add_activity("act1", "Activity one", when)

    source_data = make_minimal_data("data1")
    source_data.value = 9.81
    source_data.unit = "m/s^2"
    assert source_data.validate()

    source_file.add_data_to_activity("act1", source_data)
    source_file.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=True)
    loaded_data = loaded.activities["act1"]["data1"]

    # Loaded source should be native HDF5-backed.
    assert loaded_data.value.hdf5_location is not None

    target = escdf.ESCDF()
    target.add_activity("act2", "Activity two", when)
    target.add_data_to_activity("act2", loaded_data)

    attached_data = target.activities["act2"]["data1"]

    assert attached_data is not loaded_data
    assert attached_data.value.same_backing_location_as(loaded_data.value)
    assert attached_data.unit.same_backing_location_as(loaded_data.unit)

    assert attached_data.value[...] == np.float64(9.81)
    assert attached_data.unit[...] == "m/s^2"


def test_new_activity_starts_in_expected_state():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    assert activity.hdf5_location is None
    assert activity.has_pending_changes is False


def test_activity_link_to_metadata_sets_pending_changes():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    assert activity.has_pending_changes is False
    activity.link_to_metadata("meta1")
    assert activity.has_pending_changes is True


def test_activity_add_data_sets_pending_changes():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)
    data = make_minimal_data("data1")

    assert activity.has_pending_changes is False
    activity.add_data(data)
    assert activity.has_pending_changes is True


def test_loaded_activity_starts_hdf5_native_with_no_pending_changes(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "loaded_activity_state.h5"

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)
    data = make_minimal_data("data1")
    f.add_data_to_activity("act1", data)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))
    loaded_activity = loaded.activities["act1"]

    assert loaded_activity.hdf5_location is not None
    assert loaded_activity.has_pending_changes is False


def test_activity_write_to_disk_sets_hdf5_native_and_clears_pending_changes(tmp_path):
    file_path = tmp_path / "activity_write_state.h5"
    h5_file = h5py.File(file_path, "w")
    activity_group = h5_file.create_group("activities")

    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)
    data = make_minimal_data("data1")
    activity.add_data(data)

    assert activity.hdf5_location is None
    assert activity.has_pending_changes is True

    activity.write_to_disk(activity_group)

    assert activity.hdf5_location is not None
    assert activity.has_pending_changes is False

    h5_file.close()


def test_remove_metadata_returns_removed_object(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    removed = f.remove_metadata("meta1")

    assert removed.name == "meta1"
    assert "meta1" not in f.metadata.names
    assert f.has_pending_changes is True


def test_remove_metadata_fails_if_still_linked_without_unlink(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    md = make_minimal_metadata("meta1")
    f.add_metadata(md, activity_to_link="act1")

    with pytest.raises(ValueError, match="still linked"):
        f.remove_metadata("meta1")


def test_remove_metadata_with_unlink_removes_links(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    md = make_minimal_metadata("meta1")
    f.add_metadata(md, activity_to_link="act1")

    removed = f.remove_metadata("meta1", unlink=True)

    assert removed.name == "meta1"
    assert "meta1" not in f.metadata.names
    assert "meta1" not in f.activities["act1"].metadata_links
    assert f.has_pending_changes is True


def test_remove_activity_returns_removed_object(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    removed = f.remove_activity("act1")

    assert removed.name == "act1"
    assert "act1" not in f.activities.names
    assert f.has_pending_changes is True


def test_remove_activity_leaves_metadata_by_default(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    md = make_minimal_metadata("meta1")
    f.add_metadata(md, activity_to_link="act1")

    f.remove_activity("act1")

    assert "act1" not in f.activities.names
    assert "meta1" in f.metadata.names


def test_remove_activity_can_delete_newly_unlinked_metadata(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    md = make_minimal_metadata("meta1")
    f.add_metadata(md, activity_to_link="act1")

    f.remove_activity("act1", delete_unlinked_metadata=True)

    assert "act1" not in f.activities.names
    assert "meta1" not in f.metadata.names


def test_remove_activity_keeps_metadata_if_linked_elsewhere(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)
    f.add_activity("act2", "Activity two", when)

    md = make_minimal_metadata("meta1")
    f.add_metadata(md)
    f.link_activity_to_metadata("act1", "meta1")
    f.link_activity_to_metadata("act2", "meta1")

    f.remove_activity("act1", delete_unlinked_metadata=True)

    assert "act1" not in f.activities.names
    assert "act2" in f.activities.names
    assert "meta1" in f.metadata.names
    assert "meta1" in f.activities["act2"].metadata_links


def test_activity_remove_data_returns_removed_dataset():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)
    data = make_minimal_data("data1")

    activity.add_data(data)
    assert "data1" in activity.data.names
    assert activity.has_pending_changes is True

    # Reset to simulate an already-established state before removal.
    activity._has_pending_changes = False

    removed = activity.remove_data("data1")

    assert removed is data
    assert "data1" not in activity.data.names
    assert activity.has_pending_changes is True


def test_activity_remove_data_raises_for_missing_dataset():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    with pytest.raises(ValueError, match="No dataset with name"):
        activity.remove_data("missing_data")


def test_container_remove_data_from_activity_returns_removed_dataset(monkeypatch):
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

    assert "data1" in f.activities["act1"].data.names

    # Reset to isolate the effect of the remove call.
    f._has_pending_changes = False
    f.activities["act1"]._has_pending_changes = False

    removed = f.remove_data_from_activity("act1", "data1")

    assert removed.name == "data1"
    assert "data1" not in f.activities["act1"].data.names
    assert f.activities["act1"].has_pending_changes is True
    assert f.has_pending_changes is True


def test_removed_dataset_can_be_moved_to_another_activity(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)
    f.add_activity("act2", "Activity two", when)

    data = make_minimal_data("data1")
    data.value = 9.81
    data.unit = "m/s^2"
    assert data.validate()

    f.add_data_to_activity("act1", data)
    removed = f.remove_data_from_activity("act1", "data1")

    assert "data1" not in f.activities["act1"].data.names

    f.add_data_to_activity("act2", removed)

    assert "data1" in f.activities["act2"].data.names
    moved = f.activities["act2"]["data1"]
    assert moved.value[...] == np.float64(9.81)
    assert moved.unit[...] == "m/s^2"


def test_rename_metadata_updates_container_and_links(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    md = make_minimal_metadata("meta1")
    f.add_metadata(md, activity_to_link="act1")

    renamed = f.rename_metadata("meta1", "meta2")

    assert renamed.name == "meta2"
    assert "meta1" not in f.metadata.names
    assert "meta2" in f.metadata.names
    assert "meta2" in f.activities["act1"].metadata_links
    assert "meta1" not in f.activities["act1"].metadata_links
    assert f.has_pending_changes is True


def test_rename_metadata_rejects_invalid_name(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    with pytest.raises(ValueError, match="not a valid identifier"):
        f.rename_metadata("meta1", "not valid")


def test_rename_activity_updates_container(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    renamed = f.rename_activity("act1", "act2")

    assert renamed.name == "act2"
    assert "act1" not in f.activities.names
    assert "act2" in f.activities.names
    assert f.has_pending_changes is True


def test_activity_rename_data_updates_activity():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)
    data = make_minimal_data("data1")
    activity.add_data(data)

    renamed = activity.rename_data("data1", "data2")

    assert renamed.name == "data2"
    assert "data1" not in activity.data.names
    assert "data2" in activity.data.names
    assert activity.has_pending_changes is True


def test_container_rename_activity_data_delegates(monkeypatch):
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

    renamed = f.rename_activity_data("act1", "data1", "data2")

    assert renamed.name == "data2"
    assert "data1" not in f.activities["act1"].data.names
    assert "data2" in f.activities["act1"].data.names
    assert f.has_pending_changes is True


def test_activity_replace_data_returns_removed_dataset():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    original = make_minimal_data("data1")
    original.value = 1.0
    original.unit = "g"
    assert original.validate()

    replacement = make_minimal_data("data1")
    replacement.value = 9.81
    replacement.unit = "m/s^2"
    assert replacement.validate()

    activity.add_data(original)

    removed = activity.replace_data(replacement)

    assert removed.name == "data1"
    assert removed.value[...] == np.float64(1.0)
    current = activity["data1"]
    assert current.value[...] == np.float64(9.81)
    assert current.unit[...] == "m/s^2"
    assert activity.has_pending_changes is True


def test_activity_replace_data_raises_if_missing():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    replacement = make_minimal_data("missing_data")
    replacement.value = 9.81
    replacement.unit = "m/s^2"
    assert replacement.validate()

    with pytest.raises(ValueError, match="exists in activity"):
        activity.replace_data(replacement)


def test_container_replace_data_in_activity_returns_removed_dataset(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    original = make_minimal_data("data1")
    original.value = 1.0
    original.unit = "g"
    assert original.validate()

    replacement = make_minimal_data("data1")
    replacement.value = 9.81
    replacement.unit = "m/s^2"
    assert replacement.validate()

    f.add_data_to_activity("act1", original)
    removed = f.replace_data_in_activity("act1", replacement)

    assert removed.value[...] == np.float64(1.0)

    current = f.activities["act1"]["data1"]
    assert current.value[...] == np.float64(9.81)
    assert current.unit[...] == "m/s^2"
    assert f.has_pending_changes is True


def test_replace_metadata_returns_removed_dataset(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()

    original = make_minimal_metadata("meta1")
    original.test_name = "Original Test"
    f.add_metadata(original)

    replacement = make_minimal_metadata("meta1")
    replacement.test_name = "Replacement Test"

    removed = f.replace_metadata(replacement)

    assert removed.test_name[...] == "Original Test"
    current = f.metadata["meta1"]
    assert current.test_name[...] == "Replacement Test"
    assert f.has_pending_changes is True


def test_replace_metadata_raises_if_missing(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()

    replacement = make_minimal_metadata("missing_meta")

    with pytest.raises(ValueError, match="exists to replace"):
        f.replace_metadata(replacement)


def test_activity_realize_to_hdf5_writes_datasets_and_links(tmp_path):
    file_path = tmp_path / "activity_realize.h5"
    h5_file = h5py.File(file_path, "w")
    activities_group = h5_file.create_group("activities")

    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)
    activity.link_to_metadata("meta1")

    data = make_minimal_data("data1")
    data.value = 9.81
    data.unit = "m/s^2"
    assert data.validate()

    activity.add_data(data)

    activity.realize_to_hdf5(activities_group)

    assert "act1" in activities_group
    activity_group = activities_group["act1"]
    assert activity_group.attrs["activity_name"] == "Activity one"
    assert "parameters" in activity_group
    assert "data1" in activity_group
    assert "value" in activity_group["data1"]
    assert "unit" in activity_group["data1"]

    assert activity.hdf5_location is not None
    assert activity.has_pending_changes is False

    h5_file.close()


def test_container_realize_to_hdf5_writes_metadata_and_activities(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "container_realize.h5"

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)
    data = make_minimal_data("data1")
    f.add_data_to_activity("act1", data)
    f.link_activity_to_metadata("act1", "meta1")

    with h5py.File(file_path, "w") as h5_file:
        f.realize_to_hdf5(h5_file)

        assert h5_file.attrs["created_by"] == "unit_test_user"
        assert "meta1" in h5_file
        assert "activities" in h5_file
        assert "act1" in h5_file["activities"]
        assert "data1" in h5_file["activities"]["act1"]
        assert "parameters" in h5_file["activities"]["act1"]

    assert f.hdf5_location is not None
    assert f.has_pending_changes is False


def test_container_realize_to_hdf5_rejects_existing_group_without_overwrite(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "container_realize_conflict.h5"

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    with h5py.File(file_path, "w") as h5_file:
        h5_file.create_group("meta1")

        with pytest.raises(ValueError, match="already contains"):
            f.realize_to_hdf5(h5_file)


def test_python_metadata_retrieval_returns_same_object_reference(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    first = f.metadata["meta1"]
    second = f.metadata["meta1"]
    third = f.metadata[0]

    assert first is second
    assert first is third


def test_python_activity_retrieval_returns_same_object_reference(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    first = f.activities["act1"]
    second = f.activities["act1"]
    third = f.activities[0]

    assert first is second
    assert first is third


def test_python_activity_data_retrieval_returns_same_object_reference(monkeypatch):
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

    first = f.get_activity_data("act1", "data1")
    second = f.get_activity_data("act1", "data1")
    third = f.activities["act1"]["data1"]

    assert first is second
    assert first is third


def test_python_activity_get_data_returns_same_object_reference():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    data = make_minimal_data("data1")
    activity.add_data(data)

    first = activity.get_data("data1")
    second = activity.get_data("data1")
    third = activity["data1"]

    assert first is second
    assert first is third


def test_metadata_logical_parent_after_add_metadata(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    source_md = make_minimal_metadata("meta1")

    assert source_md.logical_parent is None

    f.add_metadata(source_md)
    attached_md = f.metadata["meta1"]

    assert attached_md is not source_md
    assert attached_md.logical_parent is f

    for prop_name in attached_md.property_names:
        prop = getattr(attached_md, prop_name)
        if prop is not None:
            assert prop.logical_parent is attached_md


def test_activity_logical_parent_after_add_activity(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)

    f.add_activity("act1", "Activity one", when)
    activity = f.activities["act1"]

    assert activity.logical_parent is f


def test_activity_data_logical_parent_after_add_data(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    data = make_minimal_data("data1")
    assert data.logical_parent is None

    f.add_data_to_activity("act1", data)
    attached_data = f.activities["act1"]["data1"]

    assert attached_data is not data
    assert attached_data.logical_parent is f.activities["act1"]

    for prop_name in attached_data.property_names:
        prop = getattr(attached_data, prop_name)
        if prop is not None:
            assert prop.logical_parent is attached_data


def test_removed_metadata_becomes_free(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    removed = f.remove_metadata("meta1")

    assert removed.logical_parent is None


def test_removed_activity_becomes_free(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    removed = f.remove_activity("act1")

    assert removed.logical_parent is None


def test_removed_activity_data_becomes_free(monkeypatch):
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

    removed = f.remove_data_from_activity("act1", "data1")

    assert removed.logical_parent is None


def test_metadata_dataset_logical_path_after_add_metadata(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    attached_md = f.metadata["meta1"]

    assert attached_md.logical_parent is f
    assert attached_md.logical_path == "/meta1"

    assert attached_md.test_name.logical_parent is attached_md
    assert attached_md.test_name.logical_path == "/meta1/test_name"


def test_activity_and_activity_data_logical_paths(monkeypatch):
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

    activity = f.activities["act1"]
    attached_data = activity["data1"]

    assert activity.logical_parent is f
    assert activity.logical_path == "/activities/act1"

    assert attached_data.logical_parent is activity
    assert attached_data.logical_path == "/activities/act1/data1"

    assert attached_data.value.logical_parent is attached_data
    assert attached_data.value.logical_path == "/activities/act1/data1/value"


def test_removed_objects_have_no_logical_path(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    removed = f.remove_metadata("meta1")

    assert removed.logical_parent is None
    assert removed.logical_path is None

    # Child properties still point to the removed dataset wrapper, but the
    # dataset wrapper itself is free, so child logical paths are also not
    # container-realizable.
    assert removed.test_name.logical_parent is removed
    assert removed.test_name.logical_path is None


def _assert_identity_chain(actual, expected):
    assert len(actual) == len(expected)
    for actual_item, expected_item in zip(actual, expected):
        assert actual_item is expected_item


def test_metadata_dataset_logical_ancestry_is_bottom_up(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    attached_md = f.metadata["meta1"]

    _assert_identity_chain(attached_md.logical_ancestry, [attached_md, f])
    assert attached_md.logical_root is f

    _assert_identity_chain(
        attached_md.test_name.logical_ancestry,
        [attached_md.test_name, attached_md, f],
    )
    assert attached_md.test_name.logical_root is f


def test_activity_logical_ancestry_is_bottom_up(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)

    activity = f.activities["act1"]

    _assert_identity_chain(activity.logical_ancestry, [activity, f])
    assert activity.logical_root is f


def test_activity_data_logical_ancestry_is_bottom_up(monkeypatch):
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

    activity = f.activities["act1"]
    attached_data = activity["data1"]

    _assert_identity_chain(attached_data.logical_ancestry, [attached_data, activity, f])
    assert attached_data.logical_root is f

    _assert_identity_chain(
        attached_data.value.logical_ancestry,
        [attached_data.value, attached_data, activity, f],
    )
    assert attached_data.value.logical_root is f


def test_free_dataset_logical_ancestry_stops_at_dataset():
    ds = make_minimal_metadata("free_meta")

    _assert_identity_chain(ds.logical_ancestry, [ds])
    assert ds.logical_root is ds

    _assert_identity_chain(ds.test_name.logical_ancestry, [ds.test_name, ds])
    assert ds.test_name.logical_root is ds


def test_removed_objects_logical_ancestry_stops_after_detach(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    removed = f.remove_metadata("meta1")

    _assert_identity_chain(removed.logical_ancestry, [removed])
    assert removed.logical_root is removed

    _assert_identity_chain(
        removed.test_name.logical_ancestry, [removed.test_name, removed]
    )
    assert removed.test_name.logical_root is removed


def test_same_logical_location_for_same_retrieved_metadata(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    md = make_minimal_metadata("meta1")
    f.add_metadata(md)

    first = f.metadata["meta1"]
    second = f.metadata["meta1"]

    assert first.same_logical_location_as(second)
    assert first.test_name.same_logical_location_as(second.test_name)


def test_same_logical_location_false_for_same_path_different_roots(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f1 = escdf.ESCDF()
    f2 = escdf.ESCDF()

    f1.add_metadata(make_minimal_metadata("meta1"))
    f2.add_metadata(make_minimal_metadata("meta1"))

    md1 = f1.metadata["meta1"]
    md2 = f2.metadata["meta1"]

    assert md1.logical_path == md2.logical_path
    assert not md1.same_logical_location_as(md2)
    assert not md1.test_name.same_logical_location_as(md2.test_name)


def test_same_logical_location_false_after_remove(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()
    f.add_metadata(make_minimal_metadata("meta1"))

    attached = f.metadata["meta1"]
    removed = f.remove_metadata("meta1")

    assert attached is removed
    assert removed.logical_parent is None
    assert removed.same_logical_location_as(removed)


def test_activity_hdf5_location_is_none_for_memory_activity():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    assert activity.hdf5_location is None


def test_loaded_activity_hdf5_location_matches_group(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "activity_location.h5"

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)
    data = make_minimal_data("data1")
    f.add_data_to_activity("act1", data)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))
    activity = loaded.activities["act1"]

    assert activity.hdf5_location is not None
    assert activity.hdf5_location.object_path == "/activities/act1"


def test_activity_same_backing_location_for_two_wrappers(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "activity_same_backing.h5"

    f = escdf.ESCDF()
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    f.add_activity("act1", "Activity one", when)
    data = make_minimal_data("data1")
    f.add_data_to_activity("act1", data)
    f.write_to_disk(str(file_path))

    loaded1 = escdf.ESCDF.load(str(file_path))
    loaded2 = escdf.ESCDF.load(str(file_path))

    act1 = loaded1.activities["act1"]
    act2 = loaded2.activities["act1"]

    assert act1 is not act2
    assert act1.same_backing_location_as(act2)


def test_activity_target_hdf5_location_uses_activities_group(tmp_path):
    file_path = tmp_path / "activity_target_location.h5"

    with h5py.File(file_path, "w") as h5_file:
        activities_group = h5_file.create_group("activities")

        when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
        activity = escdf.Activity("act1", "Activity one", when)

        location = activity.target_hdf5_location(activities_group)

        assert location.object_path == "/activities/act1"


def test_activity_is_realized_at_true_after_realization(tmp_path):
    file_path = tmp_path / "activity_realized_at.h5"

    with h5py.File(file_path, "w") as h5_file:
        activities_group = h5_file.create_group("activities")

        when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
        activity = escdf.Activity("act1", "Activity one", when)
        data = make_minimal_data("data1")
        activity.add_data(data)

        activity.realize_to_hdf5(activities_group)

        assert activity.is_realized_under(activities_group)
        assert activity.is_realized_at(activities_group["act1"])


def test_container_hdf5_location_is_none_for_memory_container(monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    f = escdf.ESCDF()

    assert f.hdf5_location is None


def test_loaded_container_hdf5_location_matches_file(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "container_location.h5"

    f = escdf.ESCDF()
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))

    assert loaded.hdf5_location is not None
    assert loaded.hdf5_location.object_path == "/"


def test_container_same_backing_location_for_two_wrappers(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "container_same_backing.h5"

    f = escdf.ESCDF()
    f.write_to_disk(str(file_path))

    loaded1 = escdf.ESCDF.load(str(file_path))
    loaded2 = escdf.ESCDF.load(str(file_path))

    assert loaded1 is not loaded2
    assert loaded1.same_backing_location_as(loaded2)


def test_container_is_realized_at_true_after_realization(tmp_path, monkeypatch):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "container_realized_at.h5"

    f = escdf.ESCDF()

    with h5py.File(file_path, "w") as h5_file:
        f.realize_to_hdf5(h5_file)
        assert f.is_realized_at(h5_file)
