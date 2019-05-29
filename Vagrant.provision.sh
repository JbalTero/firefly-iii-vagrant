#!/usr/bin/env bash

failed() {
  echo
  echo
  echo "Installation has failed."
  echo "Text above or the log file for this installation stage might be useful to understanding what exactly failed."
  echo
  exit 3
}


MYSQL_DB_NAME=${1}
MYSQL_PASSWORD=${2}
SERVER_NAME=${3}
SERVER_ADMIN=${4}
SITE_OWNER_EMAIL=${5}
TIMEZONE=${6}

doc_root_path="/var/www/$SERVER_NAME"
provision_log_dir="/var/log/vagrant-provision"

sudo mkdir -p $provision_log_dir

echo -e "\n--- 01 - Update packages ---\n"
sudo apt-get -y update >> $provision_log_dir/01-update-packages.log 2>&1

echo -e "\n--- 02 - Install Apache ---\n"
sudo apt-get -y install apache2 >> $provision_log_dir/02-install-apache.log 2>&1 || failed
sudo a2enmod rewrite || failed
sudo a2dissite 000-default.conf || failed

sudo mkdir -p /var/apache2/$SERVER_NAME || failed

# Setup webserver
if [ ! -f "/etc/apache2/sites-available/$SERVER_NAME.conf" ]; then
    echo '<VirtualHost *:80>
            ServerName '$SERVER_NAME'

            ServerAdmin '$SERVER_ADMIN'
            DocumentRoot "'$doc_root_path'/public"

            ErrorLog ${APACHE_LOG_DIR}/error.log
            CustomLog ${APACHE_LOG_DIR}/access.log combined

            <Directory "'$doc_root_path'">
              AllowOverride All
              Require all granted
            </Directory>
    </VirtualHost>
    ' >> /etc/apache2/sites-available/$SERVER_NAME.conf
fi

sudo a2ensite $SERVER_NAME.conf || failed
sudo service apache2 restart || failed

echo -e "\n--- 03 - Install PHP 7.2 ---\n"
sudo apt-get -y install curl apt-transport-https ca-certificates >> $provision_log_dir/03-install-php7.2.log 2>&1 || failed
wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
sudo echo "deb https://packages.sury.org/php/ jessie main" | tee /etc/apt/sources.list.d/php.list
sudo apt-get -y update >> $provision_log_dir/03-install-php7.2.log 2>&1
sudo apt-get -y install \
    php7.2 \
    php7.2-bcmath \
    php7.2-intl \
    php7.2-curl \
    php7.2-zip \
    php7.2-gd \
    php7.2-xml \
    php7.2-mbstring \
    php7.2-ldap \
    php7.2-common \
    php7.2-mysql \
    php7.2-cli \
    php7.2-redis \
    php7.2-xdebug \
    php7.2-imap \
    >> $provision_log_dir/03-install-php7.2.log 2>&1 || failed

sudo sed -i -e 's/upload_max_filesize = 2M/upload_max_filesize = 128M/g' /etc/php/7.2/apache2/php.ini
sudo sed -i -e 's/post_max_size = 8M/post_max_size = 128M/g' /etc/php/7.2/apache2/php.ini
sudo sed -i -e 's/max_execution_time = 30/max_execution_time = 120/g' /etc/php/7.2/apache2/php.ini

# To fix phpmyadmin error: Your PHP parameter session.gc_maxlifetime is lower that cookie validity configured in phpMyAdmin, because of this, your login will expire sooner than configured in phpMyAdmin.
sudo sed -i -e 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 10800/g' /etc/php/7.2/apache2/php.ini

sudo sed -i -e 's/upload_max_filesize = 2M/upload_max_filesize = 128M/g' /etc/php/7.2/cli/php.ini
sudo sed -i -e 's/post_max_size = 8M/post_max_size = 128M/g' /etc/php/7.2/cli/php.ini
sudo sed -i -e 's/max_execution_time = 30/max_execution_time = 120/g' /etc/php/7.2/cli/php.ini

# To fix phpmyadmin error: Your PHP parameter session.gc_maxlifetime is lower that cookie validity configured in phpMyAdmin, because of this, your login will expire sooner than configured in phpMyAdmin.
sudo sed -i -e 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 10800/g' /etc/php/7.2/cli/php.ini

# Configure XDebug
read -r -d '' xdebugconf << EOM
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.idekey=VAGRANT
EOM
echo "$xdebugconf" | sudo tee -a /etc/php/7.2/mods-available/xdebug.ini || failed

# apache umask
echo "umask 002" | sudo tee -a /etc/apache2/envvars  || failed
sudo service apache2 restart || failed

echo -e "\n--- 04 - Install MariaDB ---\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server >> $provision_log_dir/04-install-mariadb.log 2>&1 || failed
sudo mysqladmin -u root password $MYSQL_PASSWORD || failed
sudo mysql -u root -p$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;" || failed
sudo sed -i -e 's/bind-address/#bind-address/g' /etc/mysql/my.cnf || failed
sudo service mysql restart || failed
sudo service mysql status || failed

echo -e "\n--- 05 - Install phpMyAdmin ---\n"
export DEBIAN_FRONTEND=noninteractive
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get -y install phpmyadmin >> $provision_log_dir/05-install-phpmyadmin.log 2>&1 || failed
echo "<?php \$cfg['LoginCookieValidity'] = 10800;" | sudo tee -a /etc/phpmyadmin/conf.d/custom.php

echo -e "\n--- 06 - Install Composer ---\n"
curl -s https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

#echo -e "\n--- 07 - Install Redis server ---\n"
#sudo apt-get -y install build-essential >> $provision_log_dir/07-install-redis-server.log 2>&1 || failed
#cd /tmp
#wget -q http://download.redis.io/redis-stable.tar.gz || failed
#tar xvzf redis-stable.tar.gz >> $provision_log_dir/07-install-redis-server.log 2>&1 || failed
#cd redis-stable
#sudo make >> $provision_log_dir/07-install-redis-server.log 2>&1 || failed
#sudo make install >> $provision_log_dir/07-install-redis-server.log 2>&1 || failed
#sudo REDIS_PORT=6379 \
#	REDIS_CONFIG_FILE=/etc/redis/6379.conf \
#	REDIS_LOG_FILE=/var/log/redis_6379.log \
#	REDIS_DATA_DIR=/var/lib/redis/6379 \
#	REDIS_EXECUTABLE=`command -v redis-server` ./utils/install_server.sh || failed
#sudo /etc/init.d/redis_6379 status

echo -e "\n--- 08 - Install Git ---\n"
sudo apt-get -y install git-core >> $provision_log_dir/08-install-git.log 2>&1 || failed
git config --global user.name "Jim Well John Balatero"
git config --global user.email "jbalero@gmail.com"

echo -e "\n--- 09 - Install firefly-iii ---\n"
sudo mysql -u root -p$MYSQL_PASSWORD -e 'CREATE DATABASE IF NOT EXISTS `'$MYSQL_DB_NAME'`;' || failed
sudo git clone --depth 1 https://github.com/firefly-iii/firefly-iii.git $doc_root_path || failed
sudo chown -R www-data:www-data $doc_root_path || failed
sudo chmod -R 775 $doc_root_path/storage || failed
cp $doc_root_path/.env.example $doc_root_path/.env || failed
sudo chown www-data:www-data $doc_root_path/.env
sed -i -e 's/APP_ENV=local/APP_ENV=production/g' $doc_root_path/.env
sed -i -e 's/SITE_OWNER=mail@example\.com/SITE_OWNER='$SITE_OWNER_EMAIL'/g' $doc_root_path/.env
sed -i -e 's/TZ=Europe\/Amsterdam/TZ='$TIMEZONE'/g' $doc_root_path/.env
sed -i -e 's/APP_URL=http:\/\/localhost/APP_URL=http:\/\/'$SERVER_NAME'/g' $doc_root_path/.env
sed -i -e 's/DB_DATABASE=homestead/DB_DATABASE='$MYSQL_DB_NAME'/g' $doc_root_path/.env
sed -i -e 's/DB_USERNAME=homestead/DB_USERNAME=root/g' $doc_root_path/.env
sed -i -e 's/DB_PASSWORD=secret/DB_PASSWORD='$MYSQL_PASSWORD'/g' $doc_root_path/.env

sudo apt-get -y install unzip >> $provision_log_dir/08-install-git.log 2>&1 || failed
composer install --no-scripts --no-dev -d $doc_root_path >> $provision_log_dir/08-install-git.log 2>&1 || failed
sudo chown -R www-data:www-data $doc_root_path/vendor || failed

php artisan migrate:refresh --seed --force || failed
php artisan firefly:upgrade-database || failed
php artisan firefly:verify || failed
php artisan passport:install || failed
php artisan key:generate || failed

echo -e "\n--- 13 - Install cronjobs ---\n"
read -r -d '' cronjobs << EOM
0 0 * * * php $doc_root_path/artisan firefly:cron >/dev/null 2>&1
EOM
echo "$cronjobs" >> /tmp/cronjobs
crontab /tmp/cronjobs || failed

sudo rm -rf /tmp/*

#use eth0 if the network is public, eth1 if the network is private
ipaddress=`/sbin/ifconfig eth1 | grep 'inet addr' | awk -F' ' '{print $2}' | awk -F':' '{print $2}'`
echo -e "\n--- Everything is done ---"
echo -e "--- Cronjobs are running ---"
echo -e "--- Document root is $doc_root_path ---"