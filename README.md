# ai-agent-architecture

Каркас агентного workflow разработки. Три роли — Архитектор, Кодер, Ревьювер — работают итерациями и обмениваются контрактными артефактами через файлы репозитория, а не через пересказ в чате. Прикладного кода пока нет: продукт репозитория — сам процесс.

## Структура

```
ai-agent-architecture/
│
├── AGENTS.md              ← постоянные правила работы агента
├── Memory.md              ← долговременная память агента
│
├── .agents/
│   ├── ORCHESTRATOR.md    ← протокол итерации: запуск трёх ролей по очереди
│   ├── STATE_MACHINE.md   ← каноническая state machine (states, transitions, verdicts)
│   ├── HARNESS_CONTRACT.md← deterministic invariants каркаса (REQ-HARNESS-*)
│   │
│   ├── prompts/
│   │   ├── 01-analysis.md        ← Архитектор → docs/agent/PROJECT_SPEC.md
│   │   ├── 02-implementation.md  ← Кодер      → docs/agent/IMPLEMENTATION.md
│   │   └── 03-review.md          ← Ревьювер   → docs/agent/REVIEW_REPORT.md
│   │
│   ├── skills/                        ← вендоренные скиллы Архитектора
│   │   ├── grilling/SKILL.md          ← (mattpocock/skills, адаптированные
│   │   ├── to-questionnaire/SKILL.md  ←  под контракт проекта; см. адаптер
│   │   └── research/SKILL.md          ←  .agents/adapters/mattpocock-skills.md)
│   │
│   └── adapters/
│       ├── superpowers.md        ← execution-layer Кодера (obra/superpowers)
│       └── mattpocock-skills.md  ← execution-layer Архитектора (mattpocock/skills)
│
├── .opencode/
│   └── INSTALL.md         ← политика bootstrap Superpowers по ролям
│
├── docs/
│   ├── agent/             ← активный workflow (runtime + контракт)
│   │   ├── STATE.md       ← runtime workflow state (счётчики, коммиты, verdict)
│   │   └── PROJECT_SPEC.md
│   ├── architecture/      ← курируемая документация для людей
│   │   └── HARNESS_ONBOARDING.md ← приёмочный чек-лист новой среды
│   └── examples/          ← исторический/примерный материал (не runtime state)
│       ├── README.md
│       └── framework-development/
│           ├── IMPLEMENTATION.md   ← завершённый цикл разработки каркаса
│           └── REVIEW_REPORT.md
│
├── src/                   ← прикладной код (пока пуст)
└── tests/
    └── harness/           ← deterministic-проверки workflow без LLM
        ├── check-all.sh        ← aggregate: все проверки + fixtures
        ├── check-block0.sh
        ├── check-state.sh
        ├── check-contracts.sh
        ├── check-git-protocol.sh
        ├── run-fixtures.sh     ← unit tests валидаторов (negative fixtures)
        └── fixtures/           ← ожидаемые FAIL/PASS кейсы
```

## Workflow State

The current workflow state is stored in:

`docs/agent/STATE.md`

The canonical transition model is:

`.agents/STATE_MACHINE.md`

`Memory.md` is not a runtime state store.

For this repository `main` is a reusable framework template: new workflow
instances start from `State: INIT`, and historical framework-development
records live in `docs/examples/` (not runtime evidence).

## Deterministic Harness

Run:

```bash
tests/harness/check-all.sh
```

The harness validates:

- Block 0 identity;
- state machine invariants;
- transition semantics;
- contract identifier uniqueness;
- dangling references;
- Git protocol;
- iteration limits;
- review verdict routing.

## С чего начать

- Постоянные правила работы агентов — `AGENTS.md`.
- Протокол итерации: порядок запуска ролей, gates, лимиты, маршрутизация по verdict — `.agents/ORCHESTRATOR.md`.
- Каноническая state machine (состояния и transitions) — `.agents/STATE_MACHINE.md`; runtime state — `docs/agent/STATE.md`.
- Deterministic-проверки workflow — `tests/harness/`, запуск агрегатом `bash tests/harness/check-all.sh` (без LLM; CI — `.github/workflows/harness.yml`).
- Execution-слои ролей (Superpowers для Кодера, mattpocock/skills для Архитектора) — `.agents/adapters/`; политика bootstrap Superpowers — `.opencode/INSTALL.md`.
