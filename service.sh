#!/system/bin/sh
# DT2W Infinix HOT 7 PRO X625D (NT36672A / MT6765) — service.sh
# Dijalankan Magisk / KernelSU setiap boot (late_start).
# Cara kerja (hasil investigasi via ADB di device ini):
#  - Driver: NVT36xxx-ts, proc write node = /proc/gesture_function
#  - Format write = TEPAT 3 char tanpa newline, contoh: "cc1" = enable Double Tap
#    (dmesg: "CTP-gesture buff 0:c 1:c 2:1!!!"). JANGAN tulis "cc:1" (pakai titik
#    dua) — itu bikin hang. JANGAN tulis ke /proc/gesture_state (read-only status).
#  - Driver lapor DT2W sebagai KEY_F13 (kode 183) ke input "mtk-tpd"
#    (terbukti via getevent saat layar mati). Pemetaan 183 -> POWER WAKE
#    disediakan oleh system/usr/keylayout/mtk-tpd.kl dalam modul ini,
#    karena Generic.kl bawaan GSI tidak memetakan 183 dan tidak punya
#    flag WAKE.

MODDIR=${0%/*}
LOG="$MODDIR/dt2w.log"
PROC_FUN="/proc/gesture_function"
PROC_STATE="/proc/gesture_state"

log() {
  echo "[$(date '+%m-%d %H:%M:%S')] $1" >> "$LOG"
}

: >> "$LOG"
log "=== DT2W X625D service start (uptime=$(cat /proc/uptime | cut -d' ' -f1)s) ==="

# post-fs-data.sh (tahap boot paling awal) sudah menulis cc1. Di sini cukup
# verifikasi + tulis ulang bila belum aktif, jadi tidak ada jeda tambahan.

# Tunggu proc node muncul (biasanya sudah ada karena post-fs-data.sh;
# loop ini hanya pengaman, maks ~20 detik)
i=0
while [ ! -e "$PROC_FUN" ] && [ $i -lt 10 ]; do
  sleep 2
  i=$((i + 1))
done

if [ ! -e "$PROC_FUN" ]; then
  log "GAGAL: $PROC_FUN tidak ditemukan"
  exit 1
fi

# Tunggu boot selesai secukupnya untuk 'settings' (maks ~30 detik).
# cc1 sendiri TIDAK butuh ini karena sudah ditulis di post-fs-data.
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 15 ]; do
  sleep 2
  i=$((i + 1))
done
sleep 3

# 1) Pastikan Double Tap (cc) aktif. Normalnya post-fs-data.sh sudah
#    mengaktifkan; tulis ulang hanya bila status belum cc:1.
if grep -q '^cc:1;' "$PROC_STATE" 2>/dev/null; then
  log "OK: gesture cc sudah aktif (dari post-fs-data)"
elif printf '%s' 'cc1' > "$PROC_FUN" 2>>"$LOG"; then
  log "OK: gesture cc diaktifkan via service.sh (cc1 -> $PROC_FUN)"
else
  log "WARN: write cc1 gagal (rc=$?)"
fi

# 2) Verifikasi status driver (read-only, aman dibaca)
if [ -r "$PROC_STATE" ]; then
  log "--- /proc/gesture_state ---"
  cat "$PROC_STATE" >> "$LOG" 2>&1
fi

# 3) Setting Android agar framework mengizinkan DT2W.
#    Mencakup kunci milik XOS Transsion, AOSP, Lineage, dan Phh-GSI.
#    Pakai path absolut + retry bertahap; stdout+stderr dicatat agar
#    penyebab gagal terlihat di log bila masih WARN.
SETTINGS=/system/bin/settings
round=0
pending="secure:double_tap_to_wake:1 secure:wake_gesture_enabled:1 system:os_action_tapping_wake:1 system:dt2w_enabled:1 system:double_tap_to_wake:1 global:keyguard_gesture:2"
while [ -n "$pending" ] && [ $round -lt 4 ]; do
  next=""
  for kv in $pending; do
    ns=${kv%%:*}; rest=${kv#*:}; key=${rest%%:*}; val=${rest##*:}
    out=$("$SETTINGS" put "$ns" "$key" "$val" 2>&1)
    got=$("$SETTINGS" get "$ns" "$key" 2>/dev/null)
    if [ "$got" = "$val" ]; then
      log "OK: settings $ns $key=$got"
    else
      [ -n "$out" ] && log "INFO: settings $ns $key: $out"
      next="$next $kv"
    fi
  done
  pending=$(echo "$next" | tr -s ' ')
  if [ -n "$pending" ]; then
    round=$((round + 1))
    sleep 10
  fi
done
[ -n "$pending" ] && log "WARN: settings gagal:$pending"

log "=== DT2W X625D service done ==="
exit 0
