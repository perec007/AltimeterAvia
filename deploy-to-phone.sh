#!/bin/bash
# Сборка и установка AltimeterAvia на подключённый по проводу iPhone.
# Требуется: установленный Xcode и выбранный им активный developer directory.

set -e
cd "$(dirname "$0")"

if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    echo "Ошибка: активна не полная Xcode. Выполните:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# Список подключённых устройств
echo "Подключённые устройства:"
xcrun xctrace list devices 2>/dev/null || true

# Ищем первый физический iPhone
DEST=$(xcrun xctrace list devices 2>/dev/null | grep -E "iPhone|iPad" | grep -v "Simulator" | head -1)
if [ -z "$DEST" ]; then
    echo "Подключите iPhone по кабелю и разрешите доверие компьютеру на телефоне."
    exit 1
fi

# Идентификатор устройства (первое слово в строке типа "iPhone Oleg (00008103-...)")
UDID=$(echo "$DEST" | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')
if [ -z "$UDID" ]; then
    UDID=$(xcrun xcrun simctl list devices available 2>/dev/null | grep -v "unavailable" | head -1 || true)
fi

echo "Сборка для устройства: $DEST"
echo ""

# Сборка и установка на устройство по имени/UDID
xcodebuild \
    -scheme AltimeterAvia \
    -destination "generic/platform=iOS" \
    -configuration Debug \
    build

# Установка через ios-deploy или Xcode
if command -v ios-deploy &>/dev/null; then
    echo "Установка через ios-deploy..."
    ios-deploy --bundle build/Debug-iphoneos/AltimeterAvia.app
else
    echo "Сборка успешна. Для установки на телефон:"
    echo "  1. Откройте AltimeterAvia.xcodeproj в Xcode"
    echo "  2. Выберите вверху ваше подключённое устройство (iPhone)"
    echo "  3. Нажмите Run (⌘R)"
    echo ""
    echo "Либо установите ios-deploy: brew install ios-deploy"
fi
