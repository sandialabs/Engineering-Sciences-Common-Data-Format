# -*- coding: utf-8 -*-
"""
ESCDF activity container implementation.

This module defines :class:`ESCDFActivity` and
:class:`ESCDFActivityArray`, which organize activity-level result datasets
and links to metadata datasets.
"""

from .escdf_dataset import ESCDFDataset, ESCDFDatasetArray
from .escdf_property import ESCDFProperty
from .escdf_timestamps import _datetime_from_iso_utc, _datetime_to_iso_utc
from .valid_names import is_valid_identifier, make_valid_identifier
import numpy as np
import h5py as h5
import datetime as dt


class ESCDFActivity:
    """
    Activity container for ESCDF result datasets.

    An ``ESCDFActivity`` represents one test, analysis step, or processing
    action within an ESCDF file. Activities hold datasets that inherit from
    ``activity_result`` and may also reference one or more metadata
    datasets by name.

    Parameters
    ----------
    short_name : str
        Short activity identifier used as the on-disk activity group name.
    descriptive_name : str
        Human-readable activity description.
    activity_date : datetime.datetime
        Date and time associated with the activity.
    data : iterable of ESCDFDataset, optional
        Initial result datasets contained in the activity.
    metadata_links : iterable of str, optional
        Names of metadata datasets linked to the activity.
    replace_invalid_names : bool, optional
        If ``True``, invalid activity names are repaired automatically.

    Notes
    -----
    Activities do not store metadata datasets directly. Instead, they
    maintain references to metadata dataset names stored elsewhere in the
    parent :class:`ESCDF` container.

    See Also
    --------
    ESCDF
    ESCDFDataset
    ESCDFActivityArray
    """

    __slots__ = (
        "_data",
        "_metadata_links",
        "_name",
        "_descriptive_name",
        "_activity_date",
        "_backing_state",
        "_has_pending_changes",
    )

    @property
    def data(self):
        return self._data

    @property
    def data_names(self):
        return [val.name for val in self._data]

    @property
    def metadata_links(self):
        return self._metadata_links

    @property
    def name(self):
        return self._name

    @name.setter
    def name(self, value):
        if not isinstance(value, str):
            raise ValueError("`name` must be a string.")
        self._name = value

    @property
    def descriptive_name(self):
        return self._descriptive_name

    @descriptive_name.setter
    def descriptive_name(self, value):
        if not isinstance(value, str):
            raise ValueError("`descriptive_name` must be a string.")
        self._descriptive_name = value

    @property
    def activity_date(self):
        return self._activity_date

    @activity_date.setter
    def activity_date(self, value):
        if not isinstance(value, dt.datetime):
            raise ValueError("`activity_date` must be a datetime.datetime object.")
        self._activity_date = value

    @property
    def backing_state(self):
        return self._backing_state

    @property
    def has_pending_changes(self):
        return self._has_pending_changes

    def __init__(
        self,
        short_name,
        descriptive_name,
        activity_date,
        data=None,
        metadata_links=None,
        replace_invalid_names=False,
    ):
        """
        Initialize an ESCDF activity.

        Parameters
        ----------
        short_name : str
            Short activity identifier used as the on-disk activity group
            name.
        descriptive_name : str
            Human-readable activity description.
        activity_date : datetime.datetime
            Date and time associated with the activity.
        data : iterable of ESCDFDataset, optional
            Initial result datasets contained in the activity.
        metadata_links : iterable of str, optional
            Names of metadata datasets linked to the activity.
        replace_invalid_names : bool, optional
            If ``True``, invalid activity names are repaired automatically.

        Raises
        ------
        ValueError
            If the activity name is invalid and
            ``replace_invalid_names`` is ``False``, or if the supplied data
            or metadata link collections are malformed.
        """
        name_valid = is_valid_identifier(short_name)
        if (not name_valid) and replace_invalid_names:
            short_name = make_valid_identifier(short_name, "activity_")
        elif (not name_valid) and (not replace_invalid_names):
            raise ValueError(
                f"Invalid name {short_name}.  Names must start with a letter and consist of only letters, numbers, and underscores."
            )
        self.name = short_name
        self.descriptive_name = descriptive_name
        self.activity_date = activity_date
        self._data = ESCDFDatasetArray(data)

        if metadata_links is None:
            self._metadata_links = []
        else:
            try:
                if not all([isinstance(value, str) for value in metadata_links]):
                    raise ValueError(
                        "If specified, `metadata_links` must be a 1D iterable of strings"
                    )
            except (IndexError, TypeError, KeyError):
                raise ValueError(
                    "If specified, `metadata_links` must be a 1D iterable of strings"
                )
            self._metadata_links = [value for value in metadata_links]

        self._backing_state = "memory"
        self._has_pending_changes = False

    def link_to_metadata(self, metadata_name):
        """
        Add a metadata link to the activity.

        Parameters
        ----------
        metadata_name : str
            Name of the metadata dataset to link.

        Raises
        ------
        ValueError
            If the metadata name is already linked to this activity.
        """
        if metadata_name in self.metadata_links:
            raise ValueError(
                "Activity {:} is already linked to metadata {:}".format(
                    self.name, metadata_name
                )
            )
        self._metadata_links.append(metadata_name)
        self._has_pending_changes = True

    def unlink_from_metadata(self, metadata_name):
        """
        Remove a metadata link from the activity.

        Parameters
        ----------
        metadata_name : str
            Name of the metadata dataset to unlink.

        Raises
        ------
        ValueError
            If the metadata name is not currently linked to the activity.
        """
        try:
            index = self.metadata_links.index(metadata_name)
        except ValueError:
            raise ValueError(
                "Metadata {:} does not exist in activity {:}".format(
                    metadata_name, self.name
                )
            )
        self._metadata_links.pop(index)
        self._has_pending_changes = True

    def add_data(self, dataset):
        """
        Add a result dataset to the activity.

        Parameters
        ----------
        dataset : ESCDFDataset
            Dataset to add.

        Raises
        ------
        ValueError
            If the input is not an ESCDF dataset, if the dataset does not
            inherit from ``activity_result`` (or ``unknown``), or if a
            dataset with the same name already exists in the activity.
        """
        if not isinstance(dataset, ESCDFDataset):
            raise ValueError(
                "Data added to activities must be in the form of an ESCDF Dataset"
            )
        if not dataset.istype("activity_result") and not dataset.istype("unknown"):
            raise ValueError(
                'ESCDF Datasets added to activities should be an "activity_result" or inherit from it, not {:}.  Link this metadata to the activity instead.'.format(
                    dataset.dataset_type
                )
            )
        if any([ds.name == dataset.name for ds in self.data]):
            raise ValueError(
                "An ESCDF Dataset with the name {:} already exists in this activity.".format(
                    dataset.name
                )
            )
        self._data.add_dataset(dataset)
        self._has_pending_changes = True

    def remove_data(self, dataset_name):
        """
        Remove a dataset from this activity.

        Parameters
        ----------
        dataset_name : str
            Name of the dataset to remove.

        Returns
        -------
        ESCDFDataset
            The removed dataset object.

        Raises
        ------
        ValueError
            If no dataset with the given name exists in the activity.

        Notes
        -----
        This operation removes the dataset from the in-memory activity
        graph only. It does not immediately delete any underlying physical
        backing from disk.
        """
        names = self.data.names
        try:
            index = names.index(dataset_name)
        except ValueError:
            raise ValueError(
                "No dataset with name {:} was found in this activity.".format(
                    dataset_name
                )
            )
        removed = self._data[index]
        self._data.remove_dataset(index)
        self._has_pending_changes = True
        return removed

    def get_data(self, dataset_name=None):
        """
        Retrieve one or more datasets from the activity.

        Parameters
        ----------
        dataset_name : str, optional
            Name of a specific dataset to retrieve. If omitted, all
            datasets in the activity are returned.

        Returns
        -------
        ESCDFDataset or ESCDFDatasetArray
            Requested dataset, or the full activity dataset collection.

        Raises
        ------
        ValueError
            If a specific dataset name is requested but no matching dataset
            exists.
        """
        if dataset_name is None:
            return self._data[:]
        else:
            names = [ds.name for ds in self.data]
            try:
                index = names.index(dataset_name)
            except ValueError:
                raise ValueError(
                    "No dataset with name {:} was found in this activity.".format(
                        dataset_name
                    )
                )
            return self._data[index]

    def __getattr__(self, name):
        return self._data[name]

    def __getitem__(self, name):
        if isinstance(name, str):
            return self._data[name]
        else:
            raise ValueError(
                "Key values must be strings corresponding to the name of a data dataset."
            )

    def repr(self):
        date = "\n      Date: {:}".format(self.activity_date)
        out = "    {:}:\n      {:}{:}".format(self.name, self.descriptive_name, date)
        out += "\n      Data: {:}".format(", ".join(self.data_names))
        out += "\n      Metadata: {:}".format(", ".join(self.metadata_links))
        return out

    def __repr__(self):
        return self.repr()

    def write_to_disk(self, h5_activities_group: h5.Group):
        """
        Write the activity to an HDF5 activities group.

        Parameters
        ----------
        h5_activities_group : h5py.Group
            Parent HDF5 group that stores all activities for an ESCDF file.

        Notes
        -----
        The activity is written as a subgroup named after the activity's
        short name. Linked metadata names are stored in the ``parameters``
        dataset.
        """
        activity_group = h5_activities_group.create_group(self.name)
        activity_group.attrs["activity_name"] = self.descriptive_name
        activity_group.attrs["activity_date"] = _datetime_to_iso_utc(self.activity_date)
        parameters_dataset = activity_group.create_dataset(
            "parameters", (len(self.metadata_links),), dtype=h5.string_dtype()
        )
        parameters_dataset[...] = self.metadata_links
        parameters_dataset.attrs["data_type"] = "str"
        # Now go through and write each dataset to the group
        for dataset in self.data:
            data_group = activity_group.create_group(dataset.name)
            dataset.write_to_disk(data_group)

        self._backing_state = "hdf5_native"
        self._has_pending_changes = False


class ESCDFActivityArray:
    """
    Collection of :class:`ESCDFActivity` objects with name-based lookup.

    Parameters
    ----------
    activities : iterable of ESCDFActivity, optional
        Initial activities to include in the collection.

    Notes
    -----
    Activity names within the collection must be unique.
    """

    __slots__ = ["_activities"]

    @property
    def activities(self):
        return [val for val in self._activities]

    @property
    def names(self):
        return [val.name for val in self._activities]

    def __init__(self, activities=None):
        """
        Initialize an activity collection.

        Parameters
        ----------
        activities : iterable of ESCDFActivity, optional
            Initial activities to include in the collection.

        Raises
        ------
        ValueError
            If the supplied collection is not a one-dimensional iterable of
            ESCDF activities, or if activity names are not unique.
        """
        if activities is None:
            self._activities = []
        else:
            # Data must be an iterable of escdf objects
            try:
                if not all([isinstance(value, ESCDFActivity) for value in activities]):
                    raise ValueError(
                        "If specified, `activities` must be a 1D iterable of ESCDF Activities"
                    )
            except (IndexError, TypeError, KeyError):
                raise ValueError(
                    "If specified, `activities` must be a 1D iterable of ESCDF Activities"
                )
            self._activities = [value for value in activities]
            if len(set(self.names)) != len(self.names):
                raise ValueError("All activity names must be unique.")

    def add_activity(self, activity):
        """
        Add an activity to the collection.

        Parameters
        ----------
        activity : ESCDFActivity
            Activity to add.

        Raises
        ------
        ValueError
            If the input is not an ESCDF activity or if an activity with
            the same name already exists.
        """
        if not isinstance(activity, ESCDFActivity):
            raise ValueError("Added activity must be in the form of an ESCDF Activity")
        if any([ac.name == activity.name for ac in self.activities]):
            raise ValueError(
                "An ESCDF Activity with the name {:} already exists.".format(
                    activity.name
                )
            )
        self._activities.append(activity)

    def remove_activity(self, activity_identifier):
        """
        Remove an activity from the collection.

        Parameters
        ----------
        activity_identifier : int or str
            Integer index or activity name identifying the activity to
            remove.

        Raises
        ------
        ValueError
            If the identifier type is invalid or if a named activity does
            not exist.
        """
        if isinstance(activity_identifier, int):
            self._activities.pop(activity_identifier)
        elif isinstance(activity_identifier, str):
            try:
                index = self.names.index(activity_identifier)
            except ValueError:
                raise ValueError(
                    "No activity with name {:} was found.".format(activity_identifier)
                )
            self._activities.pop(index)
        else:
            raise ValueError(
                "Dataset identifier must be either an int or a string specifying the dataset name"
            )

    def __iter__(self):
        return iter(self.activities)

    def __getitem__(self, name_or_index):
        if isinstance(name_or_index, int):
            return self.activities[name_or_index]
        elif isinstance(name_or_index, str):
            try:
                index = self.names.index(name_or_index)
            except ValueError:
                raise ValueError(
                    "No activity with name {:} was found.".format(name_or_index)
                )
            return self.activities[index]
        elif isinstance(name_or_index, slice) or isinstance(name_or_index, Ellipsis):
            return ESCDFActivityArray(self.activities[name_or_index])
        else:
            raise ValueError(
                "Indexing operation must supply an index, a name in the form of a string, or a slice"
            )

    def __getattr__(self, name):
        try:
            index = self.names.index(name)
        except ValueError as exc:
            raise AttributeError(
                "No activity with name {:} was found.".format(name)
            ) from exc
        return self.activities[index]

    def repr(self):
        out = ""  #'\nESCDF Activities'
        for activity in self:
            out += "\n" + activity.repr()
        return out

    def __repr__(self):
        return self.repr()
