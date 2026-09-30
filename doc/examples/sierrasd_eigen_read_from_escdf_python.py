#!/usr/bin/env python
# coding: utf-8

# # Reading Eigensolution Results from ESCDF to Exodus
# 
# This document will demonstrate how to take in eigensolution results (i.e. Modal Data) in the ESCDF format and translate it to an Exodus file for visualization in Paraview or other such tools using Matlab (with the 1553 Exodus Utilities) or Python (with SDynPy).
# 
# ## Preliminary Setup
# To start, we will perform preliminary operations needed by our respective programming languages.  In Matlab, we clear and reset the workspace.  In Python, we import our modules.  In both cases, we need to ensure the respective libraries needed are on the Matlab or Python path.

# In[1]:


# Reading Eigensolution Results from ESCDF to Exodus
# Example problem created by Dan Rohe, 1522

# Import required packages
import sdynpy as sdpy  # SDynPy for it's exodus writers
import numpy as np  # NumPy for it's array capabilities

# If ESCDF is not on your path, uncomment the following two lines and point the
# sys.path.append function to the ESCDF folder.

#import sys
#sys.path.append('/path/to/escdf')

import escdf  # escdf required to read and write ESCDF files


# ## Loading in ESCDF Results
# 
# The next step will be to load in the ESCDF files that we will be reading.  We will assume we have either created these files following the previous documentation page, or we have downloaded them from the above links.  To demonstrate the interoperability with ESCDF, we will open the version created using Matlab with Python and vice versa.

# In[2]:


# Load in the Modal Results Data

# To show interoperability, we will load in the ESCDF file created by
# Matlab in this file.
esfile = escdf.ESCDF.load('framewing_eigen_escdf_mat.esf')


# If we type in `esfile` into the command window or console, we will see the familiar structure of our ESCDF file.

# In[3]:


esfile


# ## Identifying the Relevant Data and Metadata
# 
# In general, ESCDF files may contain many activities, each which link to many sets of data and many pieces of metadata.  They may also have different reference names assigned to them.  Therefore, when writing general functions to read in arbitrary ESCDF files, one should always reference the relevant activity or data, and use the links in ESCDF to pull the correct metadata associated with that activity, using the type of data or metadata to perform selection, rather than the name which might change from file to file.
# 
# In this case, the activity we want is the first (and only) activity in the file.  A general function may take as its input argument the activity name or activity index.  Here we simply select the first index.

# In[4]:


# Identify the modal data we are after

# We will identify the activity containing the modal data
esact = esfile.activities[0]


# Querying the `esact` variable in the command window or console will show us information on the activity.

# In[5]:


esact


# We will then use the links in the activity to select from the metadata objects associated with the activity.  We will select the metadata based on its type being `geometry`.

# In[6]:


# A general ESCDF file may have multiple geometries and other metadata,
# so best practice is to use links between the activity and metadata
# to find the relevant geometry
metadata_links = esact.metadata_links;
# Find the metadata that is a geometry
esgeos = [esfile.metadata[name] for name in metadata_links
          if esfile.metadata[name].istype('geometry')]
if len(esgeos) != 1:
    raise ValueError(
        f'Did not find a single geometry linked to activity {esact.name}')
esgeo = esgeos[0]


# We will do a similar process to select data in the activity that has the type `mode`.

# In[7]:


# Get the data in a similar way
esmodes = [data for data in esact.data
          if data.istype('mode')]
if len(esmodes) != 1:
    raise ValueError(
        f'Did not find a single mode dataset linked to activity {esact.name}')
esmode = esmodes[0]


# ## Extracting Geometry Information
# We can remind ourselves of the properties in the geometry object by querying `esgeo` in the command window or console.  One thing to note is that all properties state `on disk`, meaning that ESCDF has not loaded them into memory.  Requesting data from these fields will read the data directly from disk.

# In[8]:


esgeo


# To assemble an Exodus file, we need to extract the data in the `esgeo` object to produce a node number map, a node coordinate array, and the element blocks.  We should also pull out the local coordinate system information.  While this file is built entirely in global coordinates, arbitrary modal data that one might receive in ESCDF format may have local coordinate information, so any general scripts we might write should automatically look for that information.
# 
# One thing to also note is that we have not stored any information that would allow us to reconstruct which elements originally belonged to which element block.  The way we stored this information was more for results visualization than for reconstructing the analysis.  Therefore, we will simply reconstruct one element block per element type in the Exodus file.

# In[9]:


# Extract the geometry information

# Exodus needs node and element information to set up the exodus file.
# Let's extract that information
node_ids = esgeo.node_id[:]
coords = esgeo.node_position[:]

# We should also extract the local coordinate system information.
# Note that this particular file has everything in global coordinates,
# however, a general modal data package from an experimental group
# might not.  Therefore we should get used to understanding how to
# work with local coordinate system directions
node_x_dir = esgeo.node_x_direction[:]
node_y_dir = esgeo.node_y_direction[:]
node_z_dir = esgeo.node_z_direction[:]

# Finally, let's extract the element information.  We've lost all
# all references to the original element blocks.  Also, a general
# modal package from an experimental group would never have had
# blocks to begin with, so we should go through and create new
# blocks based on element types anyway
all_element_types = esgeo.element_type[:]
all_element_connectivities = esgeo.element_connection[:]


# To construct element blocks, we will loop through the different element types and select rows of the connectivity matrix corresponding to that type of element.  These we can then assemble into a regular array (instead of the original ragged array).  Note that the connectivity is stored in ESCDF with reference to the node number, not the node index like Exodus.  Therefore, we must create an inverse node map that maps the node number back to the index.  Similarly, Exodus element block names are not identical to ESCDF, so we should create an element type map as well.

# In[10]:


element_types = np.unique(all_element_types)

# We need to map the element types in ESCDF to the element types in
# Exodus
elem_map = {'sphere1':'SPHERE',
            'bar2':'BEAM',
            'hex20':'HEX20'}
# We also need to map the node numbers back to the indices to use with
# Exodus
node_map_inv = {id:index for index,id in enumerate(node_ids)}
# Create vectorized function to apply the map to entire connectivity arrays
node_map_inv_fn = np.vectorize(node_map_inv.__getitem__)

# Loop through each block type to extract the connectivity matrix
block_connectivities = []
for element_type in element_types:
    block_indices = all_element_types == element_type
    block_connectivity = np.array(
        all_element_connectivities[block_indices].tolist())
    # Apply the node map
    block_connectivities.append(node_map_inv_fn(block_connectivity))

# We should also map our element types
exodus_block_types = [elem_map[elem_type] for elem_type in element_types]


# ## Extracting Modal Information
# We must similarly extract modal information.  We can query the `esmode` object by typing it into the command window or console to remind ourselves of its properties.

# In[11]:


esmode


# We will extract the frequencies, the shape matrix, and the degree of freedom names from the dataset.

# In[12]:


# Extract Modal Information

# With the geometry extracted, we can now pull the modal data from the
# file.  In general, the mode shape information cannot be assumed to be
# in the same order as the node id numbers in the geometry, so we will have
# to use the dof_name property to help us sort the data.  Additionally,
# we will use the local node directions to help us convert the data to
# the global displacements desired by the exodus file.

frequencies = esmode.frequency[:]
shape_array = esmode.shape[:]
dof_names = esmode.dof_name[:]


# In Exodus, natural frequency information is stored as the time step.  Mode shape information is by default stored in variable names `DispX`, `DispY`, and `DispZ` for displacements and `RotX`, `RotY`, and `RotZ` for rotations.  We must create an array of values for each of these variables.  These will be nodal variables in the Exodus file, so there should be one value for each node for each time step.  We will assemble these as 3D arrays with shape `(num_nodes, 3, num_freqs)`.

# In[13]:


# Initialize an array of zeros
displacement_shapes = np.zeros((node_ids.size,3,frequencies.size))
rotation_shapes = np.zeros((node_ids.size,3,frequencies.size))


# ESCDF packages the degree of freedom names along with the shape matrix.  Therefore, we should never assume that the shape matrix is ordered in any specific way.  We must parse the degree of freedom names and reference it back to the node number map in order to identify the correct row of the nodal variable array we are creating.  Similarly, we should not assume that we are working in global coordinate systems and simply assign `X` degree of freedom values to the first column.  We must multiply `X` degrees of freedom by the `node_x_direction vector` to reconstruct the global motion.
# 
# We can use regular expressions to parse out the node number, direction, and polarity of the degree of freedom name.  The node number is passed to the node map to produce the node index, and these are used along with the direction string to select the direction vector.  The shape coefficient is then multiplied by the direction vector, and it is added to the proper displacement or rotation shape matrix.  By adding the values, we allow the contributions from the X, Y, and Z displacements to be summed together rather than the Z overwriting the X, for example.

# In[14]:


# Go through each degree of freedom in the shape list and add it to the
# correct index
import re # Import the regex module
name_pattern = '(\d+)([a-zA-Z]+)([+-])';
for dof_index, (name, coefficients) in enumerate(zip(dof_names,shape_array)):
    # Use regex to extract parts of the name
    name_match = re.match(name_pattern,name)
    node_num = int(name_match.group(1))
    direction_str = name_match.group(2)
    polarity = int(name_match.group(3)+'1')
    # Get the node index from the node map
    node_index = node_map_inv[node_num]
    # Use the direction string to select the correct direction vector
    if 'X' in direction_str:
        direction = polarity*node_x_dir[node_index,:]
    elif 'Y' in direction_str:
        direction = polarity*node_y_dir[node_index,:]
    elif 'Z' in direction_str:
        direction = polarity*node_z_dir[node_index,:]
    else:
        raise ValueError('Unknown Direction')
    # Multiply the shape coefficients by the direction vector (using
    # broadcasting) and add to the correct matrix.  We add because there is
    # a contribution from X, Y, and Z local directions
    if 'R' in direction_str:
        rotation_shapes[node_index,:,:] = (rotation_shapes[node_index,:,:]
                                           + direction[:,np.newaxis]*coefficients)
    else:
        displacement_shapes[node_index,:,:] = (displacement_shapes[node_index,:,:]
                                               + direction[:,np.newaxis]*coefficients)


# ## Building the Exodus File
# Now that we have constructed all of the data that the Exodus file might need, we can put it into the Exodus format.  This will look significantly different between Matlab and Python due to the differences in the 1553 Exodus Utilities and SDynPy Exodus implementation.  The 1553 Exodus Utilities construct the Exodus file in memory then write it to disk at the end.  The SDynPy Exodus tools create a file on disk immediately, then the various values are stored to that file via its function calls.
# 
# We can query the exodus object exo to see properties of the exodus file we've created.

# In[15]:


# Build the Exodus File

# Now we need to package the extracted data into the Exodus format.
# We will begin by creating an empty file
exo = sdpy.Exodus('framewing_eigen_from_escdf_py.exo','w',
                  esfile.metadata.attributes.analysis_name[...].item(),
                  num_dims=3, num_nodes=node_ids.size,
                  num_elem=sum([conn.shape[0] for conn in block_connectivities]),
                  num_blocks=len(exodus_block_types),
                  num_node_sets=0, num_side_sets=0,clobber=True)
# Add geometry information
exo.put_coord_names(['x','y','z'])
exo.put_coords(coords.T)
exo.put_node_num_map(node_ids)
exo.put_elem_blk_ids(np.arange(len(exodus_block_types))+1)
for index,(elem_type,conn) in enumerate(zip(exodus_block_types,
                                            block_connectivities)):
    exo.put_elem_blk_info(index+1, elem_type, *conn.shape)
    exo.set_elem_connectivity(index+1,conn)
# Add variable information
variable_names = ['DispX','DispY','DispZ','RotX','RotY','RotZ']
exo.put_node_variable_names(variable_names)
exo.set_times(frequencies)
for variable_name, values in zip(
        variable_names,
        np.concatenate((displacement_shapes,rotation_shapes),axis=1).transpose(1,2,0)):
    for step,value in enumerate(values):
        exo.set_node_variable_values(variable_name, step, value)

# Query the Exodus File
print(exo)

# Close the file to finalize
exo.close()


# We can load these models into a tool such as [Paraview](https://www.paraview.org/) to verify that the Exodus files were created successfully.
# 
# ![image-2025-11-6_17-1-42.png](_attachments/sierrasd_eigen_read_from_escdf/cell016/6e716884-7601-428c-9f3e-acf1c50b37a4.png)
