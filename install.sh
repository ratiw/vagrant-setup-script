#!/usr/bin/env bash

echo "-- Change Ubuntu's source update server to mirror1.ku.ac.th --"

sudo sed -i 's/us.archive.ubuntu.com/th.archive.ubuntu.com/g' /etc/apt/sources.list

echo "-- Now updating the packages list --"
sudo apt-get update

echo "-- Installing Thai language support --"
sudo apt-get install -y language-pack-th


echo ">>> Installing Base Packages"

if [[ -z $1 ]]; then
    github_url="https://raw.githubusercontent.com/fideloper/Vaprobash/master"
else
    github_url="$1"
fi

echo "-- Installing base packages --"
sudo apt-get install -qq vim wget curl unzip git-core ack-grep software-properties-common build-essential python-software-properties
# Git config and set Owner
curl --silent -L $github_url/helpers/gitconfig > ~/.gitconfig

# Common fixes for git
git config --global http.postBuffer 65536000

# Cache http credentials for one day while pull/push
git config --global credential.helper 'cache --timeout=86400'

echo ">>> Installing *.xip.io self-signed SSL"

SSL_DIR="/etc/ssl/xip.io"
DOMAIN="*.xip.io"
PASSPHRASE="vaprobash"

SUBJ="
C=US
ST=Connecticut
O=Vaprobash
localityName=New Haven
commonName=$DOMAIN
organizationalUnitName=
emailAddress=
"

sudo mkdir -p "$SSL_DIR"

sudo openssl genrsa -out "$SSL_DIR/xip.io.key" 1024
sudo openssl req -new -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -key "$SSL_DIR/xip.io.key" -out "$SSL_DIR/xip.io.csr" -passin pass:$PASSPHRASE
sudo openssl x509 -req -days 365 -in "$SSL_DIR/xip.io.csr" -signkey "$SSL_DIR/xip.io.key" -out "$SSL_DIR/xip.io.crt"

# Base box optimizations

# optimize apt sources to select best mirror
sudo perl -pi -e 's@^\s*(deb(\-src)?)\s+http://us.archive.*?\s+@\1 mirror://mirrors.ubuntu.com/mirrors.txt @g' /etc/apt/sources.list

# update repositories
sudo apt-get update

# PHP

$PHP_VERSION = "5.6"
$PHP_TIMEZONE = "Asia/Bangkok"

echo ">>> Installing PHP $PHP_VERSION"

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C

if [ $PHP_VERSION == "5.5" ]; then
    # Add repo for PHP 5.5
    sudo add-apt-repository -y ppa:ondrej/php5
else
    # Add repo for PHP 5.6
    sudo add-apt-repository -y ppa:ondrej/php5-5.6
fi

sudo apt-key update
sudo apt-get update

# Install PHP
# -qq implies -y --force-yes
sudo apt-get install -qq php5-cli php5-fpm php5-mysql php5-pgsql php5-sqlite php5-curl php5-gd php5-gmp php5-mcrypt php5-memcached php5-imagick php5-intl php5-xdebug

# Set PHP FPM to listen on TCP instead of Socket
sudo sed -i "s/listen =.*/listen = 127.0.0.1:9000/" /etc/php5/fpm/pool.d/www.conf

# Set PHP FPM allowed clients IP address
sudo sed -i "s/;listen.allowed_clients/listen.allowed_clients/" /etc/php5/fpm/pool.d/www.conf

# Set run-as user for PHP5-FPM processes to user/group "vagrant"
# to avoid permission errors from apps writing to files
# sudo sed -i "s/user = www-data/user = vagrant/" /etc/php5/fpm/pool.d/www.conf
# sudo sed -i "s/group = www-data/group = vagrant/" /etc/php5/fpm/pool.d/www.conf

# sudo sed -i "s/listen\.owner.*/listen.owner = vagrant/" /etc/php5/fpm/pool.d/www.conf
# sudo sed -i "s/listen\.group.*/listen.group = vagrant/" /etc/php5/fpm/pool.d/www.conf
sudo sed -i "s/listen\.mode.*/listen.mode = 0666/" /etc/php5/fpm/pool.d/www.conf


# xdebug Config
cat > $(find /etc/php5 -name xdebug.ini) << EOF
zend_extension=$(find /usr/lib/php5 -name xdebug.so)
xdebug.remote_enable = 1
xdebug.remote_connect_back = 1
xdebug.remote_port = 9000
xdebug.scream=0
xdebug.cli_color=1
xdebug.show_local_vars=1

; var_dump display
xdebug.var_display_max_depth = 5
xdebug.var_display_max_children = 256
xdebug.var_display_max_data = 1024
EOF

# PHP Error Reporting Config
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/fpm/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/fpm/php.ini

# PHP Date Timezone
sudo sed -i "s/;date.timezone =.*/date.timezone = ${PHP_TIMEZONE/\//\\/}/" /etc/php5/fpm/php.ini
sudo sed -i "s/;date.timezone =.*/date.timezone = ${PHP_TIMEZONE/\//\\/}/" /etc/php5/cli/php.ini

sudo service php5-fpm restart
    
# Web

# Test if PHP is installed
php -v > /dev/null 2>&1
PHP_IS_INSTALLED=$?

# Test if HHVM is installed
hhvm --version > /dev/null 2>&1
HHVM_IS_INSTALLED=$?

# If HHVM is installed, assume PHP is *not*
[[ $HHVM_IS_INSTALLED -eq 0 ]] && { PHP_IS_INSTALLED=-1; }

echo ">>> Installing Nginx"

# Add repo for latest stable nginx
sudo add-apt-repository -y ppa:nginx/stable

# Update Again
sudo apt-get update

# Install Nginx
# -qq implies -y --force-yes
sudo apt-get install -qq nginx

sudo sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

# Nginx enabling and disabling virtual hosts
curl --silent -L $github_url/helpers/ngxen.sh > ngxen
curl --silent -L $github_url/helpers/ngxdis.sh > ngxdis
curl --silent -L $github_url/helpers/ngxcb.sh > ngxcb
sudo chmod guo+x ngxen ngxdis ngxcb
sudo mv ngxen ngxdis ngxcb /usr/local/bin

sudo service nginx restart

# MySQL

echo ">>> Installing MySQL Server"

# Install MySQL without password prompt
# Set username and password to 'root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

sudo apt-get install -qq mysql-server

# Make MySQL connectable from outside world without SSH tunnel
if [ $3 == "true" ]; then
    # enable remote access
    # setting the mysql bind-address to allow connections from everywhere
    sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

    # adding grant privileges to mysql root user from everywhere
    # thx to http://stackoverflow.com/questions/7528967/how-to-grant-mysql-privileges-in-a-bash-script for this
    MYSQL=`which mysql`

    Q1="GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$1' WITH GRANT OPTION;"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}"

    $MYSQL -uroot -p$1 -e "$SQL"

    service mysql restart
fi

echo ">>> Installing SQLite Server"

# Install MySQL Server
# -qq implies -y --force-yes
sudo apt-get install -qq sqlite

# Memcached

# Install Memcached
# -qq implies -y --force-yes
sudo apt-get install -qq memcached

# Redis

echo ">>> Installing Redis"

# Add repository
sudo apt-add-repository ppa:rwky/redis -y

# Install Redis
# -qq implies -y --force-yes
sudo apt-get install -qq redis-server

# Redis Configuration
sudo mkdir -p /etc/redis/conf.d

# transaction journaling - config is written, only enabled if persistence is requested
cat << EOF | sudo tee /etc/redis/conf.d/journaling.conf
appendonly yes
appendfsync everysec
EOF

# Persistence
if [ ! -z "$1" ]; then
	if [ "$1" == "persistent" ]; then
		echo ">>> Enabling Redis Persistence"

		# add the config to the redis config includes
		if ! cat /etc/redis/redis.conf | grep -q "journaling.conf"; then
			sudo echo "include /etc/redis/conf.d/journaling.conf" >> /etc/redis/redis.conf
		fi

		# schedule background append rewriting
		if ! crontab -l | grep -q "redis-cli bgrewriteaof"; then
			line="*/5 * * * * /usr/bin/redis-cli bgrewriteaof > /dev/null 2>&1"
			(sudo crontab -l; echo "$line" ) | sudo crontab -
		fi
	fi # persistent
fi # arg check

sudo service redis-server restart

# Beanstalkd

echo ">>> Installing Beanstalkd"

# Install Beanstalkd
# -qq implies -y --force-yes
sudo apt-get install -qq beanstalkd

# Set to start on system start
sudo sed -i "s/#START=yes/START=yes/" /etc/default/beanstalkd

# Start Beanstalkd
sudo service beanstalkd start


# Install Composer

echo "-- Installing Composer --"
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "-- Installing Global Composer Packages: PhpUnit --"
composer global require "phpunit/phpunit:4.0.*"

# Install Laravel

#echo "-- Installing Laravel --"


########


# phpMyAdmin

echo "-- Installing phpMyAdmin --"
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean true'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/app-password-confirm password root'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password root'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password root'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect none'
sudo apt-get install -y phpmyadmin


#echo "-- Merge phpMyAdmin config to default Apache2 config --"
#sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.config.original
#sudo bash -c 'cat /etc/phpmyadmin/apache.conf >> /etc/apache2/apache2.conf'

echo ""
echo "All done."



