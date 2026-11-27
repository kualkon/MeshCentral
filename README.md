# MeshCentral agent installers for Intel Macs

Готовые самоустанавливающиеся агенты MeshCentral для Intel-Mac: две отдельные версии под
**macOS 10.13.x High Sierra** и **macOS 12.x Monterey**. Оба варианта работают с
порталом `https://support.kualkon.top` и кладут устройство в группу **Test**.

| Версия | ОС | Клиентский файл | Исходник |
|---|---|---|---|
| High Sierra | 10.13.6 | `setup_meshagent.command` | `setup_meshagent_highsierra.sh` |
| Monterey | 12.x | `setup_meshagent_monterey.command` | `setup_meshagent_monterey.sh` |

Оба скрипта:

1. Получают **свежий одноразовый `meshid`** со страницы приглашения Mesh-портала
   (портал выдаёт новый код при каждом открытии — захардкоженный код быстро перестаёт работать).
2. Скачивают официальный `MeshAgent.pkg` по этому приглашению (`ARCHID 16`, Intel x86-64).
3. Устанавливают пакет и пишут `/Library/LaunchDaemons/meshagent.plist` с флагом
   **`--disableUpdate=1`**, чтобы агент не обновился до несовместимой сборки.
4. Отключают вспомогательный `meshagent-launchagent`, который может падать с `EX_CONFIG`.
5. Запускают службу через `launchctl` и проверяют TCP-соединение с порталом.

Скрипты **идемпотентны**: если агент уже работает и подключён, печатается
`Agent is already running and connected (PID ...). Nothing to do.` и выход.

## Почему две версии

Актуальный агент MeshCentral собирается с новым SDK (macOS 11+) и не запускается на
High Sierra:

```
dyld: cannot load 'meshagent' (load command 0x80000034 is unknown)
```

Поэтому **High Sierra**-версия дополнительно скачивает последнюю совместимую сборку
(`macOS_May-2022.zip`, из issue `Ylianst/MeshAgent#137`), ставит пакет и заменяет
несовместимый бинарник рабочим.

**Monterey** (macOS 12) уже относится к macOS 11+, поэтому свежий агент работает
нативно — замены бинарника нет. Версия просто ставит официальный Intel-пакет и
фиксирует конфигурацию. Перед установкой проверяется архитектура: только Intel
x86-64 (`ARCHID 16`); на Apple Silicon скрипт остановится с понятной ошибкой.
Если версия macOS не 12.x — выводится предупреждение, но установка продолжается.

## Файлы

| Файл | Назначение |
|---|---|
| `setup_meshagent.command` | High Sierra, рабочая копия для клиента: двойной клик в Finder → Terminal → пароль administrator |
| `setup_meshagent_highsierra.sh` | High Sierra, исходник/мастер для редактирования и рассылки |
| `setup_meshagent_monterey.command` | Monterey, рабочая копия для клиента: двойной клик в Finder → Terminal → пароль administrator |
| `setup_meshagent_monterey.sh` | Monterey, исходник/мастер для редактирования и рассылки |

Пары `.command` / `.sh` идентичны по содержимому. SHA256:

```
aafab82e3b186e7ec49062dd489b5d537ea29bb64823730b4248ebcd444dbfad  setup_meshagent.command
aafab82e3b186e7ec49062dd489b5d537ea29bb64823730b4248ebcd444dbfad  setup_meshagent_highsierra.sh
2aea69ad12148e417e641650b4dce5fb8228c2cdf0df21b5252d654277f00185  setup_meshagent_monterey.command
2aea69ad12148e417e641650b4dce5fb8228c2cdf0df21b5252d654277f00185  setup_meshagent_monterey.sh
```

## Использование (для клиента)

1. Скопировать нужный `.command` на Desktop клиентского Mac:
   `setup_meshagent.command` — для High Sierra, `setup_meshagent_monterey.command` — для Monterey.
2. Двойной клик по файлу. Если macOS ругается на «скачанный из интернета» — правый клик → **Open**.
3. Ввести пароль administrator в Terminal (символы не отображаются — нормально).
4. Подождать 20–30 секунд.
5. В конце увидеть:

```
--- verification ---
        state = running
        successive crashes = 0
        pid = <PID>
meshagent <PID> root ... TCP <local-ip>:<port>->173.212.230.119:443 (ESTABLISHED)

Done. Check the device in MeshCentral (group Test).
```

6. Закрыть Terminal. Агент останется службой и поднимется после перезагрузки.
7. В Mesh-портале (`https://support.kualkon.top`) устройство появится в группе **Test** онлайн.

## Требования

- High Sierra: macOS 10.13.6, Intel x86-64.
- Monterey: macOS 12.x, Intel x86-64 (не Apple Silicon).
- Права administrator на Mac.
- Интернет: `support.kualkon.top` и `github.com` (только для High Sierra — запасной бинарник).

## Обслуживание

Если в портале создана новая ссылка-приглашение, меняется только переменная `INVITE_URL`
в начале **обоих** скриптов. `meshid` извлекается автоматически — править его вручную
**не нужно**.

Проверка вручную на уже работающем Mac:

```bash
sudo launchctl print system/meshagent | grep -E 'state =|pid =|successive crashes'
sudo lsof -nP -iTCP -a -p $(pgrep -f 'meshagent/meshagent' | head -1) | grep ESTABLISHED
```

Полная переустановка: просто запустить скрипт ещё раз.

## Безопасность и известные нюансы

- Скрипты используют только встроенные утилиты macOS (`curl`, `unzip`, `installer`,
  `launchctl`), дополнительных зависимостей (Homebrew, Node, Python) не требуют.
- `--disableUpdate=1` выставлен в обеих версиях: в High Sierra он критичен, в Monterey
  фиксирует проверенную конфигурацию.
- Запасной бинарник 2022 года в High Sierra не имеет всех новых функций MeshCentral,
  но обеспечивает стабильное подключение и базовое удалённое управление.
- Для Apple Silicon нужна отдельная сборка с `ARCHID 29` (или Universal `10005`) —
  в этом репозитории её нет.
- Вспомогательный `meshagent-launchagent` отключён в обеих версиях: системный демон
  обеспечивает подключение к порталу.

## Проверка

- **High Sierra:** полный чистый прогон выполнен на iMac `Tests-iMac.local`
  (macOS 10.13.6, 17G14042): служба перешла в `state = running`,
  `successive crashes = 0`, TCP-соединение с `support.kualkon.top:443` установлено
  (`173.212.230.119`).
- **Monterey:** скрипт добавлен, синтаксис проверен `bash -n`. Прогон на реальном
  Mac с macOS 12.x ещё не выполнялся — перед рассылкой стоит проверить на тестовом устройстве.
