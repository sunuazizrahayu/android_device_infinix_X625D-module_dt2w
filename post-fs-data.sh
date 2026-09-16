#!/system/bin/sh
# DT2W Infinix HOT 7 PRO X625D — post-fs-data.sh
# Dijalankan Magisk / KernelSU di tahap post-fs-data: JAUH lebih awal dari
# service.sh (sebelum Zygote / SystemServer jalan, sebelum lockscreen muncul).
# Tujuannya: DT2W aktif sedini mungkin setelah reboot, tanpa perlu nunggu boot
# selesai. Node /proc/gesture_function dibuat driver saat probe kernel, jadi
# sudah ada di tahap ini.
#
# Format write HARUS tepat 3 char tanpa newline ("cc1"). JANGAN "cc:1".

MODDIR=${0%/*}
LOG="$MODDIR/dt2w.log"
PROC_FUN="/proc/gesture_function"

: > "$LOG"
echo "[post-fs-data uptime=$(cat /proc/uptime | cut -d' ' -f1)s] start" >> "$LOG"

i=0
while [ ! -e "$PROC_FUN" ] && [ $i -lt 60 ]; do
  sleep 1
  i=$((i + 1))
done

if [ ! -e "$PROC_FUN" ]; then
  echo "[post-fs-data] GAGAL: $PROC_FUN tidak ditemukan" >> "$LOG"
  exit 1
fi

if printf '%s' 'cc1' > "$PROC_FUN" 2>>"$LOG"; then
  echo "[post-fs-data uptime=$(cat /proc/uptime | cut -d' ' -f1)s] OK: cc1" >> "$LOG"
else
  echo "[post-fs-data] WARN: write cc1 gagal, dicoba lagi oleh service.sh" >> "$LOG"
fi

exit 0
