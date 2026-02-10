# Запуск приложения в симуляторе iOS

## Требования

- **Xcode** установлен из App Store.
- Активная папка разработчика — Xcode (не только Command Line Tools):

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

## Быстрый запуск

Из корня репозитория выполните:

```bash
./run-simulator.sh
```

Скрипт:

1. Соберёт проект для симулятора.
2. При необходимости запустит симулятор.
3. Установит приложение в симулятор.
4. Запустит приложение и выведет окно Simulator на передний план.

По умолчанию используется симулятор **iPhone 17 Pro**. Если его нет, укажите другой (см. ниже).

## Выбор другого симулятора

Список доступных симуляторов:

```bash
xcrun simctl list devices available
```

Запуск на другом устройстве (подставьте имя из списка):

```bash
DESTINATION='platform=iOS Simulator,name=iPhone 16' ./run-simulator.sh
```

Или, например, iPad:

```bash
DESTINATION='platform=iOS Simulator,name=iPad Pro 13-inch (M5)' ./run-simulator.sh
```

## Переменные окружения

| Переменная     | По умолчанию                    | Описание |
|----------------|----------------------------------|----------|
| `SCHEME`       | `AltimeterAvia`                 | Схема сборки Xcode |
| `DESTINATION`  | `platform=iOS Simulator,name=iPhone 17 Pro` | Целевой симулятор |

Пример:

```bash
SCHEME=AltimeterAvia DESTINATION='platform=iOS Simulator,name=iPhone 16e' ./run-simulator.sh
```

## Запуск из Xcode

1. Откройте `AltimeterAvia.xcodeproj` в Xcode.
2. Вверху выберите симулятор (например, iPhone 17 Pro).
3. Нажмите **Run** (▶️) или **⌘R**.

## Примечание про барометр

В симуляторе **нет барометра**. Приложение покажет сообщение о недоступности барометра; высота и VSI будут нулевыми. Полная работа высотомера и VSI — только на реальном iPhone.
