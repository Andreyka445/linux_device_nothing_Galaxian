# postmarketOS (Phosh Mobile GNOME) on Nothing Phone (3a) Lite

> **Dual-boot Linux environment running natively on Nothing Phone (3a) Lite (`galaxian` / MediaTek Dimensity 7300 / MT6878)** with full Wayland GUI, touch screen, on-screen keyboard, and instant 1-click switching to/from Android!

---

## 📱 Hardware & Specifications

| Feature | Specification |
| :--- | :--- |
| **Device** | Nothing Phone (3a) Lite |
| **Codename** | `galaxian` / `nothing-galaxian` |
| **SoC** | MediaTek MT6878 / Dimensity 7300 (4x Cortex-A78 @ 2.5 GHz + 4x Cortex-A55 @ 2.0 GHz) |
| **Display** | 6.7" AMOLED, DRM connector `DSI-1` (`/dev/dri/card0`), 1080x2392 @ 60/120Hz |
| **Touchscreen** | FocalTech `fts_ts` (`/dev/input/event3`, character device `c13:67`) |
| **Backlight** | `/sys/devices/platform/display_id/brightnessid` (comfort level: `2600`) |
| **Operating System** | postmarketOS (Alpine Linux edge/v3.20) running via native DRM chroot |
| **Mobile Desktop** | Phosh (GNOME Mobile Shell) on Phoc (wlroots Wayland compositor) |
| **Virtual Keyboard** | `wvkbd-mobintl` (Wayland layer-shell) |
| **Requirements** | Stock Nothing OS with Root (KernelSU / Magisk / APatch) |

---

## 📊 Текущий статус работы (Status & Known Issues)

| Компонент / Функция | Статус | Комментарий / Причина |
| :--- | :---: | :--- |
| **Экран (AMOLED)** | ✅ Работает | 1080x2392 @ 60Hz, аппаратный DRM/KMS `DSI-1`, управление яркостью через `brightnessid` |
| **Сенсорный экран (Touch)** | ✅ Работает | Мультитач FocalTech `fts_ts`, жесты свайпа через `c13:67` |
| **Графическая оболочка (Phosh)** | ✅ Работает | Блокировка, часы, шторка, меню приложений, быстрый 2D-рендеринг Cairo |
| **Виртуальная клавиатура** | ✅ Работает | `wvkbd-mobintl` (Wayland layer-shell, кнопки нажимаются без задержек) |
| **Терминал и консоль** | ✅ Работает | Полноценный Linux-терминал, htop, fastfetch, bash, root-доступ |
| **Быстрое переключение Android ⇄ Linux** | ✅ Работает | В 1 команду: `linux` в Termux и `android` в Phosh |
| **Звук (Audio / Динамики)** | ❌ Не работает | Не настроен проброс ALSA через MediaTek AFE / Audio HAL |
| **Wi-Fi** | ❌ Не работает | В Android chroot сокеты блокируются без прав AID_INET (gid 3003) |
| **Мобильная связь и сеть (LTE/Modem)** | ❌ Не работает | Модем управляется Android RILD; требуется интеграция ModemManager/oFono |
| **Файловый менеджер (Files / Nautilus)** | ❌ Не открывается | Падает из-за отсутствия системных демонов GVFS / tracker-miners в root-сессии |

---

## 🚀 Quick Start / Быстрый запуск

### 1. Подготовка на компьютере (Deployment via PC)

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/your-username/galaxian-pmos-dualboot.git
   cd galaxian-pmos-dualboot
   ```
2. Подключите телефон по USB с включенной отладкой по ADB.
3. Запустите скрипт автоматической установки:
   - В Windows: запустите двойным кликом `scripts/push_to_phone.bat`
   - Либо вручную через терминал:
     ```bash
     adb shell "su -c 'mkdir -p /data/pmos_files /data/pmos && chmod 777 /data/pmos_files'"
     adb push binaries/wvkbd-mobintl /data/local/tmp/wvkbd
     adb push configs/phoc.ini /data/local/tmp/phoc.ini
     adb push scripts/start_phosh.sh /data/local/tmp/start_phosh.sh
     adb push scripts/stop_phosh.sh /data/local/tmp/stop_phosh.sh
     
     adb shell "su -c 'mv /data/local/tmp/start_phosh.sh /data/pmos_files/start_phosh.sh && chmod +x /data/pmos_files/start_phosh.sh'"
     adb shell "su -c 'mv /data/local/tmp/stop_phosh.sh /data/pmos_files/stop_phosh.sh && chmod +x /data/pmos_files/stop_phosh.sh'"
     ```
4. Поместите сформированный образ `pmos_phosh.img` (3.2 ГБ) в `/data/pmos_files/pmos_phosh.img`.

---

### 2. Настройка 1 клика в Termux на телефоне

Откройте приложение **Termux** на телефоне и выполните:

```bash
echo "su -c /data/pmos_files/start_phosh.sh" > $PREFIX/bin/linux && chmod +x $PREFIX/bin/linux
```

---

## 🕹 Как пользоваться (How to Use)

### Запуск Linux:
- **Прямо с телефона (без ПК):** Откройте **Termux** и введите команду:
  ```bash
  linux
  ```
- **С компьютера (через ADB):**
  ```cmd
  adb shell "su -c /data/pmos_files/start_phosh.sh"
  ```
Экран Android выключится, и через 2 секунды загорится полноценный рабочий стол **postmarketOS Phosh** с часами, сенсорным управлением и виртуальной клавиатурой.

### Возврат в Android:
- **С самого телефона (из Linux):** Откройте приложение **Терминал** в Phosh и введите:
  ```sh
  android
  ```
- **С компьютера (если телефон завис):**
  ```cmd
  adb shell "su -c /data/pmos_files/stop_phosh.sh"
  ```
Телефон мгновенно возвращается на рабочий стол Nothing OS!

---

## ⚙️ Технические особенности реализации (Architecture)

1. **DRM_MASTER Handover (MediaTek MT6878):**
   В Android 14 на чипсетах MediaTek остановки одного `surfaceflinger` недостаточно. Графический процессор удерживается службой `vendor.hwcomposer-3-2` (`android.hardware.graphics.composer@3.2-service`). Скрипт `start_phosh.sh` корректно замораживает композитор Android сигналом `SIGSTOP` и передает управление напрямую в DRM/KMS.
2. **Аппаратная подсветка AMOLED:**
   Яркость экрана контролируется напрямую через регистр дисплейного контроллера:
   `/sys/devices/platform/display_id/brightnessid` (рабочее значение: `2600`).
3. **Сенсорный экран (Touchscreen):**
   Тачскрин FocalTech `fts_ts` (`event3`, major 13, minor 67) инициализируется подсистемой `libinput` с помощью динамической генерации свойств udev в `/run/udev/data/c13:67`.
4. **Оптимизация рендеринга (Smooth 60 FPS):**
   Так как проприетарные драйверы GPU Mali-G615 отсутствуют в чистом Linux, используется программный композитинг `WLR_RENDERER=pixman` с частотой 60 Гц (`1080x2392@60Hz`), 2D-движком `GSK_RENDERER=cairo` и переводом всех 8 ядер CPU в режим `performance`.
5. **Экранная клавиатура `wvkbd`:**
   Вместо тяжелого Squeekboard используется нативный Wayland layer-shell клиент `wvkbd-mobintl`, работающий мгновенно и без задержек.

---

## 📂 Структура проекта

```
galaxian-pmos-dualboot/
├── README.md               # Полное руководство на русском и английском
├── release_notes.md        # Техническое описание решения проблем драйверов
├── configs/
│   ├── phoc.ini            # Конфиг масштабирования экрана (2x, 60Hz)
│   └── udev_rules/c13_67   # Правило udev для сенсорного экрана
├── scripts/
│   ├── start_phosh.sh      # Главный скрипт запуска Phosh с телефона
│   ├── stop_phosh.sh       # Скрипт безопасного возврата в Android
│   ├── setup_termux.sh     # Создание команды 'linux' в Termux
│   ├── make_phosh_img.py   # Скрипт сборки ext4 rootfs образа в WSL
│   └── push_to_phone.bat   # Windows батник для установки в 1 клик
└── binaries/
    ├── wvkbd-mobintl       # Скомпилированный бинарник виртуальной клавиатуры
    └── squeekboard         # Бинарник Squeekboard для aarch64
```

---

## 📜 Лицензия
GPL-3.0 / MIT.
Разработано для сообщества postmarketOS и энтузиастов Nothing Phone.
