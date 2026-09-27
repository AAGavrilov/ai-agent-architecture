# AGENTS.md

## 1. Purpose

This file defines the permanent rules for AI agents working in this repository.

These rules apply to all tasks unless more specific instructions explicitly override them.

The repository uses the following development workflow:

1. Analysis
2. Implementation
3. Review

The corresponding project prompts are located in:

- `.agents/prompts/01-analysis.md`
- `.agents/prompts/02-implementation.md`
- `.agents/prompts/03-review.md`

When Superpowers is used, its workflow is connected to the project workflow through:

`.agents/adapters/superpowers.md`

---

## 2. Instruction Hierarchy

When instructions conflict, use the following priority:

1. System-level instructions and platform rules.
2. User instructions for the current task.
3. The most specific applicable `AGENTS.md`.
4. This `AGENTS.md`.
5. Project-specific documentation.
6. General assumptions or conventions.

If multiple `AGENTS.md` files exist, the most specific file applicable to the current directory takes precedence.

Do not override higher-priority instructions with lower-priority ones.

---

## 3. Core Principle

Before changing code, the agent must understand the relevant part of the existing system.

For non-trivial tasks, the agent should:

1. Read `AGENTS.md`.
2. Read `Memory.md`.
3. Inspect the relevant source code.
4. Inspect relevant tests.
5. Inspect relevant documentation and configuration.
6. Understand existing conventions and constraints.
7. Determine the minimum necessary change.
8. Plan the work.
9. Implement the change.
10. Verify the result.
11. Update `Memory.md` when durable project knowledge has changed.
12. Complete the task only after the relevant checks have passed.

Do not start implementing a non-trivial change based only on the task description.

---

## 4. Project Memory

The project's persistent memory is stored in:

`Memory.md`

`Memory.md` is the agent's long-term memory: the canonical source of accumulated project context that should survive across development sessions. It is distinct from the iteration contract artifacts, which live in `docs/agent/`:

- `docs/agent/PROJECT_SPEC.md` — the architecture contract (written by the Architect);
- `docs/agent/IMPLEMENTATION.md` — the iteration report (written by the Coder);
- `docs/agent/REVIEW_REPORT.md` — the independent review (written by the Reviewer).

When they conflict, the source-of-truth priority is: current code and Git history → `docs/agent/` artifacts and tests → `Memory.md`. `Memory.md` never overrides the code or the contract artifacts.

Before starting a non-trivial task, the agent must read `Memory.md` and take its contents into account.

The agent should use `Memory.md` to understand, when applicable:

- important architectural decisions;
- established conventions;
- previous implementation decisions;
- known constraints and limitations;
- unresolved issues;
- important project context;
- decisions made during previous development sessions.

### 4.1 Updating Memory.md

After completing every substantial change, the agent must explicitly determine whether the change produced information that is valuable for future development.

If it did, the agent must update `Memory.md` before considering the task complete.

Examples of information that should normally be preserved:

- architectural decisions;
- important implementation decisions;
- new project conventions;
- discovered constraints;
- non-obvious dependencies between components;
- important limitations;
- decisions that future developers or agents are likely to need;
- unresolved issues that affect future work.

The agent should not update `Memory.md` for changes that provide no durable project knowledge.

Memory should contain information that is useful beyond the current task.

Do not add:

- temporary reasoning;
- conversational noise;
- routine implementation details;
- information that can be trivially reconstructed from the code;
- speculative assumptions presented as facts.

### 4.2 Memory Update Rules

When updating `Memory.md`:

1. Preserve existing useful information.
2. Do not silently delete or rewrite valid historical context.
3. Prefer concise, durable statements.
4. Record important decisions together with their rationale when the rationale matters.
5. Remove or correct information only when it is demonstrably obsolete or incorrect.
6. Do not duplicate the entire project documentation in `Memory.md`.
7. Do not record temporary task-specific reasoning unless it has durable value.

### 4.3 Memory and Current Code

`Memory.md` describes accumulated project knowledge, but the current codebase is the source of truth for the actual implementation.

If `Memory.md` conflicts with the current code:

1. Verify the discrepancy.
2. Treat the current implementation as authoritative for the current state.
3. Determine whether the memory is outdated.
4. Update `Memory.md` when appropriate so the discrepancy does not persist.

Do not blindly follow outdated information from `Memory.md`.

### 4.4 Memory Workflow

For non-trivial tasks, use this sequence:

1. Read `AGENTS.md`.
2. Read `Memory.md`.
3. Inspect the relevant code and documentation.
4. Perform the task.
5. Run relevant verification.
6. Determine whether the completed change produced durable project knowledge.
7. If yes, update `Memory.md`.
8. Only then consider the task complete.

Updating `Memory.md` after a substantial change is part of the development workflow, not an optional documentation step.

---

## 5. Repository Understanding

Before modifying a component, identify, when relevant:

- the language and framework;
- the package manager;
- the build system;
- the test framework;
- linting and formatting tools;
- type checking;
- repository structure;
- relevant modules;
- configuration files;
- CI/CD configuration;
- deployment configuration;
- existing project conventions.

Do not assume tools or architecture when they can be determined from the repository.

Prefer existing project mechanisms over introducing new ones.

---

## 6. Existing Code First

Before creating a new implementation, search the repository for existing functionality that may already solve part of the problem.

The agent should:

- inspect relevant implementations;
- search for existing abstractions;
- inspect call sites;
- inspect interfaces and types;
- inspect tests;
- inspect configuration;
- identify dependencies between components.

Do not create duplicate mechanisms when an existing abstraction can reasonably be extended.

Do not rewrite existing code merely for stylistic preference.

---

## 7. Planning

Complex or non-trivial tasks must have an explicit implementation plan.

The plan should identify:

- the objective;
- relevant existing components;
- files or areas likely to change;
- dependencies between changes;
- architectural implications;
- testing strategy;
- Definition of Done.

For a simple, localized change, a separate detailed plan is not required.

If implementation reveals that the plan is materially incorrect, do not silently continue with a substantially different architecture.

Reassess the plan before proceeding.

---

## 8. Three-Stage Development Workflow

The project uses three primary stages. Each stage corresponds to a role and a prompt file:

| Stage | Role | Prompt file | Artifact |
| --- | --- | --- | --- |
| Analysis | Архитектор (Software Architect) | `.agents/prompts/01-analysis.md` | `docs/agent/PROJECT_SPEC.md` |
| Implementation | Кодер (Senior Developer) | `.agents/prompts/02-implementation.md` | `docs/agent/IMPLEMENTATION.md` |
| Review | Ревьювер (Lead Code Reviewer) | `.agents/prompts/03-review.md` | `docs/agent/REVIEW_REPORT.md` |

The iteration protocol that runs these roles in order is defined in `.agents/ORCHESTRATOR.md`.

Artifacts use stable identifiers (`REQ-`, `ASM-`, `Q-`, `DEC-`, `BLK-`, `BIMP-`, `REV-`, `CONFLICT-`). The convention is defined in the role prompts; do not redefine it here.

### Stage 1 — Analysis

Prompt:

`.agents/prompts/01-analysis.md`

The Analysis stage is responsible for:

- understanding the requirement;
- investigating the repository;
- identifying constraints;
- identifying relevant existing functionality;
- analyzing architectural impact;
- identifying risks;
- producing an implementation plan;
- defining the expected outcome.

Analysis should not unnecessarily modify production code.

The output of Analysis should provide sufficient context for Implementation.

---

### Stage 2 — Implementation

Prompt:

`.agents/prompts/02-implementation.md`

The Implementation stage is responsible for:

- implementing the approved plan;
- following existing architecture and conventions;
- writing or updating tests;
- performing relevant local verification;
- keeping changes minimal and focused.

Implementation should not silently introduce unrelated architectural changes.

If implementation reveals a significant architectural issue, return to Analysis rather than making an undocumented architectural decision.

---

### Stage 3 — Review

Prompt:

`.agents/prompts/03-review.md`

The Review stage is responsible for independently checking:

- requirement coverage;
- correctness;
- code quality;
- architectural consistency;
- tests;
- regressions;
- edge cases;
- security implications where applicable;
- Definition of Done.

Review must be treated as an independent verification stage, not merely as a continuation of implementation.

If Review finds an implementation defect, return to Implementation.

If Review finds an architectural problem, return to Analysis.

A task is not complete until the Review stage is satisfied or all known limitations are explicitly documented.

---

## 9. Execution-Layer Integrations

Each role has at most one execution-layer tool integration. Adapters define them:

- Superpowers ([obra/superpowers](https://github.com/obra/superpowers)) is the Coder-side execution layer: `.agents/adapters/superpowers.md`
- mattpocock/skills is the Architect-side execution layer: `.agents/adapters/mattpocock-skills.md`

The Reviewer deliberately has no execution layer: independence is the value of the Review stage.

The responsibilities are separated as follows:

- `AGENTS.md` defines permanent project rules.
- `Memory.md` contains persistent project knowledge.
- Execution layers are execution-only: Superpowers does not design architecture; mattpocock/skills does not make design decisions instead of the Architect. Neither replaces the independent Reviewer.
- The adapter files connect each tool to the project workflow.
- The three project prompts define the behavior of the individual development stages.

The role restriction is universal, tool- and harness-independent:

- Normative baseline, valid in every environment: outside its own role's session, an integrated tool's bootstrap and skills are ignored — the Architect works only by `.agents/prompts/01-analysis.md` (plus the mattpocock/skills allowlist), the Coder only by `.agents/prompts/02-implementation.md` (plus the Superpowers allowlist), the Reviewer only by `.agents/prompts/03-review.md` with no skill layers at all. Every role session must read `AGENTS.md` and its role prompt before starting work (`.agents/ORCHESTRATOR.md`, section 3), so this rule binds any agent that runs the iteration protocol, regardless of the harness or of whether the tools are installed there.
- Technical suppression is optional per-harness hardening: it prevents a tool's bootstrap or skills from entering the context at all and is configured where the tool is installed (for Superpowers in opencode: `.opencode/INSTALL.md`). It never replaces the normative baseline.
- When a skill's output format or process conflicts with the project contract (artifacts as files in `docs/agent/`, the identifier convention, role prompt output templates), the contract wins.

Do not duplicate the full workflow of an integrated tool inside `AGENTS.md`.

Do not duplicate the complete contents of the three project prompts inside `AGENTS.md`.

Each adapter should remain a thin integration layer.

---

## 10. Change Scope

Changes should be:

- minimal;
- focused;
- consistent with the existing architecture;
- easy to verify;
- easy to review;
- reasonably easy to revert.

Do not perform unrelated cleanup.

Do not reformat entire files without a reason.

Do not rename entities solely for stylistic reasons.

Do not modify unrelated components unless the task requires it.

Minimal change does not mean avoiding necessary architectural work. If a larger change is required, it should be identified and justified.

---

## 11. Architecture

Do not make significant architectural decisions silently.

Architectural changes include, but are not limited to:

- changing module boundaries;
- changing public APIs;
- changing data models;
- replacing major libraries or frameworks;
- changing communication protocols;
- changing persistence strategy;
- changing deployment architecture;
- introducing new infrastructure;
- introducing a new architectural pattern.

When a significant architectural change is required:

1. Identify it during Analysis.
2. Document the decision and rationale when appropriate.
3. Reflect the decision in `Memory.md` if it is durable project knowledge.
4. Implement it deliberately.
5. Verify its impact.

---

## 12. Public APIs and Contracts

Do not change public APIs or external contracts without determining their impact.

Before changing a contract, inspect:

- callers;
- consumers;
- tests;
- documentation;
- configuration;
- integrations;
- compatibility requirements.

Prefer backwards-compatible changes unless the task explicitly requires a breaking change.

If a breaking change is necessary, make the impact explicit.

---

## 13. Testing and Verification

After making changes, run the most relevant available checks.

Preferred order:

1. Tests directly related to the changed component.
2. Related tests.
3. Type checking or static analysis.
4. Linting.
5. Build.
6. Broader test suites when appropriate.

The exact commands should be determined from the repository rather than assumed.

Do not consider a task complete merely because the code appears correct.

If a relevant check cannot be run, report:

- which check was not run;
- why it could not be run;
- what alternative verification was performed.

Never disable or weaken tests, linting, type checking, or security checks merely to obtain a passing result.

---

## 14. Error Handling and Debugging

When a problem is found:

1. Determine the actual cause.
2. Verify assumptions.
3. Fix the underlying cause rather than only the symptom.
4. Re-run relevant verification.
5. Check for regressions.

Do not hide errors by:

- disabling tests;
- weakening validation;
- suppressing errors without justification;
- bypassing type checks;
- removing security controls.

---

## 15. Dependencies

Do not add a new dependency when existing project capabilities can reasonably solve the problem.

Before adding a dependency, check:

- whether an equivalent dependency already exists;
- whether the dependency is genuinely necessary;
- compatibility with the current stack;
- runtime implications;
- build implications;
- security implications;
- lock-file changes;
- maintenance implications.

Keep dependency changes scoped to the task.

---

## 16. Configuration

Before modifying configuration, determine:

- where the configuration is used;
- which environments it affects;
- whether environment-specific configuration exists;
- whether deployment configuration is affected;
- whether documentation must be updated.

Do not modify production configuration merely to solve a local development problem.

Do not commit secrets, credentials, API keys, private keys, passwords, or tokens.

---

## 17. Security

Security-sensitive behavior must not be weakened without explicit justification.

Do not:

- expose secrets;
- commit credentials;
- log sensitive values;
- bypass authentication;
- bypass authorization;
- disable validation;
- disable security controls;
- introduce insecure defaults.

When modifying security-sensitive functionality, inspect relevant existing security mechanisms before making changes.

---

## 18. Documentation

Update documentation when a change affects:

- public APIs;
- user-visible behavior;
- configuration;
- installation;
- development workflow;
- deployment;
- architecture;
- important project conventions.

Documentation should describe the actual current behavior.

Do not duplicate information unnecessarily between documentation and `Memory.md`.

Use `Memory.md` for durable project knowledge and decisions.

Use `docs/agent/` for the volatile, machine-oriented iteration contract artifacts (`PROJECT_SPEC.md`, `IMPLEMENTATION.md`, `REVIEW_REPORT.md`) that agents read and write by path.

Use `docs/architecture/` and other `docs/` subfolders for curated, human-facing documentation. Do not duplicate `docs/agent/` content into human docs or vice versa. `docs/specs/` and `docs/decisions/` are not used: `DEC-*` live inside `PROJECT_SPEC`.

---

## 19. Git Safety

Do not perform destructive Git operations without explicit user authorization.

Do not:

- delete user changes;
- reset unrelated work;
- overwrite uncommitted changes;
- force-push;
- rewrite history;
- discard files without authorization.

Before changing files, take existing uncommitted changes into account.

Do not assume the working tree is clean.

---

## 20. Ambiguity

If requirements are unambiguous, execute them directly.

If a critical ambiguity affects architecture, data, security, public behavior, or scope, clarify it before proceeding.

If the ambiguity can be safely resolved by inspecting the repository, documentation, or existing conventions, investigate first.

Do not ask questions whose answers can reasonably be determined from the project itself.

When making a reasonable assumption, keep the assumption consistent with existing project conventions and record it when it has durable architectural significance.

---

## 21. Scope Discipline

The agent should distinguish between:

- required changes;
- necessary supporting changes;
- optional improvements;
- unrelated improvements.

Only required and necessary supporting changes should normally be included.

Optional improvements should not be silently bundled into the task.

If an unrelated issue is discovered, mention it separately rather than expanding the scope without authorization.

---

## 22. Completion Criteria

A task is considered complete only when:

- the requested behavior is implemented;
- the implementation integrates with the existing system;
- relevant tests and checks have been performed;
- no known relevant regression remains;
- the implementation follows project conventions;
- required documentation is updated;
- durable project knowledge has been added to `Memory.md` when appropriate;
- Review has been completed;
- known limitations are explicitly documented.

---

## 23. Definition of Done

Before declaring a task complete, verify:

- [ ] Requirements are satisfied.
- [ ] Relevant existing code was inspected.
- [ ] Existing abstractions were reused where appropriate.
- [ ] The implementation is scoped to the task.
- [ ] Relevant tests were added or updated.
- [ ] Relevant tests were executed.
- [ ] Type checking/static analysis was performed when applicable.
- [ ] Linting was performed when applicable.
- [ ] Build verification was performed when applicable.
- [ ] Documentation was updated when required.
- [ ] `Memory.md` was reviewed and updated when durable knowledge changed.
- [ ] No unrelated user changes were overwritten.
- [ ] Review was completed; the verdict in `docs/agent/REVIEW_REPORT.md` is `APPROVED` or `APPROVED_WITH_CHANGES`.
- [ ] Known limitations are documented.

---

## 24. Final Response

When completing a task, the agent should provide a concise summary containing:

1. What was changed.
2. Which relevant checks were performed.
3. Whether `Memory.md` was updated.
4. Any known limitations, unresolved issues, or follow-up items.

Do not claim that a check was performed if it was not actually performed.

Do not claim that a task is fully verified when relevant verification could not be completed.

---

## 25. Guiding Principle

Prefer solutions that are:

- correct;
- simple;
- maintainable;
- consistent with the existing architecture;
- minimally invasive;
- testable;
- understandable by future developers and agents.

The goal is not merely to produce working code.

The goal is to leave the repository in a state where the next development session can understand what was done, why it was done, and how to continue safely.