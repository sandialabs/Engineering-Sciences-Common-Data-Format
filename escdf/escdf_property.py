# -*- coding: utf-8 -*-
"""
ESCDF property storage primitives.

This module defines :class:`ESCDFProperty` and helper array classes used to
represent typed dataset properties in memory and on disk, including support
for ragged numeric arrays and string arrays.
"""

import h5py as h5
import numpy as np
import warnings

VERBOSE = False

class ESCDFProperty:
    """
    Typed ESCDF dataset property.

    An ``ESCDFProperty`` stores one named property belonging to an
    :class:`ESCDFDataset`. Properties can exist either fully in memory or
    as datasets backed by HDF5 storage.

    Parameters
    ----------
    name : str
        Property name.
    datatype : str
        ESCDF datatype code such as ``f8``, ``c16``, ``u8``, ``str``, or
        ``bytes``.
    shape : tuple of int
        Property shape as defined by the active specification.
    data : array-like, optional
        Initial data to assign.
    ragged : bool, optional
        If ``True``, the property stores variable-length numeric arrays.
    hdf5group : h5py.Group, optional
        Target HDF5 group in which a new on-disk dataset should be created.
    hdf5dataset : h5py.Dataset, optional
        Existing HDF5 dataset to wrap directly.

    Notes
    -----
    Properties with datatype ``str`` or ``bytes`` do not support ragged
    mode. ``bytes`` values are represented as arrays of ``uint8``.

    See Also
    --------
    ESCDFDataset
    RaggedArray
    StringArray
    """

    __slots__ = (
        "_name",
        "_datatype",
        "_shape",
        "_data",
        "_ragged",
        "_h5_dataset",
        "_backing_state",
    )

    @property
    def name(self):
        return self._name

    @property
    def datatype(self):
        return self._datatype

    @property
    def shape(self):
        return self._shape

    @property
    def ragged(self):
        return self._ragged

    @property
    def h5_dataset(self):
        return self._h5_dataset

    @property
    def in_memory(self):
        return self.h5_dataset is None

    @property
    def backing_state(self):
        return self._backing_state

    def __init__(
        self,
        name,
        datatype,
        shape,
        data=None,
        ragged=False,
        hdf5group: h5.Group = None,
        hdf5dataset: h5.Dataset = None,
    ):
        """
        Initialize an ESCDF property.

        Parameters
        ----------
        name : str
            Property name.
        datatype : str
            ESCDF datatype code.
        shape : tuple of int
            Property shape.
        data : array-like, optional
            Initial data to assign.
        ragged : bool, optional
            If ``True``, store variable-length numeric arrays.
        hdf5group : h5py.Group, optional
            Group in which to create a new HDF5 dataset.
        hdf5dataset : h5py.Dataset, optional
            Existing HDF5 dataset to wrap.

        Raises
        ------
        ValueError
            If an unsupported ragged datatype is requested.
        """
        self._name = name
        self._datatype = datatype
        self._shape = tuple(shape)
        self._ragged = ragged
        self._backing_state = "memory"
        
        # Make sure we don't have inconsistent data
        if datatype == 'str' and ragged:
            raise ValueError('Properties with "str" datatypes do not support ragged arrays.')
        if datatype == 'bytes' and ragged:
            raise ValueError('Properties with "bytes" datatypes do not support ragged arrays.')
        
        if hdf5dataset is not None:
            self._h5_dataset = hdf5dataset
            self._data = None
            self._backing_state = "hdf5_native"
            if VERBOSE:
                print('Linked Dataset to disk: {:}'.format(name))
        elif hdf5group is not None:
            if datatype == 'str':
                dtype = h5.special_dtype(vlen=str)
            elif datatype == 'bytes':
                dtype = h5.special_dtype(vlen=np.dtype('uint8'))
            elif ragged:
                dtype = h5.vlen_dtype(datatype)
            else:
                dtype = datatype
            self._h5_dataset = hdf5group.create_dataset(name, shape, dtype)
            self.h5_dataset.attrs['data_type'] = datatype
            self._backing_state = "hdf5_native"
            if VERBOSE:
                print('Dataset Created on disk: {:}'.format(name))
            self._data = None
        else:
            self._h5_dataset = None
            self._backing_state = "memory"
            if self.datatype == 'bytes' or self.ragged:
                self._data = RaggedArray(self.shape, 'uint8' if self.datatype == 'bytes' else self.datatype)
            elif self.datatype == 'str':
                self._data = StringArray(self.shape)
            else:
                self._data = np.ndarray(self.shape, self.datatype)
            if VERBOSE:
                print('Dataset Created in Memory: {:}'.format(name))
        
        if data is not None:
            self[...] = data

    def __getitem__(self, key):
        """
        Retrieve property data by index or slice.

        Parameters
        ----------
        key : object
            NumPy-style index, slice, or ``Ellipsis``.

        Returns
        -------
        object
            Requested property data. Return type depends on the property's
            datatype and indexing operation.

        Notes
        -----
        For string datasets stored on disk, values are decoded to Python
        strings on access.
        """
        if not self.in_memory:
            out = self.h5_dataset[key]
            if self.datatype == "str":
                decoder = np.vectorize(
                    lambda x: x.decode() if isinstance(x, (bytes, np.bytes_)) else x,
                    otypes=[object],
                )
                out = decoder(out)
                if out.shape == ():
                    out = out[()]
            return out
        else:
            return self._data[key]

    def __setitem__(self, key, value):
        """
        Assign property data by index or slice.

        Parameters
        ----------
        key : object
            NumPy-style index, slice, or ``Ellipsis``.
        value : array-like
            Data to assign.
        """
        if self._backing_state == "hdf5_external":
            # TODO: This needs to be smarter when transfering between hdf5_external to hdf5_native
            # as reading the whole dataset into memory may exhaust RAM with large datasets.
            self.read_into_memory()

        if not self.in_memory:
            self.h5_dataset[key] = value
        else:
            self._data[key] = value

    def write_to_disk(self, hdf5group: h5.Group):
        """
        Write the property to an HDF5 group.

        Parameters
        ----------
        hdf5group : h5py.Group
            Target group in which the property dataset should be created.

        Notes
        -----
        If the property is already on disk, the method issues a warning and
        does not rewrite the data.
        """
        if not self.in_memory:
            # TODO: This needs to be updated because it could be on disk but on a different
            # external hdf5 file
            warnings.warn('Call to the write_to_disk method is unnecessary for dataset {:} as the data is already on disk.   Data was not written.'.format(self.name))
        else:
            if self.datatype == 'str':
                dtype = h5.special_dtype(vlen=str)
            elif self.datatype == 'bytes':
                dtype = h5.special_dtype(vlen=np.dtype('uint8'))
            elif self.ragged:
                dtype = h5.vlen_dtype(self.datatype)
            else:
                dtype = self.datatype
            self._h5_dataset = hdf5group.create_dataset(self.name,self.shape,dtype)
            self.h5_dataset.attrs['data_type'] = self.datatype
            if VERBOSE:
                print('Dataset Created on disk: {:}'.format(self.name))
            if self.ragged or self.datatype == 'bytes' or self.datatype == 'str':
                for key in np.ndindex(self._h5_dataset.shape):
                    self._h5_dataset[key] = self._data[key]
            else:
                self._h5_dataset[...] = self._data[...]
            self._data = None
            self._backing_state = "hdf5_native"
            
    def read_into_memory(self):
        """
        Load the property fully into memory.

        Notes
        -----
        If the property is already stored in memory, the method issues a
        warning and does nothing.
        """
        if self.in_memory:
            warnings.warn('Call to the read_into_memory method is unnecessary for dataset {:} as the data is already in memory.   Data was not read.'.format(self.name))
            return
        if self.datatype == 'str':
            self._data = StringArray(self.shape)
        elif self.datatype == 'bytes' or self.ragged:
            self._data = RaggedArray(self.shape, 'uint8' if self.datatype == 'bytes' else self.datatype)
        else:
            self._data = np.ndarray(self.shape, self.datatype)
        self._data[...] = self[...]
        self._h5_dataset = None
        if VERBOSE:
            print('Dataset Created in Memory: {:}'.format(self.name))
        self._backing_state = "memory"

    def mark_external_backing(self):
        """
        Mark the property as externally backed.

        Notes
        -----
        This is intended for copied/attached property wrappers that still
        reference an HDF5 source outside their new native context.
        """
        if self._backing_state == "hdf5_native":
            self._backing_state = "hdf5_external"

    def repr(self):
        """
        Return a text representation of the property.

        Returns
        -------
        str
            Human-readable summary including storage mode, name, datatype,
            and shape.
        """
        return "ESCDF Property ({:}, {:}): {:}, {:}, {:}".format(
            "in memory" if self.in_memory else "on disk",
            self.backing_state,
            self.name,
            self.datatype,
            self.shape,
        )
    
    def __repr__(self):
        return self.repr()
    
    @classmethod
    def load(cls, h5_file = None, h5_dataset_path = None, h5_dataset = None, readonly=True):
        """
        Load a property from an HDF5 dataset.

        Parameters
        ----------
        h5_file : str or h5py.File, optional
            Input file path or open HDF5 file handle.
        h5_dataset_path : str, optional
            Dataset path within ``h5_file``.
        h5_dataset : h5py.Dataset, optional
            HDF5 dataset to load directly.
        readonly : bool, optional
            If ``True`` and a file path is provided, open read-only. If
            ``False``, open read/write.

        Returns
        -------
        ESCDFProperty
            Loaded property.

        Raises
        ------
        ValueError
            If insufficient HDF5 location information is provided or if the
            requested object is not an HDF5 dataset.
        """
        if h5_dataset is None:
            if h5_file is None or h5_dataset_path is None:
                raise ValueError('If h5_dataset is not specified, then h5_file and h5_dataset_path must be specified.')
            if isinstance(h5_file,str):
                h5_file = h5.File(h5_file,'r' if readonly else 'r+')
            try:
                h5_dataset = h5_file[h5_dataset_path]
            except KeyError:
                raise ValueError('Invalid Dataset Path Specified.')
            if not isinstance(h5_dataset,h5.Dataset):
                raise ValueError('Object at specified path is not a Dataset.')
        name = h5_dataset.name.split('/')[-1]
        if VERBOSE:
            print('Property Name: {:}'.format(name))
        data_type = h5_dataset.attrs['data_type']
        if isinstance(data_type, (bytes, np.bytes_)):
            data_type = data_type.decode()
        if VERBOSE:
            print('Datatype: {:}'.format(data_type))
        shape = h5_dataset.shape
        if VERBOSE:
            print('Shape: {:}'.format(shape))
        # Need to check if it is ragged or not.
        if (data_type in ['str','bytes']) or (h5.check_dtype(vlen=h5_dataset.dtype) is None):
            ragged = False
        else:
            ragged = True
        if VERBOSE:
            print('Ragged: {:}'.format(ragged))
        self = cls(name,data_type,shape,ragged=ragged,hdf5dataset=h5_dataset)
        return self
    
class RaggedArray(np.ndarray):
    """
    Object-array container for variable-length numeric arrays.

    Parameters
    ----------
    shape : tuple of int
        Outer array shape.
    valid_dtype : str
        Datatype that all stored array elements must safely cast to.

    Notes
    -----
    Each entry in the array stores a one-dimensional NumPy array. Ragged
    arrays are used for ESCDF properties declared with
    ``variable_length``.
    """
    def __new__(cls, shape, valid_dtype, dtype=object, buffer=None, offset=0,
            strides=None, order=None,):
        obj = super(RaggedArray, cls).__new__(cls, shape, dtype, buffer, offset, strides, order)
        obj._valid_dtype = valid_dtype
        for key in np.ndindex(*obj.shape):
            if valid_dtype == 'str':
                super(RaggedArray, obj).__setitem__(key, np.array(''))
            else:
                super(RaggedArray, obj).__setitem__(key, np.zeros(0,dtype=valid_dtype))
        return obj
    
    def __array_finalize__(self,obj):
        if obj is None:
            return
        self._valid_dtype = obj._valid_dtype
    
    def __setitem__(self, index, value):
        """
        Assign one or more ragged array elements.

        Parameters
        ----------
        index : object
            NumPy-style index or slice.
        value : array-like
            Value or values to assign.

        Raises
        ------
        ValueError
            If any assigned value cannot be safely converted to the ragged
            array's declared datatype.
        """
        # First see if when we do the indexing if we get to the lower level
        # arrays or if we instead are still in the object array space
        if index is Ellipsis and self[index].ndim == 0:
            index = ()
        if self[index].dtype == 'object':
            # Still in the object-array space
            if not isinstance(value,np.ndarray):
                # If the item is not a numpy array, we will need to turn it
                # into one.
                try:
                    value = np.asarray(value)
                except ValueError:
                    # In this case, the data was inhomogeneous, so numpy didn't
                    # create an array for us.
                    value = np.asarray(value,dtype='object')
            if value.dtype != 'object':
                # If it is a numpy array with dtype != object, then we will try to
                # create an object array from it with the last dimension inside the
                # object array
                array_shape = value.shape
                value_obj = np.ndarray(array_shape[:-1],dtype='object')
                for key in np.ndindex(*array_shape[:-1]):
                    value_obj[key] = value[key]
            elif value.dtype == 'object':
                # If it is already a numpy array with dtype == object, then it is
                # already in the right format for us to use
                value_obj = np.ndarray(value.shape,dtype='object')
                for key,array in np.ndenumerate(value):
                    value_obj[key] = np.asarray(array)
            # Now we need to go through and check whether or not we can actually
            # convert the types of the arrays
            _check_casting_many_items = np.vectorize(self._check_casting_single_item,otypes=[object])
            casting_success = _check_casting_many_items(value_obj).astype(bool)
            if np.all(casting_success):
                _ravel_many_items = np.vectorize(lambda x: np.ravel(x).astype(self._valid_dtype),otypes=[object])
                assignment = _ravel_many_items(value_obj)
                super(RaggedArray, self).__setitem__(index, assignment)
            else:
                raise ValueError('Could not safely compute convert data to {:}: {:}'.format(self._valid_dtype,
                                                                                            str(value_obj[~casting_success])))
        else:
            # In the lower-level array.  In this case, we should have gotten an
            # array with the right dtype already, but it could also be a scalar
            # object array
            if isinstance(value,np.ndarray) and value.dtype == 'object':
                # Check to make sure it's length 1
                if value.size != 1:
                    raise ValueError('If assigning to a specific item, it must be a standard array or a scalar object array containing a single standard array.')
                value = np.atleast_1d(value)[0]
            value = np.asarray(value)
            if self._check_casting_single_item(value):
                super(RaggedArray,self).__setitem__(index,value.astype(self._valid_dtype))
            else:
                raise ValueError('Could not safely convert data to {:}: {:}'.format(self._valid_dtype,
                                                                                    str(value)))
    
    def _check_casting_single_item(self,item):
        item_array = np.asarray(item)
        item_to_valid = item_array.astype(self._valid_dtype)
        return np.array_equal(item_array,item_to_valid)

class StringArray(np.ndarray):
    """
    Object-array container for string-valued ESCDF properties.

    Parameters
    ----------
    shape : tuple of int
        Array shape.

    Notes
    -----
    Each entry in the array stores one Python string.
    """
    def __new__(cls, shape, buffer=None, offset=0, strides=None, order=None):
        obj = super(StringArray, cls).__new__(
            cls, shape, dtype = object, buffer=buffer, offset = offset,
            strides=strides, order=order)
        for key in np.ndindex(*obj.shape):
            super(StringArray, obj).__setitem__(key,'')
        return obj
    
    def __setitem__(self, index, value):
        """
        Assign one or more string array elements.

        Parameters
        ----------
        index : object
            NumPy-style index or slice.
        value : str or array-like of str
            Value or values to assign.

        Raises
        ------
        ValueError
            If any assigned element is not a string.
        """
        if isinstance(value,str):
            super().__setitem__(index,value)
        else:
            value_array = np.asarray(value,dtype=object)
            if not np.all([isinstance(v,str) for v in value_array.flat]):
                raise ValueError('All elements must be strings.')
            super().__setitem__(index,value)
        