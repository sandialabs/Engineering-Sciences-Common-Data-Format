# ESCDF Realization and Synchronization Model

## Purpose

This document defines the preferred direction for realization and
synchronization in ESCDF.

The goal is to describe how the current logical ESCDF object graph is
compared against a target backing representation, and how the system
decides whether objects or payloads need to be realized into that target.

This document supersedes earlier realization notes that centered on
manually maintained flags such as `has_pending_changes` or static backing
states such as `hdf5_native` and `hdf5_external`.

The preferred direction is:

> Realization state should be derived from comparing the current logical
> graph against a requested target backing representation, rather than
> maintained as a mutable flag.

---

## Core Design Principle

ESCDF should avoid storing contextual relationship states like:

- native
- external
- pending realization
- pending changes

as authoritative object state whenever those values can be derived from
more concrete information.

Instead, ESCDF should store or derive:

- the current logical location of an object in the in-memory object graph
- the current backing location of an object, if any
- the requested realization target

Then, at the time an operation is performed, ESCDF should derive:

- whether an object is in memory
- whether an object is already realized at the target
- whether an object needs realization
- whether a backing source is external relative to the target

---

## Logical Graph vs Backing Graph

ESCDF objects exist simultaneously in two conceptual graphs.

---

## Logical graph

The logical graph is the current in-memory ESCDF object graph.

Example:

```text
ESCDF container
├── metadata
│   └── geometry
│       ├── node_id
│       └── node_position
└── activities
    └── modal_test
        └── data
            └── time_data
                ├── abscissa
                └── ordinate
```

The logical graph is the user-facing editable object graph.

Logical operations include:

- add metadata
- remove metadata
- rename metadata
- replace metadata
- add activity
- remove activity
- rename activity
- add data to activity
- remove data from activity
- rename data
- replace data

These operations change the logical graph.

They should not automatically imply immediate mutation of the source HDF5
file.

---

## Backing graph

The backing graph describes where the data or structure currently exists
physically.

Examples:

```text
source_file.h5::/geometry/node_id
source_file.h5::/activities/modal_test/time_data/ordinate
```

Backing locations may refer to:

- an HDF5 file
- an HDF5 group
- an HDF5 dataset
- an in-memory payload, represented by the absence of an HDF5 backing
  location

The backing graph is not necessarily the same as the logical graph.

For example, a metadata dataset may be logically attached to a new
container while its properties are still backed by an HDF5 source file
loaded earlier.

---

## Object Locations

The preferred model uses locations rather than persistent native/external
flags.

---

## Logical location

A logical location describes where an object currently lives in the
in-memory ESCDF graph.

Examples:

```text
/metadata/geometry
/metadata/geometry/node_position
/activities/modal_test
/activities/modal_test/time_data
/activities/modal_test/time_data/ordinate
```

A logical location is meaningful only with respect to a particular
container object graph.

Two datasets with the same local name are not necessarily the same
logical object unless they also share the same logical parent/context.

---

## Backing location

A backing location describes where an object currently has physical
storage.

Examples:

```text
source_file.h5::/metadata/geometry
source_file.h5::/metadata/geometry/node_position
source_file.h5::/activities/modal_test/time_data/ordinate
```

For memory-backed objects, the backing location may be `None`.

A backing location should contain enough information to distinguish:

- file A vs file B
- group `/metadata/geometry` in one file vs the same path in another file
- dataset `/ordinate` in one dataset group vs another

A backing location may be implemented as a small value object or struct
containing:

- backing kind, such as `hdf5`
- file identity or file path
- HDF5 object path
- optionally an HDF5 object identifier or token

The exact implementation may evolve, but the conceptual role should
remain stable.

---

## In-Memory Objects

An in-memory object has no HDF5 backing location.

For example:

```text
backing_location = None
```

This means:

- the object or payload is currently represented in memory
- it is already realized with respect to its current memory
  representation
- it may still need realization if the target is an HDF5 file

In-memory does not necessarily mean free or unattached.

For example, a property can have:

```text
logical_parent = some dataset
backing_location = None
```

which means the property belongs to the dataset logically but its payload
is currently stored in memory.

---

## Free Objects

An object is free or unattached when it has no logical parent.

Example:

```text
logical_parent = None
```

This is distinct from being memory-backed.

A free object may still have an HDF5 backing location if it was loaded or
detached from a file, depending on how the API creates or returns it.

---

## Derived State

The following concepts should be derived at runtime rather than stored as
authoritative flags.

---

## In memory

An object is considered in memory if it has no HDF5 backing location.

```text
in_memory = backing_location is None
```

---

## Realized at target

An object is realized at a target when its current backing location
matches the backing location implied by the requested target.

Example:

```text
property.backing_location == target_group / property.name
```

If true, the property is already physically present at the requested
target location.

---

## External relative to target

An object is external relative to a target when it has an HDF5 backing
location but that backing location does not match the target location
being realized.

Example:

```text
property.backing_location = source_file.h5::/metadata/geometry/node_id
target_location           = target_file.h5::/metadata/geometry/node_id

property is external relative to target
```

External is therefore not an intrinsic object property. It is a derived
relationship between a backing location and a target location.

---

## Needs realization

An object needs realization relative to a target if:

- it is memory-backed and the target is persistent HDF5 storage
- its backing location differs from the target location
- one or more of its children need realization
- the target lacks required children that exist in the logical graph
- the target contains conflicting content and no overwrite/sync policy has
  been requested

This should be implemented as a method or computed property, not as a
manually maintained mutable flag.

Example:

```text
needs_realization(target) =
    not is_realized_at(target)
    OR any child needs realization at its corresponding child target
```

---

## Pending Changes

Earlier designs used `has_pending_changes` as a mutable flag.

The preferred direction is to avoid using manually maintained pending
change flags as the authoritative synchronization mechanism.

Reason:

- every editing operation would need to remember to update the flag
- flags can become desynchronized from actual object state
- changes such as rename, remove, replace, attach, and property assignment
  are better evaluated by comparing logical and backing graphs

If a UI or user-facing API later needs a convenience indicator such as
`needs_save`, that should ideally be derived from:

```text
needs_realization(current_target)
```

rather than maintained independently.

---

## Equality and Identity

ESCDF should distinguish several kinds of equality.

---

## Object identity

Object identity means two references point to the same programming object.

Python:

```text
a is b
```

MATLAB:

```text
same handle object
```

Object identity is not the same as value equality.

---

## Semantic equality

Semantic equality should answer:

```text
Do these objects contain the same ESCDF content?
```

For example, two independently loaded copies of the same file should
generally be semantically equal.

Semantic equality should compare:

- object type
- names and descriptive metadata where appropriate
- child objects
- property values
- links and relationships

Semantic equality should not necessarily require the same backing
location.

---

## Logical-location equality

Logical-location equality should answer:

```text
Do these objects occupy the same logical position in the same object graph?
```

For example:

```text
file_a.metadata["geometry"]
file_b.metadata["geometry"]
```

may be semantically equal but should not be considered the same logical
location unless they belong to the same logical container context.

---

## Backing-location equality

Backing-location equality should answer:

```text
Do these objects refer to the same physical backing location?
```

For HDF5-backed objects, this means:

- same file identity
- same HDF5 object path

This relationship is critical for synchronization and realization.

---

## Recommended Equality Semantics

Python and MATLAB differ in their object identity conventions.

In Python, object identity is checked with `is`, while `==` may be
implemented as semantic/value equality.

In MATLAB, ESCDF objects are handle classes, so `==` is preserved as
handle identity. Semantic equality, if needed, should be implemented with
an explicit method such as `semantic_equals` rather than by overloading
`==`.

This preserves normal MATLAB behavior while maintaining conceptual parity
between implementations.

---

## Assignment Semantics

Assignment must be safe with respect to backing locations.

---

## Property assignment

When assigning to a property:

```text
property[...] = value
```

the system should determine whether the current backing location may be
safely mutated.

A conceptual decision tree is:

```text
assign(property, value)
├── property has no HDF5 backing
│   └── write into memory
│
├── property backing location matches its current logical target
│   └── write through to HDF5 if mutability rules allow it
│
└── property backing location does not match logical target
    ├── do not write through to the backing source
    ├── materialize/detach into memory or a native target
    └── write the new value there
```

This avoids accidentally mutating a source file when a property has been
attached or copied into a different logical context.

---

## In-memory aliases

If a user creates an ordinary alias:

```text
property_alias = property
```

then both names refer to the same object.

Mutating through either alias mutates the same object.

This is ordinary programming-language reference behavior.

---

## Explicit copies

If a dataset or property is explicitly copied or attached into a new
container, the system should create new wrapper objects.

For first-pass behavior:

- HDF5-backed payloads may share the same backing location until realized
- memory-backed payloads should be eagerly copied
- future implementations may introduce copy-on-write memory backing if
  needed

This means:

```text
aliasing by assignment
```

and

```text
copying by attach/copy API
```

have different semantics.

---

## Attach and Copy Semantics

When an object is attached or copied into a different container:

```text
target.add_metadata(source_metadata)
```

the operation should:

- create a new wrapper object for the target logical graph
- assign the new wrapper a logical location in the target graph
- preserve backing locations from the source where practical
- avoid mutating the source backing
- allow realization later into the target backing

This means the new object may have:

```text
logical_location = target_file::/metadata/geometry
backing_location = source_file.h5::/metadata/geometry
```

This is a valid intermediate state.

---

## Remove Semantics

Remove operations mutate the logical graph.

Example:

```text
remove_metadata("geometry")
```

First-pass semantics:

- remove the object from the in-memory logical graph
- return the removed object where useful
- do not delete the original HDF5 backing immediately
- next full realization/write omits the removed object

Removed objects may still exist as free objects if the caller keeps a
reference.

---

## Rename Semantics

Rename operations mutate the logical graph.

Example:

```text
rename_metadata("geometry", "geometry_v2")
```

First-pass semantics:

- update the object's logical name
- update logical references such as metadata links
- do not rename any HDF5 group immediately
- next realization/write emits the object under the new name

---

## Replace Semantics

Replace operations mutate the logical graph.

Example:

```text
replace_data_in_activity("modal", replacement_dataset)
```

First-pass semantics:

- remove the old logical child
- attach/copy the replacement into the logical graph
- return the removed object where useful
- do not delete or mutate the old backing immediately
- next realization/write emits the replacement

---

## Realization

Realization is the process of producing a coherent backing representation
from the current logical graph.

For first-pass ESCDF behavior, realization should generally mean:

```text
write the current logical graph into a coherent target HDF5 file
```

The source backing files should not be mutated implicitly.

---

## Property realization

A property realization decision should be target-aware.

Conceptual decision tree:

```text
realize_property_to_hdf5(property, target_group)
├── expected_target = target_group / property.name
│
├── property has no HDF5 backing
│   └── write memory payload to expected_target
│
├── property backing location == expected_target
│   └── already realized; skip or update metadata if needed
│
├── target already contains property.name
│   └── raise unless an explicit overwrite/sync policy is requested
│
└── property backing location != expected_target
    └── copy/materialize source backing into expected_target
        first pass: read into memory then write
        future: direct HDF5 copy or streamed copy
```

This is safer than using a stored `native` or `external` flag.

---

## Dataset realization

Dataset realization should:

- compute the target HDF5 group location for the dataset
- realize each present property into that group
- omit properties that are absent in the logical graph
- handle extra/noncanonical properties according to the modified-property
  policy

Conceptual decision tree:

```text
realize_dataset_to_hdf5(dataset, target_parent_group)
├── target_group = target_parent_group / dataset.name
├── create target_group if needed
├── for each present property:
│   └── realize_property_to_hdf5(property, target_group)
└── omit absent properties
```

---

## Activity realization

Activity realization should:

- compute the target activity group
- write activity metadata such as descriptive name and date
- write metadata links
- realize each activity dataset

Conceptual decision tree:

```text
realize_activity_to_hdf5(activity, activities_group)
├── target_group = activities_group / activity.name
├── create target_group if needed
├── write activity attributes
├── write metadata links
└── for each dataset:
    └── realize_dataset_to_hdf5(dataset, target_group)
```

---

## Container realization

Container realization should:

- treat the current logical graph as authoritative
- create/write a coherent target HDF5 file
- realize metadata datasets
- realize activities and activity datasets
- omit removed objects
- write renamed objects under current logical names

Conceptual decision tree:

```text
realize_container_to_hdf5(container, target_file)
├── create target file or target root group
├── write file-level attributes
├── for each metadata dataset in logical graph:
│   └── realize_dataset_to_hdf5(metadata, target_file)
├── create activities group
└── for each activity in logical graph:
    └── realize_activity_to_hdf5(activity, activities_group)
```

---

## First-Pass Synchronization Policy

The first synchronization model should prefer full coherent target
realization.

That means:

- current logical graph is authoritative
- removed objects are omitted
- renamed objects are written under new logical names
- replaced objects are written as replacements
- external backing sources are copied/materialized
- source files are not modified in place

This avoids premature complexity around partial in-place updates.

---

## Future Synchronization Strategies

Future implementations may add:

- in-place synchronization for editable draft files
- direct HDF5-to-HDF5 copy
- streamed copy for large datasets
- chunk-aware copy
- appendable/extensible datasets
- partial synchronization
- attachment append/remove without full materialization

These should be added behind the realization abstraction rather than
spread across high-level CRUD operations.

---

## Non-Mutating Attachment Helpers

Non-mutating attachment operations are safe under this model.

Examples:

- list attachment names
- get attachment index
- dump one attachment to disk
- dump all attachments to disk

Mutating attachment operations such as:

- add attachment
- remove attachment
- replace attachment
- clear attachments

should wait until extensible arrays or a well-defined property mutation
realization strategy exists.

---

## Implementation Direction

The preferred implementation direction is:

1. Store or derive logical locations.
2. Store backing locations for HDF5-backed objects.
3. Use `None` or equivalent for memory-backed payloads.
4. Derive in-memory/native/external status at operation time.
5. Implement `is_realized_at(target)` helpers.
6. Implement `needs_realization(target)` helpers.
7. Make realization target-aware.
8. Avoid maintaining mutable realization flags that can desynchronize.

---

## Migration From Earlier Backing-State Model

Earlier first-pass implementations used static states such as:

```text
memory
hdf5_native
hdf5_external
```

Those were useful for early experimentation but should not remain the
long-term source of truth.

The direction should be to replace those static states with:

```text
backing_location = None or HDF5Location(...)
logical_location = derived from logical parent graph
```

Then:

```text
in_memory       = backing_location is None
native/external = comparison between backing_location and target location
realized        = backing_location == target location
```

---

## Summary

The realization and synchronization model should be target-aware and
derived from concrete locations.

The core idea is:

```text
logical graph + backing locations + target location
    → derive realization requirements
```

rather than:

```text
manually maintained native/external/pending flags
```

This should reduce desynchronization risk and provide a stronger
foundation for future out-of-core and synchronization workflows.