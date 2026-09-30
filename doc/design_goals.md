# Major Design Goals

The ESCDF was designed with the following goals in mind:

## Object-Oriented

While the term object-oriented can strike fear in the hearts of Matlab and Python script-jockeys, the concept exists for a reason. When we use object-oriented programming, we define templates for what data members and functionality must exist within an object of a certain type. In the same way, the ESCDF must standardize the field names that exist in data products. This way, consumers of data do not need to interpret or guess what a data producer meant with a specific field name.   For example, the field is always node_id and never node_ids, node_num, or id. This allows consumers of data to set up automated scripts to parse datasets of specific types knowing that the field name will not change.

## Don't Repeat Yourself

Another concept taken from programming is the concept of not repeating code or data. In addition to the obvious advantage of making data products smaller, not repeating data also has the advantage of keeping one clean "truth" data source. This way, if an error is found in a data package, it only needs to be fixed in one place. In the context of the ESCDF, this means we will utilize links within data files to identify when a set of metadata is used to describe multiple sets of data.

For example, a single test geometry, which would include sensor position and orientations, might be used for several vibration and shock tests. It would not be wise to repeat that geometry for each test, because if a sensor was found to be oriented incorrectly, it would require remembering to fix the geometry in every place it is used. This also has implications for the eventual data storage solution (e.g. a database where all ESCDF files are stored), but this is out of scope for this project for now.

## Modularity and Extensibility

Currently, data producers are running at the ragged edge of capacity and therefore do not have the ability to implement onerous new processes. Therefore the ESCDF aims to start small, capturing only the most important data products that are important to share accurately. As time goes on, however, and users become accustomed to the workflow, it would be useful to extend this format to help document test and analysis activities as well. This is in recognition that we often consume our own data (for example to repeat a test that we ran previously), and by including additional "non-critical" metadata along with the data, we can more easily understand the results obtained.

## Minimize Coding for Users

In the Engineering Sciences Center, there is not one common toolset that gets used for data analysis. Matlab and Python are both popular scripting languages. High-performance Computing applications may use languages like C++. Therefore, the ESCDF must be careful that users of the tool are not overwhelmed with coding activities that get in the way of actually using it to store data. For the common use case, storing data to or reading data from the ESCDF should not be significantly more difficult than native formats.

As an example, a Matlab user of the ESCDF should not require more code to read a field in the ESCDF than the field of a Matlab struct. At a deeper level, test or analysis groups that implement new techniques that result in new types of data to be shared should not be responsible for creating a Matlab and Python reader for their type of data if they only use Python. Therefore the ESCDF should have some capability to automatically understand how to store and extract data in multiple languages without the user explicitly defining those interfaces.

## Accommodate Large Datasets

Data products used by the Engineering Sciences Center are routinely in the terabyte size range, meaning it is important for the ESCDF to be able to handle large data efficiently. This means efficient storage (e.g. binary rather than plain-text) and efficient access (e.g. reading portions of data directly from disk instead of requiring entire datasets to be read into memory).

## Human Readable-ish

No computer format is ever truly human readable. Even plain text files must be interpreted from their underlying bits to characters on a screen. Additionally, the need to store large datasets precludes the usage of plain-text data. The ESCDF will therefore target a "human readable-ish" file format. This type of format will generally have plain-text field names tied to binary data sets. This is important, because not everyone who encouters an ESCDF file will have the ESCDF toolset contained in this repository; however such users may still wish to interrogate the data.