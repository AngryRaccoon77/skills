# cc-thingz для Codex

Адаптация [umputun/cc-thingz](https://github.com/umputun/cc-thingz) для Codex. В каталоге семь плагинов cc-thingz и отдельный Portfolio Analyst.

## Установка

~~~sh
codex plugin marketplace add AngryRaccoon77/skills
~~~

Если каталог уже добавлен, обновите его.

~~~sh
codex plugin marketplace upgrade local-codex-plugins
~~~

Установите нужные плагины. Команды ниже добавят все пакеты cc-thingz.

~~~sh
codex plugin add brainstorm@local-codex-plugins
codex plugin add planning@local-codex-plugins
codex plugin add review@local-codex-plugins
codex plugin add release-tools@local-codex-plugins
codex plugin add thinking-tools@local-codex-plugins
codex plugin add workflow@local-codex-plugins
codex plugin add skill-eval@local-codex-plugins
~~~

В приложении Codex откройте **Plugins → Local Codex Plugins**. После установки начните новый чат.

## Что входит

| Плагин | Навыки и назначение |
| --- | --- |
| brainstorm | `$brainstorm:brainstorm` для обсуждения вариантов и проектирования |
| planning | `$planning:make` для плана, `$planning:exec` для реализации и ревью |
| review | `$review:pr`, `$review:git-review` и `$review:writing-style` |
| release-tools | `$release-tools:new` и `$release-tools:last-tag` |
| thinking-tools | `$thinking-tools:ask-codex`, `$thinking-tools:dialectic` и `$thinking-tools:root-cause-investigator` |
| workflow | `$workflow:backlog`, `$workflow:clarify`, `$workflow:learn`, `$workflow:md-copy`, `$workflow:txt-copy` и `$workflow:wrong` |
| skill-eval | Хук UserPromptSubmit с подсказкой проверить доступные навыки |

Навыки используют средства Codex для планирования, вопросов и субагентов. `$review:git-review` открывает цикл с комментариями в файле diff. План можно обсуждать в чате или править в файле.

Вспомогательные скрипты используют PowerShell 7 (pwsh). Для `$thinking-tools:ask-codex` и независимого ревью в `$planning:exec` нужен доступный CLI Codex. Для некоторых операций ревью и релиза нужен CLI хостинга репозитория.

Хуку skill-eval нужна команда python в PATH. Codex запустит хук после проверки в **Settings → Hooks** или в меню /hooks. [Документация по хукам](https://learn.chatgpt.com/docs/hooks#plugin-bundled-hooks)

Правила brainstorm и planning хранятся в .codex/rules/ проекта или в ~/.codex/rules/. Правила проекта имеют приоритет. Команды Claude Code и хук ExitPlanMode заменены навыком `$planning:make` и ревью плана в Codex.

## Источник и лицензия

За основу взяты [cc-thingz на коммите 68d29a4b7734a004a067c3c5869884d2269b0a17](https://github.com/umputun/cc-thingz/tree/68d29a4b7734a004a067c3c5869884d2269b0a17) и локальный порт скриптов на PowerShell. Лицензия MIT приведена в [LICENSES/cc-thingz-MIT.txt](LICENSES/cc-thingz-MIT.txt).

## Portfolio Analyst

Плагин анализа российских акций и облигаций доступен отдельно.

~~~sh
codex plugin add ru-market-portfolio-analyst@local-codex-plugins
~~~
