# Superpowers Adapter

## Назначение

Этот адаптер подключает Superpowers — фреймворк инженерных скиллов [obra/superpowers](https://github.com/obra/superpowers) — к production-процессу проекта.

Superpowers используется как **внутренний execution layer Кодера** (роль A: execution-only):

```text
PROJECT_SPEC
     ↓
Superpowers workflow
     ↓
Implementation
     ↓
Verification
     ↓
docs/agent/IMPLEMENTATION.md
     ↓
Iteration N
```

Superpowers **не заменяет**:

* `PROJECT_SPEC`;
* архитектурные решения `DEC-*`;
* требования `REQ-*`;
* замечания `REV-*`;
* блокеры `BLK-*`;
* заблокированные реализации `BIMP-*`;
* архитектурные конфликты `CONFLICT-*`;
* `docs/agent/IMPLEMENTATION.md`;
* `docs/agent/REVIEW_REPORT.md`;
* независимого Ревьювера;
* Git-протокол проекта.

Superpowers **не проектирует архитектуру** и не принимает архитектурных решений. Дизайн — только Архитектор, см. `.agents/ORCHESTRATOR.md`. Скиллы `brainstorming` и `writing-plans` на уровне дизайна проекта не используются (см. §21).

Скиллы Superpowers триггерятся автоматически через bootstrap `using-superpowers`. Поэтому вне сессии Кодера его скиллы игнорируются, а bootstrap при возможности технически подавляется (см. §22).

---

## 1. ИЕРАРХИЯ ИСТОЧНИКОВ ИСТИНЫ

При конфликте между Superpowers и production-контрактом проекта действует следующий приоритет:

```text
PROJECT_SPEC
    ↓
REQ-* / DEC-*
    ↓
REVIEW_REPORT / REV-*
    ↓
BLK-* / BIMP-* / CONFLICT-*
    ↓
AGENTS.md
    ↓
Superpowers workflow
    ↓
локальный implementation plan
```

Superpowers не имеет права самостоятельно изменять более высокий уровень.

В частности:

* Superpowers не может изменить `REQ-*`;
* Superpowers не может изменить `DEC-*`;
* Superpowers не может принять архитектурное решение вместо Архитектора;
* Superpowers не может закрыть `REV-*` без фактической проверки;
* Superpowers не может считать задачу завершённой только потому, что его внутренний workflow завершён.

---

## 2. SUPERPOWERS — ВНУТРЕННИЙ WORKFLOW КОДЕРА

Используй Superpowers для:

1. понимания задачи;
2. исследования существующего кода;
3. формулирования implementation plan (`writing-plans`);
4. декомпозиции сложной работы;
5. TDD (`test-driven-development`);
6. реализации (`executing-plans` или `subagent-driven-development`);
7. локальной проверки (`verification-before-completion`);
8. self-review;
9. диагностики (`systematic-debugging`).

Не создавай отдельную конкурирующую систему статусов проекта.

Внешний статус итерации определяется только production-контрактом:

```text
DONE
NOT_DONE
```

Отдельного статуса `BLOCKED` не существует: блокировка выражается через `BLK-*` / `BIMP-*`, а пропуск/дефект — через `NOT_DONE` и `REV-*`. Вердикт ревью берётся из `docs/agent/REVIEW_REPORT.md` (`APPROVED`, `APPROVED_WITH_CHANGES`, `CHANGES_REQUIRED`, `REJECTED`), а не из внутреннего состояния Superpowers.

---

## 3. SUPERPOWERS START GATE

Superpowers запускается **на стороне Кодера**, когда существует конкретная implementation-задача.

Superpowers **не запускается для определения архитектуры проекта** и не заменяет Архитектора.

### Первый запуск

Для новой фичи или нового проекта порядок такой:

```text
Требование / задача
        ↓
Архитектор
        ↓
PROJECT_SPEC
        ↓
утверждение архитектуры
        ↓
Кодер + Superpowers
```

Superpowers может начинать implementation workflow только после того, как:

1. `docs/agent/PROJECT_SPEC.md` существует;
2. текущая implementation-задача определена;
3. затронутые `REQ-*` идентифицированы;
4. соответствующие `DEC-*` прочитаны;
5. отсутствует нерешённый архитектурный `BLK-*` / `CONFLICT-*`, делающий реализацию неопределённой.

### Повторный запуск после ревью

Если предыдущая implementation получила:

```text
CHANGES_REQUIRED
```

Кодер снова запускает Superpowers для исправления:

```text
PROJECT_SPEC
+
REVIEW_REPORT
+
текущий код
+
Git history
        ↓
Кодер + Superpowers
        ↓
следующая Iteration
```

Если замечание требует изменения архитектуры, Superpowers не исправляет его самостоятельно. Сначала задача передаётся Архитектору.

### Не запускать Superpowers

Не запускай implementation workflow, если:

* отсутствует критически необходимое архитектурное решение;
* `PROJECT_SPEC` противоречив;
* требуется изменить `REQ-*` или `DEC-*`;
* есть нерешённый архитектурный `CONFLICT-*`;
* невозможно определить acceptance criteria.

В этих случаях создай соответствующий `Q-*`, `BLK-*` или `CONFLICT-*`.

### Важное правило

Скиллы Superpowers не нумерованы и не запускаются «по номерам». Кодер использует Superpowers как единый execution workflow и активирует подходящий навык по текущему этапу работы — из списка, разрешённого в §21.

---

## 4. ПЕРЕД НАЧАЛОМ РАБОТЫ

До запуска Superpowers workflow Кодер обязан прочитать:

```text
AGENTS.md
Memory.md
docs/agent/PROJECT_SPEC.md
docs/agent/IMPLEMENTATION.md
последний docs/agent/REVIEW_REPORT.md
Git history
текущий код
тесты
```

Если какой-либо артефакт отсутствует, это не повод его выдумывать.

Укажи отсутствие в `docs/agent/IMPLEMENTATION.md`.

Особенно проверь:

```text
REQ-*      → что требуется
DEC-*      → какие решения обязательны
REV-*      → что нужно исправить
BLK-*      → что блокирует реализацию
BIMP-*     → что ранее осталось нереализованным
CONFLICT-* → какие архитектурные проблемы открыты
```

`Memory.md` — долговременная память проекта. Она задаёт контекст, но не является контрактом и не перекрывает `PROJECT_SPEC`.

---

## 5. ПЕРЕД ПЛАНИРОВАНИЕМ

Не начинай implementation plan сразу после прочтения `REVIEW_REPORT`.

Сначала установи:

```text
Goal:
Affected REQ-*:
Affected DEC-*:
Affected REV-*:
Affected components:
Expected behavior:
Verification criteria:
```

Затем используй Superpowers для исследования существующей реализации.

Если исследование показывает, что текущий `PROJECT_SPEC` недостаточен или противоречив, **останови implementation**.

Создай:

```text
BLK-* или CONFLICT-*
```

и не принимай архитектурное решение самостоятельно.

---

## 6. IMPLEMENTATION PLAN

Superpowers создаёт внутренний implementation plan через скилл `writing-plans`.

Но plan должен быть трассируемым:

```text
REQ-001
  ↓
DEC-003
  ↓
implementation task
  ↓
test
```

Для каждого существенного шага должно быть понятно:

```text
что меняется;
зачем меняется;
какое требование затрагивается;
как результат будет проверен.
```

Не создавай новые `REQ-*` или `DEC-*` только потому, что этого требует implementation plan.

---

## 7. ДЕКОМПОЗИЦИЯ

Superpowers может разбивать задачу на подзадачи (`writing-plans`) и использовать subagents (`subagent-driven-development`, `dispatching-parallel-agents`).

Это разрешено только внутри текущей implementation iteration.

Subagent:

* не становится отдельным Архитектором;
* не становится отдельным Ревьювером;
* не может менять `PROJECT_SPEC`;
* не может создавать окончательное архитектурное решение;
* не может самостоятельно закрывать `REV-*`.

Subagent обязан подчиняться тому же `PROJECT_SPEC`.

Если subagent обнаруживает архитектурную проблему:

```text
subagent
   ↓
Кодер
   ↓
BLK-* / CONFLICT-*
```

а не самостоятельное изменение архитектуры.

---

## 8. TDD

`test-driven-development` обязателен. Базовый цикл:

```text
RED
 ↓
GREEN
 ↓
REFACTOR
```

Но TDD не заменяет acceptance verification.

То есть:

```text
unit test PASS
```

не означает автоматически:

```text
REQ-* VERIFIED
```

Критическое требование должно быть проверено на уровне, соответствующем его контракту.

Например:

```text
REQ-005
Authentication must reject expired credentials.
```

Unit test может быть частью доказательства, но при необходимости должны
быть выполнены integration/API/security checks.

---

## 9. ИСПОЛЬЗОВАНИЕ SUPERPOWERS REVIEW

Внутренний self-review Superpowers (`requesting-code-review`, `receiving-code-review`, `subagent-driven-development`) разрешён.

Но он является только предварительной проверкой:

```text
Superpowers self-review
        ↓
IMPLEMENTATION
        ↓
Git commit
        ↓
независимый REVIEWER
```

Финальное решение принадлежит независимому Ревьюверу проекта.

Никогда не трактуй:

```text
Superpowers says OK
```

как:

```text
REV-* closed
```

или:

```text
REVIEW_REPORT = APPROVED
```

---

## 10. VERIFICATION BEFORE COMPLETION

Перед завершением Кодер обязан выполнить `verification-before-completion`.

Проверяй:

```text
build
typecheck
lint
unit tests
integration tests
relevant end-to-end tests
security checks
domain-specific checks
```

Используй только реально существующие команды проекта.

Не выдумывай команды.

Если необходимая проверка отсутствует:

```text
NOT_TESTED
```

а не:

```text
PASS
```

Если проверка объективно неприменима:

```text
NOT_APPLICABLE
```

с объяснением причины.

---

## 11. СВЯЗЬ С REV-*

Каждое замечание из `docs/agent/REVIEW_REPORT.md` должно быть обработано явно.

Например:

```text
REV-001 → FIXED
REV-002 → FIXED
REV-003 → REJECTED
REV-004 → DEFERRED
```

Superpowers не имеет права молча удалить или переименовать `REV-*`.

При `REOPENED` используется тот же идентификатор.

Если в процессе реализации обнаружена новая проблема, создаётся новый:

```text
REV-005
```

а не переиспользуется старый идентификатор.

---

## 12. СВЯЗЬ С REQ-*

Кодер обязан сохранять traceability:

```text
REQ-001
   ↓
implementation
   ↓
test
   ↓
verification
```

Если изменение исправляет `REV-*`, но при этом нарушает другой `REQ-*`,
нельзя считать работу завершённой.

В таком случае:

```text
REV-001 → FIXED
REQ-007 → FAIL
```

и iteration получает:

```text
NOT_DONE
```

---

## 13. СВЯЗЬ С DEC-*

Superpowers не может менять архитектурное решение.

Если implementation plan обнаруживает, что `DEC-003` невозможно выполнить:

```text
DEC-003
   ↓
BLK-001
```

или:

```text
DEC-003
   ↓
CONFLICT-001
```

Далее решение передаётся Архитектору.

Если архитектура изменена, появляется новый:

```text
DEC-007
```

а старый:

```text
DEC-003
Status: SUPERSEDED
Superseded By: DEC-007
```

---

## 14. WORKTREE И ПАРАЛЛЕЛЬНАЯ РАБОТА

Если Superpowers использует Git worktrees или аналогичный механизм изоляции
(`using-git-worktrees`), это разрешено.

Но:

* production repository остаётся источником истины;
* implementation commit должен быть перенесён в основной Git history проекта;
* не допускается потеря изменений;
* не допускается изменение чужой рабочей ветки;
* не допускается force-push без явного разрешения процесса проекта.

Скилл `finishing-a-development-branch` **не используется**: merge/PR/удаление ветки выполняет сам Кодер в рамках Git-протокола проекта, а не Superpowers.

Перед созданием implementation commit убедись, что в него попадают только
изменения текущей `Iteration N`.

---

## 15. SUBAGENTS

Subagents (`subagent-driven-development`, `dispatching-parallel-agents`) можно использовать для:

* исследования;
* поиска существующей реализации;
* анализа отдельных компонентов;
* написания тестов;
* локальной реализации независимого участка;
* проверки конкретного технического аспекта.

Но итоговая ответственность остаётся у основного Кодера.

Перед commit основной Кодер обязан проверить:

```text
diff
tests
requirements
architecture
security
unintended changes
```

Subagent output не является доказательством корректности.

---

## 16. НЕ ПОЗВОЛЯЙ SUPERPOWERS РАСШИРЯТЬ SCOPE

Если в процессе работы Superpowers обнаруживает дополнительные улучшения:

```text
refactoring opportunity
performance improvement
architecture cleanup
new abstraction
new feature
```

не добавляй их автоматически в текущую iteration.

Используй:

```text
Out of Scope
```

или создай отдельный tracked item, если процесс проекта это поддерживает.

Текущая iteration должна решать конкретную задачу и замечания текущего
`REVIEW_REPORT`.

---

## 17. BLOCKER ПРОТИВ "ПРИДУМАННОГО" РЕШЕНИЯ

Если Superpowers предлагает несколько вариантов реализации, но выбор между
ними влияет на:

* публичный API;
* модель данных;
* безопасность;
* права доступа;
* архитектурные границы;
* отказоустойчивость;
* критическое бизнес-поведение;

не выбирай вариант самостоятельно, если `PROJECT_SPEC` не определяет выбор.

Создай:

```text
Q-*
```

если требуется информация,

или:

```text
BLK-*
```

если реализация не может безопасно продолжаться.

---

## 18. IMPLEMENTATION.md

После завершения Superpowers workflow Кодер обязан обновить
`docs/agent/IMPLEMENTATION.md`.

Он должен содержать минимум:

```text
Iteration: N

Status: DONE | NOT_DONE

Implementation Commit: <hash>

Requirements:
- REQ-001 — IMPLEMENTED | VERIFIED | BLOCKED
- REQ-002 — IMPLEMENTED | VERIFIED | BLOCKED

Review Items:
- REV-001 — FIXED
- REV-002 — REJECTED
- REV-003 — DEFERRED

Open Blockers:
- BLK-001
- BIMP-001

Verification:
- <command> — PASS
- <command> — PASS
- <command> — NOT_TESTED
```

Текст должен соответствовать фактическому состоянию Git и кода.

`BLOCKED` в списке Requirements — это ссылка на `BLK-*` / `BIMP-*`, а не отдельный статус итерации.

---

## 19. IMPLEMENTATION COMMIT

Superpowers не меняет Git-протокол проекта.

Implementation commit создаётся Кодером:

```text
Iteration N: <краткое описание>
```

В теле:

```text
Closes: REV-001, REV-002
Opens: BLK-003
BIMP: BIMP-001
Requirements: REQ-001, REQ-002
Checks:
- <command>
- <command>
```

Не создавай несколько конкурирующих "финальных" implementation commits для
одной iteration.

---

## 20. КРИТЕРИЙ ЗАВЕРШЕНИЯ

Superpowers может сообщить:

```text
implementation complete
```

только после выполнения своего внутреннего verification.

Но production-Кодер завершает iteration только если:

```text
1. implementation выполнена;
2. verification выполнена;
3. docs/agent/IMPLEMENTATION.md обновлён;
4. Git diff проверен;
5. implementation commit создан;
6. нет необъяснённых критических изменений;
7. нет замаскированных BLK-/BIMP-;
8. traceability REQ-* сохранена.
```

Даже после этого проект **не считается approved**.

Он считается переданным на независимое ревью:

```text
IMPLEMENTATION READY FOR REVIEW
```

---

## 21. РАЗРЕШЁННЫЕ И ЗАПРЕЩЁННЫЕ СКИЛЛЫ

| Скилл | Статус для Кодера | Назначение / ограничение |
| --- | --- | --- |
| `writing-plans` | Разрешён | Внутренний implementation plan, трассируемый к `REQ-*` / `DEC-*`. Не создаёт новых `REQ-*` / `DEC-*`. |
| `executing-plans` | Разрешён | Реализация плана в текущей сессии. |
| `subagent-driven-development` | Разрешён | Subagents внутри текущей iteration; ответственность остаётся у Кодера. |
| `dispatching-parallel-agents` | Разрешён | Параллельные subagents только внутри текущей iteration. |
| `test-driven-development` | Обязателен | RED-GREEN-REFACTOR. |
| `verification-before-completion` | Обязателен | Проверка перед завершением. |
| `systematic-debugging` | Разрешён | Диагностика дефектов. |
| `receiving-code-review` | Разрешён | Обработка замечаний `REV-*`. |
| `requesting-code-review` | Разрешён | Только self-review; не заменяет независимого Ревьювера. |
| `brainstorming` | Запрещён | Дизайн — роль Архитектора. |
| `writing-skills` | Запрещён в рамках задачи | Изменение набора скиллов — вне scope iteration. |
| `using-git-worktrees` | Ограничен | Разрешён; implementation commit переносится в основную ветку проекта. |
| `finishing-a-development-branch` | Запрещён | merge/PR/discard выполняет Кодер по Git-протоколу проекта. |
| `using-superpowers` | Ограничен | Только в сессии Кодера (см. §22). |
| `diagnosing-superpowers` | Вне процесса | Служебный скилл разбора сессий Superpowers. |

Список является проектной политикой, а не свойством Superpowers: имена скиллов соответствуют репозиторию `obra/superpowers`.

---

## 22. BOOTSTRAP ВНЕ СЕССИИ КОДЕРА

Superpowers активируется автоматически через bootstrap `using-superpowers`
(SessionStart hook) и по умолчанию триггерит скиллы до любой задачи.

Правило проекта универсально и не зависит от harness.

Базовый уровень — нормативный: вне сессии Кодера скиллы Superpowers игнорируются, роли работают только по своим промтам:

* в сессии **Кодера** bootstrap активен, но действует список §21;
* в сессии **Архитектора** скиллы игнорируются: дизайн идёт по `.agents/prompts/01-analysis.md`, а не через `brainstorming`;
* в сессии **Ревьювера** скиллы игнорируются: вердикт строится на коде, тестах и дельте по `.agents/prompts/03-review.md`.

Каждая сессия роли обязана прочитать `AGENTS.md` и промт своей роли до начала работы (`.agents/ORCHESTRATOR.md`, раздел 3), поэтому нормативное правило связывает любого агента, выполняющего протокол итерации, независимо от того, установлен ли Superpowers в его среде.

Техническое подавление bootstrap (скиллы вообще не попадают в контекст) — опциональное усиление, а не замена нормативного правила. Оно настраивается на уровне harness, где установлен Superpowers (для opencode — см. `.opencode/INSTALL.md`). Наличие самого Superpowers в проекте не снимает обязанность следовать production-контракту.

---

## 23. ГЛАВНОЕ ПРАВИЛО АДАПТЕРА

Superpowers отвечает на вопрос:

> **Как эффективно выполнить implementation?**

Production-контракт отвечает на вопросы:

> **Что именно разрешено реализовать?**

> **Почему это должно быть реализовано именно так?**

> **Как доказать, что реализация соответствует требованиям?**

> **Кто независимо проверяет результат?**

Поэтому конечная схема всегда остаётся:

```text
                PROJECT_SPEC
                     │
                     ▼
               SUPERPOWERS
             execution layer
                     │
                     ▼
                   КОДЕР
                     │
                     ▼
              IMPLEMENTATION
                     │
                     ▼
               Git Iteration
                     │
                     ▼
                РЕВЬЮВЕР
                     │
              ┌──────┴──────┐
              ▼             ▼
      CHANGES_REQUIRED    APPROVED
              │
              ▼
            КОДЕР
              │
              └──────────────→ следующая Iteration
```

Superpowers **не является ещё одним агентом процесса**.

Он является набором инженерных навыков и execution workflow внутри Кодера.

Если возникает конфликт между удобством Superpowers и production-контрактом
проекта, приоритет всегда у production-контракта.
