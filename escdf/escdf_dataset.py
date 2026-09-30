# -*- coding: utf-8 -*-
"""
Specification-driven ESCDF dataset implementation.

This module defines :class:`ESCDFDataset`, the primary object used to store
metadata and activity-result datasets in memory and on disk according to
the ESCDF specification files.
"""

from glob import glob
import numpy as np
import h5py as h5
import os
from .escdf_property import ESCDFProperty, RaggedArray
from .valid_names import is_valid_identifier, make_valid_identifier
import warnings
import re

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


def _startup_activities():
    """
    Parse specification files and construct dataset metadata dictionaries.

    Returns
    -------
    specification_data : dict
        Mapping from specification name to parsed specification metadata.
    property_dictionaries : dict
        Mapping from specification name to property-definition dictionaries.

    Notes
    -----
    This function is executed at module import time to populate the global
    specification registries used by :class:`ESCDFDataset`.
    """

    specification_files = glob(
        os.path.join(os.path.dirname(os.path.realpath(__file__)), "specifications/*.txt")
    )
    specification_data = {}
    subclass_property_dictionaries = {}
    property_dictionaries = {}
    specification_classes = {}
    specification_text = {}

    def parse_specification_file(specification_file):
        if VERBOSE:
            print("Parsing {:}".format(specification_file))
        with open(specification_file) as f:
            lines = f.readlines()
        name_part, version_part = lines[0].split("-")
        name = name_part.strip().replace(" ", "_")
        major, minor, hotfix = [int(v) for v in version_part.strip().replace("v", "").split(".")]
        version = (major, minor, hotfix)
        if VERBOSE:
            print("  Name {:}".format(name))
            print("  Version {:}.{:}.{:}".format(major, minor, hotfix))
        # Find the extends line
        extends_line = [
            index for index, line in enumerate(lines) if len(line) >= 8 and "extends:" == line[:8]
        ][0]
        parent_class = lines[extends_line].split(":")[-1].strip()
        if VERBOSE:
            print("  Found Parent Class {:} at line {:}".format(parent_class, extends_line + 1))

        # Find the properties section
        properties_line = [
            index for index, line in enumerate(lines) if line.strip() == "properties"
        ][0]
        if VERBOSE:
            print("  Found Properties Header at Line {:}".format(properties_line + 1))
        properties = []
        for index, line in enumerate(lines[properties_line + 2 :]):
            if line.strip() == "":
                index -= 1
                break
            if VERBOSE:
                print("  Found Property at Line {:}".format(properties_line + index + 2))
            property_info = [value.strip() for value in line.split("-")]
            # If there is a regex, it might have a - in the options, and
            # it might have gotten split into multiple arguments, so let's
            # recompile the arguments
            if len(property_info) > 3:
                property_info[3] = "-".join(property_info[3:])
                property_info = property_info[:4]
            property_name = property_info[0]
            if VERBOSE:
                print("    Name: {:}".format(property_name))
            property_type = property_info[1]
            if property_type not in _acceptable_datatypes:
                raise ValueError(
                    "In file {:} variable {:}, {:} is not a valid type.  Must be one of {:}".format(
                        specification_file, property_name, property_type, _acceptable_datatypes
                    )
                )
            if VERBOSE:
                print("    Type: {:}".format(property_type))
            try:
                if property_info[2] == "scalar":
                    property_shape = ()
                else:
                    property_shape = property_info[2].split(",")
            except IndexError:
                property_shape = ()
            if VERBOSE:
                print("    Shape: {:}".format(property_shape))
            for i in range(len(property_shape)):
                try:
                    property_shape[i] = int(property_shape[i])
                except ValueError:
                    property_shape[i] = property_shape[i].strip()
            try:
                property_options = [v.strip() for v in property_info[3].split(",")]
                # If there is a regex in any of them, we need to join it with
                # the rest because it might have a , in it
                regex_found = np.nonzero(["regex:" in option for option in property_options])[0]
                if len(regex_found) > 0:
                    property_options[regex_found[0]] = ",".join(property_options[regex_found[0] :])
                    property_options = property_options[: regex_found[0] + 1]
            except IndexError:
                property_options = ()
            if VERBOSE:
                print("    Options: {:}".format(property_options))
            properties.append(
                [property_name, property_type, property_shape, tuple(property_options)]
            )

        # Find the enumerations section if it exists
        enumerations_line = [
            index for index, line in enumerate(lines) if line.strip() == "enumerations"
        ]
        enumerations = {}
        if len(enumerations_line) == 0:
            if VERBOSE:
                print("  No Enumerations Found")
            enumerations_line = None
        else:
            enumerations_line = enumerations_line[0]
            if VERBOSE:
                print("  Found Enumerations Header at Line {:}".format(enumerations_line + 1))
            for index, line in enumerate(lines[enumerations_line + 2 :]):
                if line.strip() == "":
                    index -= 1
                    break
                if VERBOSE:
                    print("  Found Enumeration at Line {:}".format(enumerations_line + index + 2))
                enumeration_name, *enumeration_value_strings = [
                    val.strip() for val in line.strip().split("-")
                ]
                enumeration_value_string = '-'.join(enumeration_value_strings)
                enumeration_values = [val.strip() for val in enumeration_value_string.split(",")]
                if VERBOSE:
                    print("    Name: {:}".format(enumeration_name))
                    print("    Values: {:}".format(", ".join(enumeration_values)))
                enumerations[enumeration_name] = enumeration_values

        # Grab the documentation
        documentation = "".join(lines[extends_line + 1 : properties_line])
        if VERBOSE:
            print("  Documentation")
            print(documentation)
        if enumerations_line is None:
            extra_documentation = "".join(lines[properties_line + index + 3 :])
        else:
            extra_documentation = "".join(lines[enumerations_line + index + 3 :])
        if VERBOSE:
            print("  Extra Documentation")
            print(extra_documentation)

        return (
            name,
            documentation,
            extra_documentation,
            parent_class,
            properties,
            enumerations,
            version,
        )

    def create_property_dictionary(properties):
        output_dict = {}
        for property_name, property_type, property_shape, property_options in properties:
            is_option = False
            # Parse the options:
            if property_options is not None:
                # Loop through and see if it's an "or"
                for option in property_options:
                    if "or:" == option[:3]:
                        option_name, option_choice = option.split(":")[1:]
                        if option_name not in output_dict:
                            output_dict[option_name] = {}
                        if option_choice not in output_dict[option_name]:
                            output_dict[option_name][option_choice] = []
                        output_properties = [v for v in property_options if v[:3] != "or:"]
                        output_properties = () if len(output_properties) == 0 else output_properties
                        output_dict[option_name][option_choice].append(
                            [property_name, property_type, property_shape, output_properties]
                        )
                        is_option = True
                        break
                if is_option:
                    continue
            output_dict[property_name] = [
                property_name,
                property_type,
                property_shape,
                property_options,
            ]
        return output_dict

    # Construct the specification information
    for file in specification_files:
        output = parse_specification_file(file)
        specification_data[output[0]] = output
        subclass_property_dictionaries[output[0]] = create_property_dictionary(output[4])
        with open(file) as f:
            specification_text[output[0]] = "".join(f.readlines())
    # Now we need to take the subclass dictionaries and add items from their parents
    full_enums = {}
    for name in subclass_property_dictionaries:
        local_properties = [subclass_property_dictionaries[name]]
        local_enums = [specification_data[name][5]]
        # Get the parent from the data
        parent = specification_data[name][3]
        while parent.lower() != "none":
            local_properties.append(subclass_property_dictionaries[parent])
            local_enums.append(specification_data[parent][5])
            parent = specification_data[parent][3]
        # Flip the order so parents get overwritten
        local_properties.reverse()
        local_enums.reverse()
        property_dictionary = {}
        for dictionary in local_properties:
            property_dictionary.update(dictionary)
        enum_dictionary = {}
        for dictionary in local_enums:
            enum_dictionary.update(dictionary)

        property_dictionaries[name] = property_dictionary
        full_enums[name] = enum_dictionary
    for key in full_enums:
        specification_data[key] = (
            specification_data[key][:5] + (full_enums[key],) + specification_data[key][6:]
        )
    return specification_data, property_dictionaries


_specification_data, _property_dictionaries = _startup_activities()


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

    @property
    def dataset_type(self):
        return self._dataset_type

    @property
    def descriptive_name(self):
        return self._descriptive_name

    @descriptive_name.setter
    def descriptive_name(self, value):
        if not isinstance(value, str):
            raise ValueError("`descriptive_name` must be a string.")
        self._descriptive_name = value

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

    @has_modified_properties.setter
    def has_modified_properties(self, val):
        if not isinstance(val, bool):
            raise ValueError("`has_modified_properties` must be boolean")
        if self.has_modified_properties and not val:
            raise ValueError("`cannot reset modified properties once they have been modified")
        self._has_modified_properties = val

    def __init__(
        self, name, dataset_type, descriptive_name="", replace_invalid_names=False, **kwargs
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
        self._valid_properties = set()
        self._descriptive_name = descriptive_name
        self._has_modified_properties = False
        self._modified_properties = set()
        self._version = _specification_data[dataset_type][6]
        property_dictionary = _property_dictionaries[self._dataset_type]
        for name, props in property_dictionary.items():
            if isinstance(props, dict):
                # This is a property that has options
                for option_name, option_properties in props.items():
                    for option in option_properties:
                        name = option[0]
                        self._valid_properties.add(name)
                        if name in kwargs:
                            setattr(self, name, kwargs[name])
                        else:
                            setattr(self, name, None)
            else:
                self._valid_properties.add(name)
                if name in kwargs:
                    setattr(self, name, kwargs[name])
                else:
                    setattr(self, name, None)

    def __setattr__(self, name, value):
        if name in [
            "_name",
            "_dataset_type",
            "_valid_properties",
            "_descriptive_name",
            "_has_modified_properties",
            "name",
            "dataset_type",
            "descriptive_name",
            "has_modified_properties",
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
            # First let's find all of the options that it could be
            property_dictionary = _property_dictionaries[self.dataset_type]
            property_data = []
            # See if initially we can just find the name in the dictionary as a
            # regular old property
            try:
                this_property_data = property_dictionary[name]
                if not isinstance(this_property_data, dict):
                    property_data.append(this_property_data)
            except KeyError:
                pass
            # If we didn't find it, then we have to look through all of the options
            if len(property_data) == 0:
                for key, prop_data in property_dictionary.items():
                    # See if the key we are looking at is an option
                    if not isinstance(prop_data, dict):
                        continue
                    # Now look through all of the options
                    for option_key, option_data in prop_data.items():
                        for option_prop_data in option_data:
                            if option_prop_data[0] == name:
                                property_data.append(option_prop_data)

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
                this_property = ESCDFDataset.build_property_from_array(name, property_data, value)
            # Now we will check if this is a valid property
            if name not in self._modified_properties:
                if not ESCDFDataset.check_if_property_is_acceptable(property_data, this_property):
                    raise ValueError(
                        "Assigned property is not consistent with the specification for {:}".format(
                            name
                        )
                    )
            super().__setattr__(name, this_property)
        else:
            raise AttributeError(
                "{:} is not a valid property name for Dataset {:} with dataset type {:}".format(
                    name, self.name, self.dataset_type
                )
            )

    @staticmethod
    def build_property_from_array(name, acceptable_specifications, data):
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
        for property_data in acceptable_specifications:
            is_ragged = "variable_length" in property_data[3]
            if is_ragged:
                num_dims = len(property_data[2])
                data_shape = np.array(data, dtype=object).shape
                data_shape = data_shape[:num_dims]
                data_array = np.empty(data_shape, dtype=object)
                data_array[...] = data
                data = data_array
            else:
                data_shape = np.array(data).shape
            sizes = []
            if len(property_data[2]) == 0:
                size_name = "scalar"
            else:
                size_name = ",".join([str(val) for val in property_data[2]])
                for i in range(len(property_data[2])):
                    if isinstance(property_data[2][i], str):
                        try:
                            sizes.append(data_shape[i])
                        except IndexError:
                            if VERBOSE:
                                print("Supplied data did not have enough dimensions.")
                            continue
                    else:
                        sizes.append(property_data[2][i])
            if VERBOSE:
                print("Name: {:}".format(name))
                print("Type: {:}".format(property_data[1]))
                print("Size: {:} ({:})".format(size_name, str(sizes)[1:-1]))
                print("Options: {:}".format(property_data[3]))
            # Create the property
            prop = ESCDFProperty(name, property_data[1], sizes, ragged=is_ragged)
            try:
                prop[...] = data
            except Exception:
                if VERBOSE:
                    print("Could not assign data to property.")
                continue
            # Check and see if we maintained accuracy with the casting
            if is_ragged and (property_data[1] in check_against):
                check_against_array = RaggedArray(sizes, check_against[property_data[1]])
                check_against_array[...] = data
                is_equal = True
                for key, value in np.ndenumerate(check_against_array):
                    if np.any(prop[key] != value):
                        is_equal = False
                        break
            elif property_data[1] in check_against:
                check_against_array = np.ndarray(sizes, dtype=check_against[property_data[1]])
                check_against_array[...] = data
                is_equal = np.all(check_against_array == prop[...])
            else:
                is_equal = True
            if is_equal or len(acceptable_specifications) == 1:
                all_properties.append(prop)
                type_scores.append(preferred_type_order.index(property_data[1]))
        if len(all_properties) < 1:
            raise ValueError(
                "Could not build a Property object {:} to match the requested specifications.".format(
                    name
                )
            )
        min_index = np.argmin(type_scores)
        return all_properties[min_index]

    @staticmethod
    def check_if_property_is_acceptable(acceptable_specifications, this_property: ESCDFProperty):
        isacceptable = False
        for name, datatype, shape, options in acceptable_specifications:
            ragged = "variable_length" in options
            if name != this_property.name:
                continue
            if datatype != this_property.datatype:
                continue
            if ragged != this_property.ragged:
                continue
            # Check the sizes
            if len(shape) != len(this_property.shape):
                continue
            all_sizes_match = True
            for size_desired, size_actual in zip(shape, this_property.shape):
                if isinstance(size_desired, str):
                    continue
                else:
                    if size_desired != size_actual:
                        all_sizes_match = False
                        break
            if not all_sizes_match:
                continue
            # If we get through all of those conditions and we are still matching,
            # then we are good to go.
            isacceptable = True
            break
        return isacceptable

    def set_version(self, major, minor, hotfix):
        self._version = (major, minor, hotfix)

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
            num_nones = len([None for obj in [self, other] if getattr(obj, prop) is None])
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

    def validate(self, property_dictionary=None, hide_issues=False):
        """
        Validate dataset properties against the active specification.

        Parameters
        ----------
        property_dictionary : dict or iterable, optional
            Alternate property definition mapping to validate against. If
            omitted, the dataset's declared specification is used.
        hide_issues : bool, optional
            If ``True``, suppress diagnostic messages describing validation
            failures.

        Returns
        -------
        bool
            ``True`` if the dataset satisfies the specification and
            ``False`` otherwise.

        Notes
        -----
        Validation checks include:

        - presence of required properties
        - datatype consistency
        - shape and dimension consistency
        - enumeration membership
        - regular-expression conformance
        - satisfaction of ``or:`` choice groups

        Datasets containing unknown extra properties loaded from disk are
        considered invalid for normal write operations.
        """
        if property_dictionary is None:
            property_dict_provided = False
            property_dictionary = _property_dictionaries[self.dataset_type]
        else:
            property_dict_provided = True
        specification_data = _specification_data[self.dataset_type]
        # This would be if we passed a list of property specifications
        if not isinstance(property_dictionary, dict):
            temp_property_dictionary = {}
            for prop_data in property_dictionary:
                name = prop_data[0]
                temp_property_dictionary[name] = prop_data
            property_dictionary = temp_property_dictionary
        # This function will go through and make sure everything that needs to
        # be defined is defined, and that all dimensions are consistent.
        variable_dimensions = {}
        missing_properties = []
        missing_choices = []
        bad_types = []
        bad_sizes = []
        invalid_enumerations = []
        invalid_regexes = []
        isvalid = True
        property_names = []
        for name, property_info in property_dictionary.items():
            property_names.append(name)
            if isinstance(property_info, dict):
                valid_choice = self.find_valid_choice_specification(property_info)
                if len(valid_choice) > 1:
                    raise ValueError(f"Multiple valid choices found for choice group {name}: {valid_choice}")
                if len(valid_choice) < 1:
                    missing_choices.append((name, property_info))
                    continue
                # Since we already satified name, type, and size, we should
                # just be able to check that the names are consistent.  We will
                # also not the dimension sizes so we can be sure that they are
                # consistent across multiple properties
                all_property_info = property_info[valid_choice[0]]
                for property_info in all_property_info:
                    property_name = property_info[0]
                    property_size = property_info[2]
                    property_ = getattr(self, property_name)
                    current_property_size = property_.shape
                    for j, (this_size, this_current_size) in enumerate(
                        zip(property_size, current_property_size)
                    ):
                        if isinstance(this_size, str):
                            if this_size not in variable_dimensions:
                                variable_dimensions[this_size] = []
                            variable_dimensions[this_size].append(
                                [property_name, this_current_size]
                            )
                        else:
                            if this_size != this_current_size:
                                bad_sizes.append([property_name, this_current_size, this_size, j])
            else:
                # Go through everything and make sure it makes sense
                property_name, property_type, property_size, property_options = property_info
                # Extract the object
                property_ = getattr(self, property_name)
                # Check if the property is missing
                if (property_ is None) and ("optional" not in property_options):
                    missing_properties.append(property_name)
                    continue
                elif (property_ is None) and ("optional" in property_options):
                    continue
                # Check if the type and size match
                if property_.datatype != property_type:
                    bad_types.append([property_name, property_.datatype, property_type])
                    continue
                current_property_size = property_.shape
                if len(current_property_size) != len(property_size):
                    bad_sizes.append([property_name, -1, -1, -1])
                    continue
                for j, (this_size, this_current_size) in enumerate(
                    zip(property_size, current_property_size)
                ):
                    if isinstance(this_size, str):
                        if this_size not in variable_dimensions:
                            variable_dimensions[this_size] = []
                        variable_dimensions[this_size].append([property_name, this_current_size])
                    else:
                        if this_size != this_current_size:
                            bad_sizes.append([property_name, this_current_size, this_size, j])
                # Check if the enumerations and regexes are satisfied.
                for j, property_option in enumerate(property_options):
                    if property_option[:5] == "enum:":
                        enum_name = property_option.split(":")[1].strip()
                        valid_values = specification_data[5][enum_name]
                        enum_data = property_[...]
                        valid_enums = np.isin(enum_data, valid_values)
                        if not np.all(valid_enums):
                            bad_vals = np.unique(enum_data[~valid_enums])
                            invalid_enumerations.append((property_name, valid_values, bad_vals))
                    if property_option[:6] == "regex:":
                        pattern = property_option.split(":")[1].strip()
                        regex_data = property_[...].flatten()
                        matches = np.array(
                            [
                                bool(
                                    re.match(
                                        pattern,
                                        entry.item() if isinstance(entry, np.ndarray) else entry,
                                    )
                                )
                                for entry in regex_data
                            ]
                        )
                        if not np.all(matches):
                            invalid_regexes.append(
                                (
                                    property_name,
                                    [
                                        val.item() if isinstance(val, np.ndarray) else val
                                        for val in np.unique(regex_data[~matches])
                                    ],
                                )
                            )
        # Now make sure everything is OK
        if len(missing_properties) > 0:
            isvalid = False
            if not hide_issues:
                for missing_property in missing_properties:
                    print("Required Property {:} is missing.".format(missing_property))
        if len(bad_types) > 0:
            isvalid = False
            if not hide_issues:
                for prop_name, prop_format, desired_format in bad_types:
                    print(
                        "Property {:} has type {:} when it should be {:}.".format(
                            prop_name, prop_format, desired_format
                        )
                    )
        if len(bad_sizes) > 0:
            isvalid = False
            if not hide_issues:
                for prop_name, prop_size, desired_size, size_index in bad_sizes:
                    if prop_size == -1 and desired_size == -1 and size_index == -1:
                        print("Property {:} has the wrong number of dimensions.".format(prop_name))
                    else:
                        print(
                            "Property {:} dimension {:} has size {:} when it should be {:}.".format(
                                prop_name, size_index, prop_size, desired_size
                            )
                        )
        if len(missing_choices) > 0:
            isvalid = False
            if not hide_issues:
                for name, property_info in missing_choices:
                    print("No valid choice for {:}:".format(name))
                    for choice_name, choice_properties in property_info.items():
                        print("  For {:} define:".format(choice_name.replace("_", " ")))
                        for (
                            property_name,
                            property_type,
                            property_size,
                            property_options,
                        ) in choice_properties:
                            print(
                                "    {:} ({:}, size: {:})".format(
                                    property_name,
                                    property_type,
                                    (
                                        " x ".join([str(v) for v in property_size])
                                        if len(property_size) > 0
                                        else "scalar"
                                    ),
                                )
                            )
        if len(invalid_enumerations) > 0:
            isvalid = False
            for prop_name, valid_values, bad_values in invalid_enumerations:
                if not hide_issues:
                    print(
                        f'Property {prop_name} has invalid values {", ".join(bad_values)}.  Values must be one of {", ".join(valid_values)}.'
                    )
        if len(invalid_regexes) > 0:
            isvalid = False
            for prop_name, bad_values in invalid_regexes:
                if not hide_issues:
                    print(f'Property {prop_name} has invalid values {", ".join(bad_values)}.')
        # Now go through the variable sized properties and make sure they all
        # match.
        for variable_dimension, variable_dimension_data in variable_dimensions.items():
            lengths = np.array([vdd[1] for vdd in variable_dimension_data])
            if not np.all(lengths == lengths[0]):
                isvalid = False
                if not hide_issues:
                    print(
                        "Dimension {:} is inconsistent across properties.".format(
                            variable_dimension
                        )
                    )
                    for prop_name, dim_length in variable_dimension_data:
                        print("  {:}: {:}".format(prop_name, dim_length))
        if self.has_modified_properties and not property_dict_provided:
            if not hide_issues:
                print("Dataset has modified properties and therefore cannot be valid.")
            isvalid = False
        return isvalid

    def find_valid_choice_specification(self, choice_dictionary):
        """
        Identify valid choice branches for a specification choice group.

        Parameters
        ----------
        choice_dictionary : dict
            Mapping from choice name to property-definition lists.

        Returns
        -------
        list of str
            Names of choice branches that validate successfully for the
            current dataset state.

        Notes
        -----
        Most choice groups are expected to resolve to exactly one valid
        branch. Multiple valid branches are treated as ambiguous.
        """
        valid_choices = []
        for choice, property_dictionary in choice_dictionary.items():
            if VERBOSE:
                print("Choice: {:}".format(choice))
            isvalid = self.validate(property_dictionary, hide_issues=True)
            if isvalid:
                valid_choices.append(choice)
        return valid_choices

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
        if not data_type in _specification_data:
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
            if isinstance(h5_group[name], h5.Dataset) and name not in self._valid_properties
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
        Only properties whose shapes include ``dimension_name`` are
        considered.
        """
        try:
            import pandas as pd
        except ModuleNotFoundError:
            raise ModuleNotFoundError("Pandas must be installed to dump to table.")
        # First need to find all entries with that dimension name
        property_dictionary = _property_dictionaries[self.dataset_type]
        property_dimension_info = []
        for key, property_info in property_dictionary.items():
            if isinstance(property_info, dict):
                for key, option_properties in property_info.items():
                    for property_data in option_properties:
                        property_size = property_data[2]
                        dimension_matches = [name == dimension_name for name in property_size]
                        if any(dimension_matches):
                            property_dimension_info.append(
                                [
                                    property_data[0],
                                    property_data[1],
                                    property_data[2],
                                    property_data[3],
                                    dimension_matches,
                                ]
                            )
            else:
                property_size = property_info[2]
                dimension_matches = [name == dimension_name for name in property_size]
                if any(dimension_matches):
                    property_dimension_info.append(
                        [
                            property_info[0],
                            property_info[1],
                            property_info[2],
                            property_info[3],
                            dimension_matches,
                        ]
                    )
        # Now we need to parse through and create the table
        column_names = []
        data_array = []
        for name, type, dimension_names, options, matches in property_dimension_info:
            try:
                property = getattr(self, name)
            except AttributeError:
                # If the property doesn't exist, we will simply continue
                continue
            if not self.validate([[name, type, dimension_names, options]], True):
                # If the property signature doesn't match we will also continue
                continue
            dimension_match = np.where(matches)[0][0]
            dimension_not_match = [i for i in range(len(dimension_names)) if i != dimension_match]
            data = np.moveaxis(property[:], dimension_match, 0)
            # Now we need to iterate over all dimensions but the first
            indices = np.empty(len(dimension_names), dtype=object)
            for j, dimensions in enumerate(np.ndindex(data.shape[1:])):
                indices[0] = slice(None)
                indices[1:] = dimensions
                data_array.append(data[tuple(indices)])
                index_string = np.empty(len(dimension_names), dtype=object)
                index_string[dimension_match] = ":"
                index_string[dimension_not_match] = indices[1:]
                column_name = name + "[" + ",".join(str(v) for v in index_string) + "]"
                column_names.append(column_name)
                if j >= max_columns:
                    break
        lengths = np.array([len(array) for array in data_array])
        length_values, length_counts = np.unique(lengths, return_counts=True)
        most_common_length = length_values[np.argmax(length_counts)]
        ids_to_keep = lengths == most_common_length
        column_names = np.array(column_names)[ids_to_keep]
        data_array = np.array(
            [row for row, keep in zip(data_array, ids_to_keep) if keep], dtype=object
        )
        return pd.DataFrame(data_array.T, columns=column_names)

    def get_dimension_names(self):
        """
        Return symbolic dimension names used by the dataset specification.

        Returns
        -------
        list of str
            Unique named dimensions referenced by the dataset
            specification.
        """
        dimension_names = set()
        property_dictionary = _property_dictionaries[self.dataset_type]
        for key, property_info in property_dictionary.items():
            if isinstance(property_info, dict):
                for key, option_properties in property_info.items():
                    for property_data in option_properties:
                        property_size = property_data[2]
                        for name in property_size:
                            if isinstance(name, str):
                                dimension_names.add(name)
            else:
                property_size = property_info[2]
                for name in property_size:
                    if isinstance(name, str):
                        dimension_names.add(name)
        return list(dimension_names)

    def get_supertypes(self):
        """
        Return the dataset specification inheritance chain.

        Returns
        -------
        list of str
            Ordered list of this dataset type and its parent types up the
            specification inheritance chain.
        """
        supertype_list = [_specification_data[self.dataset_type][0]]
        parent = _specification_data[self.dataset_type][3]
        while parent.lower() != "none":
            supertype_list.append(_specification_data[parent][0])
            parent = _specification_data[parent][3]
        return supertype_list

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
                raise ValueError("If specified, `datasets` must be a 1D iterable of ESCDF Datasets")
            self._datasets = [value for value in datasets]
            if len(set(self.names)) != len(self.names):
                raise ValueError("All dataset names must be unique.")

    def add_dataset(self, dataset):
        if not isinstance(dataset, ESCDFDataset):
            raise ValueError("Added dataset must be in the form of an ESCDF Dataset")
        if any([ds.name == dataset.name for ds in self.datasets]):
            raise ValueError(
                "An ESCDF Dataset with the name {:} already exists.".format(dataset.name)
            )
        self._datasets.append(dataset)

    def remove_dataset(self, dataset_identifier):
        if isinstance(dataset_identifier, int):
            self._datasets.pop(dataset_identifier)
        elif isinstance(dataset_identifier, str):
            try:
                index = self.names.index(dataset_identifier)
            except ValueError:
                raise ValueError("No dataset with name {:} was found.".format(dataset_identifier))
            self._datasets.pop(index)
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
                raise ValueError("No dataset with name {:} was found.".format(name_or_index))
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
            raise AttributeError("No dataset with name {:} was found.".format(name)) from exc
        return self.datasets[index]

    def repr(self):
        out = "\nESCDF Datasets"
        for dataset in self:
            out += "\n  {:} ({:} {:})".format(dataset.name, dataset.dataset_type, dataset.version)
            out += "\n    {:}".format(", ".join(dataset._valid_properties))
        return out

    def __repr__(self):
        return self.repr()
