# -*- coding: utf-8 -*-
"""
Dynamic ESCDF dataset class generation.

This module creates convenience Python classes from the loaded ESCDF
specifications so that datasets can be constructed by specification name
through attribute access on :data:`classes`.
"""

from .escdf_dataset import _property_dictionaries,_specification_data,ESCDFDataset,VERBOSE

specification_classes = {}

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
    Create a Python dataset class from an ESCDF specification.

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
        print('Creating a class for {:}'.format(name))
    global specification_classes
    name, documentation, extra_documentation, parent_class, properties, enumerations, version = _specification_data[name]
    if parent_class.lower() == 'none':
        parent_class = (ESCDFDataset,)
    else:
        if parent_class not in specification_classes:
            create_class_from_specification(parent_class,verbose)
        parent_class = (specification_classes[parent_class],)
    class_dict = {'__init__':get_constructor(name),
                  '__doc__':create_docstring_for_class(name)}
    specification_classes[name] = type(name,parent_class,class_dict)

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
        ``optional``, ``enum:...``, or ``regex:...``.

    Returns
    -------
    str
        Human-readable description of the option.
    """
    if option == 'variable_length':
        return "This property can have variable length.  "
    elif option == 'optional':
        return "This property is optional.  "
    elif 'enum:' in option:
        enum_name = option.split(':')[1].strip()
        return "This property may only be assigned values defined in the enumeration {:}.  ".format(enum_name)
    elif 'regex:' in option:
        pattern = option.split(':')[1]
        return "This property is specified by the regular expression {:}.  ".format(pattern)

def create_docstring_for_class(name):
    """
    Build a generated class docstring from specification metadata.

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
    docstring = _specification_data[name][1].strip()
    docstring += """
    
Properties
----------
    """
    properties = _property_dictionaries[name]
    for property_name,property_data in properties.items():
        if isinstance(property_data,dict):
            docstring += """
            
    {:} can be defined in multiple ways:""".format(property_name)
            for choice_name,choice_data in property_data.items():
                docstring += """
                
        Case "{:}":""".format(choice_name.replace('_',' '))
                for pname,ptype,psize,poptions in choice_data:
                    docstring += """
                    
            {:} -- {:} -- {:} {:}""".format(pname,
                                            type_map[ptype],
                                            '(' + (' x '.join([str(v) for v in psize]) if len(psize) > 0 else 'scalar')+')',
                                            '-- {:}'.format(' '.join([statement_fn(v) for v in poptions])) if len(poptions) > 0 else '')
        else:
            property_name, property_type, property_size, property_options = property_data
            docstring += """
            
    {:} -- {:} -- {:} {:}""".format(property_name,
                                    type_map[property_type],
                                    '(' + (' x '.join([str(v) for v in property_size]) if len(property_size) > 0 else 'scalar')+')',
                                    '-- {:}'.format(' '.join([statement_fn(v) for v in property_options])) if len(property_options) > 0 else '')
    
    docstring += _specification_data[name][2]
    return docstring

for name in _specification_data:
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