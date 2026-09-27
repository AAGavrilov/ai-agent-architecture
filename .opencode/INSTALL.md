# Superpowers — установка в opencode

Файл фиксирует способ подключения Superpowers ([obra/superpowers](https://github.com/obra/superpowers)) к проекту и правило подавления его bootstrap.

## Bootstrap `using-superpowers`

Superpowers активируется автоматически через bootstrap `using-superpowers` (SessionStart hook) и по умолчанию триггерит скиллы до любой задачи.

Правило проекта (см. `.agents/adapters/superpowers.md`, §22):

| Сессия | Bootstrap `using-superpowers` |
| --- | --- |
| Кодер | активен; действует список разрешённых скиллов из §21 адаптера |
| Архитектор | подавлен/игнорируется; работа идёт по `.agents/prompts/01-analysis.md` |
| Ревьювер | подавлен/игнорируется; вердикт строится по `.agents/prompts/03-review.md` |

## Подавление bootstrap

Bootstrap подавляется на уровне harness'а установки Superpowers. Для opencode это выполняется настройкой установленного Superpowers (SessionStart hook `using-superpowers`), а не правкой файлов проекта.

Конкретный способ подавления зависит от версии и конфигурации установленного Superpowers. Этот файл фиксирует только проектную политику: наличие Superpowers в проекте не снимает обязанность следовать production-контракту (`AGENTS.md`, `.agents/ORCHESTRATOR.md`).

## Границы

Superpowers — execution-layer Кодера. Он не проектирует архитектуру и не заменяет независимого Ревьювера. Приоритет источников истины задан в `.agents/adapters/superpowers.md`, §1.
