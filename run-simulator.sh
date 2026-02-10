#!/bin/bash
#
# Сборка и запуск AltimeterAvia в симуляторе iOS.
# Требуется: Xcode (xcode-select -s /Applications/Xcode.app/Contents/Developer).
#

set -e
cd "$(dirname "$0")"

SCHEME="${SCHEME:-AltimeterAvia}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
BUNDLE_ID="com.altimeteravia.app"

echo "Схема: $SCHEME"
echo "Симулятор: $DESTINATION"
echo ""

# Сборка в известную папку, чтобы не искать .app по DerivedData
BUILD_DIR="./build/Simulator"
echo "Сборка..."
xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" -configuration Debug \
  -derivedDataPath "$BUILD_DIR/DerivedData" build -quiet

APP="$BUILD_DIR/DerivedData/Build/Products/Debug-iphonesimulator/AltimeterAvia.app"
if [ ! -d "$APP" ]; then
  echo "Ошибка: не найден $APP после сборки."
  exit 1
fi

# Запущен ли симулятор
BOOTED=$(xcrun simctl list devices | grep "Booted" | head -1)
if [ -z "$BOOTED" ]; then
  echo "Запуск симулятора..."
  xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
  sleep 3
fi

# Установка и запуск
echo "Установка приложения..."
xcrun simctl install booted "$APP"
echo "Запуск приложения..."
xcrun simctl launch booted "$BUNDLE_ID"

# Вывести Simulator на передний план
open -a Simulator 2>/dev/null || true

echo ""
echo "Готово. Приложение запущено в симуляторе."
echo "Примечание: барометр в симуляторе недоступен — высота и VSI работают только на устройстве."
