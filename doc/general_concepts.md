# General Concepts

Throughout the ESCDF Documentation, we will use the following definitions:

## File

The ESCDF file is the complete ESCDF package that will be delivered to the data consumer. This may contain one or more **Activities** which contain **Data** and reference **Metadata**.

## Activity

An activity is a general term for a test, analysis, or calculation that produces **Data** and is defined by **Metadata**. An example of an activity might be a random vibration test.

## Data

Data is the output of an **Activity** that we would like to share. Each piece of data will generally have multiple **Properties** associated with it. An example could be an acceleration signal over time.

## Metadata

Metadata is incidental or contextual information that aids in interpreting the **Data**. This could be signal processing parameters used to compute a spectral quantity, or geometric information showing where a measurement was obtained, or software settings used to run a given test.

## Property

A Property is an individual field of a **Data** or **Metadata** object. A **Data** object might have time steps, ordinate values, units, and a label to define which degree of freedom it is associated with. A **Metadata** object might have activity-specific settings like the window function used in a signal processing calculation.