# ESCDF Storage, Backing, Lifecycle, and Mutation Model

## Purpose

This document defines the storage/backing, lifecycle, and mutation model
for ESCDF objects.

The goal of this model is to provide a clear foundation for:

- CRUD and editing operations
- safe handling of loaded objects backed by HDF5 storage
- draft and finalized file workflows
- future out-of-core and partial-materialization workflows

This model is intentionally **simpler** than a fully synchronized logical
ownership model. It focuses on tracking what is needed for correctness and
safe persistence while avoiding overly fragile bookkeeping.

This model is intended to be implemented in both Python and MATLAB.

---

## Design Philosophy

### 1. Track physical backing strongly
The model should explicitly track where data is physically backed:

- in memory
- in HDF5 storage

and whether that backing is:

- native to the current object/container context
- external to the current object/container context
- mixed across properties or subobjects

This is the most important information for correctness during copy,
attach, save, and future out-of-core workflows.

### 2. Track lifecycle and mutability strongly
The model should explicitly track whether a file/container is:

- draft
- finalized

and whether mutation is currently allowed:

- editable
- read-only

This is essential for safe user-facing mutation behavior.

### 3. Keep logical ownership bookkeeping lightweight
The model should **not** attempt to fully synchronize logical ownership or
parent/child relationships across arbitrary object aliases and references.

Instead, ownership-related state transitions should be defined at
**explicit operations** such as:

- attach to container
- copy
- detach
- save/finalize

### 4. Prefer explicit transitions over inferred synchronization
If an object changes storage/backing semantics, that should happen through
an explicit operation, not by trying to infer and propagate ownership
changes through every possible reference alias.

### 5. Allow future expansion
If the simpler model proves insufficient in practice, additional
bookkeeping can be added later.

---

## Scope

This model applies to:

- ESCDF container objects
- Activity objects
- Dataset objects
- Property objects

The model is especially important for properties, since property payloads
are the actual units of in-memory or on-disk storage.

---

## Core Concepts

## 1. Logical object graph
ESCDF objects exist in an in-memory object graph such as:

- container
  - metadata datasets
  - activities
    - activity datasets

CRUD operations initially act on this in-memory graph.

The in-memory graph is conceptually distinct from the physical backing
state of the object payloads.

---

## 2. Physical backing
Physical backing describes where the data currently comes from or is
stored.

Examples:
- property data stored fully in memory
- property data backed by an HDF5 dataset in file A
- property data attached to a draft container but still backed by file A
- property data written into a target file B

Physical backing is the main source of truth for copy/materialization
semantics.

---

## 3. Backing relation
Backing relation describes whether the current physical backing is
considered native to the current object/container context.

Examples:
- **native**
  - the backing belongs to the current object/container context
- **external**
  - the backing comes from some other source and would need to be copied or
    materialized before independent persistence
- **mixed**
  - different subobjects or properties have different backing relations

Backing relation is distinct from backing medium.

Examples:
- an object may be HDF5-backed and native
- an object may be HDF5-backed and external
- an object may be memory-backed and native

---

## 4. Lifecycle state
Lifecycle state describes whether a file/container is:

- still under construction
- a persisted draft
- finalized and frozen

Lifecycle state is primarily a container/file-level concern.

---

## 5. Mutability state
Mutability describes whether mutation operations are currently allowed.

Examples:
- editable
- read-only

A finalized object is typically read-only. A loaded draft may be editable
or read-only depending on how it was opened.

---

## 6. Change tracking flag
The model should include a simple flag describing whether an object has
unsaved semantic changes relative to its current authoritative persisted
or reference state.

Possible names for this concept include:
- `modified`
- `needs_save`
- `pending_changes`

This document uses **pending changes** as the conceptual term to avoid the
negative connotations of terms like “dirty.”

Pending changes are **not** the same thing as mixed backing relation.

Examples:
- an object may be mixed-backed but still have no pending changes
- an object may be fully memory-backed/native and still have pending
  changes because it was edited after load
- an object may be both mixed-backed and have pending changes

This flag is conceptually distinct from:
- malformed extra-property handling such as `has_modified_properties`
- backing relation
- lifecycle state

---

## Object-Level State Model

## Container-level state

An ESCDF container should track at least:

- lifecycle state
- mutability state
- whether it has a persisted backing target/source
- whether it has pending changes

### Suggested conceptual container states
The following are examples of combined interpretations, not a single flat
enum:

- **transient draft**
  - created in memory only
  - no persisted file target yet
  - editable
- **persisted draft**
  - written to disk as a working/incomplete file
  - still editable
- **loaded draft**
  - loaded from a draft file
- **loaded finalized**
  - loaded from a finalized file
  - typically read-only
- **editable clone of finalized**
  - a user-created working copy derived from a finalized file

The container does **not** need to aggressively track every alias that
references child objects. It should instead define semantics for explicit
operations.

---

## Activity-level state

Activities primarily exist as part of the container object graph.

An activity should generally inherit or reference container-level
lifecycle and mutability semantics rather than maintaining a fully
independent lifecycle.

An activity may additionally carry a source/backing descriptor if it was
loaded from disk and needs to preserve source path information.

---

## Dataset-level state

Datasets should track enough information to distinguish:

- a transient in-memory dataset
- a dataset loaded from disk
- a dataset copied/attached into a different container but still backed by
  the original source
- a dataset fully native to its current target context
- a dataset with pending changes

### Suggested conceptual dataset backing states
These are best understood as combinations of backing medium and backing
relation:

- **memory-backed, native**
  - all properties stored in memory for the current dataset context
- **HDF5-backed, native**
  - properties backed by HDF5 storage native to the current dataset
  context
- **HDF5-backed, external**
  - logically part of a new dataset/container, but still physically backed
    by an external source
- **mixed-backed**
  - some properties are native and some are still externally backed

Datasets may additionally carry a pending-changes flag.

---

## Property-level state

Properties are the most important level for storage/backing tracking.

Each property should conceptually track:

- its datatype and shape
- its backing medium:
  - memory
  - HDF5
- its backing relation:
  - native
  - external
- whether it has pending changes relative to its current reference state

### Suggested conceptual property states
Again, these are combinations rather than a single flat state list:

- **memory-backed, native**
- **HDF5-backed, native**
- **HDF5-backed, external**
- **mixed-backed** (mainly meaningful when discussed at higher levels)
- **pending changes = true/false**

Properties are the primary objects that future out-of-core and
copy/materialization logic will operate on.

---

## Explicit Operations

This model relies on explicit operations to change storage/backing
semantics.

---

## Attach / add to container

Example:
```text
esfile_2.add_metadata(metadata)
```

### Intended semantics
This is an explicit transition point.

The system should not simply reinterpret all existing aliases of the
original object. Instead, it should define what happens to the newly
attached object representation.

### Recommended first-pass semantics
- create a new dataset-level object wrapper for the target container
- preserve external physical backing where practical
- do **not** modify the original source file/backing
- mark the new attached object as externally backed relative to the new
  container if its properties still point to an external source
- do not require eager read-into-memory unless needed

### Important note
A variable reference such as:
```text
metadata = esfile.metadata[0]
```
does **not** imply a state transition.
Only the explicit attach/copy operation does.

---

## Copy / clone

Copying should be explicit.

Examples:
- clone metadata
- copy dataset into new container
- duplicate activity

### Recommended semantics
The copy operation should define whether the new object is:
- fully materialized in memory immediately
- externally backed until saved/materialized
- copy-on-write after first modification

This should be a deliberate API decision, not inferred from general
reference aliasing.

---

## Detach

Detach should be explicit.

Detaching means:
- produce an object no longer semantically tied to its original backing
  context
- usually materialize required state into memory or otherwise ensure the
  object can survive independently

Detachment should not happen implicitly through ordinary variable
assignment.

---

## Save / write

Writing an ESCDF container to disk should:
- persist the current logical object graph
- materialize externally backed content as needed
- avoid mutating original external sources
- enforce lifecycle/validation rules appropriate to the target state

The write operation is where draft vs finalized behavior becomes
especially important.

---

## Mutation Semantics

## General principle

CRUD and editing operations should first be understood as **logical
mutations of the in-memory object graph**.

They should **not** be assumed to immediately mutate original source HDF5
storage.

This avoids many desynchronization problems and keeps semantics simpler.

---

## Remove

Examples:
- remove metadata from container
- remove activity
- remove dataset from activity

### First-pass semantics
- remove from the in-memory object graph
- do not mutate original source file immediately
- changes are persisted only when writing/saving the modified container

---

## Rename

Examples:
- rename metadata
- rename activity
- rename dataset within activity

### First-pass semantics
- rename within the in-memory object graph
- update internal logical references/links accordingly
- do not mutate original source file immediately
- persisted on next write/save

---

## Replace

Examples:
- replace metadata dataset
- replace activity data

### First-pass semantics
- update the logical object graph
- old backing remains untouched unless the modified container is written
- new replacement object may be memory-backed or externally backed
  depending on how it was introduced

---

## Property assignment

Examples:
- assign a new array to a property
- assign an HDF5-backed property object
- assign a loaded external property into a copied dataset

### Recommended semantics
Property assignment is a separate mutation path from container-level CRUD.
It should:
- validate the assigned value against the canonical specification
- update property-level backing and pending-changes state
- trigger copy-on-write detachment/materialization if needed for an
  externally backed property

This is a lower-level operation than add/remove/rename at the dataset or
container level.

---

## Draft and Finalized Files

## Draft
A draft file/container is:
- provisional
- editable by default
- potentially incomplete
- not yet canonical/frozen

Draft files may exist on disk and still be under active construction.

This explicitly covers the important workflow:
- object created in memory
- temporarily written to disk
- reopened later for continued work
- not all datasets/properties necessarily present yet

---

## Finalized
A finalized file/container is:
- considered canonical
- frozen in time
- not intended to be modified in place

Users should not be able to accidentally delete or alter canonical
content from finalized files.

### Recommended first-pass semantics
Mutation operations on finalized containers should either:
- be disallowed directly, or
- require an explicit clone/edit-copy workflow

---

## Read-only
Read-only is a mutability mode, not necessarily the same as finalized.

A file may be:
- draft but opened read-only
- finalized and read-only
- finalized but cloned into a new editable draft

The model should distinguish:
- lifecycle
- mutability

---

## Relationship Between References and State

## Ordinary variable references do not imply semantic state transitions

Example:
```text
metadata = esfile.metadata[0]
```

This should generally be treated as:
- another reference to the same dataset object
- no attach/copy/detach transition
- no new backing relation change

This is an important simplification that avoids fragile ownership
synchronization.

---

## Explicit operations define transitions

State transitions should occur at explicit operations such as:
- `add_metadata`
- `add_data_to_activity`
- explicit copy/clone
- explicit detach
- write/save

This sharply reduces desynchronization risk.

---

## Synchronization Invariants

The simpler model should preserve only a few strong invariants.

### Invariant 1
Physical backing state must be accurate enough to determine:
- whether data is in memory or HDF5
- whether data is externally backed
- whether data must be copied/materialized before safe independent write

### Invariant 2
Lifecycle/mutability state at the container level must be accurate enough
to determine whether editing operations are allowed.

### Invariant 3
Pending-changes state must be accurate enough to determine whether an
object or container needs to be rewritten or finalized again.

### Invariant 4
State transitions that affect backing or lifecycle semantics must occur
through explicit API operations rather than through arbitrary reference
aliasing.

The model does **not** attempt to maintain a perfectly synchronized
ownership graph across all possible aliases and references.

---

## Implications for Future Out-of-Core Work

This simplified model is intended to be compatible with future out-of-core
features.

Examples:
- externally backed properties can be copied directly from HDF5 source to
  HDF5 target without full eager materialization
- copy-on-write semantics can avoid unnecessary RAM use
- persisted draft containers can hold incomplete but valid-for-draft
  externally backed content
- partial materialization and completeness tracking can later be layered on

This means the model should be viewed as a foundation, not an endpoint.

---

## Non-Goals of the First Model

The first model intentionally does **not** try to solve all of the
following:

- perfect synchronization of logical owner metadata across arbitrary
  object aliases
- automatic reparenting of existing child objects when referenced from
  multiple places
- fully automatic direct in-place mutation of loaded canonical HDF5 files
- complete out-of-core workflow implementation

These may be revisited later if real workflows demand them.

---

## Summary

The first-pass ESCDF storage/backing/lifecycle model should:

- track physical backing/source state carefully
- distinguish backing medium from backing relation
- track lifecycle and mutability at the container/file level carefully
- track a simple pending-changes flag rather than a full ownership graph
- treat CRUD operations primarily as logical mutations of the in-memory
  object graph
- use explicit operations such as attach/copy/detach/save to define state
  transitions
- avoid overly aggressive logical ownership synchronization across
  arbitrary aliases and references
- leave room for future expansion if more bookkeeping is needed

This model is intended to provide a stable and minimally fragile
foundation for user-facing CRUD operations, finalized file protection, and
future out-of-core workflows.