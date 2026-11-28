# MeshCentral — установщики агента для Intel Mac (High Sierra и Monterey)

Два готовых самоустанавливающихся скрипта MeshCentral для портала
`https://support.kualkon.top`. Устройства попадают в группу **Test**.

| Скрипт | ОС | Что делает |
|---|---|---|
| [`setup_meshagent_highsierra.command`](setup_meshagent_highsierra.command) | macOS **10.13.x High Sierra**, Intel | Ставит агента и заменяет несовместимый бинарник на последнюю рабочую сборку 2022 года |
| [`setup_meshagent_monterey.command`](setup_meshagent_monterey.command) | macOS **12.x Monterey**, Intel | Ставит обычный актуальный агент — замена бинарника не нужна |

Оба файла — законченные installer'ы: они сами скачивают приглашение, агента, ставят пакет,
настраивают `launchd`, запускают службу и проверяют соединение с порталом.

---

## Быстрый старт: скачать и запустить одной командой

Откройте **Terminal** на клиентском Mac и вставьте полностью **одну строку** — свою для нужной ОС.

### High Sierra (10.13.x)

```bash
curl -fsSL https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/opencode/monterey-installer/setup_meshagent_highsierra.command -o /tmp/setup_meshagent_highsierra.command && sudo bash /tmp/setup_meshagent_highsierra.command
```

### Monterey (12.x)

```bash
curl -fsSL https://raw.githubusercontent.com/kualkon/MeshCentral/refs/heads/opencode/monterey-installer/setup_meshagent_monterey.command -o /tmp/setup_meshagent_monterey.command && sudo bash /tmp/setup_meshagent_monterey.command
```

**Дальше:**
1. Введите пароль administrator (символы при вводе не отображаются — это нормально), Enter.
2. Подождите 20–30 секунд.
3. Увидите блок проверки (см. ниже). Закройте Terminal — агент останется службой и поднимется после перезагрузки.
4. В портале `https://support.kualkon.top` устройство появится в группе **Test** онлайн.

`chmod`, «правый клик → Open» и двойной клик в Finder **не нужны**: команда запускает скрипт
через `sudo bash`, поэтому справляется с любыми правами скачанного файла и с карантином macOS.

> Ссылки ведут на ветку PR #1. После мержа замените
> `refs/heads/opencode/monterey-installer` на `refs/heads/main` в обеих командах.
> Форма `refs/heads/...` выбрана намеренно: короткий вариант
> `raw.githubusercontent.com/kualkon/MeshCentral/<ветка>/...` может отдавать кэшированную старую версию.

---

## Что делает каждый скрипт

### Общее для обоих

1. Повышает права до `root` через `sudo bash "$0"` (работает даже без бита исполнения).
2. Сразу проверяет, не работает ли агент уже: если служба в `state = running` и есть
   `ESTABLISHED`-соединение, печатает `Agent is already running and connected (PID ...). Nothing to do.`
   и выходит — повторный запуск безопасен (идемпотентность).
3. Останавливает старые службы `meshagent` и `meshagent-launchagent`.
4. Читает **свежий одноразовый `meshid`** со страницы приглашения портала. Портал выдаёт
   новый код при каждом открытии, поэтому захардкоженный `meshid` быстро перестаёт работать —
   скрипт извлекает его автоматически.
5. Скачивает официальный `MeshAgent.pkg` (`ARCHID 16`, Intel x86-64) и ставит его через `installer`.
6. Пишет `/Library/LaunchDaemons/meshagent.plist` с флагом **`--disableUpdate=1`**.
7. Отключает вспомогательный `/Library/LaunchAgents/meshagent-launchagent.plist`: он может
   падать с `EX_CONFIG`, а соединение с порталом держит системный демон.
8. Запускает службу через `launchctl bootstrap`, ждёт 6 секунд и проверяет результат
   (`launchctl print` + `lsof` на `ESTABLISHED`).

### Отличие High Sierra

Актуальный агент собран с новым SDK (macOS 11+) и на 10.13 падает:

```
dyld: cannot load 'meshagent' (load command 0x80000034 is unknown)
```

Поэтому `setup_meshagent_highsierra.command` дополнительно:
- скачивает `macOS_May-2022.zip` (последняя совместимая сборка, issue `Ylianst/MeshAgent#137`);
- перед заменой сохраняет текущий бинарник как `meshagent.incompatible.<timestamp>`;
- ставит совместимый `meshagent_osx-x86-64` на место рабочего.

### Отличие Monterey

macOS 12 относится к macOS 11+, поэтому свежий агент работает нативно — скачивание и замена
старого бинарника **не производятся**. Скрипт проверяет Intel x86-64 (на Apple Silicon
останавливается с ошибкой) и предупреждает, если версия macOS не 12.x.

---

## Что видно в конце

```
--- verification ---
        state = running
        successive crashes = 0
        pid = <PID>
meshagent <PID> root ... TCP <local-ip>:<port>->173.212.230.119:443 (ESTABLISHED)

Done. Check the device in MeshCentral (group Test).
```

---

## Требования

- High Sierra: macOS **10.13.6**, Intel x86-64.
- Monterey: macOS **12.x**, Intel x86-64 (не Apple Silicon).
- Права administrator на Mac.
- Интернет по HTTPS: `support.kualkon.top`; для High Sierra ещё `github.com` (запасной бинарник).
- Только встроенные утилиты macOS: `curl`, `unzip`, `installer`, `launchctl`, `lsof`.
  Homebrew / Node / Python не нужны.

---

## Обслуживание

- Если в портале создали новую ссылку-приглашение, меняется только переменная `INVITE_URL`
  в начале нужного скрипта. `meshid` извлекается автоматически — вручную его править не нужно.
- Полная переустановка = повторный запуск той же команды.
- Ручная проверка на работающем Mac:

```bash
sudo launchctl print system/meshagent | grep -E 'state =|pid =|successive crashes'
sudo lsof -nP -iTCP -a -p $(pgrep -f 'meshagent/meshagent' | head -1) | grep ESTABLISHED
```

---

## Известные нюансы

- `--disableUpdate=1` выставлен в обоих скриптах: в High Sierra он критичен (иначе агент
  обновится до несовместимой версии), в Monterey фиксирует проверенную конфигурацию.
- Бинарник 2022 года в High Sierra не содержит всех новых функций MeshCentral, но даёт
  стабильное подключение и базовое удалённое управление.
- Apple Silicon не поддерживается этими скриптами — нужен отдельный агент `ARCHID 29`
  или Universal `10005`.
- Вспомогательный `meshagent-launchagent` отключён в обоих вариантах; подключение к порталу
  обеспечивает системный демон.
- `xattr -dr com.apple.quarantine` снимает карантин с каталога агента, чтобы macOS не блокировала бинарник.

---

## Контрольные суммы (SHA256)

```
3d9c5dcbba00c89882a3e420cdc6c8d978b287d08d0bf5b901e6b3c74a105031  setup_meshagent_highsierra.command
44a6798b471896296904b85b0d8f1af704b78448fb2415edaba3bf394c98ca4c  setup_meshagent_monterey.command
```

---

## Статус проверки

- **High Sierra:** полный чистый прогон на iMac `Tests-iMac.local` (10.13.6, 17G14042):
  `state = running`, `successive crashes = 0`, TCP до `support.kualkon.top:443` установлен.
- **Monterey:** целевой Mac `MacBookPro.fritz.box` подключён через MeshCentral,
  фактическая ОС подтверждена удалённо: macOS **12.7.4** (21H1123), агент онлайн в группе Test.
  Синтаксис скрипта проверен `bash -n`; повторный чистый прогон установщика на этой машине не требуется,
  пока агент работает.
