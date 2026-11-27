# MeshCentral agents for Intel Macs

Два варианта установки агента MeshCentral для Intel-Mac с порталом `https://support.kualkon.top`
(устройства попадают в группу **Test**):

- **macOS 10.13.x High Sierra** — классическая пара файлов `setup_meshagent.command` /
  `setup_meshagent_highsierra.sh` (без изменений).
- **macOS 12.x Monterey** — один файл `setup_meshagent_monterey.command`, который скачивается
  и запускается одной командой в Terminal.

## Monterey: скачать и запустить

Откройте Terminal на клиентском Mac и вставьте **одну строку**:

```bash
curl -fsSL https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/opencode/monterey-installer/setup_meshagent_monterey.command -o /tmp/setup_meshagent_monterey.command && bash /tmp/setup_meshagent_monterey.command
```

или ещё короче (скрипт сам скачает копию в `/tmp`):

```bash
curl -fsSL https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/opencode/monterey-installer/setup_meshagent_monterey.command | bash
```

Дальше нужно только ввести пароль administrator по запросу `sudo` (символы не отображаются —
это нормально) и подождать 20–30 секунд. Ни `chmod`, ни правый клик «Open» не нужны:
скрипт повышает права через `sudo bash`, поэтому работает даже без бита исполнения.

> Ссылка использует каноническую форму `refs/heads/...`: короткий вариант
> `raw.githubusercontent.com/kualkon/MeshCentral/opencode/monterey-installer/...` может
> отдавать кэшированную старую версию. После мержа PR замените ссылки на
> `https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/main/setup_meshagent_monterey.command`.

### Что делает скрипт

1. Проверяет macOS 12.x и Intel x86-64 (`ARCHID 16`); на Apple Silicon останавливается.
2. Если агент уже работает и подключён — ничего не меняет
   (`Agent is already running and connected (PID ...). Nothing to do.`).
3. Получает **свежий одноразовый `meshid`** со страницы приглашения портала — хардкодить его
   нельзя, портал выдаёт новый код при каждом открытии.
4. Скачивает официальный `MeshAgent.pkg`, устанавливает его.
5. Пишет `/Library/LaunchDaemons/meshagent.plist` с флагом **`--disableUpdate=1`**.
6. Отключает вспомогательный `meshagent-launchagent`, который может падать с `EX_CONFIG`.
7. Запускает службу через `launchctl` и проверяет TCP-соединение с порталом.

В конце видно:

```
--- verification ---
        state = running
        successive crashes = 0
        pid = <PID>
meshagent <PID> root ... TCP <local-ip>:<port>->173.212.230.119:443 (ESTABLISHED)

Done. Check the device in MeshCentral (group Test).
```

## High Sierra (без изменений)

Скрипт обходит несовместимость свежего агента с High Sierra (`dyld: cannot load 'meshagent'
(load command 0x80000034 is unknown)`): скачивает_last совместимую сборку 2022 года
(`macOS_May-2022.zip`), ставит пакет и заменяет бинарник, затем включает `--disableUpdate=1`.

Для клиента: `setup_meshagent.command`, двойной клик в Finder → пароль administrator.
Исходник для правок: `setup_meshagent_highsierra.sh`.

Если скачанный файл потерял бит исполнения — запустите `bash ~/Desktop/setup_meshagent.command`.

## Файлы и SHA256

| Файл | Назначение | SHA256 |
|---|---|---|
| `setup_meshagent_monterey.command` | Monterey, один файл: скачать + запустить | `30840ea73fd2ad2581b2dcfe3eec3bf1f18c54d61cae2d83f3add62b5087c440` |
| `setup_meshagent.command` | High Sierra, клиент | `aafab82e3b186e7ec49062dd489b5d537ea29bb64823730b4248ebcd444dbfad` |
| `setup_meshagent_highsierra.sh` | High Sierra, исходник (идентичен клиентскому) | `aafab82e3b186e7ec49062dd489b5d537ea29bb64823730b4248ebcd444dbfad` |

## Требования

- Monterey: macOS 12.x, Intel x86-64 (не Apple Silicon).
- High Sierra: macOS 10.13.6, Intel x86-64.
- Права administrator на Mac.
- Интернет: `support.kualkon.top` и (для High Sierra) `github.com`.

## Обслуживание

Если в портале создана новая ссылка-приглашение, меняется только `INVITE_URL` в начале
соответствующего скрипта. `meshid` извлекается автоматически.

Проверка вручную на работающем Mac:

```bash
sudo launchctl print system/meshagent | grep -E 'state =|pid =|successive crashes'
sudo lsof -nP -iTCP -a -p $(pgrep -f 'meshagent/meshagent' | head -1) | grep ESTABLISHED
```

Полная переустановка — повторный запуск скрипта.

## Известные нюансы

- Для Apple Silicon нужен отдельный агент (`ARCHID 29` или Universal `10005`).
- `--disableUpdate=1` фиксирует проверенную версию; без него агент может обновиться.
- Вспомогательный `meshagent-launchagent` отключён: подключение к порталу держит системный демон.
- Скрипт использует только встроенные утилиты macOS (`curl`, `unzip`, `installer`, `launchctl`).

## Проверка

- High Sierra: полный прогон на iMac `Tests-iMac.local` (10.13.6, 17G14042) — служба
  `state = running`, `successive crashes = 0`, TCP до `support.kualkon.top:443` установлен.
- Monterey: синтаксис проверен `bash -n`; прогон на реальном Mac 12.x ещё предстоит.
