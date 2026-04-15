#!/usr/bin/env bash
#
# Inspiration from following seafile dockers:
#   https://github.com/foxel/seafile-docker/blob/master/scripts/setup.sh

DOWNLOAD_DOMAIN='https://www.seafile.com/en/download/'
SEAFILE_PATH=''                       # will be defined later on, as it depends on the seafile version
VER_REGEX='^[0-9]+\.[0-9]+\.[0-9]+$'  # seafile version validation regex


# 1) downloads tarball (either the latest or specified ver, depending on $VER);
# 2) defines $SEAFILE_PATH pointing to active installation directory;
# 3) untars downloaded tarball into $SEAFILE_PATH.
download_seafile() {
    local downloaded_tarball url

    readonly downloaded_tarball='/tmp/seafile-server.tar.gz'

    if [[ "$VER" == latest ]]; then
        url="$(wget \
            --no-check-certificate \
            "$DOWNLOAD_DOMAIN" -O- \
            | grep -o 'https://.*/seafile-server_.*_x86-64.tar.gz' \
            | sort -u \
            | tail -n1)" || fail "dl url resolution failed for version [$VER]"

        VER="$(grep -Po 'seafile-server_\K.*(?=_x86-64.*$)' <<< "$url")" || fail "unable to parse latest version from url [$url]"
        [[ "$VER" =~ $VER_REGEX ]] || fail "found latest ver was in an unexpected format: [$VER]"
    else  # actual version number was specified:
        url="$(wget \
            --no-check-certificate \
            "$DOWNLOAD_DOMAIN" -O- \
            | grep -o "https://.*/seafile-server_${VER}_x86-64.tar.gz")" || fail "dl url resolution failed for version [$VER]"
    fi

    is_valid_url "$url" || fail "found download url [$url] is not a valid url"

    readonly SEAFILE_PATH="/seafile/seafile-server-$VER"  # define installation dir

    # sanity:
    [[ -e "$SEAFILE_PATH" ]] && fail "[$SEAFILE_PATH] already exists; assuming [$VER] is already installed. abort."

    wget \
        --progress=dot:mega \
        --no-check-certificate \
        -O "$downloaded_tarball" \
        "$url" || fail "wgetting tarball from [$url] failed"

    mkdir -p -- "$SEAFILE_PATH" || fail "mkdir -p $SEAFILE_PATH failed w/ $?"
    tar -xzf "$downloaded_tarball" --strip-components=1 -C "$SEAFILE_PATH" || fail "untarring [$downloaded_tarball] failed w/ $?"
    rm -- "$downloaded_tarball" || exit 1
}


source /common.sh || { echo -e "    ERROR: failed to import /common.sh"; exit 1; }

[[ "$#" -gt 1 ]] && fail "max one arg (version) allowed"
[[ -n "$1" ]] && VER="$1"

# Perform sanity:
if [[ -z "$VER" ]]; then
    fail "VER env var was not provided"
elif ! [[ "$VER" =~ $VER_REGEX || "$VER" == latest ]]; then
    fail "version was in an unaccepted format: [$VER]"
fi

download_seafile

exit 0

