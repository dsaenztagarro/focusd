# Features

End-to-end documentation of a shipped feature: what it does, the user flow, its configuration, and how the pieces connect. Where an [explainer](../architecture/) describes one *mechanism*, a feature doc describes one *capability* as the user experiences it — often spanning several mechanisms.

A feature doc doubles as a **backend design doc** for the `/epic` workflow: authored up front from an approved plan, it decomposes into implementation tickets; kept current after shipping, it explains the feature to the next maintainer.

## Suggested shape

- **Overview & user flow** — what it does and the path through it.
- **Configuration** — flags, settings, prerequisites.
- **Architecture** — an ASCII diagram and the key files/mechanisms (link their explainers/ADRs).
- **Edge cases & troubleshooting.**

## Conventions

- One feature per file, named for the feature.
- ASCII diagrams only; prose one line per paragraph.

<!-- Add feature docs here as capabilities ship. This folder starts empty by design. -->
