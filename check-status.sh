#!/usr/bin/env bash
set -euo pipefail

echo "=== Realtek rtw89 (RTL8852BE) Wi-Fi Status Check ==="
echo ""

echo "1. PCI Wireless Hardware:"
lspci -nnk | grep -iA3 -E "wireless|network|8852" || echo "   (lspci not found or no matching device)"
echo ""

echo "2. Kernel Command Line (/proc/cmdline):"
cat /proc/cmdline
echo ""

echo "3. Active rtw89 Module Parameters:"
all_ok=true
for path in \
    /sys/module/rtw89_pci/parameters/disable_aspm_l1 \
    /sys/module/rtw89_pci/parameters/disable_aspm_l1ss \
    /sys/module/rtw89_core/parameters/disable_ps_mode; do
    if [[ -f "$path" ]]; then
        val=$(cat "$path")
        echo "   $path = $val"
        if [[ "$val" != "Y" ]]; then
            all_ok=false
        fi
    else
        echo "   $path = (not found - module not loaded?)"
        all_ok=false
    fi
done

echo ""
if [[ "$all_ok" == true ]]; then
    echo "✅ All rtw89 power-saving workarounds (ASPM L1, L1SS, PS Mode) are ACTIVE (Y)."
else
    echo "⚠️  One or more parameters are NOT active. Run 'sudo ./fix-wifi.sh' and reboot."
fi
