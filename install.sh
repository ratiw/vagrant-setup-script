#!/usr/bin/env bash

echo "-- Change Ubuntu's source update server to mirror1.ku.ac.th --"

sudo sed -i 's/us.archive.ubuntu.com/mirror1.ku.ac.th/g' /etc/apt/sources.list
sudo sed -i 's/security.ubuntu.com/mirror1.ku.ac.th/g' /etc/apt/sources.list

echo "-- Now updating the packages list --"
sudo apt-get update

echo "-- Installing Thai language support --"
sudo apt-get install -y language-pack-th


echo "-- MySQL stuffs --"
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'

echo "-- Installing base packages --"
sudo apt-get install -y git-core vim curl wget build-essential python-software-properties
# Git config and set Owner
curl -L https://gist.githubusercontent.com/fideloper/3751524/raw/.gitconfig > /home/vagrant/.gitconfig
sudo chown vagrant:vagrant /home/vagrant/.gitconfig


sudo add-apt-repository -y ppa:ondrej/php5
sudo apt-get update

echo "-- Installing SQLite Server --"
sudo apt-get install -y sqlite

echo "-- Installing PHP-specific packages --"
sudo apt-get install -y php5 apache2 libapache2-mod-php5 php5-curl php5-gd php5-mcrypt php5-readline mysql-server-5.5 php5-mysql php5-sqlite git-core php5-xdebug
cat << EOF | sudo tee -a /etc/php5/mods-available/xdebug.ini
xdebug.scream=1
xdebug.cli_color=1
xdebug.show_local_vars=1
EOF

sudo a2enmod rewrite

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini
sudo sed -i "s/disable_functions = .*/disable_functions = /" /etc/php5/cli/php.ini

echo "-- Restarting Apache --"
sudo service apache2 restart

echo "-- Setting document root --"
#sudo rm -rf /var/www
#sudo ln -fs /vagrant/laravel/public /var/www

#sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

echo "-- Installing Memcached --"
sudo apt-get install -y memcached php5-memcached
sudo service apache2 restart

echo "-- Installing Composer --"
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "-- Installing phpMyAdmin --"
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean true'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/app-password-confirm password root'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password root'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password root'
sudo debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect none'
sudo apt-get install -y phpmyadmin


echo "-- Merge phpMyAdmin config to default Apache2 config --"
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.config.original
sudo bash -c 'cat /etc/phpmyadmin/apache.conf >> /etc/apache2/apache2.conf'

echo ""
echo "All done."



