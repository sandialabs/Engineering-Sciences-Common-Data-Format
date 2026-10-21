from __future__ import annotations

from dataclasses import dataclass
import os


@dataclass(frozen=True)
class HDF5Location:
    """
    Runtime-local HDF5 backing location.

    Parameters
    ----------
    file_path : str
        File path for the HDF5 file.
    object_path : str
        Internal HDF5 object path.
    file_uuid : str, optional
        Optional future persistent file identifier.

    Notes
    -----
    This object is intended as a runtime/session-local descriptor. It is
    not currently intended to be a persistent cross-machine identifier.
    """

    file_path: str
    object_path: str
    file_uuid: str | None = None

    def __post_init__(self):
        normalized_file_path = self.normalize_file_path(self.file_path)
        normalized_object_path = self.normalize_object_path(self.object_path)

        object.__setattr__(self, "file_path", normalized_file_path)
        object.__setattr__(self, "object_path", normalized_object_path)

    @staticmethod
    def normalize_file_path(file_path: str) -> str:
        """
        Normalize an HDF5 file path.

        Parameters
        ----------
        file_path : str
            Input file path.

        Returns
        -------
        str
            Absolute, real-normalized file path.
        """
        return os.path.realpath(os.path.abspath(str(file_path)))

    @staticmethod
    def normalize_object_path(object_path: str) -> str:
        """
        Normalize an HDF5 internal object path.

        Parameters
        ----------
        object_path : str
            Input HDF5 object path.

        Returns
        -------
        str
            Normalized HDF5 object path.
        """
        object_path = str(object_path)
        if not object_path.startswith("/"):
            object_path = "/" + object_path
        if len(object_path) > 1:
            object_path = object_path.rstrip("/")
        return object_path

    @classmethod
    def from_h5_object(cls, h5_object) -> "HDF5Location":
        """
        Construct a location from an h5py object.

        Parameters
        ----------
        h5_object : h5py.File, h5py.Group, or h5py.Dataset
            HDF5 object.

        Returns
        -------
        HDF5Location
            Backing location for the HDF5 object.
        """
        return cls(h5_object.file.filename, h5_object.name)

    @classmethod
    def child_of_group(cls, h5_group, child_name: str) -> "HDF5Location":
        """
        Construct the location of a child object under a target HDF5 group.

        Parameters
        ----------
        h5_group : h5py.Group
            Parent HDF5 group.
        child_name : str
            Child object name.

        Returns
        -------
        HDF5Location
            Expected HDF5 location of the child object.
        """
        parent_path = h5_group.name
        if parent_path == "/":
            object_path = f"/{child_name}"
        else:
            object_path = f"{parent_path.rstrip('/')}/{child_name}"

        return cls(h5_group.file.filename, object_path)

    def same_file_as(self, other: "HDF5Location") -> bool:
        """
        Return whether two HDF5 locations refer to the same file identity.

        Parameters
        ----------
        other : HDF5Location
            Other location.

        Returns
        -------
        bool
            True if both locations refer to the same file.
        """
        if not isinstance(other, HDF5Location):
            return False

        if self.file_uuid is not None and other.file_uuid is not None:
            return self.file_uuid == other.file_uuid

        return self.file_path == other.file_path

    def same_location_as(self, other: "HDF5Location") -> bool:
        """
        Return whether two HDF5 locations refer to the same HDF5 object.

        Parameters
        ----------
        other : HDF5Location
            Other location.

        Returns
        -------
        bool
            True if both locations refer to the same file and object path.
        """
        return (
            isinstance(other, HDF5Location)
            and self.same_file_as(other)
            and self.object_path == other.object_path
        )
