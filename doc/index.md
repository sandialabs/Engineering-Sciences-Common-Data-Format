---
title: "ESCDF: Engineering Sciences Common Data Format"
site:
  hide_title_block: false
---

## Welcome to ESCDF's Documentation!

[![matlab](badges/matlab_test_coverage.svg)](/matlab_coverage/) [![python](badges/python_test_coverage.svg)](/python_coverage/)

The Engineering Sciences Common Data Format (ESCDF) is a file format that was designed to solve issues surrounding storage and sharing of data between various test laboratories, simulation groups, and environment teams.

The major issue became that every data producer packaged and delivered their data products in slightly different ways, even for what should nominally be identical data products. Typically, a data producer might produce a Matlab .mat file, which provides the flexibility to store arbitrary data, but no standardization. A field that might store the node identification numbers from a finite element model might be called `node_num`, `node_id`, `node_ids`, `ids`, etc. Additionally, metadata that might be important to interpret the data (units, local coordinate system directions, etc.) would often be missing. These metadata would often be communicated separately (e.g. via email), which works in the short term, but if the data were revisited by someone in the future, that metadata link would be lost. All of this put great strain on the consumers of this data, as they were not only responsible for their own analysis that they needed to perform on the data, they also had the additional responsibility to decode and parse out the data packages. Consumers of data often spent more time trying to figure out missing metadata from datasets than on their own analyses.

The ESCDF was therefore conceived as a solution to this issue, attempting to standardize data transfer between and within groups at Sandia National Laboratories.  As it could also be useful sharing data with partners working with Sandia National Laboratories, it was also released open source.

### Important Links

- [GitHub Repository](https://github.com/sandialabs/Engineering-Sciences-Common-Data-Format) - Download the Software, Submit Bugs and Feature Requests, Contribute to ESCDF