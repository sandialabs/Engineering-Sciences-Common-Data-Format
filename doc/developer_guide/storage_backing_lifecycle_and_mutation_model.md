# ESCDF Storage, Lifecycle, and Mutation Model

## Purpose

This document summarizes ESCDF lifecycle and logical-mutation semantics.

Physical backing identity, logical/backing graph comparison, realization,
and synchronization are defined in
`realization_and_synchronization.md`.

---

## Core Principles

1. CRUD operations mutate the in-memory logical object graph.
2. Logical mutation does not immediately rename, remove, or replace HDF5
   objects in a source file.
3. HDF5 backing identity is represented by `HDF5Location`, not by stored
   native/external flags.
4. Memory-backed objects have no HDF5 backing location.
5. Whether backing is native or external is derived relative to a target.
6. Realization requirements are computed with `needs_realization(target)`,
   not maintained as authoritative mutable flags.
7. HDF5 handles may be cached for I/O, but backing-location comparisons
   use normalized file and HDF5 object paths.

---

## Logical Object Graph

The logical graph is:

```text
ESCDF container
├── metadata datasets
│   └── properties
└── activities
    └── activity datasets
        └── properties
```

Each child stores a logical parent reference. The logical ancestry is
bottom-up:

```text
property → dataset → activity → container
```

or:

```text
property → metadata dataset → container
```

A free object has no logical parent.

Ordinary language-level aliasing does not change logical parentage.
Explicit add, remove, attach, and replacement operations do.

---

## Logical Mutation

### Add and attach

Adding an existing dataset creates a new wrapper in the destination
logical graph.

- memory-backed property payloads are copied for the first implementation;
- HDF5-backed property wrappers may retain the source backing location;
- source objects and source HDF5 files remain unchanged.

### Remove

Removal detaches an object from its logical parent and returns the removed
object where appropriate.

The removed object may retain its HDF5 backing location. Physical source
data is not deleted immediately.

### Rename

Rename changes the logical name and therefore the root-relative logical
path. Existing HDF5 backing paths are not renamed immediately.

### Replace

Replacement removes the old logical child and attaches the replacement.
The replaced object is returned where appropriate. Physical backing is
reconciled during realization.

---

## Lifecycle and Mutability

### Draft

A draft container may be incomplete and editable. It may exist only in
memory or be persisted as a working file.

### Finalized

A finalized container represents canonical frozen content. Future
implementation should prevent direct mutation and require an explicit
editable draft copy.

### Read-only

Read-only is an access/mutability mode and is distinct from lifecycle.
Draft and finalized files may both be opened read-only.

Lifecycle enforcement and persisted lifecycle metadata remain future work.

---

## Identity and Equality

Python:

```text
is                         object identity
==                         semantic equality, where implemented
same_logical_location_as   same object-reference ancestry
same_backing_location_as   same HDF5 file and object path
```

MATLAB:

```text
== / verifySameHandle      handle identity
semantic_equals            future explicit semantic equality
same_logical_location_as   same handle ancestry
same_backing_location_as   same HDF5 file and object path
```

MATLAB `==` remains handle identity and is not overloaded for semantic
equality.

---

## Public Write vs Internal Realization

`write_to_disk(path)` is a top-level container API that creates a complete
ESCDF file.

Lower-level objects expose:

```text
realize_to_hdf5(parent, strategy, overwrite)
```

The supplied HDF5 object is the logical HDF5 parent:

```text
property → dataset group
dataset  → file root or activity group
activity → activities group
container → HDF5 file
```

Lower-level `write_to_disk(...)` methods are intentionally not part of the
API.

---

## Future Work

- finalized/frozen lifecycle enforcement;
- direct HDF5-to-HDF5 realization;
- streamed/chunked copy;
- extensible arrays;
- partial synchronization;
- efficient attachment mutation;
- explicit advanced I/O sessions.