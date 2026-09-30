# Canonical Internal Specification Model for ESCDF

## Purpose

This document defines the canonical internal representation for ESCDF specification files. The goal of this model is to replace brittle tuple/list indexing and mixed nested dictionary structures with explicit, named objects that are easier to maintain, validate, extend, and debug.

This model is intended to be implemented in both Python and MATLAB.

---

## Design Goals

1. **Flat canonical property representation**
   - Every property declaration in a specification file is normalized into exactly one `PropertyDefinition`.
   - Choice groups are not represented canonically through nested maps; instead, they are expressed through fields on `PropertyDefinition`.

2. **Explicit local vs resolved specifications**
   - A `Specification` represents what is directly declared in a single specification file.
   - A `ResolvedSpecification` represents the effective specification after inheritance resolution.

3. **Eager derived indexes**
   - `ResolvedSpecification` eagerly computes commonly used indexes and derived views to simplify validation and debugging.

4. **Separation of intrinsic vs relational semantics**
   - Intrinsic property semantics remain on `PropertyDefinition`.
   - Relational semantics between properties are normalized into specification-level `ConstraintRule` objects.

5. **Extensibility**
   - The model includes placeholders for constraints and storage hints from the beginning, even if initial implementations are minimal.

---

## Core Objects

## `Version`

### Role
Represents a specification version number.

### Fields
- `major`
- `minor`
- `patch`

### Invariants
- All fields must be integers.
- All fields must be nonnegative.

### Notes
- A version is associated with a specification itself, not with inherited ancestry as a composite object.
- A `ResolvedSpecification` retains the version of the resolved specification being requested.

---

## `Dimension`

### Role
Represents one dimension token from a property shape.

### Kinds
A dimension is one of:
- `fixed`
- `symbolic`

### Fields
- `kind`
- `value`

### Examples
- fixed dimension: `3`
- symbolic dimension: `num_nodes`

### Invariants
- If `kind == "fixed"`:
  - `value` must be an integer
  - `value` must be positive
- If `kind == "symbolic"`:
  - `value` must be a nonempty string

### Notes
- Shapes are represented as ordered lists of `Dimension`.
- Scalar properties are represented by an empty shape list.

---

## `PropertyDefinition`

### Role
Represents one normalized property declaration.

Each property declaration line in the specification file becomes exactly one `PropertyDefinition`.

### Fields
- `name`
- `datatype`
- `shape`
- `optional`
- `variable_length`
- `enumeration_name`
- `regex`
- `choice_group`
- `choice_branch`
- `value_constraints`
- `source_specification`

### Field Semantics

#### `name`
The property name.

#### `datatype`
The ESCDF datatype string, such as:
- `u1`, `u2`, `u4`, `u8`
- `i1`, `i2`, `i4`, `i8`
- `f4`, `f8`
- `c8`, `c16`
- `str`
- `bytes`

#### `shape`
An ordered list of `Dimension`.

Examples:
- scalar -> `[]`
- `num_nodes` -> `[symbolic("num_nodes")]`
- `num_nodes,3` -> `[symbolic("num_nodes"), fixed(3)]`

#### `optional`
Boolean indicating whether the property is unconditionally required by the specification.

Important:
- `optional = true` does **not** mean the property can never become conditionally required by a relationship rule.
- It only means absence of the property alone does not invalidate the dataset.

#### `variable_length`
Boolean indicating whether the property is declared as variable-length / ragged.

#### `enumeration_name`
Optional name of an enumeration that constrains the property's values.

#### `regex`
Optional regular expression constraining the property's values.

#### `choice_group`
Optional name of the choice group to which this property declaration belongs.

#### `choice_branch`
Optional name of the branch within the choice group.

#### `value_constraints`
List of intrinsic value constraints such as:
- `positive`
- `nonnegative`
- `finite`
- `increasing`
- `strictly_increasing`
- `unique`

These are property-intrinsic constraints, not cross-property relationships.

#### `source_specification`
The name of the specification file in which this property definition originated.

### Invariants
- `datatype` must be one of the recognized ESCDF datatypes.
- `shape` must be a list of `Dimension`.
- If `choice_group` is set, `choice_branch` must also be set.
- If `choice_branch` is set, `choice_group` must also be set.
- Relational modifiers such as `requires:*` must **not** remain attached to `PropertyDefinition` after normalization.

### Notes
- A single logical property name may correspond to multiple `PropertyDefinition` objects if the specification provides multiple alternatives (for example through choice groups or multiple datatypes).
- Canonical representation is flat; grouping by property name or choice group is a derived view.

---

## `ConstraintRule`

### Role
Represents a cross-property or specification-level relationship constraint.

### Fields
- `kind`
- `subject_properties`
- `target_properties`
- `source_property`
- `source_choice_group`
- `source_choice_branch`
- `source_specification`

### Field Semantics

#### `kind`
The type of relationship, for example:
- `requires`
- `paired`
- `all_or_none`
- `exactly_one_of`

#### `subject_properties`
List of property names that trigger or define the rule.

#### `target_properties`
List of property names referenced by the rule.

#### `source_property`
Optional property name from which the rule originated during parse/normalization.

#### `source_choice_group`
Optional choice group context if the rule originated from a property declaration inside a choice group.

#### `source_choice_branch`
Optional branch context if the rule originated from a branch-specific property declaration.

#### `source_specification`
The name of the specification file in which the rule originated.

### Invariants
- `kind` must be a recognized constraint type.
- `subject_properties` and `target_properties` must contain valid property names.
- Constraint rules must not duplicate intrinsic property semantics.

### Notes
- Constraint rules are part of specification-level semantics.
- Even if authored inline on a property, relational modifiers are normalized into `ConstraintRule` objects.
- Constraint rules may later be authored in a dedicated `constraints` section as well.

---

## `StorageHint`

### Role
Represents default storage-related recommendations associated with a property.

### Fields
- `property_name`
- `kind`
- `value`
- `overridable`
- `source_specification`

### Field Semantics

#### `property_name`
The property to which the hint applies.

#### `kind`
The type of storage hint, for example:
- `chunking`
- `strategy`
- future storage-related categories

#### `value`
The associated value for the hint.

Examples:
- explicit chunk shape
- named strategy such as `channel_major`

#### `overridable`
Boolean indicating whether user code is allowed to override the hint. Initial implementations may default this to true.

#### `source_specification`
The name of the specification file in which the hint originated.

### Invariants
- Storage hints are advisory defaults, not schema-validity requirements.
- Storage hints should reference valid property names in the effective specification.

### Notes
- Storage hints should not overcomplicate core property syntax.
- A dedicated `chunking` or `storage_hints` section is preferred for more complex storage defaults.

---

## `Specification`

### Role
Represents the canonical local contents of a single parsed specification file, before inheritance resolution.

### Fields
- `name`
- `version`
- `extends`
- `documentation`
- `notes`
- `local_properties`
- `enumerations`
- `constraints`
- `storage_hints`
- `source_file`

### Field Semantics

#### `name`
Specification name.

#### `version`
A `Version` object.

#### `extends`
Name of parent specification, or a null/none value if this specification has no parent.

#### `documentation`
Freeform descriptive text between the `extends` line and the `properties` section.

#### `notes`
Freeform notes text from the `notes` section or equivalent trailing narrative content.

#### `local_properties`
Flat list of `PropertyDefinition` objects declared directly in this file.

#### `enumerations`
Map from enumeration name to allowed string values.

#### `constraints`
List of `ConstraintRule` objects declared directly or lifted during normalization from inline property modifiers.

#### `storage_hints`
List or map of `StorageHint` objects declared directly in this file.

#### `source_file`
Source file path used to parse the specification.

### Invariants
- `local_properties` is flat.
- Enumeration names are unique within the local specification.
- Each property declaration from the specification file yields exactly one `PropertyDefinition`.
- Constraint rules and storage hints are local to the file at this stage.

### Notes
- `Specification` does not contain inherited parent properties.
- `Specification` is the canonical parsed form of a file, not the final resolved form used for dataset validation.

---

## `ResolvedSpecification`

### Role
Represents the effective specification after inheritance resolution.

### Fields
- `name`
- `version`
- `ancestry`
- `properties`
- `enumerations`
- `constraints`
- `storage_hints`

### Eager Derived Indexes
- `properties_by_name`
- `choice_groups`
- `standalone_properties`
- `required_properties`
- `optional_properties`
- `property_names`
- `dimension_names`

### Field Semantics

#### `ancestry`
Ordered list of specification names in inheritance application order,
beginning with the root ancestor and ending with the resolved
specification itself.

#### `properties`
Flat list of all effective `PropertyDefinition` objects after inheritance resolution.

#### `enumerations`
Effective enumeration map after inheritance resolution.

#### `constraints`
Effective list of `ConstraintRule` objects after inheritance resolution.

#### `storage_hints`
Effective list or map of `StorageHint` objects after inheritance resolution.

### Eager Derived Index Semantics

#### `properties_by_name`
Map:
- property name -> list of `PropertyDefinition`

Used to handle cases where one logical property name has multiple declarations.

#### `choice_groups`
Map:
- choice group name -> branch map
- branch map: branch name -> list of `PropertyDefinition`

This is a derived view only.

#### `standalone_properties`
List of effective properties with no choice group.

#### `required_properties`
List of effective standalone properties with `optional = false`.

#### `optional_properties`
List of effective standalone properties with `optional = true`.

#### `property_names`
Set or list of all effective property names.

#### `dimension_names`
Set or list of all symbolic dimension names appearing in the effective properties.

### Invariants
- All derived indexes are constructed eagerly.
- Choice-group and branch structure is internally consistent.
- No malformed property definitions survive into the resolved object.

### Notes
- `ResolvedSpecification` is the primary input to validation and class-generation logic.
- Debugging should be easier because all major views are precomputed and inspectable.

---

## `SpecificationRegistry`

### Role
Owns specification loading, parsing, caching, and inheritance resolution.

### Responsibilities
- load specification files from one or more directories
- parse files into local `Specification`
- cache local specifications
- resolve specifications into `ResolvedSpecification`
- cache resolved specifications
- support reload / cache invalidation

### Core Operations
- load specifications from disk
- retrieve local specification by name
- retrieve resolved specification by name
- list known specifications
- reload/rebuild registry state

### Invariants
- Local specs and resolved specs are clearly distinguished.
- Resolved specs are built from local specs through inheritance resolution.
- Cache behavior is predictable and explicit.

---

## Normalization Rules

### General Rule
Specification text is parsed in stages:
1. Raw file parsing
2. Property normalization
3. Local `Specification` construction
4. Inheritance resolution into `ResolvedSpecification`
5. Eager derived index construction

---

## Property Option Classification

Property modifiers fall into three categories.

### 1. Intrinsic property modifiers
These remain on `PropertyDefinition`.

Examples:
- `optional`
- `variable_length`
- `enum:*`
- `regex:*`
- value constraints such as `positive`

### 2. Structural choice modifiers
These become explicit fields on `PropertyDefinition`.

Examples:
- `or:group:branch`

### 3. Relational modifiers
These are lifted into `ConstraintRule`.

Examples:
- `requires:*`
- future paired or all-or-none style inline forms

---

## Relational Modifier Normalization

### Authored Form
A user may author a relational rule inline with a property.

Example:
```text
attachments - bytes - num_attachments - optional,requires:attachment_names
```

### Canonical Form
During normalization:
- `optional` remains on `PropertyDefinition`
- `requires:attachment_names` becomes a `ConstraintRule`
- the relational modifier is not retained as a raw property option

### Important Rule
After normalization, relational modifiers must not remain duplicated in `PropertyDefinition`.

This avoids multiple sources of truth.

---

## Shape Normalization

### Raw Form
Shapes may be authored as:
- `scalar`
- `num_nodes`
- `num_nodes,3`

### Canonical Form
They normalize to a list of `Dimension`.

Examples:
- `scalar` -> `[]`
- `num_nodes` -> `[symbolic("num_nodes")]`
- `num_nodes,3` -> `[symbolic("num_nodes"), fixed(3)]`

---

## Inheritance Resolution Rules

### Parent-to-child order
Inheritance is resolved from parent to child.

### Effective Properties
Resolved properties are formed by combining inherited and local `PropertyDefinition` objects.

#### Property merging rule
- If declarations are distinct, they are retained.
- If identical declarations arise through inheritance, duplicate retention policy may be simplified later, but initial implementations should preserve correctness over aggressive deduplication.
- Same property names with different declarations remain valid as multiple effective alternatives.

### Enumerations
Enumerations are merged with child definitions overriding parent definitions on name collision.

### Constraints
Constraints are accumulated through inheritance.

### Storage Hints
Storage hints are accumulated through inheritance, with child-level overrides allowed where appropriate.

---

## Validation Semantics

### Principle
Modifiers do not use a general operator-precedence system. Instead, validation operates through semantic layers.

#### Layer 1: property-local semantics
For each present property:
- datatype validity
- shape validity
- enum validity
- regex validity
- value constraint validity

#### Layer 2: choice semantics
Determine validity of choice groups and branches.

#### Layer 3: relational semantics
Evaluate cross-property `ConstraintRule` objects.

---

## Meaning of `optional`
`optional` means:
- the property is not unconditionally required by the schema

It does **not** mean:
- the property can never become conditionally required through a relationship rule

---

## Meaning of `requires`
`requires` means:
- if the subject property is present, the target property must also be present

This is conditional presence logic, not an override of the `optional` flag.

---

## Choice-Group Interaction
A branch is valid only if:
- all of its properties satisfy local declaration checks
- all relevant relational constraints are satisfied

Constraint rules that originate from a property inside a choice branch should carry source context so future implementations can scope them appropriately when evaluating branch validity.

---

## Debugging and Inspection

The canonical model should support easy inspection for debugging. At minimum, implementations should provide ways to inspect:

- local properties of a `Specification`
- effective properties of a `ResolvedSpecification`
- property groupings by name
- choice groups and branches
- dimension names
- constraint rules
- storage hints
- ancestry chain

---

## Future Extensions

This model is designed to support future additions without another major structural refactor, including:

- richer value constraints
- dedicated `constraints` section parsing
- dedicated `chunking` or `storage_hints` section parsing
- improved validation reports
- out-of-core storage defaults
- documentation generation from canonical objects
- optional alternate machine-oriented spec serializations

---

## Summary

The canonical internal specification model has the following key properties:

- flat canonical property storage
- explicit dimension abstraction
- explicit local vs resolved specifications
- eager resolved indexes for debugging and validation
- relational constraints lifted to specification-level rules
- storage hints included as first-class placeholders
- validation semantics layered rather than precedence-based

This model should become the foundation for parser refactoring, validation refactoring, documentation generation, and future specification-language extensions in both Python and MATLAB.