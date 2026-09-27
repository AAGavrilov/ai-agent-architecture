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

Any non-terminal state
  -> WAITING_HUMAN
  when blocking Q-* exists and no approved ASM-* can resolve it

WAITING_HUMAN
  -> suspended state
  when human answer is received

Any non-terminal state
  -> HALTED
  when a configured limit is exceeded

Any non-terminal state
  -> HALTED
  when an unrecoverable protocol violation occurs

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
