# Software Implementation

Currently two implementations for ESCDF have been created: Python and Matlab. Both implementations are nearly identical from a user's perspective, with similarly named objects and methods. The implementations consist of four main parts:

## ESCDF Property Class

The Property class (Matlab: `escdf_property`, Python: `escdf.Property`) defines the behavior of individual properties within data or metadata objects. Property objects store all of the size and format options for each property and handle the low-level storing and retrieving of data from disk or memory.

## ESCDF Dataset Class

The Dataset class (Matlab: `escdf_dataset`, Python: `escdf.Dataset`) defines the behavior of groups of properties that form a Data or Metadata object. The Dataset class is what handles parsing of the specification files to determine what types of datasets exist and what their properties are. The Dataset class also does validation to ensure it is defined correctly per the specification file. It is used to represent both Data and Metadata objects.

Note that while Matlab natively handles arrays of classes, Python does not, so an additional class `DatasetArray` is defined in the Python implementation to describe the behavior of multiple datasets together (for example, indexing, display in the command window, etc.).

## ESCDF Activity Class

The Activity class (Matlab: `escdf_activity`, Python: `escdf.Activity`) defines the behavior of a specific test or analysis activity. It stores Data datasets within itself to track data that came from the activity. It stores links to Metadata datasets that are used to define the activity. The activity also stores basic metadata like a descriptive name and the date the activity was performed. Most users will not interact with the Activity class directly, but rather work through the ESCDF class.

Note that while Matlab natively handles arrays of classes, Python does not, so an additional class `ActivityArray` is defined in the Python implementation to describe the behavior of multiple activities together (for example, indexing, display in the command window, etc.).

## ESCDF Class

The highest level class is the ESCDF class, which represents a complete ESCDF package (Matlab: `escdf`, Python: `escdf.ESCDF`). This represents a collection of activities and metadata that define a test or analysis effort. This is where most of the functionality is for adding activities, data, and metadata to the file exists. It also has functionality for loading and saving entire files from and to the disk.

## Dependencies

The Matlab implementation has no external dependencies; Matlab natively has HDF5 readers that the ESCDF uses. Python has no native HDF5 readers, so it uses the de facto standard h5py which can be installed using pip.

```{code-block}
pip install h5py
```

## Code Storage

Code is stored on the GitHub repository: https://github.com/sandialabs/Engineering-Sciences-Common-Data-Format