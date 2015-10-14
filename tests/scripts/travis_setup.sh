#!/bin/bash

# Database creation and priveleges.
mysql -u root -e 'create database drupal;'
mysql -u root -e "create database fedora;"
mysql -u root -e "GRANT ALL PRIVILEGES ON fedora.* To 'fedora'@'localhost' IDENTIFIED BY 'fedora';"
mysql -u root -e "GRANT ALL PRIVILEGES ON drupal.* To 'drupal'@'localhost' IDENTIFIED BY 'drupal';"

# Java 8, if needed.
if [ $FEDORA_VERSION = "3.8.1" ]; then
  sudo apt-get install -y oracle-java8-installer oracle-java8-set-default
  sudo update-java-alternatives -s java-8-oracle
  export JAVA_HOME=/usr/lib/jvm/java-8-oracle
fi

# Islandora Tomcat installation.
cd $HOME
git clone git://github.com/Islandora/tuque.git
wget http://alpha.library.yorku.ca/islandora_tomcat.$FEDORA_VERSION.tar.gz
tar xf islandora_tomcat.$FEDORA_VERSION.tar.gz
cd islandora_tomcat
export CATALINA_HOME='.'
export JAVA_OPTS="-Xms1024m -Xmx1024m -XX:MaxPermSize=512m -XX:+CMSClassUnloadingEnabled -Djavax.net.ssl.trustStore=$CATALINA_HOME/fedora/server/truststore -Djavax.net.ssl.trustStorePassword=tomcat"
./bin/startup.sh

# Drush installation.
cd $HOME
pear channel-discover pear.drush.org
pear upgrade --force Console_Getopt
pear upgrade --force pear
pear channel-discover pear.drush.org
wget http://alpha.library.yorku.ca/drush-6.3.tar.gz
tar xf drush-6.3.tar.gz
sudo mv drush-6.3 /opt/
sudo ln -s /opt/drush-6.3/drush /usr/bin/drush

# PHPCS installation.
wget http://alpha.library.yorku.ca/PHP_CodeSniffer-1.5.6.tgz
pear install PHP_CodeSniffer-1.5.6.tgz

# PHP Copy-Paste Detection installation.
wget http://alpha.library.yorku.ca/phpcpd.phar
sudo mv phpcpd.phar /usr/local/bin/phpcpd
sudo chmod +x /usr/local/bin/phpcpd

# Drupal installation.
phpenv rehash
drush dl --yes drupal
cd drupal-*
drush si minimal --db-url=mysql://drupal:drupal@localhost/drupal --yes
drush runserver --php-cgi=$HOME/.phpenv/shims/php-cgi localhost:8081 &>/tmp/drush_webserver.log &
# Add Islandora to the list of symlinked modules.
ln -s $ISLANDORA_DIR sites/all/modules/islandora
# Use our custom Travis test config for Simpletest.
mv sites/all/modules/islandora/tests/travis.test_config.ini sites/all/modules/islandora/tests/test_config.ini
# Grab Tuque.
mkdir sites/all/libraries
ln -s $HOME/tuque sites/all/libraries/tuque
# Grab and enable other modules.
drush dl --yes coder-7.x-2.4
drush dl --yes potx-7.x-1.0
drush en --yes coder_review
drush en --yes simpletest
drush en --yes potx
drush en --user=1 --yes islandora
drush cc all
# The shebang in this file is a bogeyman that is haunting the web test cases.
rm /home/travis/.phpenv/rbenv.d/exec/hhvm-switcher.bash
sleep 20
