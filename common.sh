#!/usr/bin/env bash
#

LOG_ROOT='/seafile/logs'

# Checks whether given url is a valid url.
#
# @param {string}  url   url which validity to test.
#
# @returns {bool}  true, if provided url was a valid url.
is_valid_url() {
    local regex='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
    [[ "$1" =~ $regex ]]
}


check_is_file() {
    local file="$1"
    [[ -f "$file" ]] || fail "${FUNCNAME[1]}: [$file] is not a valid file"
}


check_dependencies() {
    local i

    for i in wget nc pgrep pkill crudini; do
        command -v "$i" >/dev/null || fail "[$i] not installed"
    done
}


err() {
    >&2 echo -e "$*" 1>&2
}


fail() {
    err "ERR: $*"
    exit 1
}


is_autostart() {
    [[ "$AUTOSTART" =~ ^[Tt]rue$ ]]
}


wait_for_db() {
    local host port messaged

    __parse_db_connection_details() {
        local config='/seafile/conf/seafile.conf'

        check_is_file "$config"
        host="$(crudini --get "$config" database host)" || fail "fetching db host from config file [$config] failed"
        port="$(crudini --get "$config" database port)" || fail "fetching db port from config file [$config] failed"
        [[ -z "$host" || -z "$port" ]] && fail "couldn't parse either db hostname and/or port"
    }

    __parse_db_connection_details
    until nc -z "$host" "$port"; do
        [[ -z "$messaged" ]] && echo "Waiting until db @ [$host:$port] is responding..." && messaged=TRUE
        sleep 2
    done

    echo "Connection to db @ [$host:$port] established"
    return 0
}

check_dependencies
