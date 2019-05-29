# firefly-iii LAMPP stack provisioner

NOTE: This is for development purposes only. Not for production.

# Preparation
* Install [Vagrant](https://www.vagrantup.com/downloads.html)
* Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* `cd` to this repo's directory
* copy `.env.example` for to `.env`
* Update `.env` according to what you want.
* Open cli with admin privilege and run: `vagrant up`
    * Admin priv is required for hostmanager to update your host file.
* Once everything is successful and done, access the site using the `HOST_NAME` you set in .env
* run `vagrant rsync-auto` to auto sync files while developing 

# The vagrant provisioner will install:
* Apache
    * Will also install virtual host file for firefly-iii
* PHP 7.2, with the following extensions
    * php7.2-bcmath
    * php7.2-intl
    * php7.2-curl
    * php7.2-zip
    * php7.2-gd
    * php7.2-xml
    * php7.2-mbstring
    * php7.2-ldap
    * php7.2-common
    * php7.2-mysql
    * php7.2-cli
    * php7.2-redis
    * php7.2-xdebug
    * php7.2-imap
* php.ini configuration:
    * upload_max_filesize = 128M
    * post_max_size = 128M
    * max_execution_time = 120
    * session.gc_maxlifetime = 10800
* It will configure xdebug for you so you can use it for debugging
* MariaDb - the root password is set in .env file
* phpMyAdmin
    * You can access it via `HOSTNAME`/phpmyadmin
        * Use username: root, password: `MYSQL_DB_PASSWORD` set in `.env`
* Composer
* Git
* firefly-iii
    * with cronjobs 