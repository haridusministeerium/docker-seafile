#!/usr/bin/env bash
#
# https://manual.seafile.com/deploy/using_mysql/
#
#
# Inspiration from following seafile dockers:
#   https://github.com/foxel/seafile-docker/blob/master/scripts/setup.sh

SEAFILE_URL="https://$SERVER_IP"      # note https (assuming you've enabled https)


# Taken from https://github.com/haiwen/seafile-server-installer-cn/blob/master/seafile-server-ubuntu-14-04-amd64-http
setup_seafile() {
    local init_admin init_admin_bak

    init_admin="${SEAFILE_PATH}/check_init_admin.py"
    init_admin_bak="${init_admin}.bak"

    check_is_file "$init_admin"
    # Backup check_init_admin.py befor applying changes
    cp -- "$init_admin" "$init_admin_bak" || exit 1

    sed --follow-symlinks -i 's/= ask_admin_email()/= '"\"${SEAHUB_ADMIN_USER}\""'/' "$init_admin" || exit 1
    sed --follow-symlinks -i 's/= ask_admin_password()/= '"\"${SEAHUB_ADMIN_PW}\""'/' "$init_admin" || exit 1

    # TODO: -i param is only passed so python script would read env vars; see https://github.com/haiwen/seafile-server/pull/24
    "${SEAFILE_PATH}/setup-seafile-mysql.sh" auto -i "$SERVER_IP" || fail "seafile setup failed."

    # Start and stop Seafile eco system. This generates the initial admin user.
    "${SEAFILE_PATH}/seafile.sh" start || fail "seafile start failed"
    sleep 2
    "${SEAFILE_PATH}/seahub.sh" start || fail "seahub start failed"
    sleep 2
    "${SEAFILE_PATH}/seahub.sh" stop || fail "seahub stop failed"
    sleep 1
    "${SEAFILE_PATH}/seafile.sh" stop || fail "seafile stop failed"
    sleep 2

    # Restore original check_init_admin.py
    mv -- "$init_admin_bak" "$init_admin" || exit 1
}


# https://manual.seafile.com/extension/webdav/
setup_webdav() {
    local f='./conf/seafdav.conf'

    check_is_file "$f"
    crudini --merge "$f" <<'EOF'
[WEBDAV]
enabled = true
port = 8080
host = 0.0.0.0
fastcgi = false
share_name = /seafdav
show_repo_id = true
EOF
}


# https://manual.seafile.com/config/seahub_settings_py/
# additional conf from:
#   https://manual.seafile.com/deploy/https_with_nginx/#modifying-seahub_settingspy
setup_seahub_settings_for_nginx() {
    local f='./conf/seahub_settings.py'

    check_is_file "$f"

    cat >> "$f" <<EOF
ENABLE_SIGNUP = False
ACTIVATE_AFTER_REGISTRATION = False
SERVICE_URL = '$SEAFILE_URL'
CSRF_TRUSTED_ORIGINS = [SERVICE_URL]
FILE_SERVER_ROOT = '${SEAFILE_URL}/seafhttp'
ENABLE_THUMBNAIL = True
LOGIN_ATTEMPT_LIMIT = 2
ENABLE_WIKI = True
CACHES = {
    'default': {
        'BACKEND': 'django_pylibmc.memcached.PyLibMCCache',
        'LOCATION': 'memcached:11211',
    },
    'locmem': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}
COMPRESS_CACHE_BACKEND = 'locmem'

# Enable or disable thumbnail for video. ffmpeg and moviepy should be installed first.
# For details, please refer to https://manual.seafile.com/deploy/video_thumbnails/
# NOTE: since version 6.1
# TODO: video thumb deprecated since 7.1?
#ENABLE_VIDEO_THUMBNAIL = True

# Use the frame at 5 second as thumbnail
# TODO: video thumb deprecated since 7.1?
#THUMBNAIL_VIDEO_FRAME_TIME = 5

# Absolute filesystem path to the directory that will hold thumbnail files.
#THUMBNAIL_ROOT = '/seafile/seahub-data/thumbnail'

EOF

if [[ -n "$ONLY_OFFICE_DOMAIN" ]]; then
    cat >> "$f" <<EOF
### enable ONLYOFFICE (for online doc viewing/editing):
# Enable Only Office
ENABLE_ONLYOFFICE = True
VERIFY_ONLYOFFICE_CERTIFICATE = True
ONLYOFFICE_APIJS_URL = '${ONLY_OFFICE_DOMAIN}/web-apps/apps/api/documents/api.js'
ONLYOFFICE_FILE_EXTENSION = ('doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'odt', 'fodt', 'odp', 'fodp', 'ods', 'fods')
ONLYOFFICE_EDIT_FILE_EXTENSION = ('docx', 'pptx', 'xlsx')
ONLYOFFICE_JWT_SECRET = '${ONLYOFFICE_JWT_SECRET}'

EOF
fi
}



# TODO: should we source download-seafile instead of calling it? otherwise common imports & SEAFILE_PATH definition would left undefined!
#source /common.sh || { echo -e "    ERROR: failed to import /common.sh"; exit 1; }  # provided by download-seafile
download-seafile || exit 1
setup_seafile
setup_webdav
setup_seahub_settings_for_nginx

exit 0
