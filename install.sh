#!/usr/bin/env bash

echo "-- Change Ubuntu's source update server to mirror1.ku.ac.th --"

sudo sed -i 's/us.archive.ubuntu.com/mirror1.ku.ac.th/g' /etc/apt/sources.list
sudo sed -i 's/security.ubuntu.com/mirror1.ku.ac.th/g' /etc/apt/sources.list

echo "-- Now updating the packages list --"
sudo apt-get update

echo "-- MySQL stuffs --"
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

echo "-- Installing base packages --"
sudo apt-get install -y vim curl build-essential python-software-properties

echo "-- Updating the packages list again --"
sudo apt-get update

echo "-- Adding PHP repository --"
sudo add-apt-repository -y ppa:ondrej/php5

echo "-- Updating the packages list, ah..gain --"
sudo apt-get update

echo "-- Installing PHP-specific packages --"
sudo apt-get install -y php5 apache2 libapache2-mod-php5 php5-mysql php5-pgsql php5-sqlite php5-curl php5-gd php5-mcrypt mysql-server-5.5 git-core

echo "-- Installing and configuring Xdebut --"
sudo apt-get install -y php5-xdebug

echo "-- Installing Thai language support --"
sudo apt-get install -y language-pack-th ttf-thai-tlwg

cat << EOF | sudo tee -a /etc/php5/mods-available/xdebug.ini
xdebug.scream=1
xdebug.cli_color=1
xdebug.show_local_vars=1
EOF

echo "-- Enabling mod-rewrite --"
sudo a2enmod rewrite

echo "-- Setting document root --"
sudo rm -rf /var/www
sudo ln -fs /vagrant/laravel/public /var/www

echo "--- What developer codes without errors turned on? Not you, master. ---"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini

sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

echo "-- Restarting Apache --"
sudo service apache2 restart

echo "-- Installing Memcached --"
sudo apt-get install -y memcached php5-memcached
sudo service apache2 restart

echo "-- Installing Composer --"
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer


echo ""
echo "All done."

echo ""
echo "To use Tinker command in Laravel 4. Comment out line 'disable_functions' in /etc/php5/cli/php.ini"


