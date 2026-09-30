"""
Timestamp conversion helpers for ESCDF.

This module provides helper functions for converting Python datetime
objects to and from the canonical ESCDF timestamp string format.
"""
from datetime import datetime, timezone
import warnings

def _datetime_to_iso_utc(value: datetime) -> str:
    """
    Convert a datetime value to canonical ESCDF UTC timestamp text.

    Parameters
    ----------
    value : datetime.datetime
        Datetime value to convert.

    Returns
    -------
    str
        ISO 8601 UTC timestamp string in the form
        ``YYYY-MM-DDTHH:MM:SS.ffffffZ``.

    Raises
    ------
    ValueError
        If ``value`` is not a ``datetime.datetime`` instance.

    Warns
    -----
    UserWarning
        Issued if the datetime is naive and is therefore assumed to be UTC.

    Notes
    -----
    ESCDF timestamps are written in UTC with a trailing ``Z``.
    """
    if not isinstance(value, datetime):
        raise ValueError("value must be a datetime.datetime object.")
    if value.tzinfo is None:
        warnings.warn(
            "Naive datetime encountered with no timezone information; assuming UTC."
        )
        value = value.replace(tzinfo=timezone.utc)
    else:
        value = value.astimezone(timezone.utc)
    return value.strftime("%Y-%m-%dT%H:%M:%S.%fZ")

def _datetime_from_iso_utc(value: str) -> datetime:
    """
    Parse an ESCDF timestamp string as a UTC datetime.

    Parameters
    ----------
    value : str
        Timestamp string to parse.

    Returns
    -------
    datetime.datetime
        Parsed datetime value with timezone set to UTC.

    Raises
    ------
    ValueError
        If the timestamp string cannot be parsed.

    Warns
    -----
    UserWarning
        Issued if the timestamp string lacks explicit timezone information
        and is therefore assumed to be UTC.

    Notes
    -----
    Canonical ESCDF timestamps use UTC with a trailing ``Z``. Several
    older or looser ISO-style formats are accepted for backward
    compatibility.
    """
    if isinstance(value, bytes):
        value = value.decode("utf-8")
    if not isinstance(value, str):
        value = str(value)

    # Preferred canonical form: ...Z
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=timezone.utc)
    except ValueError:
        pass

    # Backward compatibility: no fractional seconds, still UTC Z
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        pass

    # Backward compatibility: generic ISO format, possibly with offset
    try:
        dt_val = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt_val.tzinfo is None:
            warnings.warn(
                f'Datetime string "{value}" has no timezone information; assuming UTC.'
            )
            dt_val = dt_val.replace(tzinfo=timezone.utc)
        else:
            dt_val = dt_val.astimezone(timezone.utc)
        return dt_val
    except ValueError as exc:
        raise ValueError(f"Could not parse datetime string: {value}") from exc