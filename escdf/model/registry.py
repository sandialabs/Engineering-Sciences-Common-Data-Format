from __future__ import annotations

from pathlib import Path

from .specification import (
    Specification,
    ResolvedSpecification,
    PropertyDefinition,
    ConstraintRule,
    StorageHint,
)
from .parser import SpecificationParser


class SpecificationRegistry:
    """
    Registry for loading, caching, and resolving ESCDF specifications.

    Notes
    -----
    This class is intended to become the central interface for
    specification discovery, canonical parsing, inheritance resolution,
    and caching.

    The registry maintains two conceptually distinct stores:

    - local specifications, which are parsed directly from individual
      specification files
    - resolved specifications, which are effective specifications after
      inheritance resolution
    """

    __slots__ = (
        "_local_specifications",
        "_resolved_specifications",
        "_loaded_directories",
    )

    def __init__(self):
        """
        Initialize an empty specification registry.
        """
        self._local_specifications: dict[str, Specification] = {}
        self._resolved_specifications: dict[str, ResolvedSpecification] = {}
        self._loaded_directories: list[str] = []

    @property
    def local_specifications(self) -> dict[str, Specification]:
        """
        Return a copy of the loaded local specification map.

        Returns
        -------
        dict of {str: Specification}
            Mapping from specification name to local specification object.
        """
        return dict(self._local_specifications)

    @property
    def resolved_specifications(self) -> dict[str, ResolvedSpecification]:
        """
        Return a copy of the resolved specification cache.

        Returns
        -------
        dict of {str: ResolvedSpecification}
            Mapping from specification name to resolved specification
            object.
        """
        return dict(self._resolved_specifications)

    @property
    def loaded_directories(self) -> list[str]:
        """
        Return directories that have been loaded into the registry.

        Returns
        -------
        list of str
            Previously loaded specification directories.
        """
        return list(self._loaded_directories)

    def has_local(self, name: str) -> bool:
        """
        Return whether a local specification is loaded.

        Parameters
        ----------
        name : str
            Specification name.

        Returns
        -------
        bool
            ``True`` if a local specification with the given name is
            loaded.
        """
        return name in self._local_specifications

    def has_resolved(self, name: str) -> bool:
        """
        Return whether a resolved specification is cached.

        Parameters
        ----------
        name : str
            Specification name.

        Returns
        -------
        bool
            ``True`` if a resolved specification with the given name is
            cached.
        """
        return name in self._resolved_specifications

    def get_local(self, name: str) -> Specification:
        """
        Return a loaded local specification.

        Parameters
        ----------
        name : str
            Specification name.

        Returns
        -------
        Specification
            Local specification object.

        Raises
        ------
        KeyError
            Raised if no local specification with the given name is
            loaded.
        """
        try:
            return self._local_specifications[name]
        except KeyError as exc:
            raise KeyError(f'No local specification named "{name}" is loaded.') from exc

    def get_resolved(self, name: str) -> ResolvedSpecification:
        """
        Return a cached resolved specification.

        Parameters
        ----------
        name : str
            Specification name.

        Returns
        -------
        ResolvedSpecification
            Resolved specification object.

        Raises
        ------
        KeyError
            Raised if no resolved specification with the given name is
            cached.
        """
        try:
            return self._resolved_specifications[name]
        except KeyError as exc:
            raise KeyError(f'No resolved specification named "{name}" is loaded.') from exc

    def list_local_names(self) -> list[str]:
        """
        Return loaded local specification names.

        Returns
        -------
        list of str
            Sorted list of loaded local specification names.
        """
        return sorted(self._local_specifications.keys())

    def list_resolved_names(self) -> list[str]:
        """
        Return cached resolved specification names.

        Returns
        -------
        list of str
            Sorted list of cached resolved specification names.
        """
        return sorted(self._resolved_specifications.keys())

    def clear(self) -> None:
        """
        Clear all registry state.

        Notes
        -----
        This removes all loaded local specifications, all cached resolved
        specifications, and all loaded-directory records.
        """
        self._local_specifications.clear()
        self._resolved_specifications.clear()
        self._loaded_directories.clear()

    def add_local_specification(self, specification: Specification) -> None:
        """
        Add a local specification to the registry.

        Parameters
        ----------
        specification : Specification
            Local specification object to register.

        Raises
        ------
        ValueError
            Raised if the input is not a ``Specification`` object or if a
            local specification with the same name is already present.
        """
        if not isinstance(specification, Specification):
            raise ValueError("specification must be a Specification object.")
        if specification.name in self._local_specifications:
            raise ValueError(f'A local specification named "{specification.name}" already exists.')
        self._local_specifications[specification.name] = specification

    def add_resolved_specification(self, specification: ResolvedSpecification) -> None:
        """
        Add or replace a resolved specification in the cache.

        Parameters
        ----------
        specification : ResolvedSpecification
            Resolved specification object to cache.

        Raises
        ------
        ValueError
            Raised if the input is not a ``ResolvedSpecification`` object.
        """
        if not isinstance(specification, ResolvedSpecification):
            raise ValueError("specification must be a ResolvedSpecification object.")
        self._resolved_specifications[specification.name] = specification

    def mark_directory_loaded(self, directory: str) -> None:
        """
        Record a specification directory as loaded.

        Parameters
        ----------
        directory : str
            Directory path.

        Notes
        -----
        Duplicate directory entries are not added.
        """
        if directory not in self._loaded_directories:
            self._loaded_directories.append(directory)

    def load_from_directory(self, directory: str) -> None:
        """
        Load specification files from a directory.

        Parameters
        ----------
        directory : str
            Directory containing specification files.

        Raises
        ------
        FileNotFoundError
            Raised if the directory does not exist.
        ValueError
            Raised if duplicate specification names are encountered.

        Notes
        -----
        This method:
        - discovers ``*.txt`` specification files in the directory
        - parses each file into a local ``Specification``
        - registers each local specification
        - clears any cached resolved specifications
        - records the loaded directory

        This method does not automatically resolve all specifications;
        resolution remains demand-driven unless ``resolve_all()`` is
        called explicitly.
        """
        path = Path(directory)
        if not path.is_dir():
            raise FileNotFoundError(f"Specification directory not found: {directory}")

        spec_files = sorted(path.glob("*.txt"))
        for spec_file in spec_files:
            specification = SpecificationParser.parse_file(str(spec_file))
            self.add_local_specification(specification)

        # Local specifications changed, so resolved cache is no longer trustworthy.
        self._resolved_specifications.clear()
        self.mark_directory_loaded(str(path))

    def resolve(self, specification_name: str) -> ResolvedSpecification:
        """
        Resolve and return an effective specification.

        Parameters
        ----------
        specification_name : str
            Name of the specification to resolve.

        Returns
        -------
        ResolvedSpecification
            Effective resolved specification object.

        Raises
        ------
        KeyError
            Raised if the specification is not loaded.
        ValueError
            Raised if inheritance resolution detects a cycle.

        Notes
        -----
        Resolution behavior:
        - returns a cached resolved specification if available
        - otherwise walks the inheritance chain from parent to child
        - merges properties, enumerations, constraints, and storage hints
        - eagerly constructs the ``ResolvedSpecification``
        - caches and returns the result
        """
        if specification_name in self._resolved_specifications:
            return self._resolved_specifications[specification_name]

        local_spec = self.get_local(specification_name)
        chain = self._build_resolution_chain(specification_name)

        ancestry = [spec.name for spec in reversed(chain)]
        property_definitions: list[PropertyDefinition] = []
        enumerations: dict[str, list[str]] = {}
        constraints: list[ConstraintRule] = []
        storage_hints: list[StorageHint] = []

        # Parent-to-child merge order
        for spec in reversed(chain):
            property_definitions.extend(spec.local_properties)

            # Child overrides parent on enumeration name collisions
            enumerations.update(spec.enumerations)

            # Conservative accumulation for constraints
            constraints.extend(spec.constraints)

            # Storage hints: child overrides parent when same property_name/kind pair
            storage_hints = self._merge_storage_hints(storage_hints, spec.storage_hints)

        resolved = ResolvedSpecification(
            name=local_spec.name,
            version=local_spec.version,
            ancestry=ancestry,
            property_definitions=property_definitions,
            enumerations=enumerations,
            constraints=constraints,
            storage_hints=storage_hints,
        )

        self._resolved_specifications[specification_name] = resolved
        return resolved

    def resolve_all(self) -> None:
        """
        Resolve all loaded local specifications.

        Notes
        -----
        This method forces construction and caching of all effective
        resolved specifications currently loaded in the registry.
        """
        for specification_name in self.list_local_names():
            self.resolve(specification_name)

    def reload(self) -> None:
        """
        Reload all previously loaded specification directories.

        Raises
        ------
        FileNotFoundError
            Raised if a previously loaded directory no longer exists.
        ValueError
            Raised if loading a reloaded directory fails.

        Notes
        -----
        This method:
        - remembers previously loaded directories
        - clears all registry state
        - reloads each remembered directory
        """
        directories = self.loaded_directories
        self.clear()
        for directory in directories:
            self.load_from_directory(directory)

    def _build_resolution_chain(self, specification_name: str) -> list[Specification]:
        """
        Build the inheritance chain for a specification.

        Parameters
        ----------
        specification_name : str
            Name of the specification to resolve.

        Returns
        -------
        list of Specification
            Resolution chain beginning with the requested local
            specification and proceeding upward through its parent chain.

        Raises
        ------
        KeyError
            Raised if a required parent specification is not loaded.
        ValueError
            Raised if an inheritance cycle is detected.
        """
        chain: list[Specification] = []
        seen: set[str] = set()

        current_name = specification_name
        while current_name is not None:
            if current_name in seen:
                raise ValueError(
                    f'Inheritance cycle detected while resolving "{specification_name}".'
                )
            seen.add(current_name)

            spec = self.get_local(current_name)
            chain.append(spec)
            current_name = spec.extends

        return chain

    def _merge_storage_hints(
        self,
        existing_hints: list[StorageHint],
        new_hints: list[StorageHint],
    ) -> list[StorageHint]:
        """
        Merge storage hints with child-level override behavior.

        Parameters
        ----------
        existing_hints : list of StorageHint
            Previously accumulated storage hints.
        new_hints : list of StorageHint
            Newly added storage hints, typically from a child
            specification.

        Returns
        -------
        list of StorageHint
            Merged storage-hint list.

        Notes
        -----
        The current override rule is based on the pair
        ``(property_name, kind)``. If a new hint has the same pair as an
        existing hint, the new hint replaces the old one.
        """
        merged: dict[tuple[str, str], StorageHint] = {}

        for hint in existing_hints:
            merged[(hint.property_name, hint.kind)] = hint

        for hint in new_hints:
            merged[(hint.property_name, hint.kind)] = hint

        return list(merged.values())

    @staticmethod
    def get_default_specification_directory() -> Path:
        """
        Return the packaged ESCDF specification directory.

        Returns
        -------
        pathlib.Path
            Path to the packaged ESCDF specification directory.
        """
        return Path(__file__).resolve().parent.parent / "specifications"

    @staticmethod
    def build_default_registry() -> "SpecificationRegistry":
        """
        Build a specification registry from the packaged ESCDF
        specifications.

        Returns
        -------
        SpecificationRegistry
            Registry loaded from the packaged specification directory.
        """
        registry = SpecificationRegistry()
        registry.load_from_directory(
            str(SpecificationRegistry.get_default_specification_directory())
        )
        return registry