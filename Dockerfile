FROM phusion/baseimage:noble
#########################
# see https://github.com/haiwen/seafile-docker/blob/master/image/seafile_12.0/Dockerfile for 
# official Dockerfile image (note it still contains nginx as of writing!);
# for additional clarity, also refer to the installation script @ https://github.com/haiwen/seafile-server-installer/blob/master/seafile-7.1_ubuntu
#
# NOTE:
# - we install python3-dev build-essential ourselves as otherwise pip-installed
#   packages fail to install
# - we remove the python3-jwt system package, as otherwise pyjwt pip pkg fails to install
#########################

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

## Give children processes x sec timeout on exit: (note this is phusion-specific)
#ENV KILL_PROCESS_TIMEOUT=30
## Give all other processes (such as those which have been forked) x sec timeout on exit:
#ENV KILL_ALL_PROCESSES_TIMEOUT=30

# Seafile dependencies and system configuration
RUN apt-get -y update --fix-missing && \
    apt-get -y upgrade && \
    apt-get -y remove --purge python3-jwt && \
    apt-get install --no-install-recommends -y \
        vim htop net-tools psmisc wget curl git unzip \
        tzdata \
        libmysqlclient-dev \
        libmemcached11 libmemcached-dev \
        fuse poppler-utils \
        ldap-utils libldap2-dev ca-certificates dnsutils pkg-config \
        netcat-traditional \
        crudini \
        unattended-upgrades \
        python3 python3-pip python3-setuptools python3-ldap3 \
        python3-dev build-essential && \

    rm /usr/lib/python3.12/EXTERNALLY-MANAGED && \
    rm -f /usr/bin/python && ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install --no-cache-dir --ignore-installed -U setuptools cryptography && \
    rm -rf /usr/lib/python3/dist-packages/setuptools* && rm -rf /usr/lib/python3/dist-packages/cryptography* && \

    pip3 install --no-cache-dir --timeout=3600 \
        click termcolor colorlog pytz \
        sqlalchemy==2.0.* gevent==24.2.* pymysql==1.1.* jinja2 markupsafe==2.0.1 django-pylibmc pylibmc psd-tools lxml \
        django==4.2.* cffi==1.17.0 future==1.0.* mysqlclient==2.2.* captcha==0.6.* django_simple_captcha==0.6.* \
        pyjwt==2.9.* djangosaml2==1.9.* pysaml2==7.3.* pycryptodome==3.20.* python-ldap==3.4.* pillow==10.4.* pillow-heif==0.18.* && \

    ulimit -n 30000 && \
    update-locale LANG=C.UTF-8 && \
# prep dirs for seafile services' daemons:
    mkdir /etc/service/seafile /etc/service/seahub && \
# Clean up for smaller image:
    apt-get remove -y --purge --autoremove \
        python3-pip \
        python3-dev \
        build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*  /root/.cache/pip

# note lxml is installed as otherwise seafile-installdir/logs/seafdav.log had this warning:
#          WARNING :  Could not import lxml: using xml instead (up to 10% slower). Consider `pip install lxml`(see https://pypi.python.org/pypi/lxml).


# TODO: do we want to download in dockerfile, and house the binary within container (by foxel)?:
#ENV SEAFILE_VERSION 7.0.5
#ENV SEAFILE_PATH "/opt/seafile/seafile-server-$SEAFILE_VERSION"
#
#RUN \
#    mkdir -p /seafile "${SEAFILE_PATH}" && \
#    wget --progress=dot:mega --no-check-certificate -O /tmp/seafile-server.tar.gz \
#        "https://download.seadrive.org/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz" && \
#    tar -xzf /tmp/seafile-server.tar.gz --strip-components=1 -C "${SEAFILE_PATH}" && \
#    sed -ie '/^daemon/d' "${SEAFILE_PATH}/runtime/seahub.conf" && \
#    rm /tmp/seafile-server.tar.gz \ &&
#    useradd -r -s /bin/false seafile && \
#    chown seafile:seafile /run/seafile "$SEAFILE_PATH"


# Baseimage init process
ENTRYPOINT ["/sbin/my_init"]

# Seafile daemons
ADD common.sh gc.sh  /
ADD seafile.sh /etc/service/seafile/run
ADD seahub.sh /etc/service/seahub/run

ADD setup-seafile.sh /usr/local/sbin/setup-seafile
ADD download-seafile.sh /usr/local/sbin/download-seafile
ADD apt-auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades


EXPOSE 10001 12001 8000 8080 8082 8083
VOLUME "/seafile"
WORKDIR "/seafile"
