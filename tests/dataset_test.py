import sys
sys.path.insert(0, '..')
import pytest
import os
import h5py
THIS_DIR = os.path.dirname(os.path.abspath(__file__))

import string
import numpy as np
import escdf
rng = np.random.default_rng()
FLOAT_SCALE = 10000
CHARACTERS = string.ascii_letters+string.digits
MAX_RAGGED_LENGTH = 50

@pytest.fixture
def hdf5_and_properties(tmp_path):
    file_path = tmp_path/'escdf_dataset_test.h5'
    file = h5py.File(file_path,'w',libver='latest')
    file.close()
    test_specification_path = os.path.join(THIS_DIR,'..','escdf','specifications')
    test_specification_file  = os.path.join(test_specification_path,'unittesting_specification.txt')
    choice_specification_file = os.path.join(test_specification_path,'choicetesting_specification.txt')
    enum_specification_file = os.path.join(test_specification_path,'enumtesting_specification.txt')
    table_specification_file = os.path.join(
        test_specification_path, "tabletesting_specification.txt"
    )
    data_type = [
        'u1','u2','u4','u8',
        'i1','i2','i4','i8',
        'f4','f8',
        'c8','c16',
        'str','bytes'
    ]
    data_size = [
        [],
        [8],
        [9,6],
        [12,8,10]
    ]
    ragged = [
        True, False
    ]
    property_names = []
    property_values = []
    with open(test_specification_file,'w') as f:
        f.write('unittesting_specification - v0.1.0\n-------------------------\nextends: activity_result\n\nproperties\n----------\n')
        for dt in data_type:
            for ds in data_size:
                ndim = len(ds)
                ds_name = ','.join([str(v) for v in ds])
                for rg in ragged:
                    if rg and dt=='str':
                        continue
                    elif rg and dt=='bytes':
                        continue
                    elif rg and dt=='c8':
                        continue
                    elif rg and dt=='c16':
                        continue
                    name = '{:}_ndim_{:}'.format(dt,ndim)
                    if rg:
                        name = name + '_ragged'
                    f.write('{:} - {:}'.format(name,dt))
                    if len(ds_name) == 0:
                        if rg:
                            f.write(' - scalar')
                    else:
                        f.write(' - {:}'.format(ds_name))
                    if rg:
                        f.write(' - variable_length\n')
                    else:
                        f.write('\n')
                    property_names.append(name)
                    property_values.append((dt,ds,rg))
    with open(choice_specification_file,'w') as f:
        f.write('choicetesting_specification - v0.1.0\n--------------------------\nextends: activity_result\n\nproperties\n----------\n')
        f.write('a - i8 - scalar - or:choicetest:ab_scalar\n')
        f.write('b - i8 - scalar - or:choicetest:ab_scalar\n')
        f.write('a - i8 - scalar - or:choicetest:ac_scalar\n')
        f.write('c - i8 - scalar - or:choicetest:ac_scalar\n')
        f.write('d - i8 - scalar - or:choicetest:d_scalar\n')
        f.write('d - i8 - size_a - or:choicetest:d_array\n')
        f.write('e - f8 - scalar - or:choicetest:e_real\n')
        f.write('e - c16 - scalar - or:choicetest:e_complex\n')
    with open(enum_specification_file,'w') as f:
        f.write('enumtesting_specification - v0.1.0\n')
        f.write('-------------------------\n')
        f.write('extends: activity_result\n')
        f.write('\n')
        f.write('properties\n')
        f.write('----------\n')
        f.write('enum_scalar - str - scalar - enum:enum1\n')
        f.write('enum_one_dim - str - num_vals - enum:enum2\n')
        f.write('enum_two_dim - str - num_rows,num_cols - enum:enum2\n')
        f.write('enum_three_dim - str - num_rows,num_cols,3 - enum:enum3\n')
        f.write('enum_optional - str - scalar - optional,enum:enum1\n')
        f.write('no_enum - str - scalar\n')
        f.write('\n')
        f.write('enumerations\n')
        f.write('------------\n')
        f.write('enum1 - red,orange,yellow,green,blue,violet\n')
        f.write('enum2 - one, two, three, four,\n')
        f.write('enum3 - do, re, mi, fa, sol, la, ti, do\n')
    with open(table_specification_file, "w") as f:
        f.write("tabletesting_specification - v0.1.0\n")
        f.write("---------------------------\n")
        f.write("extends: activity_result\n")
        f.write("\n")
        f.write("properties\n")
        f.write("----------\n")
        f.write("vec - f8 - num_points\n")
        f.write("mat - f8 - num_rows,num_cols\n")
        f.write("cube - f8 - num_layers,num_rows,num_cols\n")
        f.write("labels - str - num_rows\n")
    for key in list(sys.modules.keys()):
        if key.startswith('escdf'):
            del sys.modules[key]
    import escdf
    yield file_path,property_names,property_values,escdf
    os.remove(test_specification_file)
    os.remove(choice_specification_file)
    os.remove(enum_specification_file)
    os.remove(table_specification_file)

def testChoices(hdf5_and_properties):
    """
    Verify that valid non-ambiguous choice branches are accepted and
    incomplete branches are rejected.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    test_dataset = escdf.Dataset("choice_dataset", "choicetesting_specification")
    test_dataset.a = 1
    assert not test_dataset.validate()
    test_dataset.b = 1
    assert test_dataset.validate()

    test_dataset = escdf.Dataset("choice_dataset", "choicetesting_specification")
    test_dataset.a = 1
    assert not test_dataset.validate()
    test_dataset.c = 1
    assert test_dataset.validate()

    test_dataset = escdf.Dataset("choice_dataset", "choicetesting_specification")
    test_dataset.d = 1
    assert test_dataset.validate()
    test_dataset.d = [1, 1]
    assert test_dataset.validate()

    test_dataset = escdf.Dataset("choice_dataset", "choicetesting_specification")
    test_dataset.e = 1.0
    assert test_dataset.validate()
    test_dataset.e = 1 + 1j
    assert test_dataset.validate()


def testChoices_reports_ambiguous_choice_as_invalid(hdf5_and_properties):
    """
    Verify that a dataset matching multiple valid choice branches is
    reported as invalid rather than raising an exception.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    test_dataset = escdf.Dataset("choice_dataset", "choicetesting_specification")
    test_dataset.e = 1 + 1j
    test_dataset.d = 1

    assert test_dataset.validate() is False

    report = test_dataset.validate(report=True)
    assert report.is_valid is False
    assert len(report.ambiguous_choices) > 0


def testEnums(hdf5_and_properties):
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties
    test_dataset = escdf.Dataset('enum_dataset','enumtesting_specification')
    test_dataset.enum_scalar = 'red'
    test_dataset.enum_one_dim = ['one','three','three','one']
    test_dataset.enum_two_dim = np.array([['one','three'],['two','four'],['one','one']],dtype=object)
    test_dataset.enum_three_dim = np.tile(np.array([['do','re'],['mi','fa'],['sol','la']],dtype=object)[:,:,np.newaxis],[1,1,3])
    test_dataset.no_enum = 'hello'
    assert test_dataset.validate()
    test_dataset.enum_scalar = 're'
    assert not test_dataset.validate()
    test_dataset.enum_scalar = 'red'
    test_dataset.enum_three_dim = np.tile(np.array([['do','ree'],['mi','fa'],['soo','la']],dtype=object)[:,:,np.newaxis],[1,1,3])
    assert not test_dataset.validate()

def testStorageAndRecall(hdf5_and_properties):
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties
    # Create the dataset
    dataset_name = 'test_dataset'
    dataset_type = 'unittesting_specification'
    dataset_descriptive_name = 'A dataset to test out the ability to read and write different formats.'
    test_dataset = escdf.Dataset(dataset_name,dataset_type,dataset_descriptive_name)
    # Verify that the items are set correctly
    assert test_dataset.name == dataset_name
    assert test_dataset.descriptive_name == dataset_descriptive_name
    assert test_dataset.dataset_type == dataset_type

    stored_data = []
    for prop_name, prop_data in zip(property_names,property_values):
        data_type, data_shape, ragged = prop_data
        stride = 1

        strides = tuple([slice(0,size,stride) for size in data_shape])
        stride_sizes = [len(np.arange(sz)[sd]) for sz,sd in zip(data_shape,strides)]

        if 'u' in data_type or 'i' in data_type:
            if ragged:
                data = np.ndarray(stride_sizes,dtype='object')
                for key in np.ndindex(*stride_sizes):
                    data[key] = rng.integers(2**64-1,dtype='u8',size=np.random.randint(MAX_RAGGED_LENGTH)).astype(data_type)
            else:
                data = rng.integers(2**64-1,dtype='u8',size=stride_sizes).astype(data_type)
        elif 'f' in data_type:
            if ragged:
                data = np.ndarray(stride_sizes,dtype='object')
                for key in np.ndindex(*stride_sizes):
                    data[key] = (FLOAT_SCALE*rng.random(dtype='f8',size=np.random.randint(MAX_RAGGED_LENGTH))-FLOAT_SCALE/2).astype(data_type)
            else:
                data = (FLOAT_SCALE*rng.random(dtype='f8',size=stride_sizes)-FLOAT_SCALE/2).astype(data_type)
        elif 'c' in data_type:
            if ragged:
                data = np.ndarray(stride_sizes,dtype='object')
                for key in np.ndindex(*stride_sizes):
                    size = np.random.randint(MAX_RAGGED_LENGTH)
                    data[key] = (FLOAT_SCALE*rng.random(dtype='f8',size=size)-FLOAT_SCALE/2+
                                1j*(FLOAT_SCALE*rng.random(dtype='f8',size=size)-FLOAT_SCALE/2)).astype(data_type)
            else:
                data = (FLOAT_SCALE*rng.random(dtype='f8',size=stride_sizes).astype(data_type)-FLOAT_SCALE/2 +
                        1j*(FLOAT_SCALE*rng.random(dtype='f8',size=stride_sizes).astype(data_type)-FLOAT_SCALE/2)).astype(data_type)
        elif data_type == 'str':
            data = np.ndarray(stride_sizes,dtype='object')
            for key in np.ndindex(*stride_sizes):
                data[key] = ''.join([CHARACTERS[i] for i in rng.integers(len(CHARACTERS),size=np.random.randint(MAX_RAGGED_LENGTH))])
        elif data_type == 'bytes':
            data = np.ndarray(stride_sizes,dtype='object')
            for key in np.ndindex(*stride_sizes):
                data[key] = rng.integers(2**64-1,dtype='u8',size=np.random.randint(MAX_RAGGED_LENGTH)).astype('u1')

        stored_data.append(data)
        setattr(test_dataset,prop_name,data)

    assert test_dataset.validate()

     # Now read all data back to make sure we get what we specified
    for prop_name,data in zip(property_names,stored_data):
        prop = getattr(test_dataset,prop_name)
        data_shape = prop.shape
        if len(data_shape) == 0:
            if data.dtype == 'object':
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...],data)
        else:
            if data.dtype == 'object':
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...].view(np.ndarray),data)
    
    hdf5_file = h5py.File(hdf5_file_path,'r+')
    test_dataset.write_to_disk(hdf5_file)

    for prop_name,data in zip(property_names,stored_data):
        prop = getattr(test_dataset,prop_name)
        data_shape = prop.shape
        if len(data_shape) == 0:
            if data.dtype == 'object':
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    if prop.datatype == 'str':
                        np.testing.assert_array_equal(actual,data[key])
                    else:
                        np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...],data)
        else:
            if data.dtype == 'object':
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...].view(np.ndarray),data)

    test_dataset.read_into_memory()

    for prop_name,data in zip(property_names,stored_data):
        prop = getattr(test_dataset,prop_name)
        data_shape = prop.shape
        if len(data_shape) == 0:
            if data.dtype == 'object':
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...],data)
        else:
            if data.dtype == 'object':
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...].view(np.ndarray),data)


def test_get_supertypes_returns_canonical_ancestry_order(hdf5_and_properties):
    """
    Verify that get_supertypes() returns canonical inheritance application
    order, beginning with the root ancestor and ending with the dataset
    type itself.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    ds = escdf.Dataset("d1", "unittesting_specification")
    assert ds.get_supertypes() == [
        "parameter_set",
        "activity_result",
        "unittesting_specification",
    ]


def test_get_dimension_names_returns_symbolic_dimensions(hdf5_and_properties):
    """
    Verify that get_dimension_names() returns symbolic dimensions from the
    effective resolved specification.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    ds = escdf.Dataset("d1", "choicetesting_specification")
    dimension_names = ds.get_dimension_names()

    assert "size_a" in dimension_names


def test_istype_uses_canonical_inheritance_chain(hdf5_and_properties):
    """
    Verify that istype() still works correctly when driven by canonical
    ancestry information.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    ds = escdf.Dataset("d1", "unittesting_specification")

    assert ds.istype("unittesting_specification") is True
    assert ds.istype("activity_result") is True
    assert ds.istype("parameter_set") is True
    assert ds.istype("scalar") is False


def test_dump_to_table_vector_dimension(hdf5_and_properties):
    """
    Verify that dump_to_table() returns a single-column table for a simple
    one-dimensional property.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    ds = escdf.Dataset("d1", "tabletesting_specification")
    ds.vec = np.array([10.0, 20.0, 30.0], dtype=np.float64)

    table = ds.dump_to_table("num_points")

    assert list(table.columns) == ["vec[:]"]
    np.testing.assert_allclose(table["vec[:]"].to_numpy(), np.array([10.0, 20.0, 30.0]))


def test_dump_to_table_middle_dimension_in_3d_property(hdf5_and_properties):
    """
    Verify that dump_to_table() correctly uses a middle symbolic dimension
    as the row dimension for a three-dimensional property.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    ds = escdf.Dataset("d1", "tabletesting_specification")

    ds.mat = np.array(
        [
            [1.0, 2.0],
            [3.0, 4.0],
            [5.0, 6.0],
        ],
        dtype=np.float64,
    )

    ds.cube = np.array(
        [
            [
                [100.0, 101.0],
                [102.0, 103.0],
                [104.0, 105.0],
            ],
            [
                [200.0, 201.0],
                [202.0, 203.0],
                [204.0, 205.0],
            ],
        ],
        dtype=np.float64,
    )

    ds.labels = np.array(["row1", "row2", "row3"], dtype=object)

    table = ds.dump_to_table("num_rows")

    # Number of rows should match num_rows, which is the middle dimension
    assert len(table) == 3

    # Matrix-derived columns should be present
    assert "mat[:,0]" in table.columns
    assert "mat[:,1]" in table.columns
    np.testing.assert_allclose(table["mat[:,0]"].to_numpy(), np.array([1.0, 3.0, 5.0]))
    np.testing.assert_allclose(table["mat[:,1]"].to_numpy(), np.array([2.0, 4.0, 6.0]))

    # String labels should also align with num_rows
    assert "labels[:]" in table.columns
    np.testing.assert_array_equal(
        table["labels[:]"].to_numpy(),
        np.array(["row1", "row2", "row3"], dtype=object),
    )

    # Cube-derived columns: verify that the middle dimension is used for rows
    assert "cube[0,:,0]" in table.columns
    assert "cube[1,:,1]" in table.columns
    np.testing.assert_allclose(
        table["cube[0,:,0]"].to_numpy(),
        np.array([100.0, 102.0, 104.0]),
    )
    np.testing.assert_allclose(
        table["cube[1,:,1]"].to_numpy(),
        np.array([201.0, 203.0, 205.0]),
    )


def test_new_dataset_starts_in_expected_state(hdf5_and_properties):
    """
    Verify that a newly constructed dataset starts as memory-backed with no
    pending changes.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    ds = escdf.Dataset("d1", "unittesting_specification")

    assert ds.backing_state == "memory"
    assert ds.has_pending_changes is False
    assert ds.has_modified_properties is False


def test_dataset_assignment_sets_pending_changes(hdf5_and_properties):
    """
    Verify that assigning a property marks the dataset as having pending
    changes.
    """
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties

    ds = escdf.Dataset("d1", "tabletesting_specification")
    assert ds.has_pending_changes is False

    ds.vec = np.array([1.0, 2.0, 3.0], dtype=np.float64)

    assert ds.has_pending_changes is True
    assert ds.backing_state == "memory"


def test_loaded_dataset_starts_hdf5_native_with_no_pending_changes(tmp_path, monkeypatch):
    """
    Verify that a dataset loaded from disk starts HDF5-native and has no
    pending changes.
    """
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "dataset_state_roundtrip.h5"

    f = escdf.ESCDF()
    md = escdf.Dataset("meta1", "scalar", "Scalar metadata")
    md.value = 2.0
    md.unit = "g"
    assert md.validate()

    f.add_metadata(md)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))
    loaded_md = loaded.metadata["meta1"]

    assert loaded_md.backing_state == "hdf5_native"
    assert loaded_md.has_pending_changes is False
    assert loaded_md.has_modified_properties is False


def test_dataset_write_to_disk_sets_hdf5_native_and_clears_pending_changes(tmp_path, monkeypatch):
    """
    Verify that writing a dataset to disk sets it HDF5-native and clears
    pending changes.
    """
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "dataset_write_state.h5"
    h5_file = h5py.File(file_path, "w")

    ds = escdf.Dataset("meta1", "scalar", "Scalar metadata")
    ds.value = 2.0
    ds.unit = "g"

    assert ds.has_pending_changes is True
    assert ds.backing_state == "memory"

    group = h5_file.create_group("meta1")
    ds.write_to_disk(group)

    assert ds.backing_state == "hdf5_native"
    assert ds.has_pending_changes is False

    h5_file.close()


def test_dataset_read_into_memory_sets_memory_backing_state(tmp_path, monkeypatch):
    """
    Verify that reading a dataset into memory updates its dataset-level
    backing state to memory.
    """
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "dataset_read_into_memory_state.h5"

    f = escdf.ESCDF()
    md = escdf.Dataset("meta1", "scalar", "Scalar metadata")
    md.value = 2.0
    md.unit = "g"
    f.add_metadata(md)
    f.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path))
    loaded_md = loaded.metadata["meta1"]

    assert loaded_md.backing_state == "hdf5_native"

    loaded_md.read_into_memory()

    assert loaded_md.backing_state == "memory"
    assert loaded_md.value.backing_state == "memory"
    assert loaded_md.unit.backing_state == "memory"


def test_attached_cloned_dataset_starts_memory_backed_and_not_pending_changes(
    tmp_path, monkeypatch
):
    """
    Verify that an attached cloned dataset wrapper starts memory-backed and
    without pending changes.
    """
    monkeypatch.setattr(
        escdf.ESCDF,
        "get_or_prompt_attribution_name",
        staticmethod(lambda **kwargs: "unit_test_user"),
    )

    file_path = tmp_path / "attached_clone_state.h5"

    source_file = escdf.ESCDF()
    md = escdf.Dataset("meta1", "scalar", "Scalar metadata")
    md.value = 2.0
    md.unit = "g"
    source_file.add_metadata(md)
    source_file.write_to_disk(str(file_path))

    loaded = escdf.ESCDF.load(str(file_path), readonly=True)
    loaded_md = loaded.metadata["meta1"]

    target = escdf.ESCDF()
    target.add_metadata(loaded_md)

    attached_md = target.metadata["meta1"]

    assert attached_md.backing_state == "memory"
    assert attached_md.has_pending_changes is False