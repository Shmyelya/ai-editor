# AI text editor project

## User

Прочитай docs/TASK.md и AGENTS.md. Репозиторий — база из моего прошлого
проекта (AI-чат): клиент Groq со стримингом, ошибки, Secrets, SwiftData.
Перепиши AGENTS.md под новое задание — AI-редактор текста. Код не пиши.

Мои решения:
- Стек, сеть, ключ, XcodeGen, Build.command — как сейчас. Проект, схема и
  таргет остаются test; отображаемое имя «AI-редактор», bundle ID
  com.yelzhanyelikbayev.aieditor.
- Переиспользовать GroqChatService, разбор ошибок, «Стоп», «Повторить».
  Экраны чата заменить, лишнее удалить.
- Экраны: редактор (ввод текста, выбор действия, язык для перевода, запуск
  и «Стоп», результат, копирование), история, просмотр правки из истории.
- Действия: перефразировать, сократить, перевести, исправить ошибки. Для
  каждого свой системный промпт; модель возвращает только итоговый текст,
  без вступлений и разметки.
- «Было — стало»: сравнение по словам через difference(from:) из
  стандартной библиотеки, считается после конца стрима. Удалённые слова —
  красные зачёркнутые, добавленные — зелёные, цвета системные.
- История в SwiftData: исходный текст, результат, действие, язык, дата.
- Ввод ограничен 4000 символами, виден счётчик.
- Имя модели — одна константа.
- Лента и списки результата без LazyVStack; новая URLSession на каждый
  запрос, таймаут 15 с; интерфейс и даты на русском.
- Опциональное вне объёма; первым, если останется время, — выбор тона.
- На всё 4 часа: шаги мелкие, сборка и коммит после каждого.
Если что-то неясно — спроси.

## Assistant

Сначала прочитаю задание и текущие правила, чтобы переписать `AGENTS.md` под AI-редактор и ничего не додумать сверх ваших решений.

### Tool Glob File Search

```
{"targetDirectory":"/Users/yelzhanyelikbaev/Desktop/second_test","globPattern":"docs/**/*.md"}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/AGENTS.md"}
```

### Tool Glob File Search

```
{"targetDirectory":"/Users/yelzhanyelikbaev/Desktop/second_test","globPattern":"**/*.{md,yml,swift}"}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/docs/TASK.md"}
```

## Assistant

Задание и текущие правила прочитаны. Смотрю, что уже есть в клиенте Groq и в экранах чата, чтобы в правилах точно отделить то, что остаётся, от того, что заменяется.

### Tool Glob File Search

```
{"targetDirectory":"/Users/yelzhanyelikbaev/Desktop/second_test","globPattern":"**/*.{swift,yml,command,md}"}
```

### Tool Ripgrep Raw Search

```
{"pattern":"enum |struct |class |func |URLSession|LazyVStack|timeout|reasoning","path":"/Users/yelzhanyelikbaev/Desktop/second_test/test","glob":"*.swift","caseInsensitive":false,"multiline":false,"toolCallId":"call-0c873428-ff6e-428d-bd43-22b69409e954-5\nfc_215648c2-8b17-9231-9fa6-166eb6b4ebca_1","offset":0}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/test/Services/ChatService.swift"}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/test/ChatScreenModel.swift","limit":80}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/project.yml","limit":80}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/test/Services/GroqChatService.swift","offset":1,"limit":50}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/test/ChatScreenModel.swift","offset":80}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/test/Services/GroqChatService.swift","offset":100}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/test/Services/GroqChatService.swift","offset":44,"limit":60}
```

### Tool Glob File Search

```
{"targetDirectory":"/Users/yelzhanyelikbaev/Desktop/second_test","globPattern":"README*"}
```

## Assistant

Решения достаточно полные, чтобы зафиксировать правила. В файл не войдут список языков и способ сборки «было — стало»: этого в задании нет, поэтому уточню отдельно.

### Tool Edit File V2

## Assistant

`AGENTS.md` переписан под AI-редактор текста. Код и `docs/PLAN.md` не трогал.

Зафиксировано то, что вы назвали: стек, Groq, ключ и `Build.command` как в чате; проект, схема и таргет `test`; имя «AI-редактор» и bundle ID `com.yelzhanyelikbayev.aieditor`. Экраны чата заменяются тремя экранами редактора, остаются `GroqChatService`, разбор ошибок, «Стоп» и «Повторить». Четыре действия, свой системный промпт у каждого, в историю попадают только исходный текст, результат, действие, язык и дата. Сравнение по словам считается после конца стрима. Ввод — до 4000 символов со счётчиком. Имя модели — одна константа `openai/gpt-oss-120b`. Новая `URLSession` на каждый запрос, таймаут 15 секунд, без `LazyVStack`. Выбор тона — первый необязательный пункт, и только отдельным подтверждённым шагом плана.

Два места я сознательно не заполнил.

1. Какие языки перевода показывать?
2. «Было — стало»: одна общая лента или два блока, и что считать словом — кусок между пробелами или разбор по границам слов?

## User

1. Языки перевода - фиксированный список в меню: английский, русский,
   немецкий, французский, испанский, итальянский, турецкий, китайский.
   По умолчанию английский. Меню языка видно только при действии
   «Перевести».

2. «Было — стало» - одна общая лента: удалённые слова красные зачёркнутые,
   добавленные зелёные, неизменённые обычные. Над результатом переключатель
   из двух режимов: «Результат» (чистый текст) и «Изменения» (лента с
   подсветкой). Копируется всегда чистый результат.
   Слово — кусок между пробельными символами, знаки препинания остаются
   при слове. Переводы строк — отдельные токены, чтобы абзацы сохранялись.
   Для действия «Перевести» режим «Изменения» не показывается: сравнивать
   по словам тексты на разных языках бессмысленно, там «было — стало» —
   это исходный текст и перевод двумя блоками.

## Assistant

Допишу в `AGENTS.md` список языков и правило ленты «было — стало» так, как вы их задали. Код не трогаю.

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/AGENTS.md","offset":55,"limit":50}
```

### Tool Read File V2

```
{"path":"/Users/yelzhanyelikbaev/Desktop/second_test/AGENTS.md","offset":103}
```

### Tool Edit File V2

### Tool Edit File V2

## Assistant

Оба ответа записаны в `AGENTS.md`. Код по-прежнему не менялся.

Меню языка видно только у «Перевести». В нём фиксированный список: английский, русский, немецкий, французский, испанский, итальянский, турецкий, китайский. Сначала выбран английский.

Для остальных действий после стрима над результатом стоят «Результат» и «Изменения». «Изменения» — одна лента: удалённые слова красные зачёркнутые, добавленные зелёные, неизменённые обычные. Слово — кусок между пробелами, знаки препинания остаются при нём, перевод строки — отдельный токен. У «Перевести» режима «Изменения» нет: исходный текст и перевод показаны двумя блоками. Копируется всегда чистый результат.

Сразу после стрима выбран «Результат», и тот же переключатель есть на экране просмотра правки. Если здесь иначе — поправьте.