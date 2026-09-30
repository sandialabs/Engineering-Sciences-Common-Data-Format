import sys
sys.path.insert(0, '..')
import escdf
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
def hdf5_file_path(tmp_path):
    file_path = tmp_path/'escdf_property_test.h5'
    file = h5py.File(file_path,'w',libver='latest')
    file.close()
    yield file_path

@pytest.mark.parametrize('data_type',[
    'u1', 'u2','u4','u8',
    'i1','i2','i4','i8',
    'f4','f8',
    'c8','c16', 
    'str',
    'bytes'
    ])
@pytest.mark.parametrize('data_shape',[
    [],
    [8],
    [9,6],
    [12,8,10]
    ])
@pytest.mark.parametrize('stride',[
    1,
    2
    ])
@pytest.mark.parametrize('in_memory',[
    True,
    False
    ])
@pytest.mark.parametrize('ragged',[
    True,
    False
    ])
def test_storage_and_recall(hdf5_file_path, data_type, data_shape, stride, in_memory, ragged):
    # Open the HDF5 file
    hdf5_file = h5py.File(hdf5_file_path,'r+')
    
    ndim = len(data_shape)
    name = '{:}_{:}_ndim_{:}_stride_{:}'.format(
        data_type,'in_memory' if in_memory else 'on_disk',ndim,stride)
    try:
        prop = escdf.Property(name,data_type,data_shape,ragged=ragged,
                              hdf5group=None if in_memory else hdf5_file)
    except ValueError as e:
        assert str(e) == 'Properties with "{:}" datatypes do not support ragged arrays.'.format(data_type)
        return
    assert prop.name == name
    assert prop.datatype == data_type
    assert prop.shape == tuple(data_shape)
    
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
    
    if len(data_shape) == 0:
        prop[...] = data
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
        prop[strides] = data
        if data.dtype == 'object':
            actual = prop[strides]
            was_called = False
            for key in np.ndindex(*data.shape):
                was_called = True
                np.testing.assert_array_equal(actual[key],data[key])
            assert was_called
        else:
            np.testing.assert_array_equal(prop[strides].view(np.ndarray),data)
    
    assert prop.in_memory == in_memory
    assert prop.ragged == ragged

    if in_memory:
        prop.write_to_disk(hdf5_file)
        if len(data_shape) == 0:
            prop[...] = data
            if data.dtype == 'object':
                actual = prop[...]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    if prop.datatype == 'str':
                        np.testing.assert_array_equal(actual, data[key])
                    else:
                        np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[...],data)
        else:
            prop[strides] = data
            if data.dtype == 'object':
                actual = prop[strides]
                was_called = False
                for key in np.ndindex(*data.shape):
                    was_called = True
                    np.testing.assert_array_equal(actual[key],data[key])
                assert was_called
            else:
                np.testing.assert_array_equal(prop[strides].view(np.ndarray),data)
        assert not prop.in_memory
    prop.read_into_memory()
    if len(data_shape) == 0:
        prop[...] = data
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
        prop[strides] = data
        if data.dtype == 'object':
            actual = prop[strides]
            was_called = False
            for key in np.ndindex(*data.shape):
                was_called = True
                np.testing.assert_array_equal(actual[key],data[key])
            assert was_called
        else:
            np.testing.assert_array_equal(prop[strides].view(np.ndarray),data)
    assert prop.in_memory

    hdf5_file.close()