#!/system/bin/sh

# ============================================
# Power2Swipe - 长按电源键触发三指上划
# ============================================

LONG_PRESS_MS=800

log_msg() {
    echo "[Power2Swipe] $*"
    log -t Power2Swipe "$*" 2>/dev/null || true
}

log_msg "Power2Swipe starting..."

three_finger_swipe() {
    log_msg "Triggering three-finger swipe via ColorDirectService"
    CLASSPATH=/system/framework/am.jar /system/bin/app_process /system/bin com.android.commands.am.Am start-foreground-service -p "com.coloros.colordirectservice" --ei "triggerType" 12
    log_msg "Three-finger swipe triggered"
}

# ---------- 工具函数 ----------

cleanup() {
    rm -f /data/local/tmp/power2swipe_fifo
    log_msg "Power2Swipe stopped"
    exit 0
}

trap cleanup EXIT TERM INT

# ---------- 主循环 ----------

FIFO=/data/local/tmp/power2swipe_fifo
rm -f "$FIFO"
mkfifo "$FIFO" || {
    log_msg "ERROR: failed to create fifo"
    exit 1
}

getevent 2>/dev/null | grep --line-buffered ": 0001 0074 " > "$FIFO" &
GETEVENT_PID=$!
sleep 0.5

if ! kill -0 $GETEVENT_PID 2>/dev/null; then
    log_msg "ERROR: getevent/grep pipeline failed"
    exit 1
fi

log_msg "Power2Swipe monitoring started (PID: $$)"

TIMER_PID=0

while read -r line; do
    value="${line##* }"
    case "$value" in
        "00000001")
            [ "$TIMER_PID" -ne 0 ] && kill $TIMER_PID 2>/dev/null
            (
                sleep 0.8
                three_finger_swipe
            ) &
            TIMER_PID=$!
            ;;
        "00000000")
            if [ "$TIMER_PID" -ne 0 ] && kill -0 $TIMER_PID 2>/dev/null; then
                kill $TIMER_PID 2>/dev/null
                log_msg "Power key released before long press"
            fi
            TIMER_PID=0
            ;;
    esac
done < "$FIFO"
