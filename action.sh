#!/system/bin/sh
# DT2W X625D — action.sh (tombol "Action" di aplikasi Magisk / KernelSU).
# Untuk enable ulang manual + cek status tanpa reboot.

PROC_FUN="/proc/gesture_function"
PROC_STATE="/proc/gesture_state"

echo "--- DT2W X625D ---"
if [ ! -e "$PROC_FUN" ]; then
  echo "GAGAL: $PROC_FUN tidak ada (kernel tidak cocok?)"
  exit 1
fi

if printf '%s' 'cc1' > "$PROC_FUN" 2>&1; then
  echo "OK: gesture cc (double tap) diaktifkan."
else
  echo "WARN: write cc1 gagal, cek dmesg."
fi

echo ""
echo "[gesture_state]"
cat "$PROC_STATE" 2>&1
echo ""
echo "[keylayout mtk-tpd]"
dumpsys input 2>/dev/null | grep -A3 'mtk-tpd' | grep -i keylayout
echo ""
echo "Tips: matikan layar, tunggu 3 detik, lalu double-tap."
exit 0
