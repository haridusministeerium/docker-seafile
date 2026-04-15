# Deprecated

As of seafile v13, binary installations are not supported and official
Docker image is to be used.

---

# Seafile for Docker

[Seafile](http://www.seafile.com/) is a "next-generation open source cloud storage
with advanced features on file syncing, privacy protection and teamwork".

This Dockerfile does not really package Seafile for Docker, but provides an environment
for running it including startup scripts + all dependencies for using MySQL and
memcached.

Note this version provides only with MySQL-backed installation (not SQLite). Both db
and memcache instances are expected to be created before seafile is set up.
Also note this installation of seafile is expected to be ran behind a reverse proxy
over https. An example of nginx config that could be used is included.

## Setup

### MySql/Mariadb

Assumes accessible mysql/maria db is already installed.

Log in to the docker/machine hosting the database and create the user & databases:
(from https://github.com/foxel/seafile-docker/blob/master/scripts/setup.sh)

```
mysql -uroot -p${DB_ROOT_PW} <<'EOF'
DROP DATABASE IF EXISTS `ccnet_db`;
DROP DATABASE IF EXISTS `seafile_db`;
DROP DATABASE IF EXISTS `seahub_db`;
CREATE DATABASE `ccnet_db` CHARACTER SET = 'utf8';
CREATE DATABASE `seafile_db` CHARACTER SET = 'utf8';
CREATE DATABASE `seahub_db` CHARACTER SET = 'utf8';
DROP USER IF EXISTS 'seafile'@'%';
CREATE USER IF NOT EXISTS 'seafile'@'%' IDENTIFIED BY 'seafile_passwd';
GRANT ALL PRIVILEGES ON `ccnet_db`.* TO `seafile`@'%';
GRANT ALL PRIVILEGES ON `seafile_db`.* TO `seafile`@'%';
GRANT ALL PRIVILEGES ON `seahub_db`.* TO `seafile`@'%';
FLUSH PRIVILEGES;
EOF
```

Note you need to link seafile docker to the mariadb/mysql docker by `--link`ing it.

### Seafile

The embedded `setup-seafile` script is executed when running the image for the
first time, which installs & sets up seafile under `/seafile`.
[Reading through the setup manual](https://github.com/haiwen/seafile/wiki/Download-and-setup-seafile-server)
before setting up Seafile is still recommended, since there are more configuration
options that can be used and could be considered.
If you're using this docker on unraid, this means running the `docker run` command
below from command line, not from template.

Run the image in a container, exposing ports as needed and making `/seafile` volume permanent:

* `VER`: actual seafile server ver (eg `6.0.7`), or `latest`
* `SERVER_IP`: domain or IP of the box where seafile is set up; without the protocol

If you want to enable document preview/edit via
[OnlyOffice](https://github.com/ONLYOFFICE/),
then also define env vars
 - `ONLY_OFFICE_DOMAIN`, eg `ONLY_OFFICE_DOMAIN=https://onlyoffice.yourdomain.com` (omit trailing slash)
 - `ONLYOFFICE_JWT_SECRET`, eg `ONLYOFFICE_JWT_SECRET=jwt-secret-configured-in-your-onlyoffice-instance`

For example, you could use following command to install & setup (note the db data must
match the one you used when creating the db tables & users)

    docker run -it --rm \
      -e VER=6.0.7 \
      -e SERVER_NAME=seafile-server \
      -e SERVER_IP=seafile.yourdomain.com \
      -e FILESERVER_PORT=8082 \
      -e SEAHUB_ADMIN_USER=youradminuser \
      -e SEAHUB_ADMIN_PW=yourpassword \
      -e USE_EXISTING_DB=1 \
      -e MYSQL_HOST=db \
      -e MYSQL_PORT=3306 \
      -e MYSQL_USER=seafile \
      -e MYSQL_USER_PASSWD=seafile_passwd \
      -e CCNET_DB=ccnet_db \
      -e SEAFILE_DB=seafile_db \
      -e SEAHUB_DB=seahub_db \
      [-e AUTOSTART=false \]
      -v /path/on/host/to-installation-dir:/seafile \
      --link memcached \
      --link db \
      layr/seafile --skip-runit -- setup-seafile

Note the memcached instance is linked to your seafile container by adding
`--link memcached_container:memcached` to your docker run statement.
(or use [user defined networks](https://docs.docker.com/engine/userguide/networking/work-with-networks/#linking-containers-in-user-defined-networks)
instead, as `--link` option is now deprecated)

### Upgrade

Running following will simply download the required version and unpack it under
`/seafile`; you'll still want to follow upgrade notes afterwards (see below);
note `VER` value constraints/expectations as described above.

    docker run -it --rm \
      -e VER=6.0.7 \
      [-e AUTOSTART=false \]
      -v /path/on/host/to-installation-dir:/seafile \
      layr/seafile --skip-runit -- download-seafile

## Running Seafile

Run the image again, this time you probably want to give it a name for using some
startup scripts.
**The image will autostart the `seafile` and `seahub` processes if the environment
variable `AUTOSTART=true` is set.** A reasonable docker command would be

    docker run -d \
      --name seafile \
      -p 10001:10001 \
      -p 12001:12001 \
      -p 8000:8000 \
      -p 8080:8080 \
      -p 8082:8082 \
      -v /path/on/host/to-installation-dir:/seafile \
      -e AUTOSTART=true \
      --link memcached \
      --link db \
      layr/seafile

For unraid users: this is the command that should to be converted into a Docker template.

## Upgrades and Maintenance

The Seafile binaries are stored in the permanent volume `/seafile`. To update the
base system, just stop and drop the container, update the image using
`docker pull layr/seafile` and run it again. To update Seafile, follow the normal
upgrade process described in the [Seafile upgrade manual](https://manual.seafile.com/latest/upgrade/upgrade/).

#### General upgrade steps:
- stop seafile server
- if using unraid, make sure you set env var `AUTOSTART=false`, OR execute with
  command `--skip-runit`
- upgrade the image version if needed (if deps have changed that is)
- start server (w/ AUTOSTART=false or `--skip-runit`!)
- open shell into container
- download new seafile version using included `download-seafile` script as shown above, eg (while in container shell):
  - `$ export VER=latest`  (or eg VER=7.1.5)
    - alternatively pass version to the script, e.g. `download-seafile 7.1.5`
  - `$ download-seafile [version]`
  - `$ cd /seafile/seafile-server-7.1.5`  (assuming you just downloaded v 7.1.5)
- run migration scripts/update configs as per [upgrade manual](https://manual.seafile.com/latest/upgrade/upgrade/)
  - remember, even patch version upgrade will require migration (likely via
    `minor-upgrade.sh` script)!
- set `AUTOSTART=true` again
- restart container
- once all confirmed good - remove the old seafile installation dir from /seafile

## Backup & Recovery

See [documentation](https://manual.seafile.com/latest/administration/backup_recovery/)

## Troubleshooting

- if `seahub` fails to start and nothing obvious is in the logs, then
    - [modify conf/gunicorn.conf](https://forum.seafile.com/t/seahub-failed-to-start-error/18161/2)
      from `daemon = True` to `daemon = False`, then run `/etc/service/seahub/run`
      manually, you should see error in terminal
- if you get errors similar to
  > [WARNING] Failed to execute sql: (1054, "Unknown column 'domain' in 'org_saml_config'")
  during migration, then see [this forum post](https://forum.seafile.com/t/upgrade-from-10-0-1-to-11-0-5-issues-with-mysql/19392)

      
## GC

[GC](https://manual.seafile.com/latest/administration/seafile_gc) needs to be ran periodically
to fee up space; tl;dr:

- **shut down server!**
    - ie make sure you set env var `AUTOSTART=false`, OR execute with
        command `--skip-runit`
- `seaf-gc.sh --dry-run [repo-id1] [repo-id2] ...`
    - note the optional `--dry-run` opt
    - note this only removes deleted libraries
    - add `-r` opt to check libs for outdated historic blocks:
        - `seaf-gc.sh -r`
    - add `--rm-fs` opt you can also remove garbage fs objects
        - `seaf-gc.sh --rm-fs`
- tl;dr run these 4 commands:
    - `seaf-gc.sh --dry-run`
    - `seaf-gc.sh`
    - `seaf-gc.sh -r`
    - `seaf-gc.sh --rm-fs`
- clean up also files in `/seafile/seafile-data/webdavtmp/`
    - see line in our own run.sh or https://forum.seafile.com/t/cleanup-webdavtmp-files/15647/3

Note:
> Libraries deleted by the users are not immediately removed from the system. Instead,
  they're moved into a "trash" in the system admin page. Before they're cleared from
  the trash, their blocks won't be garbage collected.
    - meaning you'd have to log in w/ admin user and nuke the deleted library
      from trash for GC to pick it up


