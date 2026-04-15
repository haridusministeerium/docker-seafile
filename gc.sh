#!/usr/bin/env bash
#
# For reference see https://github.com/haiwen/seafile-docker/blob/master/scripts/scripts_12.0/gc.sh
#
#readonly SEAFILE_BIN=/seafile/seafile-server-latest/seafile.sh
readonly GC_BIN=/seafile/seafile-server-latest/seaf-gc.sh

# perhaps also verify /pids/ dir is empty? although currently it's not properly
# cleaned up: https://github.com/haiwen/seafile/issues/2831
is_seaf_stopped() {
    local i

    i="$(sv status seafile)"
    [[ "$i" =~ ^down: ]] || return 1  # any other status than 'down', consider running

    if pgrep -f 'seafile-controller|seaf-server' > /dev/null; then
        return 1
    fi

    return 0
}


is_seaf_running() {
    local i

    i="$(sv status seafile)"
    [[ "$i" =~ ^run: ]]  # any other status than 'run', consider NOT running
}


source /common.sh || { echo -e "    ERROR: failed to import /common.sh"; exit 1; }

is_seaf_running
RUNNING_AT_START=$?

if [[ "$RUNNING_AT_START" -eq 0 ]]; then
    sv stop seafile || fail "[sv stop seafile] failed w/ $?"
    sleep 2
fi

is_seaf_stopped || fail 'seafile not stopped, cannot run GC'  # sanity


# first nuke the webdav temp files at least 2d old, see https://forum.seafile.com/t/cleanup-webdavtmp-files/15647/3 :
webdav_tmp_dir='/seafile/seafile-data/webdavtmp/'
if [[ -d "$webdav_tmp_dir" ]]; then
    find "$webdav_tmp_dir" -type f -mtime +2 -delete || err "webdavtmp file find-delete failed w/ $?"
else
    err "[$webdav_tmp_dir] not a dir"
fi

# ...then execute GC; see https://github.com/haridusministeerium/docker-seafile#gc
"$GC_BIN"  --dry-run || fail "[$GC_BIN --dry-run] failed w/ $?"
"$GC_BIN"            || fail "[$GC_BIN] failed w/ $?"
sleep 1
"$GC_BIN"  -r        || fail "[$GC_BIN -r] failed w/ $?"
sleep 1
"$GC_BIN"  --rm-fs   || fail "[$GC_BIN --rm-fs] failed w/ $?"
sleep 1

if [[ "$RUNNING_AT_START" -eq 0 ]]; then
    sv start seafile || fail "[sv start seafile] failed w/ $?"
fi

exit 0
