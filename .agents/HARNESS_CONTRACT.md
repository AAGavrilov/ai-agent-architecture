# Harness Contract

## Purpose

This document defines the deterministic invariants of the agent workflow
framework.

It is separate from product-specific requirements.

## Runtime state model

`STATE.md` is the current workflow snapshot.
Git history is the authoritative transition evidence.

`STATE.md` is runtime workflow metadata, not an implementation artifact.
Implementation baseline diffs MUST exclude it:

```bash
git diff "$BASE" "$TARGET" -- . ':(exclude)docs/agent/STATE.md'
```

If additional runtime files appear later, they MUST be added to the same
explicit exclusion list.

## Requirements

### REQ-HARNESS-001

The canonical workflow state machine MUST be defined in:

`.agents/STATE_MACHINE.md`

### REQ-HARNESS-002

Runtime workflow state MUST be stored in:

`docs/agent/STATE.md`

### REQ-HARNESS-003

Memory.md MUST NOT be the canonical source of runtime state.

### REQ-HARNESS-004

Every state transition MUST be permitted by STATE_MACHINE.md.

### REQ-HARNESS-005

Every artifact-dependent transition MUST have Git evidence.

### REQ-HARNESS-006

Architecture commits MUST use the cycle-scoped `Architecture <cycle>.<revision>:`
commit convention.

### REQ-HARNESS-007

Implementation commits MUST use the cycle-scoped `Iteration <cycle>.<iteration>:`
commit convention.

### REQ-HARNESS-008

Review commits MUST use the cycle-scoped `Review <cycle>.<review>:`
commit convention.

### REQ-HARNESS-009

Implementation baseline MUST be derived from implementation commits.

### REQ-HARNESS-010

Blocking Q-* MUST transition the workflow to WAITING_HUMAN.

### REQ-HARNESS-011

ASM-* MUST NOT silently replace blocking Q-*.

### REQ-HARNESS-012

REJECTED MUST represent an architecture-level failure.

### REQ-HARNESS-013

POTENTIAL MUST be independent from severity.

### REQ-HARNESS-014

Global contract identifiers MUST be unique.

### REQ-HARNESS-015

Dangling contract references MUST be detected.

### REQ-HARNESS-016

Iteration limits MUST be enforced deterministically.

### REQ-HARNESS-017

NO_PROGRESS limits MUST be enforced deterministically.

### REQ-HARNESS-018

COMPLETED MUST require an APPROVED or APPROVED_WITH_CHANGES verdict.

### REQ-HARNESS-019

CHANGES_REQUIRED MUST route REVIEW_READY to IMPLEMENTATION_PENDING.

### REQ-HARNESS-020

REJECTED MUST route REVIEW_READY to ARCHITECTURE_PENDING.

### REQ-HARNESS-021

HALTED MUST contain a valid halt reason.

### REQ-HARNESS-022

WAITING_HUMAN MUST contain a suspended state and blocking question.

### REQ-HARNESS-023

The aggregate harness MUST fail if any deterministic check fails.

### REQ-HARNESS-024

CI verification is separate from local harness verification.

HARNESS_PASS means:

the deterministic harness completed successfully.

CI_PASS means:

a GitHub Actions run associated with the relevant commit
completed successfully and the harness job succeeded.

The existence of a workflow run MUST NOT be interpreted as CI_PASS.

### REQ-HARNESS-025

When the repository is operating as a reusable workflow template,
`docs/agent/STATE.md` MUST represent a fresh workflow instance.

The initial state MUST be:

```text
State: INIT
Cycle: 0
Architecture revision: 0
Implementation iteration: 0
Review iteration: 0
No-progress count: 0
Verdict: null
```

Historical artifacts MUST NOT live in the active workflow directory
(`docs/agent/`); they belong to `docs/examples/` (see the directory
semantics in `docs/examples/README.md`).

### REQ-HARNESS-026

WAITING_HUMAN MUST contain:

- suspended state;
- blocking Q identifier;
- suspension reason.

### REQ-HARNESS-027

The referenced Q-* identifier MUST exist in the repository's
active workflow artifacts.

### REQ-HARNESS-028

HALTED MUST contain:

- halt reason;
- last valid state;
- evidence describing the halt condition.

### REQ-HARNESS-029

The implementation commit referenced by STATE.md is the last implementation
artifact, not necessarily HEAD.

`HEAD != current implementation commit` is allowed (framework documentation
may be committed on top of a completed or halted workflow).

### REQ-HARNESS-030

Identifier definitions MUST use the documented syntactic forms:

- bold (`**REQ-001**`);
- heading (`### REQ-HARNESS-001`);
- artifact-owned table row (first cell under an `ID` / `REV-ID` header).

Any other occurrence of an identifier is a reference and MUST resolve to a
definition; an unresolvable reference is a dangling identifier and fails the
harness. Alternative definition styles (for example `REQ-001 — text` in prose)
are not definitions and therefore produce dangling references.

### REQ-HARNESS-031

Q-* definitions MUST live in the active workflow artifacts (`docs/agent/`).

A WAITING_HUMAN blocking Q-* that has no definition there fails the harness.

### REQ-HARNESS-032

Artifact commit numbering is cycle-scoped: `<Type> <cycle>.<counter>:`.

Commits that carry no explicit cycle (`<Type> <counter>:`) are legacy cycle 1
and MUST be normalized to `<Type> 1.<counter>:` for validation.

Counter continuity, implementation baseline rules, and STATE.md cross-checks
are evaluated per cycle: a new cycle restarts counters at 1 without
conflicting with earlier cycles.

## Validator mapping

```text
check-block0.sh
    → REQ-HARNESS-001
```

```text
check-state.sh
    → REQ-HARNESS-002
    → REQ-HARNESS-004
    → REQ-HARNESS-005
    → REQ-HARNESS-016
    → REQ-HARNESS-017
    → REQ-HARNESS-018
    → REQ-HARNESS-019
    → REQ-HARNESS-020
    → REQ-HARNESS-021
    → REQ-HARNESS-022
    → REQ-HARNESS-025
    → REQ-HARNESS-026
    → REQ-HARNESS-027
    → REQ-HARNESS-028
    → REQ-HARNESS-029
    → REQ-HARNESS-031
```

```text
ORCHESTRATOR.md (CI Verification, §12)
    → REQ-HARNESS-024
```

```text
check-contracts.sh
    → REQ-HARNESS-014
    → REQ-HARNESS-015
    → REQ-HARNESS-030
```

```text
check-git-protocol.sh
    → REQ-HARNESS-006
    → REQ-HARNESS-007
    → REQ-HARNESS-008
    → REQ-HARNESS-009
    → REQ-HARNESS-032
```
