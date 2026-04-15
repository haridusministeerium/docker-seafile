#!/usr/bin/env bash
#
# for inspiration/debugging, see https://github.com/haiwen/seafile-docker/blob/master/scripts/scripts_12.0/start.py

readonly SEAFILE_BIN=/seafile/seafile-server-latest/seafile.sh
readonly WEBDAV_PROCESS_NAME='wsgidav.server.server_cli'

# TODO: should we kill via pid-files instead? pids located @ /seafile/pids/
#
# shellcheck disable=SC2329
stop_server() {
    #sleep 2  # give chance for seahub to stop first

    printf -- "--> stopping seafile server at [%s]:" "$(date)" >> "$LOG"
    "$SEAFILE_BIN" stop >> "$LOG" 2>&1
    sleep 5

    pgrep -f 'seafile-controller|seaf-server' | xargs kill
    #pkill -f seafile-controller

    sleep 1

    # webdav sometimes appears to not shut down; see https://forum.seafile.com/t/webdav-server-does-not-stop/22477
    #                                                https://github.com/mar10/wsgidav/issues/327
    if pgrep -f  "$WEBDAV_PROCESS_NAME" > /dev/null; then
        #pkill --signal SIGHUP -f  "$WEBDAV_PROCESS_NAME"
        pkill --signal SIGINT  -f  "$WEBDAV_PROCESS_NAME"
        sleep 1
        pkill --signal SIGKILL -f  "$WEBDAV_PROCESS_NAME"
    fi

    exit 0
}

source /common.sh || { echo -e "    ERROR: failed to import /common.sh"; exit 1; }
readonly LOG="$LOG_ROOT/seafile-startup.log"

is_autostart && [[ -x "$SEAFILE_BIN" ]] || exit 0

wait_for_db
sleep 2

{
    echo '----------------------------------------'
    printf -- "--> launching seafile server at [%s]:\n" "$(date)"
} >> "$LOG"

trap stop_server SIGINT SIGTERM

"$SEAFILE_BIN" start >> "$LOG" 2>&1
# wait for process to spin up:
sleep 5

# Script should not exit unless seafile died
#while pgrep -f "seafile-controller" >/dev/null 2>&1; do
sleep infinity &  # No, sleeping in the foreground does not work
wait $!

exit 0
