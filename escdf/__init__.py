# -*- coding: utf-8 -*-
"""
Engineering Sciences Common Data Format (ESCDF) Python API.

This package provides Python classes for constructing, validating,
reading, and writing ESCDF datasets and files.
"""

from .escdf_property import ESCDFProperty as Property
from .escdf_dataset import (
    ESCDFDataset as Dataset,
    ESCDFDatasetArray as DatasetArray,
    reload_specification_cache,
    load_specification_directory,
)
from .escdf_activity import ESCDFActivity as Activity, ESCDFActivityArray as ActivityArray
from .escdf import ESCDF
from .escdf_class_factory import classes
from .valid_names import is_valid_identifier, make_valid_identifier
