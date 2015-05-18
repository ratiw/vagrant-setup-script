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

echo ">>> Installing Base Packages"

if [[ -z $1 ]]; then
    github_url="https://raw.githubusercontent.com/fideloper/Vaprobash/master"
else
    github_url="$1"
fi

echo "-- Installing base packages --"
sudo apt-get install -qq vim wget curl unzip git-core ack-grep software-properties-common build-essential python-software-properties
# Git config and set Owner
curl --silent -L $github_url/helpers/gitconfig > /home/vagrant/.gitconfig
sudo chown vagrant:vagrant /home/vagrant/.gitconfig

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

# Setting up Swap

# Disable case sensitivity
shopt -s nocasematch

if [[ ! -z $2 && ! $2 =~ false && $2 =~ ^[0-9]*$ ]]; then

  echo ">>> Setting up Swap ($2 MB)"

  # Create the Swap file
  fallocate -l $2M /swapfile

  # Set the correct Swap permissions
  chmod 600 /swapfile

  # Setup Swap space
  mkswap /swapfile

  # Enable Swap space
  swapon /swapfile

  # Make the Swap file permanent
  echo "/swapfile   none    swap    sw    0   0" | tee -a /etc/fstab

  # Add some swap settings:
  # vm.swappiness=10: Means that there wont be a Swap file until memory hits 90% useage
  # vm.vfs_cache_pressure=50: read http://rudd-o.com/linux-and-free-software/tales-from-responsivenessland-why-linux-feels-slow-and-how-to-fix-that
  printf "vm.swappiness=10\nvm.vfs_cache_pressure=50" | tee -a /etc/sysctl.conf && sysctl -p

fi

# Enable case sensitivity
shopt -u nocasematch

# Base box optimizations

# exit script if not run as root
if [[ $EUID -ne 0 ]]; then
  cat <<END
you need to run this script as the root user
use :privileged => true in Vagrantfile
END

  exit 0
fi

# optimize apt sources to select best mirror
perl -pi -e 's@^\s*(deb(\-src)?)\s+http://us.archive.*?\s+@\1 mirror://mirrors.ubuntu.com/mirrors.txt @g' /etc/apt/sources.list

# update repositories
apt-get update

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



