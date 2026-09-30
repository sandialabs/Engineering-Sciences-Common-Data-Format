"""
Helper functions to handle validation of identifier names in ESCDF.
"""

import re
import warnings

def is_valid_identifier(identifier):
    """
    Check whether a string is a valid ESCDF identifier.

    A valid ESCDF identifier:

    - starts with an ASCII letter
    - contains only ASCII letters, digits, and underscores

    Parameters
    ----------
    identifier : str
        Identifier string to validate.

    Returns
    -------
    bool
        ``True`` if the identifier is valid, otherwise ``False``.
    """
    # Regular expression to match the constraints
    pattern = r"^[a-zA-Z][a-zA-Z0-9_]*$"
    return bool(re.match(pattern, identifier))

def make_valid_identifier(identifier, prefix="prefix_"):
    """
    Convert a string into a valid ESCDF identifier.

    Invalid identifiers are repaired by:

    - replacing whitespace with underscores
    - removing invalid characters
    - prepending ``prefix`` if the transformed identifier does not begin
      with a letter

    Parameters
    ----------
    identifier : str
        Identifier string to transform.
    prefix : str, optional
        Prefix to apply if the transformed identifier still does not begin
        with a letter.

    Returns
    -------
    str
        Valid ESCDF identifier derived from the input string.

    Warns
    -----
    UserWarning
        Issued if the returned identifier differs from the input string.
    """
    original_identifier = identifier
    # Replace whitespace with underscores
    identifier = re.sub(r"\s+", "_", identifier)

    # Remove invalid characters (anything not a letter, number, or underscore)
    identifier = re.sub(r"[^a-zA-Z0-9_]", "", identifier)

    # Check if the identifier is valid
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9_]*$", identifier):
        identifier = prefix + identifier
    if identifier != original_identifier:
        warnings.warn(f'Replaced name {original_identifier} with name {identifier}')

    return identifier