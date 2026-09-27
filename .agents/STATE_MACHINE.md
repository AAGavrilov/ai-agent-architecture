# Workflow State Machine

## Purpose

This document is the canonical definition of the workflow state machine.

Role prompts MUST NOT redefine state transitions.

Role prompts MAY explain how a role performs work inside an allowed state.

## States

- INIT
- ARCHITECTURE_PENDING
- ARCHITECTURE_READY
- IMPLEMENTATION_PENDING
- IMPLEMENTATION_READY
- REVIEW_PENDING
- REVIEW_READY
- WAITING_HUMAN
- COMPLETED
- HALTED

## Verdicts

- APPROVED
- APPROVED_WITH_CHANGES
- CHANGES_REQUIRED
- REJECTED

## Transition rules

### Normal transitions

INIT
  -> ARCHITECTURE_PENDING

ARCHITECTURE_PENDING
  -> ARCHITECTURE_READY
  when valid Architecture commit exists

ARCHITECTURE_READY
  -> IMPLEMENTATION_PENDING
  when Coder is dispatched

IMPLEMENTATION_PENDING
  -> IMPLEMENTATION_READY
  when valid Implementation commit exists

IMPLEMENTATION_READY
  -> REVIEW_PENDING
  when Reviewer is dispatched

REVIEW_PENDING
  -> REVIEW_READY
  when valid Review commit exists

REVIEW_READY
  -> COMPLETED
  when verdict = APPROVED

REVIEW_READY
  -> COMPLETED
  when verdict = APPROVED_WITH_CHANGES

REVIEW_READY
  -> IMPLEMENTATION_PENDING
  when verdict = CHANGES_REQUIRED
  and implementation limit is not exceeded

REVIEW_READY
  -> ARCHITECTURE_PENDING
  when verdict = REJECTED
  and architecture revision limit is not exceeded

WAITING_HUMAN
  -> suspended state
  when human answer is received

### Escalation transitions

Escalation applies from any non-terminal state (including WAITING_HUMAN):

any non-terminal state
  -> WAITING_HUMAN
  when an unresolved blocking Q-* exists

any non-terminal state
  -> HALTED
  when a configured limit is exceeded

any non-terminal state
  -> HALTED
  when an unrecoverable protocol violation occurs

A blocking Q-* is unresolved when no approved ASM-* resolves it.

An ASM-* resolves a Q-* when its definition declares both clauses on the
same line:

    - **ASM-NNN** — <text> — Resolves: Q-NNN; Status: APPROVED

`Status: APPROVED` is the approval marker; any other status (for example
`PROPOSED`) does not resolve the question. See HARNESS_CONTRACT.md,
REQ-HARNESS-033 and ORCHESTRATOR.md, Q-* AND ASM-* PROTOCOL.

### Bootstrap escalation from INIT

INIT is a non-terminal state and is NOT exempt from the escalation rule:

INIT
  -> WAITING_HUMAN

Allowed when:

- a blocking Q-* exists;
- that Q-* is unresolved;
- human input is required before Cycle 1 can start.

This is a bootstrap escalation, not a normal transition: no role is allowed
to perform workflow work in INIT, so the orchestrator (or the human) parks
the instance until the question is answered, and the workflow then resumes
at INIT.

Escalation never applies from a terminal state, and never targets the
source state itself (no self-loop).

## Terminal states

COMPLETED
HALTED

No automatic transition is allowed from a terminal state.

## Runtime state

Runtime state is stored in:

docs/agent/STATE.md

Memory.md MUST NOT store runtime state.

## Git evidence

Every state transition that depends on an artifact MUST have corresponding repository evidence.

No textual claim by an agent is sufficient evidence when the state can be verified deterministically.
