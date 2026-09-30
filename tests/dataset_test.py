import sys
sys.path.insert(0, '..')
import pytest
import os
import h5py
THIS_DIR = os.path.dirname(os.path.abspath(__file__))

import string
import numpy as np
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
    for key in list(sys.modules.keys()):
        if key.startswith('escdf'):
            del sys.modules[key]
    import escdf
    yield file_path,property_names,property_values,escdf
    os.remove(test_specification_file)
    os.remove(choice_specification_file)
    os.remove(enum_specification_file)

def testChoices(hdf5_and_properties):
    hdf5_file_path, property_names, property_values, escdf = hdf5_and_properties
    test_dataset = escdf.Dataset('choice_dataset','choicetesting_specification')
    test_dataset.a = 1
    assert not test_dataset.validate()
    test_dataset.b = 1
    assert test_dataset.validate()
    test_dataset = escdf.Dataset('choice_dataset','choicetesting_specification')
    test_dataset.a = 1
    assert not test_dataset.validate()
    test_dataset.c = 1
    assert test_dataset.validate()
    test_dataset = escdf.Dataset('choice_dataset','choicetesting_specification')
    test_dataset.d = 1
    assert test_dataset.validate()
    test_dataset.d = [1,1]
    assert test_dataset.validate()
    test_dataset = escdf.Dataset('choice_dataset','choicetesting_specification')
    test_dataset.e = 1.0
    assert test_dataset.validate()
    test_dataset.e = 1+1j
    assert test_dataset.validate()
    test_dataset.d = 1
    error_occurred = False
    try:
        test_dataset.validate()
    except ValueError:
        error_occurred = True;
    assert error_occurred;

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