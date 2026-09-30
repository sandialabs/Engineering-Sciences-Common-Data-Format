# ESCDF CRUD / Editing / Parity Matrix

## Purpose

This matrix summarizes the current and desired create/read/update/delete
(CRUD) and related editing workflows across the ESCDF API surface in both
Python and MATLAB.

The goal is to:

- identify user-facing workflows that are currently supported
- identify gaps in Python/MATLAB parity
- clarify expected semantics for future implementation
- guide retirement of transitional or legacy editing paths

This matrix is organized by object level:
- ESCDF container
- Activity
- Metadata dataset
- Activity result dataset
- Property
- Attachments
- Validation/reporting
- Specification/cache management

---

## Status labels

- **Implemented**: supported in a clear, intended way
- **Implemented (transitional)**: supported, but via a legacy or temporary path
- **Partially implemented**: some workflow exists, but missing important behavior or ergonomics
- **Missing**: no supported workflow exists
- **Not needed**: operation is not expected for this object level

---

## Container-level workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| ESCDF container | Create empty container | Instantiate a new top-level ESCDF file object | Implemented | Implemented | `escdf.ESCDF()` / `escdf()` |
| ESCDF container | Load file | Load an ESCDF HDF5 file into memory-backed objects | Implemented | Implemented | Canonical spec model now drives loading behavior |
| ESCDF container | Write file | Validate and write an ESCDF file to disk | Implemented | Implemented | Uses canonical validation by default |
| ESCDF container | Set created metadata | Set `created_by` and `created_date` | Implemented | Implemented | Public API present in both languages |
| ESCDF container | Read created metadata | Access `created_by` / `created_date` | Implemented | Partially implemented | Python has direct properties; MATLAB often verifies indirectly or through display/file |
| ESCDF container | Remove activity | Remove an activity by name | Implemented | Implemented | Present, but semantics should be documented clearly |
| ESCDF container | Remove metadata | Remove metadata by name | Implemented | Implemented | Present, but behavior with active links should be documented clearly |
| ESCDF container | Rename activity | Rename an activity and preserve internal contents/links | Missing | Missing | High-value user-facing gap |
| ESCDF container | Rename metadata | Rename metadata and update links automatically | Missing | Missing | High-value user-facing gap |
| ESCDF container | Copy activity | Duplicate an activity under a new name | Missing | Missing | Useful but lower priority |
| ESCDF container | Copy metadata | Duplicate metadata under a new name | Missing | Missing | Useful but lower priority |
| ESCDF container | Replace metadata | Replace an existing metadata object in-place | Missing | Missing | Could be expressed via remove + add, but no dedicated API |
| ESCDF container | Replace activity | Replace an activity object in-place | Missing | Missing | Not currently a supported workflow |
| ESCDF container | Summary / repr | Human-readable summary of contents | Implemented | Implemented | Could still be improved further |
| ESCDF container | Dump to plain structure | Export container to plain dict/struct | Partially implemented | Implemented | MATLAB has `dump_to_struct`; Python equivalent is weaker/nonexistent |

---

## Activity-level workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| Activity | Create | Add activity to container with name/description/date | Implemented | Implemented | `add_activity(...)` |
| Activity | Read by name | Retrieve one activity by name | Implemented | Implemented | |
| Activity | List names | List all activity names | Implemented | Implemented | |
| Activity | Update description/date | Modify activity descriptive fields after creation | Partially implemented | Partially implemented | Possible through object mutation, but not strongly surfaced/documented |
| Activity | Rename | Rename activity object | Missing | Missing | High-value CRUD gap |
| Activity | Delete | Remove activity from container | Implemented | Implemented | |
| Activity | Link metadata | Link metadata name to activity | Implemented | Implemented | |
| Activity | Unlink metadata | Remove metadata link from activity | Implemented | Implemented | |
| Activity | Get linked metadata names | Inspect metadata links | Implemented | Implemented | |
| Activity | Get linked metadata objects | Retrieve linked metadata objects | Implemented | Implemented | |
| Activity | Add data | Add result dataset to activity | Implemented | Implemented | |
| Activity | Read data by name | Retrieve one activity dataset by name | Implemented | Implemented | |
| Activity | List data names | List all result datasets in activity | Implemented | Implemented | |
| Activity | Remove data | Remove dataset from activity | Implemented | Implemented | |
| Activity | Replace data | Replace one dataset in activity | Missing | Missing | High-value editing gap |
| Activity | Rename data | Rename one dataset within activity | Missing | Missing | High-value editing gap |
| Activity | Reorder data | Preserve/alter ordering of activity datasets | Not needed / missing | Not needed / missing | Usually not essential unless ordering matters for UI |

---

## Metadata dataset workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| Metadata dataset | Create | Instantiate dataset object with metadata spec type | Implemented | Implemented | |
| Metadata dataset | Add to container | Add metadata dataset to ESCDF container | Implemented | Implemented | |
| Metadata dataset | Read by name | Retrieve metadata dataset from container | Implemented | Implemented | |
| Metadata dataset | Update property values | Assign or replace spec-defined properties | Implemented | Implemented | Canonical assignment path now used |
| Metadata dataset | Clear property | Remove a property value by assigning `None` / `[]` | Implemented | Implemented | This is the effective property-delete mechanism |
| Metadata dataset | Rename dataset | Rename metadata dataset object | Missing | Missing | Distinct from renaming the underlying object variable |
| Metadata dataset | Delete from container | Remove metadata dataset | Implemented | Implemented | |
| Metadata dataset | Delete unknown extra property | Remove loaded malformed/extra field | Missing | Missing | Potential future editing helper |
| Metadata dataset | Inspect type/version/supertypes | Read canonical type metadata | Implemented | Implemented | Canonical model now backs this behavior |
| Metadata dataset | Validate | Validate against canonical spec | Implemented | Implemented | |
| Metadata dataset | Structured validation report | Request detailed validation report | Implemented | Implemented | |
| Metadata dataset | Write malformed/extra property back out | Preserve modified properties | Partially implemented | Partially implemented | Modified-property handling exists but deserves explicit workflow design |

---

## Activity result dataset workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| Activity result dataset | Create | Instantiate dataset object with result spec type | Implemented | Implemented | |
| Activity result dataset | Add to activity | Add dataset to activity | Implemented | Implemented | |
| Activity result dataset | Read by name | Retrieve from activity | Implemented | Implemented | |
| Activity result dataset | Update property values | Assign or replace spec-defined properties | Implemented | Implemented | Canonical assignment path now used |
| Activity result dataset | Clear property | Remove a property value by assigning `None` / `[]` | Implemented | Implemented | |
| Activity result dataset | Rename dataset | Rename activity dataset object | Missing | Missing | High-value editing gap |
| Activity result dataset | Delete from activity | Remove dataset from activity | Implemented | Implemented | |
| Activity result dataset | Validate | Validate against canonical spec | Implemented | Implemented | |
| Activity result dataset | Structured validation report | Request detailed validation report | Implemented | Implemented | |
| Activity result dataset | Table dump | Convert selected dimensions to table | Implemented | Implemented | Now canonicalized in both languages |
| Activity result dataset | Struct/dict dump | Convert to plain structure | Partially implemented | Implemented | Python equivalent still weaker than MATLAB |

---

## Property-level workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| Property | Create from raw array | Assign raw array/list/string/bytes to dataset field | Implemented | Implemented | Canonical property-definition matching now used |
| Property | Create from existing property object | Assign an already-built property object | Implemented | Implemented | |
| Property | Create from HDF5 dataset/group handle | Support load-time wrapping of on-disk property storage | Implemented | Implemented | |
| Property | Validate against candidate definitions | Internal assignment-time acceptability check | Implemented | Implemented | Now canonicalized |
| Property | Clear property | Assign `None` / `[]` to unset property | Implemented | Implemented | |
| Property | Rename property | Rename spec-defined property | Not needed | Not needed | Property names are part of the specification |
| Property | Remove unknown extra property | Remove malformed loaded extra property | Missing | Missing | Could be a useful future editing helper |
| Property | Read into memory | Force on-disk property into memory | Implemented | Implemented | |
| Property | Write to disk | Write one property into HDF5 group | Implemented | Implemented | |
| Property | Preserve on-disk backing | Keep property disk-backed where applicable | Implemented | Implemented | Out-of-core ergonomics still need work |

---

## Attachment workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| Attachments | Set from files | Read files and store as `attachments` + `attachment_names` | Implemented | Implemented | |
| Attachments | Read stored attachment names | Inspect `attachment_names` | Implemented | Implemented | |
| Attachments | Dump attachments to disk | Write stored attachments back to files | Implemented | Implemented | |
| Attachments | Replace full attachment set | Reassign `attachments` / `attachment_names` | Implemented | Implemented | Through normal property assignment |
| Attachments | Remove one attachment | Remove one attachment by name | Missing | Missing | Good candidate for user-editing milestone |
| Attachments | Clear all attachments | Remove all attachments cleanly | Partially implemented | Partially implemented | Can be done by clearing properties, but no dedicated helper |
| Attachments | Validate name/data consistency | Ensure `attachments` and `attachment_names` stay compatible | Implemented | Implemented | Via canonical validation + `requires` |

---

## Validation / reporting workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| Validation | Boolean validation | `validate()` returns valid/invalid | Implemented | Implemented | Canonical validation is now the default path |
| Validation | Structured report | `validate(report=True)` / equivalent | Implemented | Implemented | |
| Validation | Missing required properties | Report invalid | Implemented | Implemented | |
| Validation | Choice-group invalidity | Report invalid | Implemented | Implemented | |
| Validation | Ambiguous choice groups | Report invalid, not exception | Implemented | Implemented | New canonical behavior |
| Validation | Enum constraint checking | Report invalid | Implemented | Implemented | |
| Validation | Regex constraint checking | Report invalid | Implemented | Implemented | |
| Validation | Value constraint checking | Report invalid | Implemented | Implemented | `positive`, `nonnegative`, `finite`, `increasing`, `strictly_increasing`, `unique`, `nonempty` |
| Validation | `requires` constraint checking | Report invalid | Implemented | Implemented | First relational rule implemented |
| Validation | Additional constraint kinds | `paired`, `all_or_none`, etc. | Missing | Missing | Future work |
| Validation | Validation modes | schema / structure / final | Missing | Missing | Future work |
| Validation | Lifecycle-aware validation | draft/final/incomplete semantics | Missing | Missing | Future work |

---

## Specification / cache management workflows

| Object level | Operation | Expected workflow | Python status | MATLAB status | Notes / gap |
|---|---|---|---|---|---|
| Spec/cache | Load packaged default specs | Build canonical registry from packaged spec directory | Implemented | Implemented | |
| Spec/cache | Cache canonical registry | Reuse resolved spec state across runtime operations | Implemented | Implemented | |
| Spec/cache | Reload packaged default specs | Reset cache to packaged defaults | Implemented | Implemented | |
| Spec/cache | Append additional spec directory | Add temporary or custom specs at runtime | Implemented | Implemented | Used heavily in tests now |
| Spec/cache | Inspect local spec | Access local canonical specification | Implemented | Implemented | |
| Spec/cache | Inspect resolved spec | Access resolved canonical specification | Implemented | Implemented | |
| Spec/cache | Legacy compatibility views | Reconstruct old `_specification_data` / property dictionaries | Python: likely removable | MATLAB: likely removable | Should be removed once final audit confirms no remaining consumers |

---

## Summary of major remaining user-facing gaps

The largest user-facing gaps remaining are:

1. **Rename operations**
   - rename activity
   - rename metadata
   - rename dataset within an activity

2. **Replace/upsert operations**
   - replace dataset in activity
   - replace metadata in container

3. **Fine-grained attachment editing**
   - remove one attachment
   - clear all attachments with a dedicated helper

4. **Explicit cleanup of malformed extra properties**
   - remove unknown extra field from a loaded modified dataset

5. **Formal parity cleanup**
   - ensure Python and MATLAB provide equivalent editing workflows even if syntax differs

These are strong candidates for the next milestone.