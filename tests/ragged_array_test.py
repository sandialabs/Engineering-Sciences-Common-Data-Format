import sys
sys.path.insert(0,'..')
import escdf
import pytest
import os
import h5py
THIS_DIR = os.path.dirname(os.path.abspath(__file__))

import numpy as np
rng = np.random.default_rng()
FLOAT_SCALE = 10000
MAX_RAGGED_LENGTH = 50

@pytest.mark.parametrize('data_type',[
    'u1','u2','u4','u8',
    'i1','i2','i4','i8',
    'f4','f8',
    'c8','c16', 
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
def test_valid_storage_and_recall(data_type,data_shape,stride):
    print('data_type = {:}; data_shape = {:}; stride = {:};'.format(repr(data_type),data_shape,stride))
    strides = tuple([slice(0,size,stride) for size in data_shape])
    stride_sizes = [len(np.arange(sz)[sd]) for sz,sd in zip(data_shape,strides)]
    
    ragged_array = escdf.escdf_property.RaggedArray(
        data_shape,data_type)
    
    for key,value in np.ndenumerate(ragged_array):
        assert value.dtype == data_type
        assert value.size == 0
        assert value.ndim == 1
    
    if 'u' in data_type or 'i' in data_type:
        data = np.ndarray(stride_sizes,dtype='object')
        for key in np.ndindex(*stride_sizes):
            data[key] = rng.integers(2**64-1,dtype='u8',size=np.random.randint(MAX_RAGGED_LENGTH)).astype(data_type)
    elif 'f' in data_type:
        data = np.ndarray(stride_sizes,dtype='object')
        for key in np.ndindex(*stride_sizes):
            data[key] = (FLOAT_SCALE*rng.random(dtype='f8',size=np.random.randint(MAX_RAGGED_LENGTH))-FLOAT_SCALE/2).astype(data_type)
    elif 'c' in data_type:
        data = np.ndarray(stride_sizes,dtype='object')
        for key in np.ndindex(*stride_sizes):
            size = np.random.randint(MAX_RAGGED_LENGTH)
            data[key] = (FLOAT_SCALE*rng.random(dtype='f8',size=size)-FLOAT_SCALE/2+
                         1j*(FLOAT_SCALE*rng.random(dtype='f8',size=size)-FLOAT_SCALE/2)).astype(data_type)
            
    ragged_array[strides] = data
    received_data = ragged_array[strides]
    for key in np.ndindex(*data.shape):
        np.testing.assert_array_equal(received_data[key],data[key])
    