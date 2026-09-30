---
downloads:
  - file: flatten_unflatten_python.ipynb
    title: Python Notebook (.ipynb)
  - file: flatten_unflatten_python.py
    title: Python Script (.py)
  - file: flatten_unflatten_matlab.ipynb
    title: Matlab Notebook (.ipynb)
  - file: flatten_unflatten_matlab.m
    title: Matlab Script (.m)
  - file: flatten_unflatten.md
    title: Markdown (.md)
---
# Flatten and Unflatten 3+ Dimensional Data with ESCDF

This document will demonstrate how we can flatten and unflatten 3+ dimensional data (e.g., CPSD and FRF matrices) when reading and writing data with ESCDF.

ESCDF is designed to store all data in the ordinate property of the data object in two-dimensions for code simplicity and robustness. For data that is two-dimensional (e.g., a time history matrix that is $n$ channels $\times$ $m$ time steps), the data can be directly written to and read from ESCDF without any special formatting. However, for data that is three or more dimensions (e.g., a FRF matrix that is $n$ outputs $\times$ $m$ inputs $\times$ $f$ frequencies), extra steps are needed to flatten the data to two-dimensions (e.g., ($n \times m$) rows by $f$ columns for the FRF matrix noted previously) to write to ESCDF and unflatten the two-dimensional data from ESCDF to perform analysis. The Matlab implementation of the ESCDF code has built-in functions, `escdf_dataset.flatten_data()` and `escdf_dataset.unflatten_data()`, to assist the user with performing the flatten/unflatten operations and all associated bookkeeping.  The Python implementation relies on tools like SDynPy to re-order data.

## Preliminary Setup

To start, we will perform preliminary operations needed by our respective programming languages. In Matlab, we clear and reset the workspace. In Python, we import our modules. In both cases, we need to ensure the respective libraries needed are on the Matlab or Python path.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:1
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:1
:remove-output: false
:remove-input: false
```
:::
::::

## Load in Example Data

The next step will be to load in our 3+ dimensional data we want to store in ESCDF. We will assume we have saved the `.mat` file linked above to the same directory as the scripts being run. If that is not the case, the paths will need to be adjusted in the code snippets below accordingly.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:2
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:2
:remove-output: false
:remove-input: false
```
:::
::::

The contents of the loaded data can be verified by typing the variable name LoadData into the command window or console. We see that the data contains the following variables:

  - `ordinate`: An $n$-channel by $n$-channel by $f$-frequencies matrix defining the Cross Power Spectral Density (CPSD) matrix of the model/test response.
  - `abscissa`: An $f$-frequencies by 1 vector defining the frequency vector of each row-column pair in the ordinate data. In this case, and most cases, the same frequency vector describes all row-column pairs of the CPSD data in ordinate.
  - `node`: A $n$-channel by 1 vector defining the node number of each row and column of the CPSD matrix. In the special case of a CPSD matrix, the same nodes define the rows and the columns.
  - `direction`: A $n$-channel by 1 vector defining the node direction of each row and column of the CPSD matrix. In the special case of a CPSD matrix, the same directions define the rows and the columns.

In Python, we can load the data using `loadmat` from `scipy.io`.  This will load the data into a dictionary where the keys are the field name and the values are the arrays.  To make it easier to work with in Python, we will construct a `PowerSpectralDensityArray` object from this data.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:3
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:3
:remove-output: false
:remove-input: false
```
:::
::::

## Initialize an ESCDF Dataset

To start, we will create an empty ESCDF file, which we will then populate with the data from our example file.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:4
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:4
:remove-output: false
:remove-input: false
```
:::
::::

If we type the variable name ESCDF into the command window or console, we will see a representation of this empty ESCDF file. Currently no activities or metadata are present in the file.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:5
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:5
:remove-output: false
:remove-input: false
```
:::
::::

CPSD data, amongst other data types, are stored in ESCDF using a `data` object. The specification file for a data object can be reviewed to understand the properties defining the object and their associated data types, dimensions, and options.  We can see this in Matlab by reading the corresponding `.txt` file for the type (`data.txt`).  In Python, we can look at the docstring of the class using the built-in `help` functionality.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:6
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:6
:remove-output: false
:remove-input: false
```
:::
::::

## Writing Unflattened Data to ESCDF

The ESCDF implementation in Matlab has built-in functions that will flatten and unflatten data for the user. These functions operate on a structure that is populated with fields that mimic the properties of the data object and appear exactly like the structures output from the `dump_to_struct()` function. All the user needs to do is format the shaped, or unshaped, data into the structure expected by the `escdf_dataset.flatten_data()` and `escdf_dataset.unflatten_data()` functions. 

The Python ESCDF implementation does not have such functionality, and instead relies on the reshaping functionality that exists in SDynPy.  In fact, SDynPy has built-in ESCDF functionality in its `escdf` subpackage, so we can simply convert directly from a `PowerSpectralDensityArray` object into an `escdf_dataset` using `sdynpy.escdf.from_data`.

::::{tab-set}
:::{tab-item} Python
:sync: python

The `sdynpy.escdf.from_data` function will automatically handle all of the reshaping necessary to put the data into ESCDF format.

```{embed} #flatten_unflatten:python:7
:remove-output: false
:remove-input: false
```

However, SDynPy does not keep track of all parameters that are required by the ESCDF format.  For example, SDynPy does not handle or track units applied to the system.  We can see using the `validate` method that the object returned from the `sdynpy.escdf.from_data` method does not have any units information specified.

```{embed} #flatten_unflatten:python:8
:remove-output: false
:remove-input: false
```

We can add these units to the dataset manually.

```{embed} #flatten_unflatten:python:9
:remove-output: false
:remove-input: false
```

:::
:::{tab-item} Matlab
:sync: matlab

First, we will initialize the structure that will be populated with unflattened data and input to the `escdf_dataset.flatten_data()` function. This can be done simply by using the `dump_to_struct()` function on an empty data object created with `escdf_dataset()`. The `escdf_dataset()` call is looking for three input arguments, the name of the dataset (which we will define as a dummy value `'temp'` since it is lost when dumped to a structure), the dataset type (which we will specify as `data`), and a descriptive name.

```{embed} #flatten_unflatten:matlab:7
:remove-output: false
:remove-input: false
```

Interrogating the structure by typing `unflattened_data` into the command window or console shows us that the structure of the empty dataset has all the same fields as properties in the data object.

```{embed} #flatten_unflatten:matlab:8
:remove-output: false
:remove-input: false
```

Now we can extract the data from our example file and store it in the `unflattened_data` structure. The frequency (`abscissa`) and CPSD matrices (`ordinate`) are straightforward to pull out because they are already in the format expected by the `escdf_dataset.flatten_data()` function.

```{embed} #flatten_unflatten:matlab:9
:remove-output: false
:remove-input: false
```

The `data_type` field is another easy variable to populate and an example of an enumerated property (signified by the `enum` option inline with the `data_type` property in the data specification file displayed previously). An enumerated field must take on a specific value from a list of possible options that are defined in the enumerations section of the corresponding specification file. Reviewing the list of possible options the `data_type` property can take, we see a value of `'power spectral density'` maps best to our example CPSD data. Thus, we will populate the `data_type` field accordingly.

```{embed} #flatten_unflatten:matlab:10
:remove-output: false
:remove-input: false
```

Ideally, the ordinate and abscissa units would always be provided with its respective data. We find this is not the case in our example file, thus exemplifying one of the main purposes of ESCDF which requires this information be included to allow the user to save the data. For the purposes of this example, the `abscissa_unit` describing the frequency vector is in Hz and the `ordinate_unit` describing the CPSD matrix will be in G$^2$/Hz. In the case where the same unit describes all of the data (e.g., a CPSD computed from accelerometer data all measured in G's), a scalar entry can be defined.

```{embed} #flatten_unflatten:matlab:11
:remove-output: false
:remove-input: false
```

It is entirely possible that the data cannot be described by the same unit (e.g., a CPSD matrix computed from a mix of accelerometer, force, and voltage data). In this case, we are unable to simplify the units to a single vector or scalar and must assign a unit to every entry of `ordinate`, thus requiring the `ordinate_unit` field be defined as a cell array with the same dimensions as `ordinate` excluding the last dimension (which maps to the `abscissa`). Although our example data has the same units for all entries in `ordinate`, we will demonstrate how to define a fully-populated `ordinate_unit` field pretending that the last 12 channels corresponded to a different unit (e.g., Voltage).

```{embed} #flatten_unflatten:matlab:12
:remove-output: false
:remove-input: false
```

Lastly, we need to populate the `channel` field. In the `data` specification we see the `channel` property has a `regex` option, meaning that the strings in it will be validated against that regular expression. The notes provide additional information for those who do not understand regular expressions (which is just about everyone). Essentially, this field must be a positive integer, then a direction specifier, then a polarity specifier. The direction and polarity specifiers are optional; however in our case they should be provided because there are directions and polarities associated with our data.

The channel field for an unflattened data structure is formatted as a nested cell array with an entry containing a list of channel names corresponding to each dimension of ordinate (except the last dimension that maps to the abscissa). For our CPSD example with a 120x120x2001 `ordinate`, we will have a 1x2 cell array (because there are 2 "dimensions" to a CPSD matrix) containing a 120x1 cell that defines the channels along the first dimension (row) in the first entry (because there are 120 rows in the CPSD matrix), and a 120x1 cell that defines the channels along the second dimension (column) in the second entry (because there are 120 columns in the CPSD matrix). For the special case of a CPSD, the list of channels for each dimension will be the exact same. However, this will not always be true, such as the case where we have an FRF with size $n$ outputs $\times$ $m$ inputs $\times$ $f$ frequencies. In the $n \times m \times f$ FRF case, the channel field would be a 1x2 cell array containing a $n$x1 cell that defines the channels along the first dimension (outputs, rows) in the first entry, and a $m$x1 cell that defines the channels along the second dimension (inputs, columns) in the second entry.

The following code extracts the node, direction, and polarity information from the example file and formats it to be compatible with ESCDF.

```{embed} #flatten_unflatten:matlab:13
:remove-output: false
:remove-input: false
```

Now, the unflattened data has been properly formatted into a structure compatible with the `escdf_dataset.flatten_data()` function. We will use this function to create a flattened data structure that can be directly used to create the ESCDF `data` object.

```{embed} #flatten_unflatten:matlab:14
:remove-output: false
:remove-input: false
```

Interrogating the structure by typing `flattened_data` into the command window or console shows us the contents of the flattened data structure and how ESCDF has done all the reshaping and bookkeeping for us on the `ordinate`, `abscissa`, `ordinate_unit`, `abscissa_unit`, and `channel` fields. We see the following changes:

  - ordinate: Has been reshaped from a three-dimensional $n \times n \times f$ (120x120x2001) to a two-dimensional $(n \times n) \times f$ (14400x2001) matrix.
  - ordinate_unit: Has been reshaped from a two-dimensional $n \times n$ (120x120) to a one-dimensional (as much as Matlab supports it) $(n \times n) \times 1$ (14400x1) matrix.
  - abscissa: Remains unchanged as an $f \times 1$ (2001x1) vector because a single $f \times 1$ vector was defined in the `unflattened_data` structure and could be used to describe all entries of `ordinate`. If a different `abscissa` was needed to define all entries of `ordinate`, it would have been reshaped in the same manner as `ordinate`.
  - abscissa_unit: Remains unchanged as an 1x1 cell because a single unit was defined in the `unflattened_data` structure and could be used to describe all entries of `abscissa`. If a different unit was needed to define all entries of `abscissa`, it would have been reshaped in the same manner as `ordinate_unit`.
  - channel: Has been reshaped from a 1x2 cell array with $n \times 1$ (120x1) cell entries to a $(n \times n) \times 2$ (14400x2) cell array that describes the channel pairings of each data entry in ordinate.

```{embed} #flatten_unflatten:matlab:15
:remove-output: false
:remove-input: false
```

Now, the ESCDF `data` object can be created from the flattened data structure using the `escdf_dataset.build_from_struct()` function. The `escdf_dataset.build_from_struct()` function expects a string defining the name of the resultant data object as the first input argument, which we will call `'cpsd'`, and the ESCDF-formatted structure as the second input argument.

```{embed} #flatten_unflatten:matlab:16
:remove-output: false
:remove-input: false
```

:::
::::


Interrogating the object by typing `data` into the command window or console shows us the structure of the populated dataset.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:17
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:17
:remove-output: false
:remove-input: false
```
:::
::::

## Packaging it All Together

Now that we have the dataset created, we need to put them into our ESCDF file. We do that through the ESCDF object we initially created.

To add data, we must first add the activity that generated the data. We do this with `add_activity`. This function requires a short name to use as reference, a more descriptive name, and a date and time that the activity was performed. We can pull the activity date from the last modified date in the source file. ESCDF accepts dates as native datetime objects.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:18
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:18
:remove-output: false
:remove-input: false
```
:::
::::

At this point, our ESCDF object now shows the activity we created. However, it contains no data.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:19
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:19
:remove-output: false
:remove-input: false
```
:::
::::

Finally we can add the data to the activity using `add_data_to_activity()`. The `add_data_to_activity()` method expects a string defining the name of the activity to add data to and the data object to add to the activity.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:20
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:20
:remove-output: false
:remove-input: false
```
:::
::::

`escdf_file` should now reflect the addition of the data.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:21
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:21
:remove-output: false
:remove-input: false
```
:::
::::

Now that we have a complete dataset in `escdf_file` containing our flattened CPSD data, we can write this dataset to a file using the `write_to_disk` method of the `escdf_file` object. The current convention is to keep the `h5` file extension for ESCDF files, signifying that they are indeed HDF5 files. This can signify to users without the ESCDF toolset that they could open the file with standard HDF5 readers and parse the relevant data and metadata if they had to. If the optional clobber argument is set to `true`; then if the file exists, it will be overwritten.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:22
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:22
:remove-output: false
:remove-input: false
```
:::
::::

## Reading Flattened Data from ESCDF

Now, lets read in the ESCDF file created with flattened data and unpackage and unflatten the data for use in analysis. In this example, the ESCDF file contains the CPSD data in two dimensions ($n$ outputs $\times$ $n$ outputs) $\times$ $f$ frequencies (14400 x 2001). We want to extract and unflatten the data back to its three-dimensional form, $n$ outputs $\times$ $n$ outputs $\times$ $f$ frequencies (120x120x2001), to be compatible with standard matrix operations and support analyses.

We will start by reading in the ESCDF file we just created containing the flattened CPSD data.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:23
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:23
:remove-output: false
:remove-input: false
```
:::
::::

If we type in `escdf_file` into the command window or console, we will see the familiar structure of our ESCDF file.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:24
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:24
:remove-output: false
:remove-input: false
```
:::
::::

In general, ESCDF files may contain many activities, each which link to many sets of data and many pieces of metadata. They may also have different reference names assigned to them. Therefore, when writing general functions to read in arbitrary ESCDF files, one should always reference the relevant activity or data, and use the links in ESCDF to pull the correct metadata associated with that activity, using the type of data or metadata to perform selection, rather than the name which might change from file to file.

In this case, the activity we want is the first (and only) activity in the file. Similarly, the data we want is the first (and only) dataset in the activity. So, we will extract the desired data by indexing as such.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:25
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:25
:remove-output: false
:remove-input: false
```
:::
::::

As noted above, the Matlab ESCDF implementation has built-in functions that will unflatten data for the user by operating on a structure that is populated with fields that mimic the properties of the data object and appear exactly like the structures output from `dump_to_struct()`. Thus, all we need to do is run the `dump_to_struct()` function on the data object containing the flattened data to format it appropriately for the `escdf_dataset.unflatten_data()` function.

The Python implementation is designed to integrate tightly with SDynPy, so we can simply convert our dataset to a SDynPy object using `sdynpy.escdf.to_data`.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #flatten_unflatten:python:26
:remove-output: false
:remove-input: false
```

Currently, the CPSD object is in a "flattened" state, which we can see by interrogating it in the command window.

```{embed} #flatten_unflatten:python:27
:remove-output: false
:remove-input: false
```

To get the CPSD object back into a matrix form suitable for analysis, we could call its `reshape_to_matrix()` method, which reshapes the `PowerSpectralDensityArray` based on its coordinate names.

```{embed} #flatten_unflatten:python:28
:remove-output: false
:remove-input: false
```

:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #flatten_unflatten:matlab:26
:remove-output: false
:remove-input: false
```

Interrogating the structure output by typing `flattened_data` into the command window or console shows us the contents of the flattened data structure.

```{embed} #flatten_unflatten:matlab:27
:remove-output: false
:remove-input: false
```

Now, the flattened data has been properly formatted into a structure compatible with the `escdf_dataset.unflatten_data()` function. Will will use this function to create an unflattened data structure that can then be used to support engineering analysis on the three-dimensional CPSD data.

```{embed} #flatten_unflatten:matlab:28
:remove-output: false
:remove-input: false
```

Interrogating the structure by typing UnflattenedData into the command window or console shows us the contents of the unflattened data structure and how ESCDF has done all the reshaping and bookkeeping for us on the ordinate, abscissa, ordinate_unit, abscissa_unit, and channel fields. We see the following changes:

  - `ordinate`: Has been reshaped from a two-dimensional $(n \times n) \times f$ (14400x2001) to a three-dimensional $n \times n \times f$ (120x120x2001) matrix
  - `ordinate_unit`: Has been reshaped from a one-dimensional (as much as Matlab can support) $(n \times n)$ (14400x1) to a two-dimensional $n \times n$ (120x120) matrix.
  - `abscissa`: Remains unchanged as an $f \times 1$ (2001x1) vector because a single $f \times 1$ vector was defined in the `flattened_data` structure and could be used to describe all entries of `ordinate`. If a different `abscissa` was needed to define all entries of `ordinate`, it would have been reshaped in the same manner as `ordinate`.
  - `abscissa_unit`: Remains unchanged as an 1x1 cell because a single unit was defined in the `flattened_data` structure and could be used to describe all entries of `abscissa`. If a different unit was needed to define all entries of `abscissa`, it would have been reshaped in the same manner as `ordinate_unit`.
  - `channel`: Has been reshaped from a $(n \times n) \times 2$ (14400x2) cell array that describes the channel pairings of each flattened data entry to a 1x2 cell array with $n \times 1$ (120x1) cell entries describing the channels associated with each dimension of the unflattened ordinate.

```{embed} #flatten_unflatten:matlab:29
:remove-output: false
:remove-input: false
```

:::
::::


At this point, we now have the data formatted as needed to perform standard matrix operations and general engineering analysis. 

Note that while there were perhaps many operations in this document most of them were simply translations (taking one field from one data source and putting it into ESCDF) and can easily be generalized to other data sources.