# Framework development examples

Материалы этого каталога — **историческая/примерная** документация, а не runtime state.

- `framework-development/IMPLEMENTATION.md`, `REVIEW_REPORT.md` — завершённый цикл разработки самого каркаса (cycle 1, вендоринг скиллов Архитектора, вердикт `APPROVED`).

Граница семантики:

```text
docs/agent/       = активный workflow (STATE.md + PROJECT_SPEC.md)
docs/examples/    = исторический/примерный материал
```

Runtime state нового workflow всегда живёт только в `docs/agent/STATE.md`; примеры здесь на него не влияют (`.agents/HARNESS_CONTRACT.md`, REQ-HARNESS-025).
