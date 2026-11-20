# 📱 postmarketOS (Phosh Mobile GNOME) on Nothing Phone (3a) Lite

[![postmarketOS](https://img.shields.io/badge/postmarketOS-v24.06%20%2F%20edge-009900?logo=postmarketos&logoColor=white)](https://postmarketos.org/)
[![Device](https://img.shields.io/badge/Device-Nothing%20Phone%20(3a)%20Lite%20%2F%20Galaxian-black?logo=nothing&logoColor=white)](https://nothing.tech)
[![SoC](https://img.shields.io/badge/SoC-MediaTek%20Dimensity%207200%20%2F%20MT6878-blue)](https://www.mediatek.com/)
[![GPU](https://img.shields.io/badge/GPU%20Acceleration-Panthor%20GLES2%20(Mali--G615)-orange)](https://docs.kernel.org/gpu/panthor.html)
[![Display](https://img.shields.io/badge/AMOLED-1080x2392%20%40%20120Hz-purple)](https://nothing.tech)
[![License](https://img.shields.io/badge/License-GPL--3.0-brightgreen)](LICENSE)

> **Seamless dual-boot Linux environment running natively on the Nothing Phone (3a) Lite (`galaxian` / MediaTek Dimensity 7200 / MT6878) with full Wayland GUI, hardware GPU acceleration (Panthor / Mesa Panfrost GLES2), 120 Hz AMOLED display, multi-touch, virtual keyboard, and instant 1-command switching to/from Android Nothing OS!**

---

## 🌟 Highlights

* 🚀 **Full Hardware 3D Acceleration:** Open-source **Panthor DRM driver** (`/dev/dri/renderD128`) + **Mesa Panfrost GLES2** on ARM Mali-G615 MC2!
* ⚡ **Super Smooth 120 Hz AMOLED:** Native DRM/KMS output (`card0-DSI-1`) rendered at full 1080x2392 @ 120 FPS with bilinear texture filtering.
* 🔄 **Seamless GPU Handover:** Dynamic, crash-free switching between Android's proprietary CSF Mali driver (`mali_kbase_mt6878_r44`) and Linux open-source `panthor.ko` without rebooting the phone!
* 👆 **Flawless Multi-Touch:** FocalTech capacitive touchscreen (`fts_ts`) directly integrated with `libinput` via seat assignment.
* ⌨️ **On-Screen Keyboard:** Zero-latency `wvkbd-mobintl` layer-shell virtual keyboard ready out of the box.
* 🔁 **1-Command Switching:**
  * In Android (Termux): type **`linux`** ➔ Android sleeps, screen wakes to postmarketOS Phosh desktop in 2 seconds.
  * In Linux (Terminal): type **`android`** ➔ Linux cleanly releases GPU, Mali rebinds, phone wakes back to Nothing OS desktop.

---

## 📊 Component & Hardware Status

| Component | Status | Driver / Backend | Details |
| :--- | :---: | :--- | :--- |
| **GPU 3D Acceleration** | 🟢 **Working** | Panthor (`panthor.ko`) + Panfrost GLES2 | Mali-G615 MC2 hardware accelerated Wayland & apps |
| **Display (AMOLED)** | 🟢 **Working** | MediaTek DRM (`card0-DSI-1`) | 1080x2392 @ 120 Hz, Bilinear scaling |
| **Backlight Control** | 🟢 **Working** | `/sys/devices/platform/display_id/brightnessid` | Auto-managed comfortable brightness (2600) |
| **Touchscreen** | 🟢 **Working** | FocalTech `fts_ts` (`c13:67`) | Native multi-touch gestures, swipe up/down, tapping |
| **Mobile Desktop** | 🟢 **Working** | Phosh + Phoc (wlroots) | GNOME Mobile interface, app drawer, notifications |
| **Virtual Keyboard** | 🟢 **Working** | `wvkbd-mobintl` | Fast, low-latency on-screen keyboard |
| **Terminal & Shell** | 🟢 **Working** | `kgx` (GNOME Console) / `bash` / `zsh` | Full root access, apk package manager, fastfetch |
| **Instant Switching** | 🟢 **Working** | `start_phosh.sh` / `stop_phosh.sh` | Clean GPU unbind/rebind, display wakeup |
| **Audio (Sound)** | 🟡 *In Progress* | ALSA / PipeWire | Requires routing through MTK AFE audio HAL |
| **Wi-Fi Networking** | 🟡 *In Progress* | Android kernel socket firewall | Needs `AID_INET` (gid 3003) permission mapping |
| **Cellular (Modem)** | 🟡 *In Progress* | MediaTek CCCI / RILD | Under active development |

---

## 🛠 Prerequisites / Требования

1. **Device:** Nothing Phone (3a) Lite (codename: `galaxian`, SoC: MT6878 / Dimensity 7200).
2. **Root Access:** Stock Nothing OS with **KernelSU**, **APatch**, or **Magisk** installed and working.
3. **Termux:** Installed on your phone (recommended from [F-Droid](https://f-droid.org/packages/com.termux/)).
4. **Computer (for first-time setup):** Windows or Linux PC with `adb` installed.
5. **Disk Space:** At least 4-5 GB free in `/data` on your phone.

---

## 🚀 Quick Start / Быстрая установка

### Шаг 1: Клонирование репозитория на ПК

```bash
git clone https://github.com/Andreyka445/linux_device_nothing_Galaxian.git
cd linux_device_nothing_Galaxian
```

### Шаг 2: Загрузка файлов на смартфон

Подключите телефон по USB с включенной отладкой по ADB.

* **В Windows:** просто дважды кликните по файлу:
  ```text
  scripts\push_to_phone.bat
  ```
  *(Скрипт сам создаст все нужные папки, скопирует скрипты, конфиги клавиатуры и выдаст права исполняемых файлов)*.

* **Либо вручную через терминал:**
  ```bash
  adb shell "su -c 'mkdir -p /data/pmos_files /data/pmos && chmod 777 /data/pmos_files'"
  adb push scripts/start_phosh.sh /data/local/tmp/start_phosh.sh
  adb push scripts/stop_phosh.sh /data/local/tmp/stop_phosh.sh
  adb push scripts/linux_pmos.sh /data/local/tmp/linux_pmos.sh
  adb push scripts/android_pmos.sh /data/local/tmp/android_pmos.sh
  adb push scripts/linux_termux.sh /data/local/tmp/linux_termux.sh
  adb push scripts/android_termux.sh /data/local/tmp/android_termux.sh
  adb push configs/phoc.ini /data/local/tmp/phoc.ini
  adb push binaries/wvkbd-mobintl /data/local/tmp/wvkbd

  adb shell "su -c 'mv /data/local/tmp/start_phosh.sh /data/pmos_files/start_phosh.sh && mv /data/local/tmp/stop_phosh.sh /data/pmos_files/stop_phosh.sh && mv /data/local/tmp/linux_pmos.sh /data/pmos_files/linux && mv /data/local/tmp/android_pmos.sh /data/pmos_files/android && chmod +x /data/pmos_files/* && cp /data/local/tmp/linux_termux.sh /data/data/com.termux/files/usr/bin/linux && cp /data/local/tmp/android_termux.sh /data/data/com.termux/files/usr/bin/android && chmod +x /data/data/com.termux/files/usr/bin/linux /data/data/com.termux/files/usr/bin/android'"
  ```

### Шаг 3: Получение и загрузка образа системы `pmos_phosh.img`

Сам образ файловой системы postmarketOS весит ~3.2 ГБ в распакованном виде, поэтому в git-репозиторий он напрямую не коммитится. Получить его можно двумя способами:

#### Вариант А: Скачать готовый образ (Рекомендуется для всех)
1. Перейдите во вкладку [**Releases**](https://github.com/Andreyka445/linux_device_nothing_Galaxian/releases) этого репозитория.
2. Скачайте архив релиза **`pmos_phosh.img.tar.gz`** (сжат всего до ~720 МБ).
3. Распакуйте архив на компьютере (получится файл `pmos_phosh.img`).
4. Поместите распакованный `pmos_phosh.img` в папку с проектом.
5. Запустите `push_to_phone.bat` (он автоматически спросит «Залить образ на телефон? [Y/N]» и скопирует его), либо выполните вручную:
   ```bash
   adb push pmos_phosh.img /data/local/tmp/pmos_phosh.img
   adb shell "su -c 'mv /data/local/tmp/pmos_phosh.img /data/pmos_files/pmos_phosh.img'"
   ```

#### Вариант Б: Собрать образ с нуля через pmbootstrap (Для разработчиков)
Если вы хотите собрать чистый образ самостоятельно из исходников Alpine Linux / postmarketOS:
1. Установите `pmbootstrap` в среде Linux / WSL.
2. Инициализируйте сборку для целевого устройства:
   ```bash
   pmbootstrap init
   pmbootstrap install --ui phosh
   ```
3. Запустите наш генератор loop-образа:
   ```bash
   sudo python3 scripts/make_phosh_img.py
   ```
   Скрипт создаст оптимизированный `ext4` образ `pmos_phosh.img` с меткой `pmOS_root`.

---

## 🎮 Как пользоваться / Usage

### 🟢 Запуск Linux (postmarketOS Phosh):

1. Откройте **Termux** на телефоне.
2. Введите команду:
   ```bash
   linux
   ```
3. Предоставьте Root-доступ (если появится запрос суперпользователя).
4. Экран Nothing OS погаснет, и через 2 секунды загорится рабочий стол **Phosh** с часами, шторкой и меню приложений на 120 Гц!

> **Подсказка:** Вы также можете запустить систему с компьютера через ADB:
> ```bash
> adb shell "su -c /data/pmos_files/linux"
> ```

---

### 🔴 Возврат в Android (Nothing OS):

1. На телефоне в интерфейсе Linux откройте приложение **Терминал** (`Terminal` / `Console`).
2. Введите команду:
   ```sh
   android
   ```
3. Графика Linux завершит работу, оригинальный драйвер Mali переподключится, экран смартфона автоматически включится, и вы вернетесь на рабочий стол Nothing OS!

> **Если что-то пошло не так:** в любой момент с компьютера по ADB можно выполнить принудительный возврат:
> ```bash
> adb shell "su -c /data/pmos_files/stop_phosh.sh"
> ```

---

## 💡 Полезные советы / Tips & Tricks

### 1. Как запустить `fastfetch`, чтобы он красиво помещался в экран телефона?

По умолчанию `fastfetch` выводит большой ASCII-логотип слева от системной информации, из-за чего строки на узком экране смартфона переносятся и ломают верстку.

Используйте следующие варианты:

* **Логотип сверху (наиболее красиво и наглядно):**
  ```bash
  fastfetch --logo-position top
  ```
* **Компактный пресет без логотипа (только железо и характеристики):**
  ```bash
  fastfetch -l none
  ```
* **Готовый компактный пресет:**
  ```bash
  fastfetch -c examples/2.jsonc
  ```
* **Создать постоянный алиас:**
  Добавьте в ваш `~/.bashrc` внутри postmarketOS:
  ```bash
  echo "alias ff='fastfetch --logo-position top'" >> ~/.bashrc
  ```

---

### 2. Управление яркостью экрана

Если вам нужно вручную изменить яркость AMOLED дисплея:
```bash
# Значение от 100 до 4095
echo 2600 > /sys/devices/platform/display_id/brightnessid
```

---

### 3. Логи и отладка

Все события переключения и логи композитора Phoc записываются в файл на телефоне:
```bash
adb shell "su -c 'tail -f /data/pmos_files/phosh.log'"
```

---

## 🧠 Техническая архитектура / Under the Hood

### Архитектура динамического переключения GPU (Mali CSF ⇄ Panthor)

```
+-----------------------------------------------------------------------------------+
|                                Nothing Phone (3a) Lite                            |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [ Android Nothing OS Mode ]                       [ postmarketOS Linux Mode ]    |
|                                                                                   |
|  +------------------------+                        +---------------------------+  |
|  | Android Apps / UI      |                        | Phosh (GNOME Mobile Shell)|  |
|  +------------------------+                        +---------------------------+  |
|             |                                                    |                |
|  +------------------------+                        +---------------------------+  |
|  | SurfaceFlinger & HWC   |                        | Phoc (wlroots Wayland)    |  |
|  +------------------------+                        +---------------------------+  |
|             |                                                    |                |
|  +------------------------+                        +---------------------------+  |
|  | Mali CSF Driver        |                        | Panthor Open-Source Driver|  |
|  | (mali_kbase_mt6878_r44)|                        | (Mesa Panfrost GLES2)     |  |
|  | /vendor/firmware       |                        | /data/local/tmp/panthor   |  |
|  +------------------------+                        +---------------------------+  |
|             \                                                    /                |
|              \                                                  /                 |
|               +------------------------------------------------+                  |
|               |       ARM Mali-G615 MC2 (13000000.mali)        |                  |
|               |          MediaTek MT6878 Platform              |                  |
|               +------------------------------------------------+                  |
|                                       |                                           |
|               +------------------------------------------------+                  |
|               |  MediaTek DRM/KMS Controller (card0-DSI-1)     |                  |
|               |       AMOLED Display 1080x2392 @ 120Hz         |                  |
|               +------------------------------------------------+                  |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

### Ключевые инженерные решения:

1. **Безопасная передача DRM Master:**
   В Android 14/15 на MediaTek простого `stop surfaceflinger` недостаточно — службу `vendor.hwcomposer-3-2` также необходимо остановить, иначе она удерживает эксклюзивный дескриптор `/dev/dri/card0`. Наш скрипт аккуратно координирует остановку служб.
2. **Изоляция прошивок CSF (Command Stream Frontend):**
   Mali v12+ использует CSF-микрокод. Android Mali требует бинарник MediaTek (`/vendor/firmware/mali_csffw.bin`, 290 КБ), а Linux Panthor требует совместимый с апстримом микрокод (`/data/local/tmp/panthor/mali_csffw.bin`, 274 КБ). Скрипт динамически переключает параметр ядра `/sys/module/firmware_class/parameters/path` перед загрузкой каждого драйвера, предотвращая дедлоки планировщика GPU.
3. **Подавление гонок MediaTek GED DVFS:**
   Губернатор частот MediaTek GED опрашивает GPU в фоне. Перед `unbind` драйвера Mali скрипт временно отключает `gpu_dvfs_enable`, исключая панику ядра (`ged_eb_work_cb`).
4. **Автоматическое пробуждение AMOLED и исправление PTY:**
   При возврате в Android фреймворк просыпается в режиме сна Keyguard/Doze. Скрипт аппаратно отправляет `KEYCODE_WAKEUP`, задает яркость `brightnessid = 2000`, снимает блокировку и гарантирует права `chmod 666 /dev/pts/ptmx` для стабильной работы Termux.

---

## 🤝 Вклад в проект и благодарности

* Проект разработан для сообщества **Nothing Phone** и энтузиастов **postmarketOS / Linux on Mobile**.
* Базируется на разработках проекта [postmarketOS](https://postmarketos.org/), драйвера [Panthor](https://gitlab.freedesktop.org/panfrost), и открытого стека [Phosh / Phoc](https://gitlab.gnome.org/World/Phosh/phosh).
* Pull-реквесты, issue и предложения по добавлению поддержки аудио (AFE/ALSA) и сети приветствуются!
