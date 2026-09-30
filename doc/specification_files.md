# Defining Data and Metadata

To satisfy the "object-oriented" design criteria, the ESCDF must define which properties exist for each type of Metadata and Data. This definition is done through **specification files**. These specification files are human-readable but also machine-parsable. This allows a user to easily define a new type of data or metadata, while also allowing the computer to parse the format to automatically understand how to read data from and write data to that type of object. An example specification file is shown below.

```{code-block}
:caption: Example Specification File
geometry - v0.1.0
-----------------
extends: parameter_set

This group defines a test or analysis geometry, which includes
node positions and local directions associated with each node.

properties
----------
node_id - u8 - num_nodes
node_position - f8 - num_nodes,3
node_x_direction - f8 - num_nodes,3
node_y_direction - f8 - num_nodes,3
node_z_direction - f8 - num_nodes,3
line_connection - u8 - num_lines - variable_length,optional
line_color - u8 - num_lines,3 - optional
element_connection - u8 - num_elements - variable_length,optional
element_color - u8 - num_elements,3 - optional
element_type - str - num_elements - optional, enum:element_types
position_units - str

enumerations
------------
element_types - bar2, bar3, tri3, tri6, quad4, quad8, tet4, tet10, hex8, hex20, wedge6, wedge15

notes
-----
Elements in the geometry are just for visualization, and therefore have no "physics" associated with them.
For example, there is no plane strain vs plane stress quad4, they are both represented by quad4.
```

In the specification file, we define a name of the type of the object (in this case, `geometry`).

Specification files can utilize inheritance to inherit properties from other types of objects (in this case, `extends: parameter_set` means that the geometry type inherits all properties from the `parameter_set` type). After the inheritance line, any documentation that is desirable can be placed.

There is then a block of `properties` that define the properties of the object. Each property has a name, a type (floating point number, integer, string, etc.), a size, and associated options. These are all separated by a hyphen (-).

The name of the property will be the name of the Dataset in the HDF5 file.

The type is a short identifier which specifies the type of the object. For numeric types, these are generally a letter (`u`: unsigned integer >0, `i`: integer, `f`: floating point number, `c`: complex number) and a number of bytes. For example `u1` would be a 1-byte (8-bit) unsigned integer which could store values between 0 and 255. One can also specify `str` (string) properties to store arbitrary text and `bytes` properties to store arbitrary data. Many ESCDF objects use `bytes` properties to store attachments to the dataset. Allowing objects like photographs, test plans, or reports to be stored with the data.

The size is a comma-separated list of names and numbers to specify the dimensionality and size of the property. For example a size of `num_nodes,3` would allow a 2D array of arbitrary number of rows and 3 columns to be stored. Note that if multiple properties utilize the identifier `num_nodes`, than that value must be consistent across all properties of that dataset or the ESCDF will not allow the data to be written to disk.

The last portion of a property definition allow various options to be specified. An `optional` option tells the code that the property can be defined but does not need to be. A `variable_length` option allows a dataset to be "ragged", meaning each row, for example, could have a different number of columns, which is useful for things like connectivity arrays where each element may have a different number of nodes associated with it.  For the case where there are multiple ways to define a property, an or-style identifier is defined. The syntax is `or:<choice_type>:<choice_name>`.   For string fields, the option `enum` allows for only allowing only certain enumerated strings to be accepted.  The option `regex` allows a regular expression to be provided to determine if a string is valid or not.

If any properties have enumerations defined, an additional `enumerations` block provides the valid entries for each enumeration.

Finally, after the property and enumeration definitions, additional documentation can be provided for the object.

When ESCDF is first loaded, it will parse all of the specification files to determine the different valid data types available to be used.  In this way, users do not need to worry about writing code to create readers and writers for new formats.  They need only to create the specification files, and the ESCDF implementation will automatically create the code to handle the new data type.