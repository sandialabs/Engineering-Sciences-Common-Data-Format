"""
Canonical specification model, parser, and registry for ESCDF.

This subpackage provides the internal object model used to represent
parsed ESCDF specifications, along with parsing and registry machinery.
"""

from .specification import (
    ACCEPTABLE_DATATYPES,
    Version,
    Dimension,
    PropertyDefinition,
    ConstraintRule,
    StorageHint,
    Specification,
    ResolvedSpecification,
)
from .registry import SpecificationRegistry
from .parser import SpecificationParser
