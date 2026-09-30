# Canonical Validation Model for ESCDF

## Purpose

This document defines the validation model for ESCDF datasets using the
canonical specification representation.

The goal of this validation model is to replace validation behavior that
depends on legacy reconstructed property dictionaries with validation that
directly consumes:

- `ResolvedSpecification`
- `PropertyDefinition`
- `ConstraintRule`
- future `StorageHint` and value-constraint semantics

This validation model is intended to be implemented in both Python and
MATLAB.

---

## Design Goals

1. **Canonical-model-driven validation**
   - Validation should use `ResolvedSpecification` directly as the source
     of truth.
   - Legacy compatibility dictionaries should not be required for core
     validation logic.

2. **Layered validation semantics**
   - Validation should be structured into semantic layers rather than
     ad hoc precedence rules.
   - This should make interactions among optional properties, choice
     groups, and cross-property constraints easier to reason about.

3. **Structured validation reporting**
   - Validation should produce a machine-readable report object.
   - Boolean success/failure should remain available as a convenience,
     but richer diagnostics should be preserved internally.

4. **Backward-compatible migration**
   - Existing public validation APIs should continue to work during the
     transition.
   - Existing user-facing behaviors such as printed validation messages
     can be preserved initially, even if the underlying implementation
     changes.

5. **Extensibility**
   - The validation model should support future additions such as:
     - value constraints
     - cross-property constraints
     - staged validation modes
     - draft/final file state checks

---

## Core Principles

## 1. ResolvedSpecification is the source of truth

Validation must be driven by the effective resolved specification, not
the local specification and not a legacy reconstructed property
dictionary.

This means validation should interpret:

- effective inherited properties
- effective merged enumerations
- effective constraint rules
- effective storage-related metadata, where relevant

from `ResolvedSpecification`.

---

## 2. Validation does not use a general precedence system

ESCDF validation should not be modeled as arbitrary precedence among
property modifiers.

Instead, validation should be implemented as ordered semantic layers.

This is especially important for interactions among:

- `optional`
- choice-group membership
- cross-property `requires` relationships
- future constraint rules

---

## 3. Optional means unconditionally optional, not universally optional

A property marked `optional` means:

- the property is not always required by the schema

It does **not** mean:

- the property can never become conditionally required through a
  relationship rule

Example:

```text
attachments - bytes - num_attachments - optional,requires:attachment_names
attachment_names - str - num_attachments - optional,requires:attachments
```

Valid cases:
- neither property present
- both properties present

Invalid cases:
- only one present

So `optional` and `requires` are not contradictory; they operate at
different semantic layers.

---

## 4. Validation should be explicit and inspectable

Validation should produce a report that can be:

- queried by code
- printed for humans
- displayed in notebooks or GUIs
- used in tests
- used to gate writing/finalization

A boolean-only result is insufficient as the canonical internal output.

---

## Validation Layers

Validation should proceed through ordered semantic layers.

---

## Layer 1: Property presence and local property validity

This layer checks each property that is present on the dataset object.

Checks include:

- the property exists as an `ESCDFProperty` / `escdf_property`
- datatype matches at least one acceptable declaration
- rank matches the declared rank
- fixed-size dimensions match
- property-local enum constraints are satisfied
- property-local regex constraints are satisfied
- property-local value constraints are satisfied

This layer does **not** yet decide whether a choice group is satisfied.

### Output of Layer 1
For each property declaration candidate, validation should know whether
the property is locally compatible with that declaration.

---

## Layer 2: Dimension consistency

This layer checks consistency of symbolic dimensions across all relevant
property declarations.

Examples:
- `num_nodes`
- `num_samples`
- `num_channels`

Rules:
- if multiple present properties bind the same symbolic dimension, their
  concrete sizes must match
- fixed dimensions are already checked at Layer 1
- missing optional properties do not contribute a dimension binding

### Output of Layer 2
Validation should know the concrete size bindings of all symbolic
dimensions that are actually realized in the dataset.

---

## Layer 3: Choice-group validity

This layer evaluates each choice group defined by the resolved
specification.

A choice group is valid only if exactly one branch is valid, unless a
future extension explicitly defines different cardinality semantics.

A branch is valid only if:

- all required properties of that branch are present
- all present properties in that branch satisfy Layer 1 checks
- symbolic dimensions within that branch are consistent with Layer 2
- branch-relevant relational constraints are satisfied

### Validity outcomes for one choice group
- **exactly one valid branch** → valid
- **zero valid branches** → invalid
- **multiple valid branches** → invalid / ambiguous

Ambiguous multiple-branch matches should be reported explicitly.

---

## Layer 4: Cross-property relational constraints

This layer evaluates `ConstraintRule` objects.

Constraint rules are specification-level semantic rules. Even if authored
inline with a property, they are normalized into canonical
`ConstraintRule` objects and evaluated here.

Examples:
- `requires`
- `paired`
- `all_or_none`
- `exactly_one_of`

### Example: requires
For a rule:

- kind = `requires`
- subject = `attachments`
- target = `attachment_names`

the rule means:

- if `attachments` is present, `attachment_names` must also be present

### Scope of relational rules
Constraint rules may later carry source context such as:

- `source_property`
- `source_choice_group`
- `source_choice_branch`

This allows future implementations to apply branch-specific relational
rules only in the relevant choice context.

---

## Layer 5: Dataset-level policy checks

This layer evaluates policies that are not pure schema semantics but do
affect whether a dataset is considered valid for normal operations.

Examples:
- dataset has modified/unknown extra properties
- future draft/final state checks
- future partial-write completeness checks

Current example:
- a dataset with modified properties loaded from disk is not considered
  valid for normal write operations

---

## Validation Report

Validation should produce a structured report object.

---

## Purpose of the ValidationReport

The report object should:

- record whether validation succeeded
- preserve detailed reasons for failure
- support human-readable summaries
- support future staged validation modes

---

## Suggested top-level fields

### `is_valid`
Boolean overall validation result.

### `missing_properties`
Required properties that are absent.

### `invalid_choices`
Choice groups with zero valid branches.

### `ambiguous_choices`
Choice groups with multiple valid branches.

### `bad_types`
Properties whose datatypes do not match required declarations.

### `bad_ranks`
Properties whose number of dimensions does not match required
declarations.

### `bad_sizes`
Properties whose fixed-size dimensions do not match.

### `inconsistent_dimensions`
Symbolic dimensions whose realized sizes conflict across properties.

### `invalid_enumerations`
Properties containing values not allowed by their enumeration.

### `invalid_regexes`
Properties containing values that do not satisfy a regex constraint.

### `invalid_value_constraints`
Properties violating value constraints such as:
- positive
- nonnegative
- increasing
- unique

### `constraint_failures`
Cross-property constraint failures.

### `modified_property_failures`
Failures caused by modified/unknown extra properties.

### `warnings`
Non-fatal issues or informational items.

---

## Suggested secondary fields

These are optional but useful for debugging and tooling.

### `valid_choice_branches`
Map from choice-group name to the valid branch or branches detected.

### `bound_dimensions`
Map from symbolic dimension name to realized integer size.

### `present_properties`
List or set of properties present on the dataset.

### `checked_specification`
Reference to the `ResolvedSpecification` or its name/type.

---

## ValidationReport Behavior

A validation report should support:

- conversion to bool-like overall validity
- summary text generation
- pretty-printing for humans
- direct inspection of detailed failure lists

The public dataset API may still return a boolean by default, but it
should be able to return a report on request.

---

## Suggested Validation API Direction

The exact API may evolve, but a likely direction is:

### Boolean-style validation
```text
dataset.validate() -> bool
```

### Report-style validation
```text
dataset.validate(report=true) -> ValidationReport
```

The same conceptual behavior should be supported in MATLAB, even if the
surface syntax differs.

---

## Interpretation of Present vs Absent Properties

Validation should reason explicitly about which properties are present.

A property is considered **present** if:

- the corresponding dataset attribute exists
- and its value is a property object, not `None` / `[]`

A property is considered **absent** if:

- the dataset attribute is unset
- or explicitly `None` / `[]`

Only present properties participate in datatype, shape, enum, regex, and
value-constraint checks.

---

## Interpretation of Choice Groups

Choice groups are derived from the canonical `ResolvedSpecification`
field:

- `choice_groups`

Each branch consists of one or more `PropertyDefinition` objects.

Validation must evaluate branches as branch-level units, not merely as
independent property matches.

This is important because:

- branches may contain multiple coordinated properties
- a branch may include required and optional members
- future branch-scoped constraint rules may exist

---

## Interpretation of ConstraintRule

A `ConstraintRule` is not a property option. It is a specification-level
relationship rule.

Validation must evaluate `ConstraintRule` objects directly, not through
legacy reconstructed option tokens.

### v1 rule interpretation recommendations

#### `requires`
If any subject property is present, all target properties must be
present.

#### `paired`
Either all listed subject/target properties are present or none are
present.

#### `all_or_none`
All listed properties must either all be present or all be absent.

#### `exactly_one_of`
Exactly one listed property or property group must be present.

The exact internal representation may evolve, but these semantics should
be explicit.

---

## Value Constraints

The canonical validation model should support intrinsic value
constraints stored on `PropertyDefinition`.

Examples:
- `positive`
- `nonnegative`
- `finite`
- `increasing`
- `strictly_increasing`
- `unique`
- `nonempty`

These are checked only for present properties.

Value constraints are property-local and should be evaluated before or
alongside choice-group validity, since they affect whether a candidate
branch is valid.

---

## Migration Strategy

Validation migration should proceed incrementally.

---

## Stage 1: canonical backend, legacy validation frontend
Current state after parser/registry migration:
- canonical parser and registry are the backend source of truth
- legacy compatibility views still drive validation

---

## Stage 2: structured validation report
Introduce a canonical validation report object while preserving the
existing boolean-returning public API.

---

## Stage 3: canonical-model-driven validator
Implement validation directly against `ResolvedSpecification`.

At this stage, legacy property dictionaries should no longer be required
for dataset validation.

---

## Stage 4: compatibility cleanup
Once validation and other downstream consumers are moved to canonical
objects, transitional legacy adapters can be reduced or removed.

---

## Backward Compatibility Expectations

During migration:

- public dataset constructors should remain unchanged
- `validate()` should still support the current boolean usage pattern
- printed diagnostics may remain similar, even if internally generated by
  a report object
- existing tests should continue to pass unless they depend on behavior
  that is intentionally corrected

---

## Relationship to Future Features

The canonical validation model is intended to support future work
cleanly, including:

### 1. Validation modes
Examples:
- schema-only
- structure-only
- final/publication validation

### 2. Draft/final file lifecycle checks
Examples:
- allow draft datasets/files to exist with weaker requirements
- require strict completeness for finalized files

### 3. Out-of-core completeness checks
Examples:
- allocated but not fully written arrays
- explicit partial-write markers

### 4. Richer constraint sections
Examples:
- dedicated `constraints` section parsing
- more expressive but still bounded relationship rules

---

## Summary

The canonical validation model has the following key properties:

- `ResolvedSpecification` is the semantic source of truth
- validation is layered rather than precedence-based
- `optional` means unconditionally optional, not universally optional
- choice groups are evaluated as branch-level semantic units
- `ConstraintRule` is evaluated directly as a specification-level
  relationship rule
- validation should produce a structured report object
- migration should preserve backward compatibility while moving runtime
  logic away from legacy reconstructed property dictionaries

This model should become the foundation for dataset validation in both
Python and MATLAB.