import sys

sys.path.insert(0, "..")
import os
import string

import h5py
import numpy as np
import pytest

import escdf
from escdf.backing import HDF5Location

rng = np.random.default_rng()
FLOAT_SCALE = 10000
CHARACTERS = string.ascii_letters + string.digits
MAX_RAGGED_LENGTH = 50
THIS_DIR = os.path.dirname(os.path.abspath(__file__))


def make_hdf5_property_with_logical_context(
    escdf,
    h5_file,
    parent_name,
    property_name,
    datatype,
    shape,
    *,
    ragged=False,
    in_memory=True,
):
    """
    Create an HDF5-backed property inside a minimal logical ESCDF context.

    This is intended for low-level property tests that need assignment to
    write through to HDF5 under the target-aware logical/backing model.
    """
    parent_group = h5_file.create_group(parent_name)

    root = escdf.ESCDF()
    root._hdf5_location = HDF5Location.from_h5_object(h5_file)

    dataset = escdf.Dataset(parent_name, "scalar", "Property test logical parent")
    root._insert_metadata_native(dataset)

    prop = escdf.Property(
        property_name,
        datatype,
        shape,
        hdf5group=None if in_memory else parent_group,
        ragged=ragged,
    )
    prop.set_logical_parent(dataset)

    return prop, dataset, root


@pytest.fixture
def hdf5_file_path(tmp_path):
    file_path = tmp_path / "escdf_property_test.h5"
    file = h5py.File(file_path, "w", libver="latest")
    file.close()
    yield file_path


@pytest.mark.parametrize(
    "data_type",
    [
        "u1",
        "u2",
        "u4",
        "u8",
        "i1",
        "i2",
        "i4",
        "i8",
        "f4",
        "f8",
        "c8",
        "c16",
        "str",
        "bytes",
    ],
)
@pytest.mark.parametrize("data_shape", [[], [8], [9, 6], [12, 8, 10]])
@pytest.mark.parametrize("stride", [1, 2])
@pytest.mark.parametrize("in_memory", [True, False])
@pytest.mark.parametrize("ragged", [True, False])
def test_storage_and_recall(
    hdf5_file_path, data_type, data_shape, stride, in_memory, ragged
):
    # Open the HDF5 file
    hdf5_file = h5py.File(hdf5_file_path, "r+")

    ndim = len(data_shape)
    name = "{:}_{:}_ndim_{:}_stride_{:}".format(
        data_type, "in_memory" if in_memory else "on_disk", ndim, stride
    )
    try:
        prop, parent, root = make_hdf5_property_with_logical_context(
            escdf,
            hdf5_file,
            f"{name}_parent",
            name,
            data_type,
            data_shape,
            ragged=ragged,
            in_memory=in_memory,
        )
    except ValueError as e:
        assert str(
            e
        ) == 'Properties with "{:}" datatypes do not support ragged arrays.'.format(
            data_type
        )
        return
    assert prop.name == name
    assert prop.datatype == data_type
    assert prop.shape == tuple(data_shape)

    strides = tuple([slice(0, size, stride) for size in data_shape])
    stride_sizes = [len(np.arange(sz)[sd]) for sz, sd in zip(data_shape, strides)]

    if "u" in data_type or "i" in data_type:
        if ragged:
            data = np.ndarray(stride_sizes, dtype="object")
            for key in np.ndindex(*stride_sizes):
                data[key] = rng.integers(
                    2**64 - 1, dtype="u8", size=np.random.randint(MAX_RAGGED_LENGTH)
                ).astype(data_type)
        else:
            data = rng.integers(2**64 - 1, dtype="u8", size=stride_sizes).astype(
                data_type
            )
    elif "f" in data_type:
        if ragged:
            data = np.ndarray(stride_sizes, dtype="object")
            for key in np.ndindex(*stride_sizes):
                data[key] = (
                    FLOAT_SCALE
                    * rng.random(dtype="f8", size=np.random.randint(MAX_RAGGED_LENGTH))
                    - FLOAT_SCALE / 2
                ).astype(data_type)
        else:
            data = (
                FLOAT_SCALE * rng.random(dtype="f8", size=stride_sizes)
                - FLOAT_SCALE / 2
            ).astype(data_type)
    elif "c" in data_type:
        if ragged:
            data = np.ndarray(stride_sizes, dtype="object")
            for key in np.ndindex(*stride_sizes):
                size = np.random.randint(MAX_RAGGED_LENGTH)
                data[key] = (
                    FLOAT_SCALE * rng.random(dtype="f8", size=size)
                    - FLOAT_SCALE / 2
                    + 1j
                    * (
                        FLOAT_SCALE * rng.random(dtype="f8", size=size)
                        - FLOAT_SCALE / 2
                    )
                ).astype(data_type)
        else:
            data = (
                FLOAT_SCALE
                * rng.random(dtype="f8", size=stride_sizes).astype(data_type)
                - FLOAT_SCALE / 2
                + 1j
                * (
                    FLOAT_SCALE
                    * rng.random(dtype="f8", size=stride_sizes).astype(data_type)
                    - FLOAT_SCALE / 2
                )
            ).astype(data_type)
    elif data_type == "str":
        data = np.ndarray(stride_sizes, dtype="object")
        for key in np.ndindex(*stride_sizes):
            data[key] = "".join(
                [
                    CHARACTERS[i]
                    for i in rng.integers(
                        len(CHARACTERS), size=np.random.randint(MAX_RAGGED_LENGTH)
                    )
                ]
            )
    elif data_type == "bytes":
        data = np.ndarray(stride_sizes, dtype="object")
        for key in np.ndindex(*stride_sizes):
            data[key] = rng.integers(
                2**64 - 1, dtype="u8", size=np.random.randint(MAX_RAGGED_LENGTH)
            ).astype("u1")

    if len(data_shape) == 0:
        prop[...] = data
        if data.dtype == "object":
            actual = prop[...]
            was_called = False
            for key in np.ndindex(*data.shape):
                was_called = True
                if prop.datatype == "str":
                    np.testing.assert_array_equal(actual, data[key])
                else:
                    np.testing.assert_array_equal(actual[key], data[key])
            assert was_called
        else:
            np.testing.assert_array_equal(prop[...], data)
    else:
        prop[strides] = data
        if data.dtype == "object":
            actual = prop[strides]
            was_called = False
            for key in np.ndindex(*data.shape):
                was_called = True
                np.testing.assert_array_equal(actual[key], data[key])
            assert was_called
        else:
            np.testing.assert_array_equal(prop[strides].view(np.ndarray), data)

    assert prop.in_memory == in_memory
    assert prop.ragged == ragged

    if in_memory:
        prop.write_to_disk(hdf5_file[parent.name])
        if len(data_shape) == 0:
            prop[...] = data
            if data.dtype == "object":
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    if prop.datatype == "str":
                        np.testing.assert_array_equal(actual, data[key])
                    else:
                        np.testing.assert_array_equal(actual[key], data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...], data)
        else:
            prop[strides] = data
            if data.dtype == "object":
                actual = prop[strides]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    np.testing.assert_array_equal(actual[key], data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[strides].view(np.ndarray), data)
        assert not prop.in_memory
    prop.read_into_memory()
    if len(data_shape) == 0:
        prop[...] = data
        if data.dtype == "object":
            actual = prop[...]
            was_called = False
            for key in np.ndindex(*data.shape):
                was_called = True
                np.testing.assert_array_equal(actual[key], data[key])
            assert was_called
        else:
            np.testing.assert_array_equal(prop[...], data)
    else:
        prop[strides] = data
        if data.dtype == "object":
            actual = prop[strides]
            was_called = False
            for key in np.ndindex(*data.shape):
                was_called = True
                np.testing.assert_array_equal(actual[key], data[key])
            assert was_called
        else:
            np.testing.assert_array_equal(prop[strides].view(np.ndarray), data)
    assert prop.in_memory

    hdf5_file.close()


def test_new_in_memory_property_starts_memory_backed():
    prop = escdf.Property("p1", "f8", (3,))
    assert prop.hdf5_location is None
    assert prop.in_memory is True


def test_new_hdf5_property_starts_hdf5_native(hdf5_file_path):
    hdf5_file = h5py.File(hdf5_file_path, "r+")
    prop = escdf.Property("p1", "f8", (3,), hdf5group=hdf5_file)
    assert prop.hdf5_location is not None
    assert prop.in_memory is False
    hdf5_file.close()


def test_loaded_property_starts_hdf5_native(hdf5_file_path):
    hdf5_file = h5py.File(hdf5_file_path, "r+")
    prop, parent, root = make_hdf5_property_with_logical_context(
        escdf,
        hdf5_file,
        "p1_parent",
        "p1",
        "f8",
        (3,),
        in_memory=False,
    )
    prop[...] = np.array([1.0, 2.0, 3.0], dtype=np.float64)

    loaded = escdf.Property.load(h5_dataset=prop.h5_dataset)
    assert loaded.hdf5_location is not None
    assert loaded.in_memory is False
    hdf5_file.close()


def test_read_into_memory_sets_backing_state_to_memory(hdf5_file_path):
    hdf5_file = h5py.File(hdf5_file_path, "r+")
    prop, parent, root = make_hdf5_property_with_logical_context(
        escdf,
        hdf5_file,
        "p1_parent",
        "p1",
        "f8",
        (3,),
        in_memory=False,
    )
    prop[...] = np.array([1.0, 2.0, 3.0], dtype=np.float64)

    prop.read_into_memory()

    assert prop.hdf5_location is None
    assert prop.in_memory is True
    np.testing.assert_allclose(prop[...], np.array([1.0, 2.0, 3.0]))
    hdf5_file.close()


def test_hdf5_location_object_compares_same_location(hdf5_file_path):
    hdf5_file = h5py.File(hdf5_file_path, "r+")
    prop1, parent, root = make_hdf5_property_with_logical_context(
        escdf,
        hdf5_file,
        f"p1_parent",
        "p1",
        "f8",
        (3,),
        in_memory=False,
    )
    prop1[...] = np.array([1.0, 2.0, 3.0], dtype=np.float64)

    prop2 = escdf.Property.load(h5_dataset=prop1.h5_dataset)

    assert prop1 is not prop2
    assert prop1.hdf5_location == prop2.hdf5_location
    assert prop1.same_backing_location_as(prop2)

    hdf5_file.close()


def test_memory_properties_do_not_have_same_backing_location():
    prop1 = escdf.Property("p1", "f8", (3,))
    prop2 = escdf.Property("p1", "f8", (3,))

    assert prop1.hdf5_location is None
    assert prop2.hdf5_location is None
    assert not prop1.same_backing_location_as(prop2)


def test_target_hdf5_location_uses_group_and_property_name(hdf5_file_path):
    hdf5_file = h5py.File(hdf5_file_path, "r+")
    group = hdf5_file.create_group("my_group")

    prop = escdf.Property("p1", "f8", (3,))
    location = prop.target_hdf5_location(group)

    assert location.file_path == os.path.realpath(os.path.abspath(str(hdf5_file_path)))
    assert location.object_path == "/my_group/p1"

    hdf5_file.close()


def test_assignment_to_loaded_native_property_writes_through_when_logical_and_backing_match(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "native_assignment.h5"

    f = escdf.ESCDF()
    md = escdf.Dataset("meta1", "scalar", "Scalar metadata")
    md.value = 2.0
    md.unit = "g"
    f.add_metadata(md)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=False)
    loaded_md = loaded.metadata["meta1"]

    assert loaded_md.value.can_write_through_current_hdf5_backing()

    loaded_md.value[...] = 5.0

    assert not loaded_md.value.in_memory
    assert loaded_md.value[...] == 5.0

    with h5py.File(file_path, "r") as h5_file:
        assert h5_file["meta1"]["value"][()] == 5.0


def test_assignment_to_attached_hdf5_backed_property_materializes_and_preserves_source(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    source_path = tmp_path / "source_assignment.h5"

    source = escdf.ESCDF()
    md = escdf.Dataset("meta1", "scalar", "Scalar metadata")
    md.value = 2.0
    md.unit = "g"
    source.add_metadata(md)
    source.write_to_disk(str(source_path))

    loaded = escdf.ESCDF.load(str(source_path), readonly=False)
    loaded_md = loaded.metadata["meta1"]

    target = escdf.ESCDF()
    target.add_metadata(loaded_md)
    attached_md = target.metadata["meta1"]

    assert not attached_md.value.can_write_through_current_hdf5_backing()
    assert attached_md.value.same_backing_location_as(loaded_md.value)

    attached_md.value[...] = 9.0

    assert attached_md.value.in_memory
    assert attached_md.value.hdf5_location is None
    assert attached_md.value[...] == 9.0

    assert not loaded_md.value.in_memory
    assert loaded_md.value[...] == 2.0

    with h5py.File(source_path, "r") as h5_file:
        assert h5_file["meta1"]["value"][()] == 2.0


def test_assignment_to_removed_hdf5_backed_property_materializes_and_preserves_source(
    tmp_path, monkeypatch
):
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "removed_assignment.h5"

    f = escdf.ESCDF()
    md = escdf.Dataset("meta1", "scalar", "Scalar metadata")
    md.value = 2.0
    md.unit = "g"
    f.add_metadata(md)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=False)
    removed = loaded.remove_metadata("meta1")

    assert removed.logical_parent is None
    assert not removed.value.can_write_through_current_hdf5_backing()

    removed.value[...] = 7.0

    assert removed.value.in_memory
    assert removed.value.hdf5_location is None
    assert removed.value[...] == 7.0

    with h5py.File(file_path, "r") as h5_file:
        assert h5_file["meta1"]["value"][()] == 2.0
