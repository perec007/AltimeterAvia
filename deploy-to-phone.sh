#!/bin/bash
# Сборка и установка AltimeterAvia на iPhone, подключённый по кабелю.
# Требуется: Xcode, активный developer directory (xcode-select), доверие устройства к ПК.
#
# Справка: ./deploy-to-phone.sh -h  или  ./deploy-to-phone.sh --help

set -e
cd "$(dirname "$0")"

show_help() {
    cat << 'HELP'
Справка: deploy-to-phone.sh — сборка и установка AltimeterAvia на iPhone/iPad

Использование:
  ./deploy-to-phone.sh [ -h | --help ]
  ./deploy-to-phone.sh

Описание:
  Собирает проект в конфигурации Debug для подключённого по USB устройства,
  устанавливает .app на устройство (devicectl или ios-deploy).

Требования:
  • Xcode с выбранным developer directory (xcode-select)
  • iPhone/iPad подключён по кабелю
  • На устройстве нажато «Доверять этому компьютеру»
  • При необходимости: DEVELOPMENT_TEAM для подписи (см. переменные ниже)

Переменные окружения:
  DEPLOY_DEVICE=N     Выбрать устройство по номеру из списка (1, 2, …), без запроса
  DEPLOY_UDID=UDID    Указать устройство по UDID, без запроса
  DEVELOPMENT_TEAM=ID Передать -developmentTeam в xcodebuild (Team ID в Apple Developer)

Примеры:
  ./deploy-to-phone.sh
  DEPLOY_DEVICE=2 ./deploy-to-phone.sh
  DEPLOY_UDID=00008140-00116D243EC2801C ./deploy-to-phone.sh
  DEVELOPMENT_TEAM=XXXXXXXXXX ./deploy-to-phone.sh
HELP
}

for arg in "$@"; do
    case "$arg" in
        -h|--help) show_help; exit 0 ;;
    esac
done

if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    echo "Ошибка: активна не полная Xcode. Выполните:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# Список подключённых устройств: xctrace (Xcode 15+), fallback — instruments
echo "Подключённые устройства:"
DEVICES=""
if xcrun xctrace list devices 2>/dev/null | grep -q "== Devices =="; then
    DEVICES=$(xcrun xctrace list devices 2>/dev/null | sed -n '/== Devices ==/,/== Simulators ==/p' | grep -v "== Devices ==\|== Simulators ==\|^$")
else
    DEVICES=$(xcrun instruments -s devices 2>/dev/null || true)
fi
echo "$DEVICES"
echo ""

# Список только iPhone/iPad (без симуляторов и Mac)
DEVICE_LINES=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if echo "$line" | grep -qE "iPhone|iPad" && ! echo "$line" | grep -q "Simulator"; then
        DEVICE_LINES+=("$line")
    fi
done <<< "$DEVICES"

if [ ${#DEVICE_LINES[@]} -eq 0 ]; then
    echo "Подключите iPhone по кабелю и разрешите «Доверять этому компьютеру» на телефоне."
    exit 1
fi

# Выбор устройства: по номеру (1, 2, ...), по UDID или первый по умолчанию
DEST=""
UDID=""

if [ -n "${DEPLOY_UDID:-}" ]; then
    for line in "${DEVICE_LINES[@]}"; do
        id=$(echo "$line" | sed 's/.*(\([^)]*\))$/\1/')
        if [ "$id" = "$DEPLOY_UDID" ]; then
            DEST="$line"
            UDID="$id"
            break
        fi
    done
    [ -z "$DEST" ] && echo "Устройство с UDID $DEPLOY_UDID не найдено." && exit 1
elif [ ${#DEVICE_LINES[@]} -eq 1 ]; then
    DEST="${DEVICE_LINES[0]}"
    UDID=$(echo "$DEST" | sed 's/.*(\([^)]*\))$/\1/')
else
    echo "Выберите устройство для установки:"
    for i in "${!DEVICE_LINES[@]}"; do
        echo "  $((i+1))) ${DEVICE_LINES[$i]}"
    done
    echo "  q) Выход"
    echo ""
    if [ -n "${DEPLOY_DEVICE:-}" ]; then
        choice="$DEPLOY_DEVICE"
        echo "Выбор (DEPLOY_DEVICE): $choice"
    else
        read -r -p "Номер (1-${#DEVICE_LINES[@]}): " choice
    fi
    if [ "$choice" = "q" ] || [ -z "$choice" ]; then
        echo "Отменено."
        exit 0
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#DEVICE_LINES[@]} ]; then
        echo "Неверный номер."
        exit 1
    fi
    DEST="${DEVICE_LINES[$((choice-1))]}"
    UDID=$(echo "$DEST" | sed 's/.*(\([^)]*\))$/\1/')
fi

[ -z "$UDID" ] && echo "Не удалось определить UDID устройства." && exit 1

echo "Устройство: $DEST"
echo "UDID: $UDID"
echo ""

# Артефакты в ./build для предсказуемого пути
DERIVED="build"
APP_PATH="$DERIVED/Build/Products/Debug-iphoneos/AltimeterAvia.app"

# Сборка: сначала пробуем destination по UDID; если xcodebuild не видит устройство — собираем generic/platform=iOS.
# -allowProvisioningUpdates нужен, чтобы Xcode мог создавать профили и регистрировать устройство.
echo "Сборка для устройства..."
XCBUILD=(xcodebuild -scheme AltimeterAvia -destination "id=$UDID" -derivedDataPath "$DERIVED" -configuration Debug -allowProvisioningUpdates)
[ -n "${DEVELOPMENT_TEAM:-}" ] && XCBUILD+=(-developmentTeam "$DEVELOPMENT_TEAM")
if ! "${XCBUILD[@]}" build; then
    echo ""
    echo "Сборка по id=$UDID не удалась (Xcode не видит устройство). Сборка для generic iOS, затем установка на устройство..."
    XCBUILD=(xcodebuild -scheme AltimeterAvia -destination "generic/platform=iOS" -derivedDataPath "$DERIVED" -configuration Debug -allowProvisioningUpdates)
    [ -n "${DEVELOPMENT_TEAM:-}" ] && XCBUILD+=(-developmentTeam "$DEVELOPMENT_TEAM")
    "${XCBUILD[@]}" build
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Ошибка: не найден $APP_PATH"
    exit 1
fi

# Установка: предпочтительно devicectl (Xcode 15+), иначе ios-deploy
echo ""
if xcrun devicectl device install app --device "$UDID" "$APP_PATH" 2>/dev/null; then
    echo "Приложение установлено (devicectl). Можно запускать на телефоне."
elif command -v ios-deploy &>/dev/null; then
    echo "Установка через ios-deploy..."
    ios-deploy --id "$UDID" --bundle "$APP_PATH"
    echo "Готово."
else
    echo "Сборка успешна. Установите на телефон одним из способов:"
    echo "  1. Xcode: откройте проект → выберите устройство → Run (⌘R)"
    echo "  2. Установите ios-deploy и запустите скрипт снова: brew install ios-deploy"
    echo "  3. Установка вручную: xcrun devicectl device install app --device $UDID $APP_PATH"
fi
