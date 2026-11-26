#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Realtek RTL8852BE (rtw89) Wi-Fi Random Disconnect Fix for Linux
# Disables PCIe ASPM L1, ASPM L1SS, and rtw89 Power Save Mode
# ==============================================================================

PARAMS="rtw89_pci.disable_aspm_l1=Y rtw89_pci.disable_aspm_l1ss=Y rtw89_core.disable_ps_mode=Y"
MODPROBE_CONF="/etc/modprobe.d/70-rtw89-wifi-fix.conf"
GRUB_FILE="/etc/default/grub"

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Please run this script with sudo: sudo ./fix-wifi.sh"
   exit 1
fi

echo "=== Applying Realtek RTL8852BE (rtw89) Wi-Fi Stability Fix ==="

# 1. Write /etc/modprobe.d/ configuration
echo "[1/3] Writing modprobe configuration to ${MODPROBE_CONF}..."
cat << 'EOF' > "${MODPROBE_CONF}"
# Disable PCIe ASPM L1 and L1SS to prevent Realtek RTL8852BE bus hangs
options rtw89_pci disable_aspm_l1=Y disable_aspm_l1ss=Y

# Disable internal firmware Power Save mode to prevent random Wi-Fi drops
options rtw89_core disable_ps_mode=Y
EOF

# 2. Update GRUB if /etc/default/grub exists
if [[ -f "${GRUB_FILE}" ]]; then
    echo "[2/3] Checking ${GRUB_FILE}..."
    cp "${GRUB_FILE}" "${GRUB_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    for param in $PARAMS; do
        if ! grep -q "$param" "${GRUB_FILE}"; then
            sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\([^\"]*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${param}\"/" "${GRUB_FILE}"
            echo "  + Added ${param} to GRUB_CMDLINE_LINUX_DEFAULT"
        else
            echo "  = ${param} is already present in ${GRUB_FILE}"
        fi
    done

    echo "[3/3] Updating GRUB bootloader configuration..."
    if command -v update-grub >/dev/null 2>&1; then
        update-grub
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        if [[ -f /boot/grub2/grub.cfg ]]; then
            grub2-mkconfig -o /boot/grub2/grub.cfg
        fi
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        if [[ -f /boot/grub/grub.cfg ]]; then
            grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi
else
    echo "[2/3] ${GRUB_FILE} not found (non-GRUB system). Relying on ${MODPROBE_CONF}."
fi

echo ""
echo "✅ Fix applied successfully! Please reboot your computer for changes to take full effect."
echo "After rebooting, run ./check-status.sh to verify."
