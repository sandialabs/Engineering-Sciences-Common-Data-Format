# -*- coding: utf-8 -*-
"""
Specification-driven ESCDF dataset implementation.

This module defines :class:`ESCDFDataset`, the primary object used to store
metadata and activity-result datasets in memory and on disk according to
the ESCDF specification files.
"""

import warnings
import re
import os

import numpy as np
import h5py as h5

from .escdf_property import ESCDFProperty, RaggedArray
from .valid_names import is_valid_identifier, make_valid_identifier
from .model import SpecificationRegistry
from .model.validation import validate_dataset_against_resolved_specification

VERBOSE = False

_acceptable_datatypes = [
    "i1",
    "i2",
    "i4",
    "i8",
    "f4",
    "f8",
    "c8",
    "c16",
    "u1",
    "u2",
    "u4",
    "u8",
    "str",
    "bytes",
]


_specification_registry = None


def _build_default_specification_registry():
    """
    Build the default canonical specification registry.

    Returns
    -------
    SpecificationRegistry
        Registry loaded from the packaged ESCDF specification directory.
    """
    return SpecificationRegistry.build_default_registry()


def _get_specification_registry(force_reload: bool = False):
    """
    Return the cached canonical specification registry.

    Parameters
    ----------
    force_reload : bool, optional
        If ``True``, rebuild the registry from the packaged ESCDF
        specifications even if a cached registry already exists.

    Returns
    -------
    SpecificationRegistry
        Cached canonical specification registry.
    """
    global _specification_registry

    if (_specification_registry is None) or force_reload:
        _specification_registry = _build_default_specification_registry()

    return _specification_registry


def load_specification_directory(directory: str):
    """
    Append specifications from an additional directory to the cached
    specification registry.

    Parameters
    ----------
    directory : str
        Directory containing additional ESCDF specification files.

    Notes
    -----
    This function is primarily intended for tests or specialized
    workflows that need to extend the active specification set without
    modifying the packaged ESCDF specifications.
    """
    registry = _get_specification_registry(force_reload=False)
    registry.load_from_directory(directory)


def reload_specification_cache():
    """
    Reset specification state back to the packaged ESCDF defaults.

    Notes
    -----
    This discards any appended specification directories and rebuilds the
    cached canonical specification registry and legacy compatibility views
    from the packaged ESCDF specification directory only.
    """
    _get_specification_registry(force_reload=True)


def _get_resolved_specification(dataset_type: str):
    """
    Return the cached resolved specification for a dataset type.

    Parameters
    ----------
    dataset_type : str
        Specification name.

    Returns
    -------
    ResolvedSpecification
        Effective resolved specification.
    """
    registry = _get_specification_registry(force_reload=False)
    return registry.resolve(dataset_type)


def _get_candidate_property_definitions(dataset_type: str, property_name: str):
    """
    Return canonical property-definition candidates for a property name.

    Parameters
    ----------
    dataset_type : str
        Dataset specification type.
    property_name : str
        Property name to resolve.

    Returns
    -------
    list of PropertyDefinition
        Canonical candidate property definitions for the requested name.
    """
    resolved_specification = _get_resolved_specification(dataset_type)
    return list(resolved_specification.properties_by_name.get(property_name, []))


# Initialize packaged defaults at import time to preserve existing behavior.
_get_specification_registry(force_reload=True)


# Now define the main class
class ESCDFDataset:
    """
    Specification-driven ESCDF dataset.

    An ``ESCDFDataset`` represents one typed dataset defined by an ESCDF
    specification. Dataset properties are created dynamically from the
    parsed specification files and validated against the declared data
    types, shapes, optionality rules, enumerations, and choice groups.

    Parameters
    ----------
    name : str
        Short dataset identifier used as the on-disk group name.
    dataset_type : str
        Name of the ESCDF specification used to define the dataset.
    descriptive_name : str, optional
        Human-readable dataset description.
    replace_invalid_names : bool, optional
        If ``True``, invalid dataset names are repaired automatically.
        If ``False``, invalid names raise an exception.
    **kwargs
        Initial property values keyed by property name.

    Notes
    -----
    Most user-facing metadata and result datasets are instances of this
    class. The allowed properties are determined entirely by the selected
    specification.

    Datasets inheriting from ``parameter_set`` may also support ``notes``,
    ``attachments``, and ``attachment_names``.

    See Also
    --------
    ESCDFProperty
    ESCDF
    ESCDFActivity
    """

    @property
    def name(self):
        return self._name

    @name.setter
    def name(self, value):
        if not isinstance(value, str):
            raise TypeError("`name` must be a string.")
        if not is_valid_identifier(value):
            raise ValueError(f'"{value}" is not a valid identifier.')
        self._name = value
        self._has_pending_changes = True

    @property
    def dataset_type(self):
        return self._dataset_type

    @property
    def descriptive_name(self):
        return self._descriptive_name

    @descriptive_name.setter
    def descriptive_name(self, value):
        if not isinstance(value, str):
            raise TypeError("`descriptive_name` must be a string.")
        self._descriptive_name = value
        self._has_pending_changes = True

    @property
    def version(self):
        return "v" + ".".join(str(v) for v in self._version)

    @property
    def version_numbers(self):
        return self._version

    @property
    def property_names(self):
        return sorted(self._valid_properties)

    @property
    def has_modified_properties(self):
        return self._has_modified_properties

    @property
    def has_pending_changes(self):
        return self._has_pending_changes

    @property
    def backing_state(self):
        return self._backing_state

    @has_modified_properties.setter
    def has_modified_properties(self, val):
        if not isinstance(val, bool):
            raise TypeError("`has_modified_properties` must be boolean")
        if self.has_modified_properties and not val:
            raise ValueError(
                "`cannot reset modified properties once they have been modified"
            )
        self._has_modified_properties = val

    def __init__(
        self,
        name,
        dataset_type,
        descriptive_name="",
        replace_invalid_names=False,
        **kwargs,
    ):
        """
        Initialize a specification-driven ESCDF dataset.

        Parameters
        ----------
        name : str
            Short dataset identifier used as the on-disk group name.
        dataset_type : str
            Name of the ESCDF specification used to define the dataset.
        descriptive_name : str, optional
            Human-readable dataset description.
        replace_invalid_names : bool, optional
            If ``True``, invalid dataset names are repaired automatically.
        **kwargs
            Initial property values keyed by property name.

        Raises
        ------
        ValueError
            If the dataset name is invalid and ``replace_invalid_names`` is
            ``False``.
        """
        name_valid = is_valid_identifier(name)
        if (not name_valid) and replace_invalid_names:
            name = make_valid_identifier(name, "dataset_")
        elif (not name_valid) and (not replace_invalid_names):
            raise ValueError(
                f"Invalid name {name}.  Names must start with a letter and consist of only letters, numbers, and underscores."
            )
        self._name = name
        self._dataset_type = dataset_type
        self._descriptive_name = descriptive_name
        self._has_modified_properties = False
        self._modified_properties = set()
        self._has_pending_changes = False
        self._backing_state = "memory"

        resolved_specification = _get_resolved_specification(self.dataset_type)

        self._version = resolved_specification.version.as_tuple()
        self._valid_properties = set(resolved_specification.property_names)

        for property_name in sorted(self._valid_properties):
            if property_name in kwargs:
                setattr(self, property_name, kwargs[property_name])
            else:
                setattr(self, property_name, None)

    def __setattr__(self, name, value):
        if name in [
            "_name",
            "_dataset_type",
            "_valid_properties",
            "_descriptive_name",
            "_has_modified_properties",
            "_has_pending_changes",
            "_backing_state",
            "name",
            "dataset_type",
            "descriptive_name",
            "has_modified_properties",
            "has_pending_changes",
            "backing_state",
            "_modified_properties",
            "property_names",
            "_version",
        ]:
            super().__setattr__(name, value)
        elif name in self._valid_properties:
            if VERBOSE:
                print("Setting Property {:}".format(name))
            # Here we need to construct a property object if necessary
            # Otherwise we need to do some checks to make sure the property
            # object is the right size/shape.
            # Things that could be assigned to a property:
            #  1. An already existing property object
            #  2. A file path or dataset ID that we can load into a
            #     property object
            #  3. An numpy array or list that we need to
            #     turn into a property object.
            #  4. None to say we aren't using that property.
            # There are also two things that could happen with the name.
            #  1. It could be a name that always exists or is optional.  In
            #     this case, the correct specification should be trivial to
            #     find.
            #  2. It could be a name that conditionally exists as part of a
            #     choice specified by the "or" option in the specification
            #     file.  In this case, we will need to dig through the
            #     options to find the correct specification (or a matching
            #     one).
            # This is case 4 above to say we aren't using that property
            if value is None:
                super().__setattr__(name, value)
                return
            # Find all canonical property-definition candidates for this
            # property name.
            property_definitions = _get_candidate_property_definitions(
                self.dataset_type, name
            )

            if len(property_definitions) == 0:
                # Allow assignment for already-known modified/extra
                # properties, which are intentionally outside the canonical
                # specification.
                if name not in self._modified_properties:
                    raise AttributeError(
                        "{:} is not a valid property name for Dataset {:} with dataset type {:}".format(
                            name, self.name, self.dataset_type
                        )
                    )

            # Now we need to construct an ESCDF property from the data
            if isinstance(value, ESCDFProperty):
                # If it is already a ESCDF Property, then we just need to check
                # it's name, format, and shape.
                this_property = value
            elif isinstance(value, h5.Dataset):
                # Otherwise, this could be an HDF5 dataset that we are trying to
                # load
                this_property = ESCDFProperty.load(h5_dataset=value)
            else:
                # Otherwise, this is just a regular old array that we have to
                # build into a property from scratch
                this_property = ESCDFDataset.build_property_from_array(
                    name, property_definitions, value
                )
            # Now we will check if this is a valid property
            if name not in self._modified_properties:
                if not ESCDFDataset.check_if_property_is_acceptable(
                    property_definitions, this_property
                ):
                    raise ValueError(
                        "Assigned property is not consistent with the specification for {:}".format(
                            name
                        )
                    )
            super().__setattr__(name, this_property)
            self._has_pending_changes = True
        else:
            raise AttributeError(
                "{:} is not a valid property name for Dataset {:} with dataset type {:}".format(
                    name, self.name, self.dataset_type
                )
            )

    @staticmethod
    def build_property_from_array(name, acceptable_property_definitions, data):
        """
        Build an ESCDFProperty from array-like input using canonical
        property-definition candidates.

        Parameters
        ----------
        name : str
            Property name.
        acceptable_property_definitions : list of PropertyDefinition
            Canonical candidate property definitions for this property.
        data : array-like
            Input data to convert into an ESCDF property.

        Returns
        -------
        ESCDFProperty
            Property object matching the best acceptable canonical
            definition.

        Raises
        ------
        ValueError
            If no acceptable property can be constructed from the supplied
            data.
        """
        # We will go through and basically build a property for each option and
        # score which fits the best.
        preferred_type_order = [
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
        ]
        check_against = {
            "u1": "u8",
            "u2": "u8",
            "u4": "u8",
            "u8": "u8",
            "i1": "i8",
            "i2": "i8",
            "i4": "i8",
            "i8": "i8",
            "f4": "c16",
            "f8": "c16",
            "c8": "c16",
            "c16": "c16",
        }
        all_properties = []
        # We will prefer smaller datatypes
        type_scores = []
        for property_definition in acceptable_property_definitions:
            is_ragged = property_definition.variable_length
            if is_ragged:
                num_dims = len(property_definition.shape)
                data_shape = np.array(data, dtype=object).shape
                data_shape = data_shape[:num_dims]
                data_array = np.empty(data_shape, dtype=object)
                data_array[...] = data
                candidate_data = data_array
            else:
                candidate_data = data
                data_shape = np.array(candidate_data).shape

            sizes = []
            if len(property_definition.shape) == 0:
                size_name = "scalar"
            else:
                size_name = ",".join(
                    [str(dim.value) for dim in property_definition.shape]
                )
                for i, dim in enumerate(property_definition.shape):
                    if dim.is_symbolic:
                        try:
                            sizes.append(data_shape[i])
                        except IndexError:
                            if VERBOSE:
                                print("Supplied data did not have enough dimensions.")
                            continue
                    else:
                        sizes.append(dim.value)
            if VERBOSE:
                print("Name: {:}".format(name))
                print("Type: {:}".format(property_definition.datatype))
                print("Size: {:} ({:})".format(size_name, str(sizes)[1:-1]))
                print(
                    "Options: {:}".format(
                        {
                            "optional": property_definition.optional,
                            "variable_length": property_definition.variable_length,
                            "enumeration_name": property_definition.enumeration_name,
                            "regex": property_definition.regex,
                            "choice_group": property_definition.choice_group,
                            "choice_branch": property_definition.choice_branch,
                            "value_constraints": property_definition.value_constraints,
                        }
                    )
                )
            # Create the property
            prop = ESCDFProperty(
                name, property_definition.datatype, sizes, ragged=is_ragged
            )
            try:
                prop[...] = candidate_data
            except Exception:
                if VERBOSE:
                    print("Could not assign data to property.")
                continue
            # Check and see if we maintained accuracy with the casting
            if is_ragged and (property_definition.datatype in check_against):
                check_against_array = RaggedArray(
                    sizes, check_against[property_definition.datatype]
                )
                check_against_array[...] = candidate_data
                is_equal = True
                for key, value in np.ndenumerate(check_against_array):
                    if np.any(prop[key] != value):
                        is_equal = False
                        break
            elif property_definition.datatype in check_against:
                check_against_array = np.ndarray(
                    sizes, dtype=check_against[property_definition.datatype]
                )
                check_against_array[...] = candidate_data
                is_equal = np.all(check_against_array == prop[...])
            else:
                is_equal = True

            if is_equal or len(acceptable_property_definitions) == 1:
                all_properties.append(prop)
                type_scores.append(
                    preferred_type_order.index(property_definition.datatype)
                )
        if len(all_properties) < 1:
            raise ValueError(
                "Could not build a Property object {:} to match the requested specifications.".format(
                    name
                )
            )
        min_index = np.argmin(type_scores)
        return all_properties[min_index]

    @staticmethod
    def check_if_property_is_acceptable(
        acceptable_property_definitions,
        this_property: ESCDFProperty,
    ):
        """
        Return whether a property matches one of the acceptable canonical
        property definitions.

        Parameters
        ----------
        acceptable_property_definitions : list of PropertyDefinition
            Canonical candidate property definitions.
        this_property : ESCDFProperty
            Property to check.

        Returns
        -------
        bool
            ``True`` if the property matches at least one acceptable
            canonical property definition.
        """
        isacceptable = False
        for property_definition in acceptable_property_definitions:
            if property_definition.name != this_property.name:
                continue
            if property_definition.datatype != this_property.datatype:
                continue
            if property_definition.variable_length != this_property.ragged:
                continue

            shape = property_definition.shape
            if len(shape) != len(this_property.shape):
                continue

            all_sizes_match = True
            for dimension_definition, size_actual in zip(shape, this_property.shape):
                if dimension_definition.is_symbolic:
                    continue
                if dimension_definition.value != size_actual:
                    all_sizes_match = False
                    break

            if not all_sizes_match:
                continue

            isacceptable = True
            break

        return isacceptable

    def set_version(self, major, minor, hotfix):
        self._version = (major, minor, hotfix)
        self._has_pending_changes = True

    def repr(self):
        property_list = sorted(self._valid_properties)
        longest_length = max([len(v) for v in property_list], default=0)
        string_format = "{:>" + str(longest_length + 4) + "}"
        out = "\n  ESCDF Dataset: {:} ({:} {:})\n\n  Properties:\n".format(
            self.name, self.dataset_type, "v" + ".".join(str(v) for v in self._version)
        )
        for prop_name in property_list:
            prop = getattr(self, prop_name)
            if prop is None:
                out += "\n{:}:".format(string_format.format(prop_name))
            else:
                if prop.in_memory:
                    memory_string = "in memory"
                else:
                    memory_string = "on disk"
                repr_part = prop.repr().split(prop_name + ", ")[-1]
                out += "\n{:}: {:}, {:}".format(
                    string_format.format(prop_name), repr_part, memory_string
                )
        try:
            notes = self.notes[...]
            out += "\n\n  Notes:\n    " + "\n    ".join(notes)
        except (TypeError, AttributeError):
            pass
        try:
            attachments = self.attachment_names[...]
            out += "\n\n  Attachments:\n    " + "\n    ".join(attachments)
        except (TypeError, AttributeError):
            pass
        return out

    def __repr__(self):
        return self.repr()

    def __eq__(self, other):
        if not isinstance(other, ESCDFDataset):
            return False
        if self.dataset_type != other.dataset_type:
            return False
        if self._valid_properties != other._valid_properties:
            return False
        for prop in self._valid_properties:
            # Check if they are both None
            num_nones = len(
                [None for obj in [self, other] if getattr(obj, prop) is None]
            )
            if num_nones == 2:  # They are both nones
                continue  # They are therefore equal
            elif num_nones == 1:  # One is none and the other isn't
                return False  # They are therefore not equal
            # They are both not nones so check equality
            self_array = getattr(self, prop)[...]
            other_array = getattr(other, prop)[...]
            if self_array.dtype == object:
                if self_array.shape != other_array.shape:
                    return False
                for index in np.ndindex(self_array.shape):
                    if not np.array_equal(self_array[index], other_array[index]):
                        return False
            else:
                if not np.array_equal(self_array, other_array):
                    return False
        return True

    def validate(self, hide_issues=False, report=False):
        """
        Validate dataset properties against the active specification.

        Parameters
        ----------
        hide_issues : bool, optional
            If ``True``, suppress diagnostic messages describing validation
            failures.
        report : bool, optional
            If ``True``, return a structured validation report instead of a
            boolean validity flag.

        Returns
        -------
        bool or ValidationReport
            ``True`` if the dataset satisfies the specification and
            ``False`` otherwise when ``report`` is ``False``. If
            ``report`` is ``True``, return a structured validation report.
        """
        resolved_specification = _get_resolved_specification(self.dataset_type)
        validation_report = validate_dataset_against_resolved_specification(
            self,
            resolved_specification,
            hide_issues=hide_issues,
        )
        if report:
            return validation_report
        return validation_report.is_valid

    @classmethod
    def load(cls, h5_file=None, h5_group_path=None, h5_group=None, readonly=True):
        """
        Load a dataset from an HDF5 group.

        Parameters
        ----------
        h5_file : str or h5py.File, optional
            Input file path or open HDF5 file handle.
        h5_group_path : str, optional
            Group path within ``h5_file``.
        h5_group : h5py.Group, optional
            HDF5 group to load directly. If provided, ``h5_file`` and
            ``h5_group_path`` are ignored.
        readonly : bool, optional
            If ``True`` and a file path is provided, open the file in
            read-only mode. If ``False``, open read/write.

        Returns
        -------
        ESCDFDataset
            Loaded dataset.

        Notes
        -----
        Unknown dataset types are mapped to the ``unknown`` specification.
        Extra on-disk properties that are not defined in the specification
        are preserved and marked as modified.
        """
        if h5_group is None:
            if h5_file is None or h5_group_path is None:
                raise ValueError(
                    "If h5_group is not specified, then h5_file and h5_group_path must be specified."
                )
            if isinstance(h5_file, str):
                h5_file = h5.File(h5_file, "r" if readonly else "r+")
            try:
                h5_group = h5_file[h5_group_path]
            except KeyError:
                raise ValueError("Invalid Group Path Specified.")
            if not isinstance(h5_group, h5.Group):
                raise ValueError("Object at specified path is not a Group.")
        name = h5_group.name.split("/")[-1]
        if VERBOSE:
            print("Dataset Name: {:}".format(name))
        data_type = h5_group.attrs["_specification_name"]
        if isinstance(data_type, (bytes, np.bytes_)):
            data_type = data_type.decode()
        try:
            descriptive_name = h5_group.attrs["_descriptive_name"]
            if isinstance(descriptive_name, (bytes, np.bytes_)):
                descriptive_name = descriptive_name.decode()
        except KeyError:
            descriptive_name = name
        if VERBOSE:
            print("Type of the Group: {:}".format(data_type))
        # Make sure that it is a known type
        registry = _get_specification_registry(force_reload=False)
        if not registry.has_local(data_type):
            warnings.warn(
                f"Dataset {name} has an undefined type {data_type} and will be written to an unknown dataset."
            )
            original_data_type = data_type
            data_type = "unknown"
        else:
            original_data_type = None
        # Get version number
        try:
            version_numbers = tuple(h5_group.attrs["_version"])
            if len(version_numbers) != 3:
                raise ValueError("Malformed version attribute")
        except (KeyError, ValueError, TypeError):
            warnings.warn(
                f"Unable to read valid version numbers for dataset {name} with type {data_type}."
            )
            version_numbers = (0, 0, 0)
        self = cls(name, data_type, descriptive_name, replace_invalid_names=True)
        # Check version numbers
        if not version_numbers == self.version_numbers:
            warnings.warn(
                "Version number of {:} dataset in loaded file (v{:}) is not the version in the current ESCDF implementation (v{:})".format(
                    data_type,
                    ".".join(str(v) for v in version_numbers),
                    ".".join(str(v) for v in self.version_numbers),
                )
            )
        if self.istype("unknown"):
            self.original_type_name = original_data_type
        for property_name in self._valid_properties:
            try:
                h5_dataset = h5_group[property_name]
            except KeyError:
                continue
            setattr(self, property_name, h5_dataset)
        extra_datasets = [
            name
            for name in h5_group.keys()
            if isinstance(h5_group[name], h5.Dataset)
            and name not in self._valid_properties
        ]
        for extra_dataset in extra_datasets:
            warnings.warn(
                f"When loading dataset {name}, an unknown extra property {extra_dataset} was found that was not defined in the specification."
            )
            self.has_modified_properties = True
            h5_dataset = h5_group[extra_dataset]
            self._valid_properties.add(extra_dataset)
            self._modified_properties.add(extra_dataset)
            setattr(self, extra_dataset, h5_dataset)

        self._backing_state = "hdf5_native"
        self._has_pending_changes = False
        return self

    def write_to_disk(self, h5_group: h5.Group):
        """
        Write the dataset to an HDF5 group.

        Parameters
        ----------
        h5_group : h5py.Group
            Target HDF5 group representing this dataset.

        Raises
        ------
        ValueError
            If the dataset fails validation and therefore cannot be written.

        Notes
        -----
        Dataset properties are written as datasets within ``h5_group``.
        The group also receives specification metadata attributes such as
        ``_specification_name``, ``_descriptive_name``, and ``_version``.
        """
        isvalid = self.validate()
        if not isvalid:
            raise ValueError(
                "Incomplete ESCDF Dataset {:} ({:}) cannot be written to a file.".format(
                    self.name, self.dataset_type
                )
            )
        for name in self._valid_properties:
            property_ = getattr(self, name)
            if property_ is None:
                continue
            if not property_.in_memory:
                warnings.warn(
                    "Overwriting HDF5 datasets is not currently implemented, so on-disk datasets are currently read into memory then rewritten to disk.  This could have implications for large datasets that will not fit into memory."
                )
                property_.read_into_memory()
            property_.write_to_disk(h5_group)
        h5_group.attrs["_specification_name"] = self.dataset_type
        h5_group.attrs["_descriptive_name"] = self.descriptive_name
        h5_group.attrs["_version"] = self._version

        self._backing_state = "hdf5_native"
        self._has_pending_changes = False

    def read_into_memory(self):
        """
        Load all dataset properties into memory.

        Notes
        -----
        Properties already stored in memory are left unchanged. Properties
        currently backed by HDF5 datasets are read fully into in-memory
        property objects.
        """
        for name in self._valid_properties:
            property_ = getattr(self, name)
            if property_ is not None:
                property_.read_into_memory()
        self._backing_state = "memory"

    def set_attachments(self, filenames):
        """
        Read files from disk and store them as dataset attachments.

        Parameters
        ----------
        filenames : str or iterable of str
            File path or collection of file paths to attach.

        Notes
        -----
        Only the basename of each file is stored in ``attachment_names``.
        File contents are stored in ``attachments`` as byte arrays.
        """
        if isinstance(filenames, str):
            filenames = [filenames]
        attachments = np.empty(len(filenames), dtype=object)
        attachment_names = []
        for i, attachment_file_path in enumerate(filenames):
            attachment_name = os.path.split(attachment_file_path)[-1]
            with open(attachment_file_path, "rb") as f:
                attachment = np.frombuffer(f.read(), dtype="uint8")
            attachment_names.append(attachment_name)
            attachments[i] = attachment
        self.attachment_names = attachment_names
        self.attachments = np.array(attachments, dtype=object)

    def list_attachment_names(self):
        """
        Return the names of all stored attachments.

        Returns
        -------
        list of str
            Attachment names in stored order.

        Raises
        ------
        AttributeError
            If the dataset does not contain attachment properties.
        """
        try:
            attachment_names = self.attachment_names[...]
        except AttributeError:
            raise AttributeError("No attachments found in this dataset.")
        return list(attachment_names)

    def get_attachment_index(self, filename):
        """
        Return the index of a stored attachment by name.

        Parameters
        ----------
        filename : str
            Attachment filename to look up.

        Returns
        -------
        int
            Zero-based attachment index.

        Raises
        ------
        AttributeError
            If the dataset does not contain attachment properties.
        ValueError
            If the requested attachment name is not present.
        """
        names = self.list_attachment_names()
        try:
            return names.index(filename)
        except ValueError as exc:
            raise ValueError(
                f'No attachment named "{filename}" found in this dataset.'
            ) from exc

    def dump_attachment_to_disk(self, filename, file_path="."):
        """
        Write a single stored attachment to disk.

        Parameters
        ----------
        filename : str
            Attachment filename to extract.
        file_path : str, optional
            Output directory.

        Raises
        ------
        AttributeError
            If the dataset does not contain attachment properties.
        ValueError
            If the requested attachment name is not present.
        """
        index = self.get_attachment_index(filename)
        try:
            attachment_names = self.attachment_names[...]
            attachments = self.attachments[...]
        except AttributeError:
            raise AttributeError("No attachments found in this dataset.")

        attachment_name = attachment_names[index]
        attachment = attachments[index]

        with open(os.path.join(file_path, attachment_name), "wb") as f:
            f.write(attachment.tobytes())

    def dump_attachments_to_disk(self, file_path="."):
        """
        Write stored attachments to files on disk.

        Parameters
        ----------
        file_path : str, optional
            Output directory for extracted attachments.

        Raises
        ------
        AttributeError
            If the dataset does not contain attachment properties.
        """
        try:
            attachment_names = self.attachment_names[...]
            attachments = self.attachments[...]
        except AttributeError:
            raise AttributeError("No attachments found in this dataset.")
        for attachment, attachment_name in zip(attachments, attachment_names):
            with open(os.path.join(file_path, attachment_name), "wb") as f:
                f.write(attachment.tobytes())

    def dump_to_table(self, dimension_name, max_columns=10):
        """
        Convert selected dataset properties to a tabular representation.

        Parameters
        ----------
        dimension_name : str
            Dimension name used to identify which properties should be
            expanded into table columns.
        max_columns : int, optional
            Maximum number of derived columns to include from any one
            property.

        Returns
        -------
        pandas.DataFrame
            Tabular representation of selected dataset properties.

        Raises
        ------
        ModuleNotFoundError
            If pandas is not installed.

        Notes
        -----
        This method is intended as a convenience for inspection and export.
        Only properties whose effective canonical property definitions
        include ``dimension_name`` are considered.
        """
        try:
            import pandas as pd
        except ModuleNotFoundError:
            raise ModuleNotFoundError("Pandas must be installed to dump to table.")

        resolved_specification = _get_resolved_specification(self.dataset_type)

        # Build a mapping from property name to the unique compatible
        # canonical definition that includes the requested dimension.
        compatible_dimension_definitions = {}

        for (
            property_name,
            property_definitions,
        ) in resolved_specification.properties_by_name.items():
            property_value = getattr(self, property_name)
            if property_value is None:
                continue

            matching_definitions = []
            for property_definition in property_definitions:
                shape = property_definition.shape
                dimension_matches = [
                    dim.is_symbolic and (dim.value == dimension_name) for dim in shape
                ]
                if not any(dimension_matches):
                    continue

                if not ESCDFDataset.check_if_property_is_acceptable(
                    [property_definition], property_value
                ):
                    continue

                matching_definitions.append((property_definition, dimension_matches))

            if len(matching_definitions) == 1:
                compatible_dimension_definitions[property_name] = matching_definitions[
                    0
                ]

        column_names = []
        data_array = []

        for property_name, (
            property_definition,
            dimension_matches,
        ) in compatible_dimension_definitions.items():
            property_value = getattr(self, property_name)
            data = np.moveaxis(property_value[:], np.where(dimension_matches)[0][0], 0)

            matched_dimension_index = int(np.where(dimension_matches)[0][0])
            unmatched_dimension_indices = [
                i
                for i in range(len(property_definition.shape))
                if i != matched_dimension_index
            ]

            # Iterate over all remaining dimensions after moving the matched
            # dimension to the front.
            for j, dimensions in enumerate(np.ndindex(data.shape[1:])):
                indices = np.empty(len(property_definition.shape), dtype=object)
                indices[0] = slice(None)
                indices[1:] = dimensions

                data_array.append(data[tuple(indices)])

                index_string = np.empty(len(property_definition.shape), dtype=object)
                index_string[matched_dimension_index] = ":"
                index_string[unmatched_dimension_indices] = indices[1:]
                column_name = (
                    property_name + "[" + ",".join(str(v) for v in index_string) + "]"
                )
                column_names.append(column_name)

                if j >= max_columns:
                    break

        if len(data_array) == 0:
            return pd.DataFrame()

        lengths = np.array([len(array) for array in data_array])
        length_values, length_counts = np.unique(lengths, return_counts=True)
        most_common_length = length_values[np.argmax(length_counts)]

        ids_to_keep = lengths == most_common_length
        column_names = np.array(column_names)[ids_to_keep]
        data_array = np.array(
            [row for row, keep in zip(data_array, ids_to_keep) if keep],
            dtype=object,
        )

        table = pd.DataFrame(data_array.T, columns=column_names)

        for column_name in table.columns:
            column = table[column_name]
            try:
                table[column_name] = pd.to_numeric(column)
            except (ValueError, TypeError):
                pass

        return table

    def get_dimension_names(self):
        """
        Return symbolic dimension names used by the dataset specification.

        Returns
        -------
        list of str
            Unique named dimensions referenced by the effective dataset
            specification.
        """
        resolved_specification = _get_resolved_specification(self.dataset_type)
        return list(resolved_specification.dimension_names)

    def get_supertypes(self):
        """
        Return the dataset specification inheritance chain.

        Returns
        -------
        list of str
            Ordered list of specification names in canonical inheritance
            application order, beginning with the root ancestor and ending
            with this dataset type.
        """
        resolved_specification = _get_resolved_specification(self.dataset_type)
        return list(resolved_specification.ancestry)

    def istype(self, type):
        """
        Check whether the dataset inherits from a specification type.

        Parameters
        ----------
        type : str
            Specification type name to test.

        Returns
        -------
        bool
            ``True`` if the dataset is of the requested type or inherits
            from it, otherwise ``False``.
        """
        parent_list = self.get_supertypes()
        if type in parent_list:
            return True
        else:
            return False


class ESCDFDatasetArray:
    """
    Collection of :class:`ESCDFDataset` objects with name-based lookup.

    Parameters
    ----------
    datasets : iterable of ESCDFDataset, optional
        Initial datasets to include in the collection.

    Notes
    -----
    Dataset names within the collection must be unique.
    """

    __slots__ = ["_datasets"]

    @property
    def datasets(self):
        return [val for val in self._datasets]

    @property
    def names(self):
        return [val.name for val in self._datasets]

    def __init__(self, datasets=None):
        if datasets is None:
            self._datasets = []
        else:
            # Data must be an iterable of escdf objects
            try:
                if not all([isinstance(value, ESCDFDataset) for value in datasets]):
                    raise ValueError(
                        "If specified, `datasets` must be a 1D iterable of ESCDF Datasets"
                    )
            except (IndexError, TypeError, KeyError):
                raise ValueError(
                    "If specified, `datasets` must be a 1D iterable of ESCDF Datasets"
                )
            self._datasets = [value for value in datasets]
            if len(set(self.names)) != len(self.names):
                raise ValueError("All dataset names must be unique.")

    def add_dataset(self, dataset):
        if not isinstance(dataset, ESCDFDataset):
            raise ValueError("Added dataset must be in the form of an ESCDF Dataset")
        if any([ds.name == dataset.name for ds in self.datasets]):
            raise ValueError(
                "An ESCDF Dataset with the name {:} already exists.".format(
                    dataset.name
                )
            )
        self._datasets.append(dataset)

    def remove_dataset(self, dataset_identifier):
        if isinstance(dataset_identifier, int):
            return self._datasets.pop(dataset_identifier)
        elif isinstance(dataset_identifier, str):
            try:
                index = self.names.index(dataset_identifier)
            except ValueError:
                raise ValueError(
                    "No dataset with name {:} was found.".format(dataset_identifier)
                )
            return self._datasets.pop(index)
        else:
            raise ValueError(
                "Dataset identifier must be either an int or a string specifying the dataset name"
            )

    def __iter__(self):
        return iter(self.datasets)

    def __getitem__(self, name_or_index):
        if isinstance(name_or_index, int):
            return self.datasets[name_or_index]
        elif isinstance(name_or_index, str):
            try:
                index = self.names.index(name_or_index)
            except ValueError:
                raise ValueError(
                    "No dataset with name {:} was found.".format(name_or_index)
                )
            return self.datasets[index]
        elif isinstance(name_or_index, slice) or isinstance(name_or_index, Ellipsis):
            return ESCDFDatasetArray(self.datasets[name_or_index])
        else:
            raise ValueError(
                "Indexing operation must supply an index, a name in the form of a string, or a slice"
            )

    def __getattr__(self, name):
        try:
            index = self.names.index(name)
        except ValueError as exc:
            raise AttributeError(
                "No dataset with name {:} was found.".format(name)
            ) from exc
        return self.datasets[index]

    def repr(self):
        out = "\nESCDF Datasets"
        for dataset in self:
            out += "\n  {:} ({:} {:})".format(
                dataset.name, dataset.dataset_type, dataset.version
            )
            out += "\n    {:}".format(", ".join(dataset._valid_properties))
        return out

    def __repr__(self):
        return self.repr()

    @staticmethod
    def reload_specification_cache():
        """
        Reset specification state back to the packaged ESCDF defaults.

        Notes
        -----
        This discards any appended specification directories and rebuilds
        the cached canonical specification registry from the packaged
        ESCDF specification directory only.
        """
        reload_specification_cache()

    @staticmethod
    def load_specification_directory(directory: str):
        """
        Append specifications from an additional directory to the cached
        specification registry.

        Parameters
        ----------
        directory : str
            Directory containing additional ESCDF specification files.
        """
        load_specification_directory(directory)
