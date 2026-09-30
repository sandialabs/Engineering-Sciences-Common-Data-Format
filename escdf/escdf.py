# -*- coding: utf-8 -*-
"""
Core ESCDF container implementation.

This module defines :class:`ESCDF`, the top-level container used to
organize metadata datasets, activities, and file-level creation metadata
for an ESCDF HDF5 file.
"""
from __future__ import annotations

import numpy as np
import h5py as h5
import warnings
from .escdf_activity import ESCDFActivity, ESCDFActivityArray
from .escdf_dataset import ESCDFDataset, ESCDFDatasetArray
from .escdf_property import ESCDFProperty
from .escdf_timestamps import _datetime_to_iso_utc, _datetime_from_iso_utc
from .valid_names import is_valid_identifier, make_valid_identifier
import json
import os
import sys
import tempfile

import datetime as dt
from datetime import datetime, timezone
from pathlib import Path

LIB_DISPLAY_NAME = "ESCDF"  # folder name on Windows/macOS
LIB_ID = "escdf"  # folder name on Linux (conventionally lowercase)


class ESCDF:
    """
    Container for one ESCDF file.

    An ``ESCDF`` object represents the in-memory contents of a single ESCDF
    HDF5 file, including top-level metadata datasets, activity datasets,
    and file-level creation metadata.

    The container separates datasets into two conceptual groups:

    - metadata datasets, which describe shared context such as geometry,
      channel tables, or global test attributes
    - activity datasets, which represent results associated with a specific
      test, analysis step, or processing activity

    Parameters
    ----------
    None

    Notes
    -----
    When a new container is created, the ``created_by`` field is populated
    using :meth:`get_or_prompt_attribution_name`, which may prompt the user
    for an attribution name if one has not already been cached in the local
    ESCDF configuration file.

    See Also
    --------
    ESCDFDataset
    ESCDFActivity
    """

    __slots__ = (
        "_activities",
        "_metadata",
        "_created_by",
        "_created_date",
        "_lifecycle_state",
        "_mutability_state",
        "_backing_state",
        "_has_pending_changes",
    )

    @property
    def activities(self):
        return self._activities

    @property
    def metadata(self):
        return self._metadata

    @property
    def created_by(self):
        return self._created_by

    @property
    def created_date(self):
        return self._created_date

    @property
    def lifecycle_state(self):
        return self._lifecycle_state

    @property
    def mutability_state(self):
        return self._mutability_state

    @property
    def backing_state(self):
        return self._backing_state

    @property
    def has_pending_changes(self):
        return self._has_pending_changes

    def __init__(self):
        """
        Initialize an empty ESCDF container.

        Notes
        -----
        A new container starts with no metadata datasets and no activities.
        File-level creation metadata is initialized immediately.
        """
        self._activities = ESCDFActivityArray()
        self._metadata = ESCDFDatasetArray()
        self._created_by = ESCDF.get_or_prompt_attribution_name()
        self._created_date = datetime.now(timezone.utc)

        self._lifecycle_state = "draft"
        self._mutability_state = "editable"
        self._backing_state = "memory"
        self._has_pending_changes = False

    def set_created_properties(self, created_by, created_date=None):
        """
        Set file-level creation metadata.

        Parameters
        ----------
        created_by : str
            Name or label to record as the file creator.
        created_date : datetime.datetime, optional
            Creation timestamp to associate with the file. If omitted, the
            existing ``created_date`` value is retained.

        Raises
        ------
        ValueError
            If ``created_date`` is provided but is not a
            ``datetime.datetime`` instance.
        """
        if created_date is not None:
            if isinstance(created_date, datetime):
                self._created_date = created_date
            else:
                raise ValueError("created_date must be a `datetime` object.")
        self._created_by = created_by
        self._has_pending_changes = True

    def add_activity(
        self, short_name, descriptive_name, activity_date, data=None, metadata_links=None
    ):
        """
        Add a new activity to the container.

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
            Initial activity result datasets to add to the activity.
        metadata_links : iterable of str, optional
            Names of metadata datasets linked to this activity.

        Raises
        ------
        ValueError
            If an activity with the same name already exists, or if any
            metadata link does not correspond to an existing metadata
            dataset.

        Notes
        -----
        Datasets stored in an activity should be of type
        ``activity_result`` or inherit from it.
        """
        if any([name == short_name for name in self.activities.names]):
            raise ValueError("An activity with name {:} already exists.".format(short_name))
        if metadata_links is not None:
            for link_name in metadata_links:
                if not link_name in self.metadata.names:
                    raise ValueError(
                        "Metadata link name {:} not found in metadata list".format(link_name)
                    )
        new_activity = ESCDFActivity(
            short_name, descriptive_name, activity_date, data, metadata_links
        )
        self.activities.add_activity(new_activity)
        self._has_pending_changes = True

    def add_metadata(self, metadata, activity_to_link=None):
        """
        Add a metadata dataset to the container.

        Parameters
        ----------
        metadata : ESCDFDataset
            Metadata dataset to add.
        activity_to_link : str, optional
            Name of an activity that should be linked to the metadata
            immediately after insertion.

        Raises
        ------
        ValueError
            If the dataset name already exists in the metadata collection
            or if the linked activity name is invalid.

        Notes
        -----
        The supplied dataset is cloned into a new wrapper before
        insertion so that the container owns its own dataset/property
        wrapper objects.
        """
        metadata_to_add = self._clone_dataset_for_attach(metadata)
        self.metadata.add_dataset(metadata_to_add)
        if activity_to_link is not None:
            self.activities[activity_to_link].link_to_metadata(metadata_to_add.name)
        self._has_pending_changes = True

    def add_metadata_with_duplicate_check(self, metadata, activity_to_link=None):
        """
        Add metadata unless an identical dataset already exists.

        Parameters
        ----------
        metadata : ESCDFDataset
            Metadata dataset to add or match against existing metadata.
        activity_to_link : str, optional
            Name of an activity that should be linked to the resulting
            metadata dataset.

        Returns
        -------
        str
            Name of the added metadata dataset, or the existing matching
            metadata dataset if a duplicate was detected.

        Notes
        -----
        Equality is determined using dataset-level equality checks on
        dataset type and property contents.
        """
        for existing_metadata in self.metadata:
            metadata_is_new = True
            if metadata == existing_metadata:
                metadata_is_new = False
                print(
                    f"Did not add {metadata.dataset_type} {metadata.name} because it was identical to {existing_metadata.name}"
                )
                break
        if metadata_is_new:
            self.add_metadata(metadata, activity_to_link)
            name = metadata.name
        else:
            name = existing_metadata.name
            if activity_to_link is not None:
                self.link_activity_to_metadata(activity_to_link, name)
        if metadata_is_new or (activity_to_link is not None):
            self._has_pending_changes = True
        return name

    def link_activity_to_metadata(self, activity_name, metadata_name):
        """
        Link an activity to a metadata dataset.

        Parameters
        ----------
        activity_name : str
            Name of the activity to update.
        metadata_name : str
            Name of the metadata dataset to link.

        Raises
        ------
        ValueError
            If ``metadata_name`` does not correspond to an existing
            metadata dataset.
        """
        if not metadata_name in self.metadata.names:
            raise ValueError(
                "Name {:} does not correspond to any defined metadata names".format(metadata_name)
            )
        self.activities[activity_name].link_to_metadata(metadata_name)
        self._has_pending_changes = True

    def unlink_activity_from_metadata(self, activity_name, metadata_name):
        """
        Remove a metadata link from an activity.

        Parameters
        ----------
        activity_name : str
            Name of the activity to update.
        metadata_name : str
            Name of the metadata dataset to unlink.
        """
        self.activities[activity_name].unlink_from_metadata(metadata_name)
        self._has_pending_changes = True

    def add_data_to_activity(self, activity_name, data):
        """
        Add a result dataset to an activity.

        Parameters
        ----------
        activity_name : str
            Name of the activity to modify.
        data : ESCDFDataset
            Dataset to add to the activity.

        Notes
        -----
        The supplied dataset is cloned into a new wrapper before
        insertion so that the activity/container owns its own
        dataset/property wrapper objects.
        """
        data_to_add = self._clone_dataset_for_attach(data)
        self.activities[activity_name].add_data(data_to_add)
        self._has_pending_changes = True

    def remove_data_from_activity(self, activity_name, data_name):
        """
        Remove a dataset from an activity.

        Parameters
        ----------
        activity_name : str
            Name of the activity to modify.
        data_name : str
            Name of the dataset to remove.
        """
        self.activities[activity_name].remove_data(data_name)
        self._has_pending_changes = True

    def get_activity_data(self, activity_name, data_name=None):
        """
        Retrieve one or more datasets from an activity.

        Parameters
        ----------
        activity_name : str
            Name of the activity to query.
        data_name : str, optional
            Name of a specific dataset within the activity. If omitted, all
            datasets in the activity are returned.

        Returns
        -------
        ESCDFDataset or ESCDFDatasetArray
            Requested dataset, or all datasets in the activity.
        """
        return self.activities[activity_name].get_data(data_name)

    def repr(self):
        metadata_names = sorted(self.metadata.names)
        out = f"\nESCDF\n    Created by {self.created_by} on {self.created_date}\n\n  Metadata:\n"
        for name in metadata_names:
            metadata = self.metadata[name]
            out += "\n    {:} ({:})".format(name, metadata.dataset_type)
        out += "\n\n  Activities:\n"
        out += self.activities.repr()
        return out

    def __repr__(self):
        return self.repr()

    def get_activity_metadata(self, activity_name):
        """
        Retrieve metadata datasets linked to an activity.

        Parameters
        ----------
        activity_name : str
            Name of the activity to query.

        Returns
        -------
        ESCDFDatasetArray
            Metadata datasets linked to the activity.
        """
        metadata = [self.metadata[name] for name in self.activities[activity_name].metadata_links]
        return ESCDFDatasetArray(metadata)

    @staticmethod
    def _clone_property_for_attach(property_):
        """
        Clone a property wrapper for attachment into a new container.

        Parameters
        ----------
        property_ : ESCDFProperty
            Source property to clone.

        Returns
        -------
        ESCDFProperty
            New property wrapper suitable for attachment into a new
            dataset/container context.

        Notes
        -----
        First-pass behavior:

        - memory-backed properties are eagerly copied into new in-memory
          property wrappers
        - ``hdf5_native`` properties are wrapped as ``hdf5_external`` in
          the clone
        - ``hdf5_external`` properties remain externally backed in the
          clone
        """
        if property_.backing_state == "memory":
            cloned = ESCDFProperty(
                property_.name,
                property_.datatype,
                property_.shape,
                ragged=property_.ragged,
            )
            cloned[...] = property_[...]
            return cloned

        if property_.backing_state in {"hdf5_native", "hdf5_external"}:
            cloned = ESCDFProperty.load(h5_dataset=property_.h5_dataset)
            cloned.mark_external_backing()
            return cloned

        raise ValueError(
            f'Unknown property backing_state "{property_.backing_state}" for property {property_.name}.'
        )

    @classmethod
    def _clone_dataset_for_attach(cls, dataset):
        """
        Clone a dataset wrapper for attachment into a new container.

        Parameters
        ----------
        dataset : ESCDFDataset
            Source dataset to clone.

        Returns
        -------
        ESCDFDataset
            New dataset wrapper suitable for insertion into a different
            container.

        Notes
        -----
        This is a first-pass shallow-semantic clone of the dataset
        wrapper, with per-property handling delegated to
        :meth:`_clone_property_for_attach`.
        """
        cloned = ESCDFDataset(
            dataset.name,
            dataset.dataset_type,
            dataset.descriptive_name,
            replace_invalid_names=False,
        )
        cloned.set_version(*dataset.version_numbers)

        for property_name in sorted(dataset._valid_properties):
            property_value = getattr(dataset, property_name, None)
            if property_value is None:
                continue

            if property_name not in cloned._valid_properties:
                cloned._valid_properties.add(property_name)
                cloned._modified_properties.add(property_name)
                cloned._has_modified_properties = True

            setattr(cloned, property_name, cls._clone_property_for_attach(property_value))

        # Preserve malformed/extra-property state if present.
        cloned._has_modified_properties = (
            dataset.has_modified_properties or cloned._has_modified_properties
        )
        cloned._modified_properties.update(dataset._modified_properties)

        cloned._backing_state = "memory"
        cloned._has_pending_changes = False
        return cloned

    def _insert_metadata_native(self, metadata, activity_to_link=None):
        """
        Insert a metadata dataset into the container without cloning.

        Parameters
        ----------
        metadata : ESCDFDataset
            Metadata dataset to insert directly.
        activity_to_link : str, optional
            Name of an activity to link to the metadata immediately after
            insertion.

        Notes
        -----
        This is intended for internal use during file loading, where the
        loaded dataset already belongs natively to the container being
        constructed.
        """
        self.metadata.add_dataset(metadata)
        if activity_to_link is not None:
            self.activities[activity_to_link].link_to_metadata(metadata.name)
        self._has_pending_changes = True

    def _insert_data_to_activity_native(self, activity_name, data):
        """
        Insert a dataset into an activity without cloning.

        Parameters
        ----------
        activity_name : str
            Name of the target activity.
        data : ESCDFDataset
            Dataset to insert directly.

        Notes
        -----
        This is intended for internal use during file loading, where the
        loaded dataset already belongs natively to the container being
        constructed.
        """
        self.activities[activity_name].add_data(data)
        self._has_pending_changes = True

    def write_to_disk(self, h5_file, clobber=False):
        """
        Write the container to an HDF5 file.

        Parameters
        ----------
        h5_file : str or h5py.File
            Output file path or an open HDF5 file handle.
        clobber : bool, optional
            If ``True`` and ``h5_file`` is a path, overwrite an existing
            file. If ``False``, require that the target file not already
            exist.

        Returns
        -------
        h5py.File
            Open HDF5 file handle containing the written ESCDF data.

        Raises
        ------
        ValueError
            If any metadata or activity dataset fails validation before
            writing.

        Notes
        -----
        All contained datasets are validated before any HDF5 content is
        written.
        """
        # First go through and validate the metadata
        for metadata in self.metadata:
            if not metadata.validate():
                raise ValueError(
                    "Cannot write to disk, metadata {:} is invalid.".format(metadata.name)
                )
        # Now go through and make sure all data is valid
        for activity in self.activities:
            for data in activity.data:
                if not data.validate():
                    raise ValueError(
                        "Cannot write to disk, data {:} from activity {:} is invalid.".format(
                            data.name, activity.name
                        )
                    )
        # Now create the file
        if isinstance(h5_file, str):
            if clobber:
                h5_file = h5.File(h5_file, "w")
            else:
                h5_file = h5.File(h5_file, "x")
        h5_file.attrs["created_by"] = self.created_by
        h5_file.attrs["created_date"] = _datetime_to_iso_utc(self.created_date)
        for metadata in self.metadata:
            group = h5_file.create_group(metadata.name)
            metadata.write_to_disk(group)
        activity_group = h5_file.create_group("activities")
        for activity in self.activities:
            activity.write_to_disk(activity_group)
        self._backing_state = "hdf5_native"
        self._has_pending_changes = False
        h5_file.flush()
        return h5_file

    @classmethod
    def load(cls, h5_file, readonly=True):
        """
        Load an ESCDF container from an HDF5 file.

        Parameters
        ----------
        h5_file : str or h5py.File
            Input file path or an open HDF5 file handle.
        readonly : bool, optional
            If ``True``, open the file in read-only mode when a path is
            provided. If ``False``, open in read/write mode.

        Returns
        -------
        ESCDF
            Loaded ESCDF container.

        Notes
        -----
        Unknown dataset types are loaded using the ``unknown``
        specification. Invalid identifiers encountered on disk may be
        repaired during loading to produce valid in-memory dataset and
        activity names.
        """
        escdf_file = cls()
        if isinstance(h5_file, str):
            if readonly:
                h5_file = h5.File(h5_file, "r")
            else:
                h5_file = h5.File(h5_file, "r+")
        try:
            created_by = h5_file.attrs["created_by"]
            if isinstance(created_by, (bytes, np.bytes_)):
                created_by = created_by.decode()
        except KeyError:
            warnings.warn(f'Unable to read created_by field.  Setting to "UNKNOWN"')
            created_by = "UNKNOWN"
        try:
            created_date_field = h5_file.attrs["created_date"]
            if isinstance(created_date_field, (bytes, np.bytes_)):
                created_date_field = created_date_field.decode()
            created_date = _datetime_from_iso_utc(created_date_field)
        except (ValueError, KeyError):
            warnings.warn(f"Unable to read created_date field.  Setting to 01-Jan-1900")
            created_date = dt.datetime(1900, 1, 1, tzinfo=timezone.utc)
        escdf_file.set_created_properties(created_by, created_date)
        metadata_names = [
            key
            for key in h5_file.keys()
            if isinstance(h5_file[key], h5.Group) and not key == "activities"
        ]
        for name in metadata_names:
            dataset = ESCDFDataset.load(h5_file, name)
            dataset = ESCDFDataset.load(h5_file, name)
            escdf_file._insert_metadata_native(dataset)
        activity_groups = h5_file["activities"]
        activity_names = [
            key for key in activity_groups.keys() if isinstance(activity_groups[key], h5.Group)
        ]
        for activity_name in activity_names:
            activity_group = activity_groups[activity_name]
            long_name = activity_group.attrs["activity_name"]
            if isinstance(long_name, (bytes, np.bytes_)):
                long_name = long_name.decode()
            try:
                date = _datetime_from_iso_utc(activity_group.attrs["activity_date"])
            except ValueError:
                date = dt.datetime(1900, 1, 1, tzinfo=timezone.utc)
                warnings.warn(
                    f'Unable to convert {activity_group.attrs["activity_date"]} to datetime using the ISO format.  Setting date to 01-Jan-1900 for activity {activity_name}'
                )
            except KeyError:
                date = dt.datetime(1900, 1, 1, tzinfo=timezone.utc)
                warnings.warn(
                    f'Unable to find activity date for activity {activity_name}.  Setting date to 01-Jan-1900 for activity {activity_name}.'
                )
            name_valid = is_valid_identifier(activity_name)
            if not name_valid:
                valid_activity_name = make_valid_identifier(activity_name, 'activity_')
            else:
                valid_activity_name = activity_name
            escdf_file.add_activity(valid_activity_name, long_name, date)
            try:
                links = activity_group["parameters"][...]
            except KeyError:
                warnings.warn(f"Activity {activity_name} missing parameters dataset; assuming no metadata links.")
                links = []
            for metadata_name in links:
                if isinstance(metadata_name, (bytes, np.bytes_)):
                    metadata_name = metadata_name.decode()
                name_valid = is_valid_identifier(metadata_name)
                if not name_valid:
                    metadata_name = make_valid_identifier(metadata_name, 'dataset_')
                escdf_file.link_activity_to_metadata(valid_activity_name, metadata_name)
            activity_data_names = [
                key for key in activity_group.keys() if isinstance(activity_group[key], h5.Group)
            ]
            for activity_data_name in activity_data_names:
                dataset = ESCDFDataset.load(h5_group=activity_group[activity_data_name])
                escdf_file._insert_data_to_activity_native(valid_activity_name, dataset)
        escdf_file._backing_state = "hdf5_native"
        escdf_file._lifecycle_state = "draft"
        escdf_file._mutability_state = "read_only" if readonly else "editable"
        escdf_file._has_pending_changes = False
        return escdf_file

    @staticmethod
    def _config_path() -> Path:
        """
        Return the platform-specific ESCDF configuration file path.

        Returns
        -------
        pathlib.Path
            Path to the JSON configuration file used to cache the
            attribution name and related metadata.
        """
        if sys.platform.startswith("win"):
            base = os.environ.get("APPDATA")  # Roaming
            if not base:
                base = str(Path.home())
            return Path(base) / LIB_DISPLAY_NAME / "config.json"

        if sys.platform == "darwin":
            return (
                Path.home() / "Library" / "Application Support" / LIB_DISPLAY_NAME / "config.json"
            )

        # Linux/Unix
        xdg = os.environ.get("XDG_CONFIG_HOME")
        base = Path(xdg) if xdg else (Path.home() / ".config")
        return base / LIB_ID / "config.json"

    @staticmethod
    def _atomic_write_text(path: Path, text: str) -> None:
        """
        Write text to a file using a replace-style atomic update.

        Parameters
        ----------
        path : pathlib.Path
            Target file path.
        text : str
            Text content to write.

        Notes
        -----
        The file is written to a temporary file in the destination
        directory and then moved into place with :func:`os.replace`.
        """
        path.parent.mkdir(parents=True, exist_ok=True)
        # write to temp file in same directory then replace (atomic on most filesystems)
        with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=str(path.parent), delete=False
        ) as tf:
            tmp_name = tf.name
            tf.write(text)
            tf.flush()
            os.fsync(tf.fileno())
        os.replace(tmp_name, path)

    @staticmethod
    def load_config() -> dict:
        """
        Load the local ESCDF JSON configuration file.

        Returns
        -------
        dict
            Parsed configuration dictionary. If the configuration file does
            not exist or cannot be read, an empty dictionary is returned.
        """
        path = ESCDF._config_path()
        if not path.is_file():
            return {}
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            # If corrupted, treat as missing; you could also raise.
            return {}

    @staticmethod
    def save_config(cfg: dict) -> None:
        """
        Save the local ESCDF JSON configuration file.

        Parameters
        ----------
        cfg : dict
            Configuration dictionary to serialize.

        Notes
        -----
        A schema version and update timestamp are added automatically if
        not already present.
        """
        cfg = dict(cfg)
        cfg.setdefault("schema_version", 1)
        cfg["updated_utc"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        text = json.dumps(cfg, indent=2, sort_keys=True) + "\n"
        ESCDF._atomic_write_text(ESCDF._config_path(), text)

    @staticmethod
    def get_or_prompt_attribution_name(
        *,
        interactive: bool = True,
        prompt: str = "Enter the name/label to record in files (e.g., 'anonymous', 'Team A', 'Dan R.'): ",
    ) -> str:
        """
        Return the configured attribution name or prompt the user for one.

        Parameters
        ----------
        interactive : bool, optional
            If ``True``, prompt the user when no cached attribution name is
            available. If ``False``, raise an error instead of prompting.
        prompt : str, optional
            Prompt string to use for interactive entry.

        Returns
        -------
        str
            Attribution name to record in newly created files.

        Raises
        ------
        RuntimeError
            If no attribution name is configured and interactive prompting
            is disabled.

        Notes
        -----
        When a name is entered interactively, it is stored in the local
        ESCDF configuration file for future use.
        """
        cfg = ESCDF.load_config()
        name = (cfg.get("attribution_name") or "").strip()
        if name:
            return name

        if not interactive:
            raise RuntimeError(
                "No attribution_name configured and interactive prompting is disabled. "
                f"Create {ESCDF._config_path()} with an 'attribution_name' field, or pass a name explicitly."
            )

        name = input(prompt).strip()
        if not name:
            name = "anonymous"

        cfg["attribution_name"] = name
        ESCDF.save_config(cfg)
        return name
