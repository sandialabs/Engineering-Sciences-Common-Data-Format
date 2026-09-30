---
downloads:
  - file: geometry_python.ipynb
    title: Python Notebook (.ipynb)
  - file: geometry_python.py
    title: Python Script (.py)
  - file: geometry_matlab.ipynb
    title: Matlab Notebook (.ipynb)
  - file: geometry_matlab.m
    title: Matlab Script (.m)
  - file: geometry.md
    title: Markdown (.md)
---
# Defining Geometry Metadata in ESCDF

For a given test or analysis where responses are measured or computed, we will generally need to know the location at which the response was obtained, as well as the direction in which the response was obtained.  ESCDF uses the `geometry` data type to store this information.  This document will describe how ESCDF handles geometry definitions, as well as how they map to data that might also be stored in a given ESCDF file.

## Preliminary Setup
To start, we will perform preliminary operations needed by our respective programming languages. In Matlab, we clear and reset the workspace. In Python, we import our modules. In both cases, we need to ensure the respective libraries needed are on the Matlab or Python path.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:1
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:1
:remove-output: false
:remove-input: false
```
:::
::::

## Creation of the Source Geometry
A `geometry` object may come from many sources.  Geometry may come from the nodes of a finite element model; it may come from the measurement of sensor locations on a test; it may even come from a bespoke file type such as a Universal File, an STL file, or some other geometric representation.  Since this document cannot hope to cover all possible sources of geometry information, we will assume that we can extract whatever geometry information is needed from that source and package it into simple variables defining the positions of nodes in the geometry in ($x$, $y$, $z$) coordinates, as well as the unit vectors specifying the directions in which responses on that geometry might be obtained.

For this example, we will generate a conical geometry, and assume that measurements are made in local directions that are tangential and perpendicular to the cone's surface.  This first portion of the code will construct the geometry.  We will therefore generate positions corresponding to each node, as well as unit vectors for the local $x$, $y$, and $z$ coordinate system directions.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:2
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:2
:remove-output: false
:remove-input: false
```
:::
::::

To visualize what the geometry looks like, we will plot the different local directions on the geometry on the $xz$ plane and $xy$ plane.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:3
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:3
:remove-output: false
:remove-input: false
```
:::
::::

We can see that the geometry is conical while also noting that the local $x$ directions all point perpendicular from the cone's surface, while the local $y$ directions point circumferentially and the $z$ directions point tangential to the cone's surface in the axial direction.

Note that many geometry sources may not include local coordinate system information.  For example, a finite element model typically assumes all data is in a global coordinate system.  If the case is such that all data is in the global coordinate system for a given activity, then the geometry should be defined such that all `node_x_direction` values are $(1, 0, 0)$, `node_y_direction` values are $(0, 1, 0)$, and `node_z_direction` values are $(0, 0, 1)$, which correspond to the global coordinate system directions.

## Creation of Data

For geometry to be meaningful, we might also wish to create a `data` object and a `mode` object, so we can investigate how we can use the geometry to better understand data and modal information using a geometry.  This data may come from a number of sources, such as a test or a simulation.  Therefore we will assume that the user can extract the data from whatever source the data originates from and can package it into standard arrays.  We will assume, as is typical, that data is measured and modes are fit in the local coordinate system directions.  If the users of the data wish to extract the data into a global coordinate system, they must leverage the geometry information along with the provided data or modal information to reconstruct these global motions.

To make data that is easy to visualize in this document, we will generate rigid motions.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:4
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:4
:remove-output: false
:remove-input: false
```
:::
::::

We can visualize the different measurements we might have made for this response.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:5
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:5
:remove-output: false
:remove-input: false
```
:::
::::

Let's also generate some rigid body mode shapes.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:6
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:6
:remove-output: false
:remove-input: false
```
:::
::::

## Creation of the ESCDF Geometry Object

We will create a dataset with the type `geometry`.  To see the various fields that must be specified, we can use Python's built-in `help` functionality or read the file in Matlab.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:7
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:7
:remove-output: false
:remove-input: false
```
:::
::::

We can then create the geometry dataset specifying `geometry` as the type and giving it a meaningful name and descriptive name.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:8
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:8
:remove-output: false
:remove-input: false
```
:::
::::

We can interrogate this geometry object by typing the variable name `es_geo` into the console window to see the empty structure.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:9
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:9
:remove-output: false
:remove-input: false
```
:::
::::

Let's start populating the fields we have information for.  We know the node identification numbers, positions, and direction vectors, so we will start with those.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:10
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:10
:remove-output: false
:remove-input: false
```
:::
::::

We can use the `validate` method to identify if any required field is still missing.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:11
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:11
:remove-output: false
:remove-input: false
```
:::
::::

We can see that the `validate` method is telling us that the `property_units` are missing.  Basically, our geometry object needs to know if the `node_position` values are defined in meters, inches, or any other unit.  We will specify `'m'` here for units.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:12
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:12
:remove-output: false
:remove-input: false
```
:::
::::

Even though ESCDF may declare our geometry to be valid, there might be some additional content that we wish to add to the file.  For example, we could specify elements or tracelines on the geometry to improve visualizations; otherwise, the geometry is simply a point cloud that can be challenging to interpret.

To demonstrate different types of visualizations, we will use quadrilateral elements for the first few stations, then triangual elements for the next few, then tracelines for the last few stations.  Note that because the cone "wraps around" in the circumferential direction, we will append the starting circumferential station to the end of the array as well.

Because we made the node identification numbers follow a logical pattern, we could easily use them to, for example, create elements and lines on the geometry.  For each element, we need to specify a type and a connectivity array using the node identification numbers.  Each line needs only a connectivity.  We can also specify a color for each item.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:13
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:13
:remove-output: false
:remove-input: false
```
:::
::::

We can then apply these to our geometry dataset.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:14
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:14
:remove-output: false
:remove-input: false
```
:::
::::

We now have our entire geometry completed.  We have defined the node positions, as well as the local orientations associated with measurements at each node.  We have defined the unit system that our geometry is defined in, and we have also added elements and tracelines to aid in visualization.

We will now proceed with constructing our data and shape objects and packaging it all together.

## Creating Data and Shape Objects

We will now create the data and shape objects that reference the geometries.  Again, we can see information about these types by using the Python `help` documentation or by reading the specification files in Matlab.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:15
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:15
:remove-output: false
:remove-input: false
```
:::
::::

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:16
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:16
:remove-output: false
:remove-input: false
```
:::
::::

We will now create the `mode` object, again giving a reasonable name and description.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:17
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:17
:remove-output: false
:remove-input: false
```
:::
::::

We can interrogate this object by typing the variable name `es_mode` in to the command window to identify what we need to define.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:18
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:18
:remove-output: false
:remove-input: false
```
:::
::::

We will then assign the variables we have already developed to this object.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:19
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:19
:remove-output: false
:remove-input: false
```
:::
::::

As always, we should validate to ensure that we have defined everything appropriately.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:20
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:20
:remove-output: false
:remove-input: false
```
:::
::::

We will do similarly with the data object.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:21
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:21
:remove-output: false
:remove-input: false
```
:::
::::

Again we can interrogate this object:

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:22
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:22
:remove-output: false
:remove-input: false
```
:::
::::

And then we can assign to it.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:23
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:23
:remove-output: false
:remove-input: false
```
:::
::::

And again `validate` for good measure:

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:24
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:24
:remove-output: false
:remove-input: false
```
:::
::::

## Packaging Objects into an ESCDF File
In order to save to disk, we need to store the data and metadata into an ESCDF File.  We will create the file, add an activity called `'modal_test'` and put the `data` and `mode` object into that activity.  We will then add the `geometry` metadata and link it to the activity.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:25
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:25
:remove-output: false
:remove-input: false
```
:::
::::

Let's add the data to the activity.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:26
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:26
:remove-output: false
:remove-input: false
```
:::
::::

The geometry is not directly data generated by the activity; rather it is metadata that describes the data from the activity.  We will therefore add the geometry object as metadata to the file and link it to the activity.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:27
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:27
:remove-output: false
:remove-input: false
```
:::
::::

We can then see the entire ESCDF file by typing `es_file` into the console window.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:28
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:28
:remove-output: false
:remove-input: false
```
:::
::::

Now we will write the entire file to disk so it can be shared with other stakeholders for this test.  We will specify the `clobber` argument to be `True` to ensure that any file on disk already is overwritten.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:29
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:29
:remove-output: false
:remove-input: false
```
:::
::::

## Reading and using Geometry from an ESCDF File

After the file is shared, the users of the data may wish to extract the data and the geometry information.  This will be an exercise in bookkeeping.  Any data recieved in ESCDF format may be stored in local or global coordinate system.  **The user should never assume they know how the data is stored, but rather should always reference the linked geometry metadata to identify how the data is defined.**

We will load in the ESCDF file and begin to interrogate it, loading both data and shape results, and then referencing the geometry to transform the data to a global coordinate system for further analysis.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:30
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:30
:remove-output: false
:remove-input: false
```
:::
::::

We can interrogate the loaded file to see the various activity names and data objects.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:31
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:31
:remove-output: false
:remove-input: false
```
:::
::::

We can see there are two data objects in the `modal_test` activity: `rigid_modes` and `rigid_motion`.  We also see a linked metadata `cone_geometry` to this activity.

In the general case where there may be multiple activities and multiple geometries associated with those activities, we would like to specifically define the activity we would like to get data from, and use the metadata links to find the specific metadata associated with that activity.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:32
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:32
:remove-output: false
:remove-input: false
```
:::
::::

While this may be more code than simply writing `activity_geometry = es_file.metadata[0]` (Python) or `activity_geometry = es_file.metadata(1)` (Matlab), it is significantly more robust for general, reusable code.  We can verify that `activity_geometry` now points to our `cone_geometry` object.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:33
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:33
:remove-output: false
:remove-input: false
```
:::
::::

### Using Geometry to Interpret Mode Shapes

We'll start by investigating the modal data.  We can access this by indexing the `activity_data` with the dataset name in Python or calling the `get_data` method of the `activity` object in Matlab.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:34
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:34
:remove-output: false
:remove-input: false
```
:::
::::

Depending on the information desired from the dataset, the actual analysis steps may be different.  For example, to determine if an accelerometer may have saturated during a test, one may be perfectly content to leave all data in its local coordinate system to perform the analysis.  However, other analyses, such as plotting a mode shape, may involve transforming to a global coordinate system for visualization.  We will assume that here.  We wish to construct a `node_displacements` vector that is the same size and ordering as `node_positions`, where each row corresponds to the $(x,y,z)$ displacement of that node.

For this effort, we will need to go through and multiply each shape coefficient by the corresponding unit vector, while also respecting polarity.  For example, the geometry's `node_x_direction` will specify the positive $x$ axis of the local coordinate system, so we will need to multiply that value by `-1` if we have measured, for example, $101X-$.

While there are perhaps more efficient ways to perform this analysis, recognizing, for example, that all of my local $x$-direction measurements are negative, this code will again present the most general, robust form of this analysis, so readers can use it to analyze arbitrary data.

We will start by extracting relevant geometry information and populating an empty array to store the node displacements.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:35
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:35
:remove-output: false
:remove-input: false
```
:::
::::

For documentation's sake, we will walk through the first item manually.  This will allow explanation of each step.  We will then combine this analysis into a `for` loop to automate the extraction of all data from the mode object.

We will start with the first index of the first shape in the shape matrix, and we will extract this shape coefficient from the shape matrix.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:36
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:36
:remove-output: false
:remove-input: false
```
:::
::::

Now we must figure out which degree of freedom this shape coefficient is associated with and how that maps to our `node_displacements` array.  We will interrogate the `dof_name` property to find the channel names.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:37
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:37
:remove-output: false
:remove-input: false
```
:::
::::

We see that the coefficient corresponds to node 101, and this shape is in the negative $x$ direction.  We therefore need to find the `node_x_direction` associated with node 101, as well as the row into the `node_displacements` array.  We should do this in an automated way so we can execute these operations within a future `for` loop.  Though our current measurements do not contain rotations, general measurements might, so we will also put some error checking into our code to tell users that our code won't work with rotations.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:38
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:38
:remove-output: false
:remove-input: false
```
:::
::::

We should then find the correct index into the node array corresponding to this node number.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:39
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:39
:remove-output: false
:remove-input: false
```
:::
::::

Now we can extract the correct local direction for that degree of freedom, which when multiplied by the shape coefficient and polarity will give the correct displacement for that component.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:40
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:40
:remove-output: false
:remove-input: false
```
:::
::::

We can then add this to our `node_displacements` array at the corresponding node index.  Note that we don't simply assign this value to the `node_displacements` variable at the relevant index.  Each local direction will contribute to the global displacement, so we need to add these contributions together rather than overwrite the contributions.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:41
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:41
:remove-output: false
:remove-input: false
```
:::
::::

We can easily package this into a `for` loop that will read all degrees of freedom and shape coefficients.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:42
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:42
:remove-output: false
:remove-input: false
```
:::
::::

Because we constructed the rigid shapes for this example as the displacements in the global $x$, $y$, and $z$ directions, we see that when we reconstruct the global displacements we indeed end up with the vector `[1, 0, 0]` for each node in the model in the first mode shape.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:43
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:43
:remove-output: false
:remove-input: false
```
:::
::::

Note, however, that this has only performed the transformation operation for the first mode in the mode shape matrix.  We may wish to repeat this operation for each mode and construct a complete "global mode shape matrix" that is `num_dofs` $\times$ `num_modes`.  We would then flatten this array and perform the same operation for each mode.  It would generally be useful to package a tool like this into a generic function that can be pointed at any dataset.  In this case we will handle the rotations as well, creating a second shape matrix for rotations if requested.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:44
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:44
:remove-output: false
:remove-input: false
```
:::
::::

Let's call this function on our data to verify that it works correctly.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:45
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:45
:remove-output: false
:remove-input: false
```
:::
::::

We can set up a `table` to present this data in a nice way.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:46
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:46
:remove-output: false
:remove-input: false
```
:::
::::

We can verify that for the global $x$-direction mode, all global $x$ degrees of freedom have a shape coefficient of 1, and likewise for $y$ and $z$.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:47
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:47
:remove-output: false
:remove-input: false
```
:::
::::

Similarly, we can verify that there were no rotations in the model, so the rotation matrix is zeros.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:48
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:48
:remove-output: false
:remove-input: false
```
:::
::::

### Using Geometry to Interpret Data

Now we will interpret the time data, utilizing the geometry to aid in transforming the data to a global coordinate system for visualization.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:49
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:49
:remove-output: false
:remove-input: false
```
:::
::::

Depending on the information desired and the type of data, the actual analysis steps may be different.  For example, to determine if an accelerometer may have saturated during a test, one may be perfectly content to leave all data in its local coordinate system to perform the analysis.  However, other analyses, such as plotting deflections over time, may involve transforming to a global coordinate system for visualization.  We will assume that here.  Additionally, if other types of data were provided instead of a time history, such as a power spectral density or frequency response function, then the steps to transform the coordinate systems of those data may involve multiple transformation steps for the "row" and "column degrees of freedom.

In this case, we wish to construct a `node_displacements` array that is the same size and ordering as `node_positions`, where each row corresponds to the $(x, y, z)$ displacement of that node.

For this effort, we will need to go through and multiply each local displacement by the corresponding unit vector of that degree of freedom, while also respecting polarity.  For example, the geometry’s `node_x_direction` will specify the positive $x$ axis of the local coordinate system, so we will need to multiply that value by -1 if we have measured, for example, $101X−$.

While there are perhaps more efficient ways to perform this analysis, recognizing, for example, that all of the local $x$-direction measurements are negative, this code will again present the most general, robust form of this analysis so readers can use it to analyze arbitrary data.

We will start by extracting relevant geometry information and populating an empty array to store the node displacements.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:50
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:50
:remove-output: false
:remove-input: false
```
:::
::::

For documentation's sake, we will walk through the first item manually.  This will allow for explaination of each step.  We will then combine this analysis into a `for` loop to automate extraction of all data from the `data` object.

Since our time response starts at 0 displacement, we will skip the first time step and start looking at the second time step to demonstrate the process (otherwise we will simply recover an array of zeros, which will not give us the intuition that we have set up the analysis correctly).  We will start with the index of the second time step in the data, and we will extract the displacement value from the ordinate.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:51
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:51
:remove-output: false
:remove-input: false
```
:::
::::

Now we must figure out which degree of freedom this shape coefficient is associated with and how that maps to our `node_displacements` array.  We will interrogate the `channel` property to find the channel names.

Recall that the `channel` shape is actually `num_data` $\times$ `num_channels`, because it can store higher dimensional datasets like frequency response functions or cross-power spectral density functions, which may contain more than one degree of freedom per function; for example each frequency response function has both a response degree of freedom and a reference degree of freedom.  For a time history, there is only one channel associated with each signal, so the `channel` property has a shape of `num_data` $\times$ `1`, but it is still two dimensional and needs two indices.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:52
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:52
:remove-output: false
:remove-input: false
```
:::
::::

We see that the coefficient corresponds to node 101, and this shape is in the negative $x$ direction. We therefore need to find the `node_x_direction` associated with node 101, as well as the row index into the `node_displacements` array. We should do this in an automated way so we can execute these operations within a future for loop. Though our current measurements do not contain rotations, general measurements might, so we will also put some error checking into our code to tell users that our code won’t work with rotations.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:53
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:53
:remove-output: false
:remove-input: false
```
:::
::::

We should then find the correct index into the node array corresponding to this node number.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:54
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:54
:remove-output: false
:remove-input: false
```
:::
::::

Now we can extract the correct local direction for that degree of freedom, which when multiplied by the local displacement and polarity will give the correct displacement for that component.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:55
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:55
:remove-output: false
:remove-input: false
```
:::
::::

We can then add this to our `node_displacements` array at the corresponding node index. Note that we don’t simply assign this value to the `node_displacements` variable at the relevant index. Each local direction will contribute to the global displacement, so we need to add these contributions together rather than overwrite the contributions.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:56
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:56
:remove-output: false
:remove-input: false
```
:::
::::

We can easily package this into a `for` loop that will read all degrees of freedom and local displacement values.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:57
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:57
:remove-output: false
:remove-input: false
```
:::
::::

We constructed the global response with sinusoidal motion in the direction

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:58
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:58
:remove-output: false
:remove-input: false
```
:::
::::

We can therefore see that the displacements we have recovered are some fraction of this value; all displacements are equal to `0.30901699` times the motion direction.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:59
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:59
:remove-output: false
:remove-input: false
```
:::
::::

Note, however, that this has only performed the transformation operation on the second time step of the response.  We would generally wish to repeat this operation for each time step and contruct a complete "global time response" array that is `num_dofs` $\times$ `num_timesteps`.  We would then flatten this array and perform the same operation for each time step.  It would generally be useful to package a tool like this into a generic function that can be pointed at any dataset.  In this case, we will handle the rotations as well, creating a second time history array for rotations if requested.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:60
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:60
:remove-output: false
:remove-input: false
```
:::
::::

Let's call this function on our data to verify that it works correctly.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:61
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:61
:remove-output: false
:remove-input: false
```
:::
::::

We can set up a `table` to present this data in a nice way.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:62
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:62
:remove-output: false
:remove-input: false
```
:::
::::

We can verify that the translation looks rigid.  All $x$-values are identical at each time step, likewise for $y$ and $z$.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:63
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:63
:remove-output: false
:remove-input: false
```
:::
::::

Similarly, we can verify that there were no rotations in the model, so the rotation matrix is zeros.

::::{tab-set}
:::{tab-item} Python
:sync: python
```{embed} #geometry:python:64
:remove-output: false
:remove-input: false
```
:::
:::{tab-item} Matlab
:sync: matlab
```{embed} #geometry:matlab:64
:remove-output: false
:remove-input: false
```
:::
::::

## Summary

The `geometry` data type in ESCDF is instrumental for documenting sensor orientation information.  One should never assume that data is provided in a global coordinate system, rather a `geometry` object should be used to transform local degree-of-freedom information into a global coordinate system if that is what is desired.  By utilizing the encoded channel names, we can map values in the mode shape matrix or the data ordinate to local displacement directions, which when multiplied by the value produce a contribution to the global response.  Summing all of these contributions produces the full global response.
