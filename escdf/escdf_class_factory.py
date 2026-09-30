# -*- coding: utf-8 -*-
"""
Dynamic ESCDF dataset class generation.

This module creates convenience Python classes from the loaded ESCDF
specifications so that datasets can be constructed by specification name
through attribute access on :data:`classes`.
"""

from .escdf_dataset import ESCDFDataset, VERBOSE, _get_specification_registry

specification_classes = {}

def _get_local_specification(name):
    """
    Return the local canonical specification for a given dataset type.

    Parameters
    ----------
    name : str
        Specification name.

    Returns
    -------
    Specification
        Local canonical specification.
    """
    registry = _get_specification_registry(force_reload=False)
    return registry.get_local(name)


def _get_resolved_specification(name):
    """
    Return the resolved canonical specification for a given dataset type.

    Parameters
    ----------
    name : str
        Specification name.

    Returns
    -------
    ResolvedSpecification
        Resolved canonical specification.
    """
    registry = _get_specification_registry(force_reload=False)
    return registry.resolve(name)


def get_constructor(dataset_type):
    """
    Create a dataset-type-specific constructor.

    Parameters
    ----------
    dataset_type : str
        ESCDF specification name associated with the generated class.

    Returns
    -------
    callable
        Constructor function that initializes an :class:`ESCDFDataset`
        using the supplied specification name.
    """
    def constructor(self,name,descriptive_name='',**kwargs):
        ESCDFDataset.__init__(self,name,dataset_type,descriptive_name,**kwargs)
    return constructor

def create_class_from_specification(name, verbose=False):
    """
    Create a Python dataset class from a canonical ESCDF specification.

    Parameters
    ----------
    name : str
        Specification name used to define the generated class.
    verbose : bool, optional
        If ``True``, print status messages during class creation.

    Notes
    -----
    Generated classes inherit from either :class:`ESCDFDataset` or another
    previously generated class corresponding to the specification's parent
    type.
    """
    if verbose:
        print(f"Creating a class for {name}")

    global specification_classes

    local_spec = _get_local_specification(name)
    parent_name = local_spec.extends

    if parent_name is None:
        parent_class = (ESCDFDataset,)
    else:
        if parent_name not in specification_classes:
            create_class_from_specification(parent_name, verbose)
        parent_class = (specification_classes[parent_name],)

    class_dict = {
        "__init__": get_constructor(name),
        "__doc__": create_docstring_for_class(name),
    }
    specification_classes[name] = type(name, parent_class, class_dict)


type_map = {'bytes':'bytes',
            'str':'string',
            }
for b in [1,2,4,8,16]:
    for t,n in [('u','unsigned integer'),
                ('i','integer'),
                ('f','floating-point number'),
                ('c','complex floating-point number')]:
        type_map['{:}{:}'.format(t,b)] = '{:}-bit {:}'.format(b*8,n)


def statement_fn(option):
    """
    Convert a specification option token into descriptive text.

    Parameters
    ----------
    option : str
        Specification option token such as ``variable_length``,
        ``optional``, ``enum:...``, ``regex:...``, or a value-constraint
        token.

    Returns
    -------
    str
        Human-readable description of the option.
    """
    if option == "variable_length":
        return "This property can have variable length.  "
    elif option == "optional":
        return "This property is optional.  "
    elif "enum:" in option:
        enum_name = option.split(":")[1].strip()
        return (
            f"This property may only be assigned values defined in the enumeration {enum_name}.  "
        )
    elif "regex:" in option:
        pattern = option.split(":", 1)[1]
        return f"This property is specified by the regular expression {pattern}.  "
    elif option == "positive":
        return "All values must be positive.  "
    elif option == "nonnegative":
        return "All values must be nonnegative.  "
    elif option == "finite":
        return "All values must be finite.  "
    elif option == "increasing":
        return "Values must be monotonically increasing.  "
    elif option == "strictly_increasing":
        return "Values must be strictly increasing.  "
    elif option == "unique":
        return "All values must be unique.  "
    elif option == "nonempty":
        return "Values must be nonempty.  "
    return ""


def property_definition_to_doc_options(
    property_definition,
    *,
    include_choice_token=False,
):
    """
    Convert a canonical property definition into documentation option
    tokens compatible with statement_fn().

    Parameters
    ----------
    property_definition : PropertyDefinition
        Canonical property definition.
    include_choice_token : bool, optional
        If ``True``, include an ``or:group:branch`` token when the property
        belongs to a choice group.

    Returns
    -------
    list of str
        Option tokens suitable for documentation generation.
    """
    options = []

    if property_definition.optional:
        options.append("optional")

    if property_definition.variable_length:
        options.append("variable_length")

    if property_definition.enumeration_name is not None:
        options.append(f"enum:{property_definition.enumeration_name}")

    if property_definition.regex is not None:
        options.append(f"regex:{property_definition.regex}")

    for constraint_name in property_definition.value_constraints:
        options.append(constraint_name)

    if include_choice_token and property_definition.choice_group is not None:
        options.append(f"or:{property_definition.choice_group}:{property_definition.choice_branch}")

    return options


def create_docstring_for_class(name):
    """
    Build a generated class docstring from canonical specification data.

    Parameters
    ----------
    name : str
        Specification name.

    Returns
    -------
    str
        Generated docstring describing the dataset type, its properties,
        and specification-defined options.
    """
    local_spec = _get_local_specification(name)
    resolved_spec = _get_resolved_specification(name)

    docstring = local_spec.documentation.strip()
    docstring += """

Properties
----------
    """

    # Document standalone properties first.
    for property_definition in resolved_spec.standalone_properties:
        property_name = property_definition.name
        property_type = property_definition.datatype
        property_shape = tuple(dim.value for dim in property_definition.shape)
        property_options = property_definition_to_doc_options(property_definition)

        docstring += """

    {:} -- {:} -- {:} {:}""".format(
            property_name,
            type_map[property_type],
            "("
            + (
                " x ".join([str(v) for v in property_shape])
                if len(property_shape) > 0
                else "scalar"
            )
            + ")",
            "-- {:}".format(" ".join([statement_fn(v) for v in property_options]))
            if len(property_options) > 0
            else "",
        )

    # Then document choice groups.
    for choice_group_name, branch_map in resolved_spec.choice_groups.items():
        docstring += """

    {:} can be defined in multiple ways:""".format(choice_group_name)

        for branch_name, branch_properties in branch_map.items():
            docstring += """

        Case "{:}":""".format(branch_name.replace("_", " "))

            for property_definition in branch_properties:
                property_name = property_definition.name
                property_type = property_definition.datatype
                property_shape = tuple(dim.value for dim in property_definition.shape)
                property_options = property_definition_to_doc_options(
                    property_definition,
                    include_choice_token=False,
                )

                docstring += """

            {:} -- {:} -- {:} {:}""".format(
                    property_name,
                    type_map[property_type],
                    "("
                    + (
                        " x ".join([str(v) for v in property_shape])
                        if len(property_shape) > 0
                        else "scalar"
                    )
                    + ")",
                    "-- {:}".format(" ".join([statement_fn(v) for v in property_options]))
                    if len(property_options) > 0
                    else "",
                )

    if local_spec.notes:
        docstring += local_spec.notes

    return docstring


for name in _get_specification_registry(force_reload=False).list_local_names():
    if name not in specification_classes:
        create_class_from_specification(name, verbose=VERBOSE)


class DatasetClasses:
    """
    Namespace exposing generated ESCDF dataset classes as attributes.

    Notes
    -----
    An instance of this class is available as :data:`classes`. Each loaded
    ESCDF specification becomes an attribute whose value is a dynamically
    generated Python class.
    """
    def __init__(self):
        for name,dataset_class in specification_classes.items():
            setattr(self,name,dataset_class)

classes = DatasetClasses()