# -*- coding: utf-8 -*-
"""
ESCDF activity container implementation.

This module defines :class:`ESCDFActivity` and
:class:`ESCDFActivityArray`, which organize activity-level result datasets
and links to metadata datasets.
"""

import datetime as dt
import weakref

import h5py as h5
import numpy as np

from .backing import HDF5Location
from .escdf_dataset import ESCDFDataset, ESCDFDatasetArray
from .escdf_property import ESCDFProperty
from .escdf_timestamps import _datetime_from_iso_utc, _datetime_to_iso_utc
from .valid_names import is_valid_identifier, make_valid_identifier


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
        "_hdf5_location",
        "_has_pending_changes",
        "_logical_parent_ref",
        "__weakref__",
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
    def has_pending_changes(self):
        return self._has_pending_changes

    @property
    def logical_parent(self):
        """
        Return the logical parent container for this activity.

        Returns
        -------
        ESCDF or None
            Parent ESCDF container if attached, otherwise ``None``.
        """
        if self._logical_parent_ref is None:
            return None
        return self._logical_parent_ref()

    def set_logical_parent(self, parent):
        """
        Set the logical parent for this activity.

        Parameters
        ----------
        parent : ESCDF or None
            Parent container, or ``None`` for a free activity.
        """
        self._logical_parent_ref = None if parent is None else weakref.ref(parent)

    @property
    def logical_path(self):
        """
        Return the activity logical path in the current object graph.

        Returns
        -------
        str or None
            Logical path if attached to a container, otherwise ``None``.
        """
        parent = self.logical_parent
        if parent is None:
            return None
        return f"/activities/{self.name}"

    @property
    def logical_ancestry(self):
        """
        Return the logical ancestry chain beginning with this activity.

        Returns
        -------
        list
            Bottom-up logical ancestry, beginning with this activity and
            ending at the top-level container if attached.
        """
        ancestry = [self]
        parent = self.logical_parent
        while parent is not None:
            ancestry.append(parent)
            parent = getattr(parent, "logical_parent", None)
        return ancestry

    @property
    def logical_root(self):
        """
        Return the root object of this activity's logical graph.

        Returns
        -------
        object or None
            Root object if attached, otherwise ``self``.
        """
        ancestry = self.logical_ancestry
        return ancestry[-1] if ancestry else None

    def same_logical_location_as(self, other):
        if not hasattr(other, "logical_ancestry"):
            return False

        this_ancestry = self.logical_ancestry
        other_ancestry = other.logical_ancestry

        if len(this_ancestry) != len(other_ancestry):
            return False

        return all(a is b for a, b in zip(this_ancestry, other_ancestry))

    @property
    def hdf5_location(self):
        """
        Return the current HDF5 backing location for this activity.

        Returns
        -------
        HDF5Location or None
            HDF5 group location if HDF5-backed, otherwise ``None``.
        """
        return self._hdf5_location

    def target_hdf5_location(self, activities_group):
        """
        Return the HDF5 location this activity would occupy under an
        activities group.

        Parameters
        ----------
        activities_group : h5py.Group
            HDF5 ``/activities`` group.

        Returns
        -------
        HDF5Location
            Expected HDF5 group location for this activity.
        """
        return HDF5Location.child_of_group(activities_group, self.name)

    def is_realized_at(self, activity_group):
        """
        Return whether this activity is already realized at an HDF5 group.

        Parameters
        ----------
        activity_group : h5py.Group
            HDF5 group representing the target activity.

        Returns
        -------
        bool
            ``True`` if this activity is HDF5-backed at exactly the given
            group location.
        """
        if self.hdf5_location is None:
            return False
        return self.hdf5_location.same_location_as(
            HDF5Location.from_h5_object(activity_group)
        )

    def is_realized_under(self, activities_group):
        """
        Return whether this activity is already realized under an activities
        parent group.

        Parameters
        ----------
        activities_group : h5py.Group
            HDF5 ``/activities`` group.

        Returns
        -------
        bool
            ``True`` if this activity is HDF5-backed at the expected child
            location under the activities group.
        """
        if self.hdf5_location is None:
            return False
        return self.hdf5_location.same_location_as(
            self.target_hdf5_location(activities_group)
        )

    def same_backing_location_as(self, other):
        """
        Return whether this activity has the same HDF5 backing location as
        another activity.

        Parameters
        ----------
        other : object
            Object to compare against.

        Returns
        -------
        bool
            ``True`` if both activities are HDF5-backed at the same HDF5
            group location.
        """
        if not hasattr(other, "hdf5_location"):
            return False

        this_location = self.hdf5_location
        other_location = other.hdf5_location

        if this_location is None or other_location is None:
            return False

        return this_location.same_location_as(other_location)

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

        self._hdf5_location = None
        self._has_pending_changes = False
        self._logical_parent_ref = None

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
        dataset.set_logical_parent(self)
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
        removed = self._data.remove_dataset(index)
        removed.set_logical_parent(None)
        self._has_pending_changes = True
        return removed

    def rename_data(self, old_name, new_name):
        """
        Rename a dataset within this activity.

        Parameters
        ----------
        old_name : str
            Current dataset name.
        new_name : str
            New dataset name.

        Returns
        -------
        ESCDFDataset
            The renamed dataset object.

        Raises
        ------
        ValueError
            If the old name does not exist, the new name already exists,
            or the new name is not a valid identifier.

        Notes
        -----
        This operation updates only the in-memory logical graph. It does
        not immediately rename any physical HDF5 backing.
        """
        if not isinstance(new_name, str) or not is_valid_identifier(new_name):
            raise ValueError(
                f'New dataset name "{new_name}" is not a valid identifier.'
            )

        if old_name not in self.data.names:
            raise ValueError(
                f'No dataset named "{old_name}" exists in activity "{self.name}".'
            )

        if new_name in self.data.names:
            raise ValueError(
                f'A dataset named "{new_name}" already exists in activity "{self.name}".'
            )

        dataset = self.data[old_name]
        dataset.name = new_name
        self._has_pending_changes = True
        return dataset

    def replace_data(self, dataset):
        """
        Replace a dataset within this activity.

        Parameters
        ----------
        dataset : ESCDFDataset
            Dataset to use as the replacement. Its name must match an
            existing dataset in the activity.

        Returns
        -------
        ESCDFDataset
            The removed dataset object.

        Raises
        ------
        ValueError
            If the replacement dataset name does not already exist in the
            activity.

        Notes
        -----
        This operation updates only the in-memory logical graph. It does
        not immediately modify any physical HDF5 backing.
        """
        if dataset.name not in self.data.names:
            raise ValueError(
                f'No dataset named "{dataset.name}" exists in activity "{self.name}" to replace.'
            )

        removed = self.remove_data(dataset.name)
        self.add_data(dataset)
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

    def realize_to_hdf5(self, activity_groups, strategy="memory", overwrite=False):
        """
        Realize the activity into an HDF5 activities group.

        Parameters
        ----------
        activity_groups : h5py.Group
            HDF5 group containing all activities.
        strategy : {'memory'}, optional
            Dataset/property realization strategy. The first-pass
            implementation supports only ``"memory"``.
        overwrite : bool, optional
            If ``True``, allow replacing an existing activity group with
            the same name.

        Notes
        -----
        This method treats the current logical activity object as
        authoritative. Contained datasets and metadata links are realized
        into the target activity group.
        """
        if self.name in activity_groups:
            if not overwrite:
                raise ValueError(
                    f'Target activities group already contains activity "{self.name}". '
                    "Use overwrite=True to replace it explicitly."
                )
            del activity_groups[self.name]

        activity_group = activity_groups.create_group(self.name)
        activity_group.attrs["activity_name"] = self.descriptive_name
        activity_group.attrs["activity_date"] = _datetime_to_iso_utc(self.activity_date)

        parameters = activity_group.create_dataset(
            "parameters",
            (len(self.metadata_links),),
            h5.string_dtype(encoding="utf-8"),
        )
        parameters.attrs["data_type"] = "str"
        parameters[...] = self.metadata_links

        for dataset in self.data:
            data_group = activity_group.create_group(dataset.name)
            dataset.realize_to_hdf5(
                data_group,
                strategy=strategy,
                overwrite=overwrite,
            )

        self._hdf5_location = HDF5Location.from_h5_object(activity_group)
        self._has_pending_changes = False

    def write_to_disk(self, activity_groups):
        """
        Write the activity to an HDF5 activities group.

        Parameters
        ----------
        activity_groups : h5py.Group
            HDF5 group containing all activities.

        Notes
        -----
        Compatibility wrapper around :meth:`realize_to_hdf5`.
        """
        self.realize_to_hdf5(activity_groups, strategy="memory", overwrite=False)


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
