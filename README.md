# Realtek RTL8852BE Wi-Fi Random Disconnect Fix on Linux (`rtw89`)

[![Linux](https://img.shields.io/badge/OS-Linux-FCC624?logo=linux&logoColor=black)](#)
[![Kernel](https://img.shields.io/badge/Driver-rtw89__8852be-blue)](#)
[![Hardware](https://img.shields.io/badge/Realtek-RTL8852BE%20%5B10ec%3Ab852%5D-red)](#)
[![Laptop](https://img.shields.io/badge/Lenovo-IdeaPad%20%2F%20ThinkBook%20%2F%20HP%20%2F%20ASUS-informational)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **🇺🇸 English** | **[🇪🇸 Español](#-solución-definitiva-desconexiones-wi-fi-realtek-rtl8852be-en-linux-rtw89)**

Permanent fix for **Realtek RTL8852BE PCIe 802.11ax (Wi-Fi 6)** wireless cards randomly dropping connection, freezing, or disconnecting after a few minutes/hours of use across Linux distributions (Debian, Ubuntu, Fedora, Arch Linux, Linux Mint, Manjaro, openSUSE, etc.).

Also includes the bonus kernel parameter fix for **Lenovo IdeaPad Slim 3 (`15ABR8` / `82XM`)** built-in keyboards not working on boot (`i8042.direct i8042.dumbkdb`).

---

## 🔍 Affected Hardware & Symptoms

### Hardware Identification
Run `lspci -nnk | grep -iA3 net` to verify if you have this card:

```text
02:00.0 Network controller [0280]: Realtek Semiconductor Co., Ltd. RTL8852BE PCIe 802.11ax Wireless Network Controller [10ec:b852]
	Subsystem: Lenovo Device [17aa:4853]
	Kernel driver in use: rtw89_8852be
	Kernel modules: rtw89_8852be
```

* **Chipset:** Realtek RTL8852BE (`10ec:b852`) / also applicable to RTL8852AE & RTL8852CE using `rtw89`
* **Kernel Driver:** `rtw89_8852be` (`rtw89_pci`, `rtw89_core`)
* **Common Laptops:** Lenovo IdeaPad Slim 3 (15ABR8 / 82XM), Lenovo IdeaPad Gaming 3, Lenovo V15, Lenovo ThinkBook, HP Pavilion / Victus, ASUS VivoBook / TUF.

### Symptoms
* Wi-Fi works fine immediately after booting, then **suddenly stops transmitting data or disconnects completely** after some time.
* Reconnecting to the Wi-Fi network fails or hangs until you reboot or reload the kernel module.
* `dmesg` or `journalctl -k` shows errors such as:
  * `rtw89_8852be 0000:02:00.0: firmware failed to ack for entering ps mode`
  * `rtw89_8852be 0000:02:00.0: timed out to flush pci txch`
  * `rtw89_8852be 0000:02:00.0: mac init fail` / `leave idle state failed`

---

## 🧠 Root Cause

The `rtw89` driver attempts to use **PCIe Active State Power Management (ASPM L1 and L1 Substates)** along with internal **802.11 Power Save (PS) mode**. On many motherboard PCIe implementations (especially Lenovo and HP laptops), when the Realtek RTL8852BE chip enters deep sleep (`L1` / `L1SS`), it fails to wake up properly or misses PCIe clock transitions, causing the wireless firmware to crash until a cold reboot or bus reset.

Disabling **ASPM L1**, **ASPM L1SS**, and **`rtw89` low-power PS mode** completely prevents the card from entering the broken sleep state and makes the Wi-Fi connection 100% rock-solid.

---

## 🛠️ Quick Automated Fix

Clone this repository and run the automated script, which configures both GRUB and `/etc/modprobe.d/` safely:

```bash
git clone https://github.com/TheoCerveraLede/rtl8852be-linux-wifi-fix.git
cd rtl8852be-linux-wifi-fix
sudo ./fix-wifi.sh
```

---

## 🔧 Manual Fix Instructions (Any Linux Distro)

You can apply this fix via **GRUB Kernel Parameters** (Method 1 — most reliable even when `rtw89` is packed into `initramfs`) or via **Modprobe Configuration** (Method 2 — works on any bootloader including `systemd-boot`).

### Method 1: GRUB Kernel Boot Parameters (Recommended & Battle-Tested)

1. Open `/etc/default/grub` with root privileges:
   ```bash
   sudo nano /etc/default/grub
   ```
2. Add the following three parameters to `GRUB_CMDLINE_LINUX_DEFAULT`:
   ```text
   rtw89_pci.disable_aspm_l1=Y rtw89_pci.disable_aspm_l1ss=Y rtw89_core.disable_ps_mode=Y
   ```
   Example of how the line should look:
   ```ini
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash rtw89_pci.disable_aspm_l1=Y rtw89_pci.disable_aspm_l1ss=Y rtw89_core.disable_ps_mode=Y"
   ```
   *(💡 **Lenovo IdeaPad Slim 3 Bonus:** If your built-in laptop keyboard sometimes fails on boot, also include `i8042.direct i8042.dumbkdb` in that same line).*

3. Regenerate your GRUB configuration according to your distribution:
   * **Debian / Ubuntu / Linux Mint / Kali / Zorin:**
     ```bash
     sudo update-grub
     ```
   * **Fedora / RHEL / AlmaLinux / Rocky Linux:**
     ```bash
     sudo grub2-mkconfig -o /boot/grub2/grub.cfg
     ```
   * **Arch Linux / Manjaro / EndeavourOS:**
     ```bash
     sudo grub-mkconfig -o /boot/grub/grub.cfg
     ```
   * **openSUSE:**
     ```bash
     sudo grub2-mkconfig -o /boot/grub2/grub.cfg
     ```
4. **Reboot** your system:
   ```bash
   sudo reboot
   ```

### Method 2: `/etc/modprobe.d/` Configuration (For systemd-boot / Pop!_OS / Universal)

If your distribution does not use GRUB (e.g., `systemd-boot`) or you want a bootloader-agnostic configuration:

```bash
sudo tee /etc/modprobe.d/70-rtw89-wifi-fix.conf << 'EOF'
# Disable PCIe ASPM L1 and L1SS to prevent Realtek RTL8852BE bus hangs
options rtw89_pci disable_aspm_l1=Y disable_aspm_l1ss=Y

# Disable internal firmware Power Save mode to prevent random Wi-Fi drops
options rtw89_core disable_ps_mode=Y
EOF
```

Then update your initramfs and reboot:
* **Debian / Ubuntu:** `sudo update-initramfs -u && sudo reboot`
* **Fedora:** `sudo dracut --force && sudo reboot`
* **Arch Linux:** `sudo mkinitcpio -P && sudo reboot`

---

## ✅ How to Verify the Fix is Active

After rebooting, run the included `check-status.sh` script or execute:

```bash
grep -H . /sys/module/rtw89_pci/parameters/disable_aspm_l1* /sys/module/rtw89_core/parameters/disable_ps_mode
```

**Expected Output (`Y` on all three):**
```text
/sys/module/rtw89_pci/parameters/disable_aspm_l1:Y
/sys/module/rtw89_pci/parameters/disable_aspm_l1ss:Y
/sys/module/rtw89_core/parameters/disable_ps_mode:Y
```

### Parameter Breakdown
| Kernel Module | Parameter | Value | Description |
| :--- | :--- | :---: | :--- |
| `rtw89_pci` | `disable_aspm_l1` | `Y` | Disables PCIe ASPM L1 power state |
| `rtw89_pci` | `disable_aspm_l1ss` | `Y` | Disables PCIe L1 Substates (deep sleep) |
| `rtw89_core` | `disable_ps_mode` | `Y` | Disables 802.11 low-power mode in `rtw89` core |

---
---

# 🇪🇸 Solución Definitiva: Desconexiones Wi-Fi Realtek RTL8852BE en Linux (`rtw89`)

Solución documentada y probada para evitar que la tarjeta de red inalámbrica **Realtek RTL8852BE PCIe 802.11ax (Wi-Fi 6)** se desconecte sola, pierda acceso a internet después de un tiempo de uso o sufra microcortes en cualquier distribución de Linux (Debian, Ubuntu, Fedora, Arch, Linux Mint, Manjaro, etc.).

---

## 🔍 Hardware Afectado y Causa del Problema

* **Tarjeta de Red:** `Realtek Semiconductor Co., Ltd. RTL8852BE PCIe 802.11ax Wireless Network Controller [10ec:b852]` (Subsistema Lenovo `[17aa:4853]`).
* **Driver en el Kernel:** `rtw89_8852be` (que utiliza los módulos base `rtw89_pci` y `rtw89_core`).
* **Equipo donde se validó:** Lenovo IdeaPad Slim 3 15ABR8 (`82XM`) corriendo Debian GNU/Linux (Kernel 6.12+).

### ¿Por qué se desconecta el Wi-Fi después de un tiempo?
Las tarjetas **Realtek RTL8852BE** tienen problemas graves en Linux con la gestión de energía del bus PCIe (**ASPM L1 / L1SS**) y el modo de ahorro de energía interno del chip (**PS Mode**). Cuando el sistema intenta poner la tarjeta en un estado de bajo consumo durante el uso normal, el firmware no logra despertar a tiempo del estado L1/L1SS y la conexión Wi-Fi muere hasta que se reinicia el equipo.

---

## 🛠️ Cómo Aplicar la Solución en Cualquier Distro

Puedes usar el script automático incluido en este repositorio:

```bash
sudo ./fix-wifi.sh
```

O aplicarlo manualmente con cualquiera de los siguientes métodos:

### Opción A: Por Parámetros del Kernel en GRUB (Método Recomendado)

Este método pasa las opciones directamente al kernel en el arranque (`cmdline`), asegurando que se apliquen incluso antes de montar el sistema de archivos raíz:

1. Edita el archivo `/etc/default/grub`:
   ```bash
   sudo nano /etc/default/grub
   ```
2. En la variable `GRUB_CMDLINE_LINUX_DEFAULT`, agrega los siguientes parámetros:
   ```text
   rtw89_pci.disable_aspm_l1=Y rtw89_pci.disable_aspm_l1ss=Y rtw89_core.disable_ps_mode=Y
   ```
   *(Nota: Si tienes una Lenovo IdeaPad Slim 3 como la 15ABR8, también es recomendable mantener `i8042.direct i8042.dumbkdb` para evitar problemas con el teclado integrado)*.
   ```ini
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i8042.direct i8042.dumbkdb rtw89_pci.disable_aspm_l1=Y rtw89_pci.disable_aspm_l1ss=Y rtw89_core.disable_ps_mode=Y"
   ```
3. Actualiza GRUB según tu distribución:
   * **Debian / Ubuntu / Mint:** `sudo update-grub`
   * **Fedora / RHEL:** `sudo grub2-mkconfig -o /boot/grub2/grub.cfg`
   * **Arch / Manjaro / EndeavourOS:** `sudo grub-mkconfig -o /boot/grub/grub.cfg`
4. Reinicia el equipo (`sudo reboot`).

### Opción B: Mediante `/etc/modprobe.d/` (Para distros con systemd-boot o sin GRUB)

```bash
sudo tee /etc/modprobe.d/70-rtw89-wifi-fix.conf << 'EOF'
options rtw89_pci disable_aspm_l1=Y disable_aspm_l1ss=Y
options rtw89_core disable_ps_mode=Y
EOF
```

---

## ✅ Verificación

Después de reiniciar, ejecuta `./check-status.sh` o el siguiente comando para confirmar que los 3 parámetros están en `Y`:

```bash
grep -H . /sys/module/rtw89_pci/parameters/disable_aspm_l1* /sys/module/rtw89_core/parameters/disable_ps_mode
```

Resultado esperado:
```text
/sys/module/rtw89_pci/parameters/disable_aspm_l1:Y
/sys/module/rtw89_pci/parameters/disable_aspm_l1ss:Y
/sys/module/rtw89_core/parameters/disable_ps_mode:Y
```

---

## 📄 License / Licencia
MIT License. Feel free to share, fork, and use across any Linux installation.
