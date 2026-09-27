# Приёмочный чек-лист: открытие проекта в новом агенте (harness)

Курируемый человекочитаемый документ. Проверяет одно из трёх: среда **видит** каркас, правильно его **понимает**, и вы умеете в ней **запускать протокол**. При любом расхождении с `AGENTS.md` и `.agents/ORCHESTRATOR.md` побеждают они.

## Быстрый smoke-тест

Вставьте новому агенту одним сообщением:

```text
Прочитай AGENTS.md, Memory.md, README.md и .agents/ORCHESTRATOR.md.
Затем ответь пятью пунктами:
1) Что это за проект и какие у него роли?
2) Какие скиллы тебе доступны в этом workspace и откуда они загружены?
3) Что ты сделаешь со скиллами Superpowers и mattpocock/skills, если я запущу тебя в роли Ревьювера?
4) Каким коммитом фиксируется PROJECT_SPEC и на какой ветке идут итерации?
5) В каком состоянии сейчас workflow и где лежит его runtime state?
```

Ожидаемые ответы:

| № | Ожидание | Что проверяет |
| --- | --- | --- |
| 1 | Каркас агентного workflow; три роли: Архитектор / Кодер / Ревьювер; артефакты в `docs/agent/` | instruction-loading и чтение файлов, а не фантазия (`БЛОК 0.2`) |
| 2 | `grilling`, `research`, `to-questionnaire` из `.agents/skills/`; описание `research` — «находки с цитатами в текущий `PROJECT_SPEC`» (адаптированная копия) | привязка скиллов; harness сканирует workspace `.agents/skills/` |
| 3 | «Проигнорирую, работаю только по `.agents/prompts/03-review.md`» | нормативный уровень `AGENTS.md` §9 (роль-разделение скиллов) |
| 4 | `Architecture N: <описание>`; итерации — на отдельной ветке | GIT-ПРОТОКОЛ и режим веток (`ORCHESTRATOR.md`, разделы 1–2) |
| 5 | Состояние — из `docs/agent/STATE.md` (сейчас `INIT`: `main` объявлен reusable framework template, исторические записи — в `docs/examples/`); runtime state хранится только там, не в `Memory.md`; transitions определены в `.agents/STATE_MACHINE.md` | знание state machine, template-семантики и запрета второго источника runtime state |

## Если smoke-тест не прошёл

- **Нет пункта 1** — среда не читает `AGENTS.md`: вручную укажите его в первом сообщении; для долгой работы проверьте, поддерживает ли harness instruction-файлы.
- **Нет пункта 2** — среда не сканирует `.agents/skills/`: привяжите скиллы symlink'ом на `.agents/skills/<name>` в её директорию скиллов, **не копией** (адаптер `.agents/adapters/mattpocock-skills.md`, §4: адаптированная версия существует в одном экземпляре). Если подхвачены не все скиллы — проверьте frontmatter: флаги вроде `disable-model-invocation` часть сред (например, Kimi Code) молча исключает из обнаружения; в вендоренных копиях проекта таких флагов нет.
- **Нет пункта 3** — вернитесь к `AGENTS.md` §9 и потребуйте явного ответа; агент, не применивший правило ролей, в протоколе работать не должен.
- **Нет пункта 4** — укажите агенту на GIT-ПРОТОКОЛ (`.agents/prompts/02-implementation.md`, §15) и раздел 2 оркестратора.
- **Нет пункта 5** — укажите на `.agents/STATE_MACHINE.md` и `docs/agent/STATE.md`; агент, выдумывающий состояние workflow вместо чтения STATE.md, в протоколе работать не должен.

## Специально для opencode с установленным Superpowers

Проверьте bootstrap — это единственное место с остаточной неопределённостью (способ подавления зависит от версии установки):

```text
Активен ли у тебя bootstrap using-superpowers? Какие скиллы Superpowers
тебе видны вне сессии Кодера?
```

Ожидание: вне сессии Кодера скиллы Superpowers недоступны или явно игнорируются (политика — `.opencode/INSTALL.md`).

## Запуск протокола в новой среде

Каждая сессия роли начинается с обязательного чтения (`ORCHESTRATOR.md`, раздел 3): помимо общих файлов каждая роль читает `docs/agent/STATE.md` и проходит STATE GATE своего промта (Архитектор — при `ARCHITECTURE_PENDING`, Кодер — при `IMPLEMENTATION_PENDING`, Ревьювер — при `REVIEW_PENDING`):

| Роль | Что прочитать | Формула запуска |
| --- | --- | --- |
| Архитектор | `AGENTS.md`, `Memory.md`, `docs/agent/STATE.md`, `.agents/prompts/01-analysis.md` | «Работай в роли Архитектора. Требования: <задача>» — далее отвечаете на grilling-вопросы |
| Кодер | `AGENTS.md`, `Memory.md`, `docs/agent/STATE.md`, `.agents/prompts/02-implementation.md`, `docs/agent/PROJECT_SPEC.md`; при N>1 — плюс `REVIEW_REPORT.md` и предыдущий `IMPLEMENTATION.md` | «Работай в роли Кодера, ветка `iteration/N`» |
| Ревьювер | `AGENTS.md`, `docs/agent/STATE.md`, `.agents/prompts/03-review.md`, спека, имплементация, код, дельта итерации | «Работай в роли Ревьювера» |

Организационное: прогон — на отдельной ветке; артефактные коммиты — строго `Architecture N:` / `Iteration N:` / `Review N:`; внеитерационные правки каркаса — обычные conventional-коммиты и не являются implementation baseline.

## Deterministic-проверки (без LLM)

После каждого перехода workflow и в приёмку новой среды прогоните из корня репозитория:

```bash
bash tests/harness/check-all.sh
```

Агрегат выполняет `check-block0.sh` (БЛОК 0 трёх промтов бит-идентичен), `check-state.sh` (STATE.md: состояние, счётчики, transitions, verdict routing), `check-contracts.sh` (глобальная уникальность идентификаторов, dangling references), `check-git-protocol.sh` (форматы и нумерация артефактных коммитов) и `run-fixtures.sh` (unit tests валидаторов на negative fixtures).

Всё должно завершиться `All harness checks passed.` с exit code 0 — иначе workflow продолжать нельзя. Проверки читают только Git, файловую систему и Markdown — «агент сказал, что…» доказательством не является.

CI (`Agent Architecture Harness`, job `Deterministic Harness`) прогоняет тот же агрегат на push/PR. Вывод об успехе CI допустим только для конкретного SHA (REQ-HARNESS-024, `ORCHESTRATOR.md` §12): `gh run list --json headSha,status,conclusion,databaseId`, отбор по `headSha`, затем `gh run view <id> --json jobs`; при недоступности данных — `CI_UNVERIFIABLE`, а не «успех».
