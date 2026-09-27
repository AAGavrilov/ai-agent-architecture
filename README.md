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
│   ├── agent/             ← контрактные артефакты итерации (машинные, волатильные)
│   │   ├── PROJECT_SPEC.md
│   │   ├── IMPLEMENTATION.md
│   │   └── REVIEW_REPORT.md
│   └── architecture/      ← курируемая документация для людей
│       └── HARNESS_ONBOARDING.md ← приёмочный чек-лист новой среды
│
├── src/                   ← прикладной код (пока пуст)
└── tests/
```

## С чего начать

- Постоянные правила работы агентов — `AGENTS.md`.
- Протокол итерации: порядок запуска ролей, маршрутизация по verdict, критерии остановки — `.agents/ORCHESTRATOR.md`.
- Execution-слои ролей (Superpowers для Кодера, mattpocock/skills для Архитектора) — `.agents/adapters/`; политика bootstrap Superpowers — `.opencode/INSTALL.md`.
