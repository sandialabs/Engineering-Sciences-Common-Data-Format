#!/usr/bin/env python
# coding: utf-8

# # Flatten and Unflatten 3+ Dimensional Data with ESCDF
# 
# This document will demonstrate how we can flatten and unflatten 3+ dimensional data (e.g., CPSD and FRF matrices) when reading and writing data with ESCDF.
# 
# ESCDF is designed to store all data in the ordinate property of the data object in two-dimensions for code simplicity and robustness. For data that is two-dimensional (e.g., a time history matrix that is $n$ channels $\times$ $m$ time steps), the data can be directly written to and read from ESCDF without any special formatting. However, for data that is three or more dimensions (e.g., a FRF matrix that is $n$ outputs $\times$ $m$ inputs $\times$ $f$ frequencies), extra steps are needed to flatten the data to two-dimensions (e.g., ($n \times m$) rows by $f$ columns for the FRF matrix noted previously) to write to ESCDF and unflatten the two-dimensional data from ESCDF to perform analysis. The Matlab implementation of the ESCDF code has built-in functions, `escdf_dataset.flatten_data()` and `escdf_dataset.unflatten_data()`, to assist the user with performing the flatten/unflatten operations and all associated bookkeeping.  The Python implementation relies on tools like SDynPy to re-order data.
# 
# ## Preliminary Setup
# 
# To start, we will perform preliminary operations needed by our respective programming languages. In Matlab, we clear and reset the workspace. In Python, we import our modules. In both cases, we need to ensure the respective libraries needed are on the Matlab or Python path.

# In[1]:


# Flatten and Unflatten 3+ Dimensional Data with ESCDF

# Import required packages
import sdynpy as sdpy  # SDynPy for it's exodus writers
import numpy as np  # NumPy for it's array capabilities

# If ESCDF is not on your path, uncomment the following two lines and point the
# sys.path.append function to the ESCDF folder.

#import sys
#sys.path.append('/path/to/escdf')

import escdf  # escdf required to read and write ESCDF files


# ## Load in Example Data
# 
# The next step will be to load in our 3+ dimensional data we want to store in ESCDF. We will assume we have saved the `.mat` file linked above to the same directory as the scripts being run. If that is not the case, the paths will need to be adjusted in the code snippets below accordingly.

# In[2]:


from scipy.io import loadmat

load_data = loadmat('Example_CPSD_Data.mat')


# The contents of the loaded data can be verified by typing the variable name LoadData into the command window or console. We see that the data contains the following variables:
# 
#   - `ordinate`: An $n$-channel by $n$-channel by $f$-frequencies matrix defining the Cross Power Spectral Density (CPSD) matrix of the model/test response.
#   - `abscissa`: An $f$-frequencies by 1 vector defining the frequency vector of each row-column pair in the ordinate data. In this case, and most cases, the same frequency vector describes all row-column pairs of the CPSD data in ordinate.
#   - `node`: A $n$-channel by 1 vector defining the node number of each row and column of the CPSD matrix. In the special case of a CPSD matrix, the same nodes define the rows and the columns.
#   - `direction`: A $n$-channel by 1 vector defining the node direction of each row and column of the CPSD matrix. In the special case of a CPSD matrix, the same directions define the rows and the columns.
# 
# In Python, we can load the data using `loadmat` from `scipy.io`.  This will load the data into a dictionary where the keys are the field name and the values are the arrays.  To make it easier to work with in Python, we will construct a `PowerSpectralDensityArray` object from this data.

# In[3]:


# We need to construct a coordinate array from the node and direction
# We will use .squeeze() to turn the 2D (120x1) array into a 1D (120) array
nodes = load_data['node'].squeeze()
# Directions are a bit more complicated due to how .mat files store cell array data.
directions = [direction[0] for direction in load_data['direction'].squeeze()]

coords = sdpy.coordinate_array(
    node = nodes, 
    direction = directions
)

# Create a 120x120 array of coordinates for the full CPSD matrix
cpsd_coords = sdpy.coordinate.outer_product(coords,coords)

cpsd = sdpy.power_spectral_density_array(
    load_data['abscissa'].squeeze(),
    load_data['ordinate'],
    cpsd_coords)

cpsd


# ## Initialize an ESCDF Dataset
# 
# To start, we will create an empty ESCDF file, which we will then populate with the data from our example file.

# In[4]:


escdf_file = escdf.ESCDF()


# If we type the variable name ESCDF into the command window or console, we will see a representation of this empty ESCDF file. Currently no activities or metadata are present in the file.

# In[5]:


escdf_file


# CPSD data, amongst other data types, are stored in ESCDF using a `data` object. The specification file for a data object can be reviewed to understand the properties defining the object and their associated data types, dimensions, and options.  We can see this in Matlab by reading the corresponding `.txt` file for the type (`data.txt`).  In Python, we can look at the docstring of the class using the built-in `help` functionality.

# In[6]:


help(escdf.classes.data)


# ## Writing Unflattened Data to ESCDF
# 
# The ESCDF implementation in Matlab has built-in functions that will flatten and unflatten data for the user. These functions operate on a structure that is populated with fields that mimic the properties of the data object and appear exactly like the structures output from the `dump_to_struct()` function. All the user needs to do is format the shaped, or unshaped, data into the structure expected by the `escdf_dataset.flatten_data()` and `escdf_dataset.unflatten_data()` functions.
# 
# The Python ESCDF implementation does not have such functionality, and instead relies on the reshaping functionality that exists in SDynPy.  In fact, SDynPy has built-in ESCDF functionality in its `escdf` subpackage, so we can simply convert directly from a `PowerSpectralDensityArray` object into an `escdf_dataset` using `sdynpy.escdf.from_data`.
# 
# The `sdynpy.escdf.from_data` function will automatically handle all of the reshaping necessary to put the data into ESCDF format.

# In[7]:


data = sdpy.escdf.from_data(
    dataset_name='cpsd',
    descriptive_name = 'example cpsd data',
    data = cpsd)


# However, SDynPy does not keep track of all parameters that are required by the ESCDF format.  For example, SDynPy does not handle or track units applied to the system.  We can see using the `validate` method that the object returned from the `sdynpy.escdf.from_data` method does not have any units information specified.

# In[8]:


# SDynPy doesn't keep track of all parameters required by ESCDF
# We must add unit information in order for the dataset to be
# valid.
data.validate()


# We can add these units to the dataset manually.

# In[9]:


data.ordinate_unit = 'G^2/Hz'
data.abscissa_unit = 'Hz'
data.validate()


# Interrogating the object by typing `data` into the command window or console shows us the structure of the populated dataset.

# In[17]:


data


# ## Packaging it All Together
# 
# Now that we have the dataset created, we need to put them into our ESCDF file. We do that through the ESCDF object we initially created.
# 
# To add data, we must first add the activity that generated the data. We do this with `add_activity`. This function requires a short name to use as reference, a more descriptive name, and a date and time that the activity was performed. We can pull the activity date from the last modified date in the source file. ESCDF accepts dates as native datetime objects.

# In[18]:


# Pull the date from the last modified date of the source file
import os
from datetime import datetime
creation_timestamp = os.path.getctime('Example_CPSD_Data.mat')
activity_date = datetime.fromtimestamp(creation_timestamp)

# Create the activity in the ESCDF file
escdf_file.add_activity('Environment','Response of test article to environment from Example_CPSD_Data.mat',activity_date);


# At this point, our ESCDF object now shows the activity we created. However, it contains no data.

# In[19]:


escdf_file


# Finally we can add the data to the activity using `add_data_to_activity()`. The `add_data_to_activity()` method expects a string defining the name of the activity to add data to and the data object to add to the activity.

# In[20]:


# Add data to the activity
escdf_file.add_data_to_activity('Environment',data)


# `escdf_file` should now reflect the addition of the data.

# In[21]:


escdf_file


# Now that we have a complete dataset in `escdf_file` containing our flattened CPSD data, we can write this dataset to a file using the `write_to_disk` method of the `escdf_file` object. The current convention is to keep the `h5` file extension for ESCDF files, signifying that they are indeed HDF5 files. This can signify to users without the ESCDF toolset that they could open the file with standard HDF5 readers and parse the relevant data and metadata if they had to. If the optional clobber argument is set to `true`; then if the file exists, it will be overwritten.

# In[22]:


# Write the file to disk
escdf_file.write_to_disk('Example_CPSD_Data.h5',clobber = True);


# ## Reading Flattened Data from ESCDF
# 
# Now, lets read in the ESCDF file created with flattened data and unpackage and unflatten the data for use in analysis. In this example, the ESCDF file contains the CPSD data in two dimensions ($n$ outputs $\times$ $n$ outputs) $\times$ $f$ frequencies (14400 x 2001). We want to extract and unflatten the data back to its three-dimensional form, $n$ outputs $\times$ $n$ outputs $\times$ $f$ frequencies (120x120x2001), to be compatible with standard matrix operations and support analyses.
# 
# We will start by reading in the ESCDF file we just created containing the flattened CPSD data.

# In[30]:


escdf_file = escdf.ESCDF.load('Example_CPSD_Data.h5')


# If we type in `escdf_file` into the command window or console, we will see the familiar structure of our ESCDF file.

# In[31]:


escdf_file


# In general, ESCDF files may contain many activities, each which link to many sets of data and many pieces of metadata. They may also have different reference names assigned to them. Therefore, when writing general functions to read in arbitrary ESCDF files, one should always reference the relevant activity or data, and use the links in ESCDF to pull the correct metadata associated with that activity, using the type of data or metadata to perform selection, rather than the name which might change from file to file.
# 
# In this case, the activity we want is the first (and only) activity in the file. Similarly, the data we want is the first (and only) dataset in the activity. So, we will extract the desired data by indexing as such.

# In[32]:


data = escdf_file.activities[0].data[0]


# As noted above, the Matlab ESCDF implementation has built-in functions that will unflatten data for the user by operating on a structure that is populated with fields that mimic the properties of the data object and appear exactly like the structures output from `dump_to_struct()`. Thus, all we need to do is run the `dump_to_struct()` function on the data object containing the flattened data to format it appropriately for the `escdf_dataset.unflatten_data()` function.
# 
# The Python implementation is designed to integrate tightly with SDynPy, so we can simply convert our dataset to a SDynPy object.

# In[33]:


cpsd = sdpy.escdf.to_data(data)


# Currently, the CPSD object is in a "flattened" state, which we can see by interrogating it in the command window.

# In[34]:


cpsd


# To get the CPSD object back into a matrix form suitable for analysis, we could call its `reshape_to_matrix()` method, which reshapes the `PowerSpectralDensityArray` based on its coordinate names.

# In[36]:


cpsd = cpsd.reshape_to_matrix()
cpsd


# At this point, we now have the data formatted as needed to perform standard matrix operations and general engineering analysis. 
# 
# Note that while there were perhaps many operations in this document most of them were simply translations (taking one field from one data source and putting it into ESCDF) and can easily be generalized to other data sources.
