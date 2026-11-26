# MeshCentral agent installer for macOS High Sierra (10.13.x)

Готовый самоустанавливающийся агент MeshCentral для старых Intel-Mac с macOS 10.13.6 High Sierra.

## Зачем это нужно

Актуальный агент MeshCentral собирается с новым SDK (macOS 11+) и не запускается на High Sierra:

```
dyld: cannot load 'meshagent' (load command 0x80000034 is unknown)
```

Этот репозиторий содержит скрипт, который:

1. Получает **свежий одноразовый `meshid`** со страницы приглашения Mesh-портала
   (портал выдаёт новый код при каждом открытии — захардкоженный код быстро перестаёт работать).
2. Скачивает официальный `MeshAgent.pkg` по этому приглашению.
3. Скачивает последнюю совместимую с High Sierra сборку агента
   (`macOS_May-2022.zip`, `ARCHID 16`, из issue `Ylianst/MeshAgent#137`).
4. Устанавливает пакет и заменяет несовместимый бинарник рабочим.
5. Пишет `/Library/LaunchDaemons/meshagent.plist` с флагом **`--disableUpdate=1`**
   (иначе агент самообновится до версии, которая снова не запустится).
6. Отключает вспомогательный `meshagent-launchagent`, который падал с `EX_CONFIG`.
7. Запускает службу через `launchctl` и проверяет TCP-соединение с порталом.

Скрипт **идемпотентен**: если агент уже работает и подключён, он сразу печатает
`Agent is already running and connected (PID ...). Nothing to do.` и выходит.

## Файлы

| Файл | Назначение |
|---|---|
| `setup_meshagent.command` | Рабочая копия для клиента: двойной клик в Finder → Terminal → пароль administrator |
| `setup_meshagent_highsierra.sh` | Исходник/мастер для редактирования и рассылки (идентичен по содержимому) |

SHA256 обоих файлов (на момент публикации):
`aafab82e3b186e7ec49062dd489b5d537ea29bb64823730b4248ebcd444dbfad`

## Использование (для клиента)

1. Скопировать `setup_meshagent.command` на Desktop клиентского Mac.
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

- macOS 10.13.6 High Sierra, Intel x86-64.
- Права administrator на Mac.
- Интернет: `support.kualkon.top` и `github.com` (по HTTPS).

## Обслуживание

Если в портале создана новая ссылка-приглашение, меняется только переменная `INVITE_URL`
в начале скрипта. `meshid` извлекается автоматически — править его вручную **не нужно**.

Проверка вручную на уже работающем Mac:

```bash
sudo launchctl print system/meshagent | grep -E 'state =|pid =|successive crashes'
sudo lsof -nP -iTCP -a -p $(pgrep -f 'meshagent/meshagent' | head -1) | grep ESTABLISHED
```

Полная переустановка: просто запустить скрипт ещё раз.

## Безопасность и известные нюансы

- Скрипт использует только встроенные утилиты macOS (`curl`, `unzip`, `installer`, `launchctl`),
  дополнительных зависимостей (Homebrew, Node, Python) не требует.
- `--disableUpdate=1` критичен: без него агент скачает новую несовместимую версию.
- Запасной бинарник из 2022 года не имеет всех новых функций MeshCentral, но обеспечивает
  стабильное подключение и базовое удалённое управление.
- При обновлении macOS до 11+ можно убрать `--disableUpdate=1` и вернуть свежий агент.

## Проверка

Полный чистий прогон выполнен на iMac `Tests-iMac.local` (macOS 10.13.6, 17G14042):
служба перешла в `state = running`, `successive crashes = 0`, TCP-соединение с
`support.kualkon.top:443` установлено (`173.212.230.119`).
