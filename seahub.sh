#!/usr/bin/env bash
#
# for inspiration/debugging, see https://github.com/haiwen/seafile-docker/blob/master/scripts/scripts_12.0/start.py

readonly PROCESS_NAME='seahub.wsgi:application'
readonly SEAHUB_BIN=/seafile/seafile-server-latest/seahub.sh

# TODO: should we kill via pid-files instead?
#
# shellcheck disable=SC2329
stop_server() {
    printf -- "--> stopping seahub at [%s]:" "$(date)" >> "$LOG"
    "$SEAHUB_BIN" stop >> "$LOG" 2>&1
    sleep 2

    pkill -f "$PROCESS_NAME"
    #pgrep -f seahub | xargs kill
    exit 0
}

source /common.sh || { echo -e "    ERROR: failed to import /common.sh"; exit 1; }
readonly LOG="$LOG_ROOT/seahub-startup.log"

is_autostart && [[ -x "$SEAHUB_BIN" ]] || exit 0

wait_for_db

# wait for seafile server to start:
sleep 3

{
    echo '----------------------------------------'
    printf -- "--> launching seahub at [%s]:\n" "$(date)"
} >> "$LOG"

trap stop_server SIGINT SIGTERM

"$SEAHUB_BIN" start >> "$LOG" 2>&1

# wait for process to spin up:
sleep 5

# Script should not exit unless seahub died
#while pgrep -f "$PROCESS_NAME" >/dev/null 2>&1; do
sleep infinity &  # No, sleeping in the foreground does not work
wait $!

exit 0
