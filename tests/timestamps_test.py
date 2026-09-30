import datetime as dt
from datetime import timezone, timedelta

import pytest

from escdf.escdf_timestamps import _datetime_to_iso_utc, _datetime_from_iso_utc


def test_datetime_to_iso_utc_from_aware_utc():
    value = dt.datetime(2024, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)
    out = _datetime_to_iso_utc(value)
    assert out == "2024-01-02T03:04:05.123456Z"


def test_datetime_to_iso_utc_from_offset_timezone():
    value = dt.datetime(
        2024, 1, 2, 5, 4, 5, 123456, tzinfo=timezone(timedelta(hours=2))
    )
    out = _datetime_to_iso_utc(value)
    assert out == "2024-01-02T03:04:05.123456Z"


def test_datetime_to_iso_utc_warns_on_naive_datetime():
    value = dt.datetime(2024, 1, 2, 3, 4, 5, 123456)
    with pytest.warns(UserWarning, match="assuming UTC"):
        out = _datetime_to_iso_utc(value)
    assert out == "2024-01-02T03:04:05.123456Z"


def test_datetime_from_iso_utc_canonical():
    value = _datetime_from_iso_utc("2024-01-02T03:04:05.123456Z")
    assert value == dt.datetime(2024, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)


def test_datetime_from_iso_utc_no_fraction():
    value = _datetime_from_iso_utc("2024-01-02T03:04:05Z")
    assert value == dt.datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)


def test_datetime_from_iso_utc_offset_string():
    value = _datetime_from_iso_utc("2024-01-02T05:04:05.123456+02:00")
    assert value == dt.datetime(2024, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)


def test_datetime_from_iso_utc_warns_on_naive_string():
    with pytest.warns(UserWarning, match="assuming UTC"):
        value = _datetime_from_iso_utc("2024-01-02T03:04:05.123456")
    assert value == dt.datetime(2024, 1, 2, 3, 4, 5, 123456, tzinfo=timezone.utc)


def test_datetime_from_iso_utc_rejects_invalid():
    with pytest.raises(ValueError):
        _datetime_from_iso_utc("not-a-datetime")