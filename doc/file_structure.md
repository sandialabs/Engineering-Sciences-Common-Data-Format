# File Structure

Rather than reinventing the wheel, the ESCDF will utilize the Hierarchical Data Format Version 5 (HDF5) format to store its underlying data. The HDF5 format is a self-describing, hierarchical format, where the file is organized into Groups (akin to folders on a computer file system) and Datasets (akin to files on a computer file system). Group and Dataset names are plain text and can be read directly.

HDF5 files are ubiquitous in scientific computing, meaning there are readers for many common programming languages (Matlab, Python, C/C++, Java, Fortran), and they can be read on any operating system.

HDF5 files are designed for large datasets. Portions of datasets can be read without reading the entire dataset into memory. Datasets can also be "chunked" which can enable efficient access of terabyte-sized datasets.

Through experimentation, it was found that the HDF5 file format was simpler, faster, and more flexible than the similar NetCDF4 file type, and provided more flexibility and interoperability than the Matlab .mat file type.

Within the HDF5 file, the ESCDF stores its data in a hierarchical manner. At the root level, we have all of the metadata that defines the various activities. Each metadata object is stored as a Group with the properties of that metadata object stored as Datasets within that Group. There is then an activities which holds a group for each activity. Within each activity Group, there is a data object, again stored as a Group with its properties stored as Datasets within that Group. Activities are then linked to the various metadata objects that define them. This enables a single metadata object to define multiple activities, for example if the same sensor geometry was used across multiple tests.

:::{figure} figures/heirarchy.png
Example ESCDF Hierarchy
:::