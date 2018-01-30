#!/usr/bin/env bash

function isServiceAvailable() {
    all_services="$(service --status-all 2> >(log))"
    if [[ ${all_services} =~ ${1} ]]; then
        echo 1
    else
        echo 0
    fi
}

use_php7=$4
vagrant_dir="/vagrant"

source "${vagrant_dir}/scripts/output_functions.sh"

status "Upgrading environment (recurring)"
incrementNestingLevel

status "Deleting obsolete repository"
sudo rm -f /etc/apt/sources.list.d/ondrej-php-7_0-trusty.list

status "Upgrading vagrant box paliarush/magento2.ubuntu v1.1.0"
if [[ ${use_php7} -eq 1 ]]; then
    if /usr/bin/php -v | grep -q '7.0.5' ; then
        status "Upgrading PHP 7.0.5"
        apt-get update 2> >(logError) > >(log)
        a2dismod php7.0 2> >(logError) > >(log)
        rm -rf /etc/php/7.0/apache2
        export DEBIAN_FRONTEND=noninteractive
        apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install php7.1 php7.1-mcrypt php7.1-curl php7.1-cli php7.1-mysql php7.1-gd php7.1-intl php7.1-xsl php7.1-bcmath php7.1-mbstring php7.1-soap php7.1-zip libapache2-mod-php7.1 2> >(logError) > >(log)
        a2enmod php7.1 2> >(logError) > >(log)
        update-alternatives --set php /usr/bin/php7.1

        status "Installing XDebug"
        cd /usr/lib
        rm -rf xdebug
        git clone git://github.com/xdebug/xdebug.git 2> >(logError) > >(log)
        cd xdebug
        phpize 2> >(logError) > >(log)
        ./configure --enable-xdebug 2> >(logError) > >(log)
        make 2> >(logError) > >(log)
        make install 2> >(logError) > >(log)

        rm -rf /etc/php/7.1/apache2
        ln -s /etc/php/7.1/cli /etc/php/7.1/apache2

        status "Restarting Apache"
        service apache2 restart 2> >(logError) > >(log)
    fi
fi

is_varnish_installed="$(isServiceAvailable varnish)"
if [[ ${is_varnish_installed} -eq 0 ]]; then
    status "Installing Varnish"
    apt-get update 2> >(logError) > >(log)
    apt-get install -y varnish 2> >(logError) > >(log)
fi

if varnishd -V 2>&1 | grep -q '3.0.5' ; then
    status "Upgrading Varnish to v4.1"
    export DEBIAN_FRONTEND=noninteractive
    apt-get remove varnish -y 2> >(logError) > >(log)
    apt-get remove --auto-remove varnish -y 2> >(logError) > >(log)
    apt-get purge varnish -y 2> >(logError) > >(log)
    apt-get purge --auto-remove varnish -y 2> >(logError) > >(log)

    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish41/script.deb.sh | bash 2> >(logError) > >(log)
    apt-get install varnish -y  2> >(logError) > >(log)

    rm -f "${vagrant_dir}/etc/magento2_default_varnish.vcl"
    rm -f "/etc/varnish/default.vcl"
fi

is_redis_installed="$(isServiceAvailable redis)"
if [[ ${is_redis_installed} -eq 0 ]]; then
    status "Installing Redis"
    apt-get update 2> >(logError) > >(log)
    apt-get install tcl8.5 2> >(logError) > >(log)

    wget http://download.redis.io/redis-stable.tar.gz 2> >(log) > >(log)
    tar xvzf redis-stable.tar.gz 2> >(log) > >(log)
    cd redis-stable
    make install 2> >(logError) > >(log)
    echo -n | sudo utils/install_server.sh 2> >(logError) > >(log)
fi

status "Fixing potential issue with MySQL being down after VM power off"
service mysql restart 2> >(logError) > >(log)

decrementNestingLevel
