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
    assert f.backing_state == "memory"
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
    assert f.backing_state == "memory"

    f.write_to_disk(str(file_path))

    assert f.backing_state == "hdf5_native"
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

    assert loaded.backing_state == "hdf5_native"
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

    assert loaded.backing_state == "hdf5_native"
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
    assert attached_md.test_name.backing_state == "memory"
    assert attached_md.program.backing_state == "memory"
    assert attached_md.hardware_list.backing_state == "memory"
    assert attached_md.point_of_contact.backing_state == "memory"

    # Values should match.
    assert attached_md.test_name[...] == "Original Test Name"
    assert attached_md.program[...] == "program abc"


def test_add_metadata_clones_hdf5_native_properties_as_external(tmp_path, monkeypatch):
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

    # Loaded source should be native HDF5-backed.
    assert loaded_md.test_name.backing_state == "hdf5_native"

    target = escdf.ESCDF()
    target.add_metadata(loaded_md)

    attached_md = target.metadata["meta1"]

    # New wrapper object
    assert attached_md is not loaded_md

    # Copied attached properties should now be externally backed.
    assert attached_md.test_name.backing_state == "hdf5_external"
    assert attached_md.program.backing_state == "hdf5_external"
    assert attached_md.hardware_list.backing_state == "hdf5_external"
    assert attached_md.point_of_contact.backing_state == "hdf5_external"

    # Values should still read correctly.
    assert attached_md.test_name[...] == "test program name"
    assert attached_md.program[...] == "program abc"


def test_mutating_external_backed_attached_metadata_materializes_clone_only(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "source_metadata_for_mutation.h5"

    source_file = escdf.ESCDF()
    source_md = make_minimal_metadata("meta1")
    source_file.add_metadata(source_md)
    source_file.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=True)
    loaded_md = loaded.metadata["meta1"]

    target = escdf.ESCDF()
    target.add_metadata(loaded_md)
    attached_md = target.metadata["meta1"]

    # Initially external-backed in the attached clone.
    assert attached_md.test_name.backing_state == "hdf5_external"

    # Mutating should materialize to memory for the clone.
    attached_md.test_name = "Modified In Clone"

    assert attached_md.test_name.backing_state == "memory"
    assert attached_md.test_name[...] == "Modified In Clone"

    # Original loaded dataset should remain unchanged and still native-backed.
    assert loaded_md.test_name.backing_state == "hdf5_native"
    assert loaded_md.test_name[...] == "test program name"


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
    assert attached_data.value.backing_state == "memory"
    assert attached_data.unit.backing_state == "memory"

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
    assert loaded_data.value.backing_state == "hdf5_native"

    target = escdf.ESCDF()
    target.add_activity("act2", "Activity two", when)
    target.add_data_to_activity("act2", loaded_data)

    attached_data = target.activities["act2"]["data1"]

    assert attached_data is not loaded_data
    assert attached_data.value.backing_state == "hdf5_external"
    assert attached_data.unit.backing_state == "hdf5_external"

    assert attached_data.value[...] == np.float64(9.81)
    assert attached_data.unit[...] == "m/s^2"


def test_new_activity_starts_in_expected_state():
    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)

    assert activity.backing_state == "memory"
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

    assert loaded_activity.backing_state == "hdf5_native"
    assert loaded_activity.has_pending_changes is False


def test_activity_write_to_disk_sets_hdf5_native_and_clears_pending_changes(tmp_path):
    file_path = tmp_path / "activity_write_state.h5"
    h5_file = h5py.File(file_path, "w")
    activity_group = h5_file.create_group("activities")

    when = dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    activity = escdf.Activity("act1", "Activity one", when)
    data = make_minimal_data("data1")
    activity.add_data(data)

    assert activity.backing_state == "memory"
    assert activity.has_pending_changes is True

    activity.write_to_disk(activity_group)

    assert activity.backing_state == "hdf5_native"
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
