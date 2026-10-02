# ESCDF Realization and Synchronization Model

## Purpose

This document defines the realization and synchronization model for ESCDF
objects.

The goal of this model is to explain how:

- logical in-memory edits
- backing-state transitions
- external/native property relationships
- draft working state

become coherent persisted state in memory or on disk.

This model builds on:

- the canonical specification model
- the canonical validation model
- the storage/backing/lifecycle/mutation model

This model is intended to be implemented in both Python and MATLAB.

---

## Relationship to Existing Models

### Canonical specification model
Defines:
- what the object graph is allowed to contain
- specification inheritance and validation semantics

### Storage/backing/lifecycle model
Defines:
- property backing states
- dataset/activity/container backing states
- lifecycle and mutability
- pending changes

### Realization/synchronization model
Defines:
- when and how logical edits become coherent persisted state
- how external/native-backed objects are materialized
- how the in-memory graph is reconciled with target storage

---

## Design Philosophy

### 1. Logical edits happen first
CRUD and editing operations are first interpreted as mutations of the
in-memory object graph.

Examples:
- remove metadata from a container
- rename an activity
- replace an activity dataset
- attach a copied dataset to a different container

These operations do **not** immediately imply physical mutation of an
existing HDF5 backing file.

### 2. Synchronization is explicit
Persistence of the current logical object graph into a coherent backing
representation should happen only through explicit realization or
synchronization operations.

Examples:
- `write_to_disk(...)`
- a future `synchronize(...)` operation
- a future explicit materialization operation

### 3. First realization model should be simple and safe
The first realization model should prefer:
- full coherent rewrite to a target
over:
- incremental in-place mutation of existing HDF5 structures

This is safer and more predictable, especially while lifecycle and backing
semantics are still being expanded.

### 4. External-backed payloads are allowed in memory
A container/dataset/property may temporarily exist in a logically edited
state while some payloads are still externally backed.

That is acceptable as an intermediate editing state.

### 5. Realization should eventually support more efficient strategies
Once the semantics are stable, realization may later evolve to:
- direct HDF5-to-HDF5 copy
- append-friendly extensible arrays
- partial synchronization
- streamed materialization

But the first model should not depend on those optimizations.

---

## Core Concepts

## 1. Logical state
The current in-memory object graph:
- container
- metadata datasets
- activities
- activity datasets
- property objects

This is the user-facing editable state.

## 2. Authoritative persisted/reference state
The most recent native persisted state or loaded state from which the
current object graph conceptually derives.

Examples:
- a container freshly loaded from file
- a container just written to disk
- a newly created in-memory object with no persisted state yet

## 3. Pending changes
Indicates that the logical in-memory state differs from the last
authoritative persisted/reference state.

## 4. Realization
The act of turning the current logical state into a coherent native
representation.

Examples:
- write current in-memory graph to a file
- materialize an externally backed property into native memory or native
  HDF5
- realize renamed or removed objects by producing a rewritten container
  image

## 5. Synchronization
A higher-level term for reconciling current logical state with some
backing target.

For the first model, synchronization is effectively:
- coherent write/rewrite to target

Later it may include incremental or partial realization strategies.

---

## Backing-State Interpretation During Synchronization

## Property-level backing states
Properties currently use:

- `memory`
- `hdf5_native`
- `hdf5_external`

### Meaning for realization

#### `memory`
Property payload is already in native in-memory form and can be written to
the current target directly.

#### `hdf5_native`
Property payload is backed by HDF5 storage that is native to the current
object context.

In a rewrite model, this may still be copied into a newly written target
rather than preserved in-place.

#### `hdf5_external`
Property payload is readable from an external HDF5 source but is not
native to the current target context.

Before the current logical state can be realized coherently into a new
native target, such a property must be copied/materialized into that
target.

---

## Dataset/activity/container backing states
At the dataset, activity, and container levels, backing state indicates
where the object itself is currently considered to live.

Examples:
- `memory`
- `hdf5_native`
- later possibly `hdf5_external`

These higher-level backing states do **not** replace property-level
backing states; they complement them.

---

## First Synchronization Model

## Principle
The first synchronization model should treat the current in-memory object
graph as authoritative and should produce a **coherent target image**
without mutating source backing in place.

### Consequences
- removed objects are omitted from the next write
- renamed objects are written under new names in the next write
- replaced objects are written as their replacement versions
- externally backed properties are copied/materialized into the new target
- source files remain untouched unless a future explicit in-place sync mode
  is introduced

This is the safest first model.

---

## What `write_to_disk(...)` should mean

For the first model, `write_to_disk(path)` should mean:

> Write the current logical object graph to a coherent target file at
> `path`, materializing any required external-backed payloads and using the
> current in-memory names/links/contents as the truth.

### It should not mean
- patch the original loaded file in place
- delete old groups from the source file
- rename source groups in place
- rewrite only one edited child object while preserving all original group
  layout implicitly

Those behaviors are future possibilities, not first-model semantics.

---

## Realization of CRUD Operations

## Remove
When an object is removed from the in-memory graph:
- it is no longer included in the next realized target
- the removed object may still exist as a detached in-memory object
- its original physical backing is not destroyed immediately

### Example
Removing metadata from a container:
- updates logical graph
- next write omits the metadata
- source HDF5 backing is left untouched unless a future in-place sync mode
  explicitly removes it

---

## Rename
When an object is renamed in the in-memory graph:
- its logical name changes immediately
- next write emits the object under the new name
- original source HDF5 group/dataset naming is not changed immediately

### Example
Renaming metadata:
- metadata object name changes
- metadata links in activities are updated in memory
- next write emits the metadata under the new group name

---

## Replace
When an object is replaced in the in-memory graph:
- old logical object is removed from that slot
- replacement object is inserted
- next write emits only the replacement
- old source backing is not destroyed immediately

---

## Attach / copy
When an object is attached/copied into a new container:
- a new wrapper object is created
- property wrappers are cloned
- externally/native-backed relationships are adjusted
- next write materializes the attached object into the target file if
  needed

---

## External-Backed Property Realization

## First-pass rule
Any `hdf5_external` property that is included in a write target must be
materialized/copied into the target.

### Current acceptable first-pass behavior
- read/copy into native memory if necessary
- then write out to the target HDF5 dataset/group

### Future optimized behavior
- direct HDF5-to-HDF5 copy where possible
- streamed copy for large datasets
- chunk-aware realization

The first model does not require these optimizations.

---

## Assignment vs Synchronization

## Assignment
Property assignment may trigger local materialization behavior.

Example:
- assigning to an `hdf5_external` property may first materialize it into
  native memory

This is a **local mutation-time realization**.

## Synchronization
Container/file write is a **global realization** step:
- gather current logical graph
- realize any remaining external-backed content into the target
- clear pending changes on success

These are distinct but related operations.

---

## Pending-Changes Semantics

## Container-level
`has_pending_changes = true` means:
- the in-memory container graph has changed relative to the last
  authoritative persisted/reference state
- a future write/sync is needed to realize current edits coherently

## Dataset/activity-level
`has_pending_changes = true` means:
- this subobject has changed relative to its last authoritative state

These lower-level flags may be used later for more selective sync
strategies, but the first model does not require partial synchronization.

## Property-level
In the current simplified first model, property-level change tracking is
not a separate top-level flag. Property state changes are represented via:
- current backing state
- in-memory content
- and the enclosing dataset/container pending-changes flags

---

## Successful Synchronization

After a successful full realization/write:

### Container
- `backing_state` becomes native HDF5-backed
- `has_pending_changes = false`

### Activities
- `backing_state` becomes native HDF5-backed
- `has_pending_changes = false`

### Datasets
- `backing_state` becomes native HDF5-backed
- `has_pending_changes = false`

### Properties
- `backing_state` becomes `hdf5_native`
- external/native ambiguity is resolved for the new target

This is the intended clean post-write state.

---

## Loaded Objects

After load from a native HDF5 file:

### Container
- `backing_state = hdf5_native`
- `lifecycle_state = draft` in the first implementation until finalized
  semantics are added
- `mutability_state` depends on open mode
- `has_pending_changes = false`

### Activity
- `backing_state = hdf5_native`
- `has_pending_changes = false`

### Dataset
- `backing_state = hdf5_native`
- `has_pending_changes = false`

### Property
- `backing_state = hdf5_native`

This is the clean initial loaded state.

---

## Finalized and Read-Only Files

## Finalized
Finalized files should eventually be treated as canonical frozen states.

In the first realization model, finalized behavior may be mostly
conceptual/documented if full enforcement is not yet implemented.

Eventually, the model should support:
- refusing direct mutating synchronization into a finalized source
- requiring edit-by-clone or explicit draft copy

## Read-only
Read-only mode should prevent accidental mutating writes to the current
native source context.

Even before full finalized semantics exist, read-only loading should be
compatible with:
- inspection
- export
- attach/copy into new editable draft containers

---

## What Synchronization Does Not Yet Solve

The first synchronization model intentionally does **not** yet solve:

- in-place mutation of existing native HDF5 source files
- incremental rewrite of only edited subtrees
- append/extend semantics for variable-sized arrays
- efficient mutation of attachment arrays
- partial realization policies for very large datasets
- automatic conflict handling across multiple independently edited aliases

Those belong to later phases.

---

## Future Extensions

Once the first model is stable, the following may be added:

### 1. Direct native sync / in-place update mode
An explicit mode where the current native backing is mutated directly,
subject to lifecycle and mutability rules.

### 2. Efficient external-backed copy
HDF5-to-HDF5 direct copy or streamed copy for large properties.

### 3. Extensible array support
For attachment growth and other append-like workflows.

### 4. Partial synchronization
Synchronize only changed datasets/properties where safe.

### 5. Finalized-file enforcement
Require explicit cloning/draft transitions before edits.

---

## Summary

The first-pass realization/synchronization model should:

- treat the current logical in-memory object graph as authoritative
- realize edits by writing a coherent new native target representation
- not immediately mutate source HDF5 backing during logical edits
- materialize/copy any external-backed properties needed for the target
- clear pending-change flags on successful write
- leave room for future optimized, partial, or in-place synchronization
  strategies

This model provides the next necessary layer after logical CRUD semantics
and before advanced out-of-core or finalized-file behavior.