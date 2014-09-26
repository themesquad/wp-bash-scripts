#!/bin/bash

# Status Messages
SUCCESS_MSG="\e[1;32mSuccess:\e[0m"
ERROR_MSG="\e[1;31mError:\e[0m"

# Detect paths
CAT=$(which cat)
AWK=$(which awk)
GREP=$(which grep)

# Get parameters.
PROJECT_NAME="$1"
PWD="$2"
DBUSER="$3"
DBPASS="$4"
ADMIN_EMAIL="$5"
ADMIN_USER="$6"
ADMIN_PASSWORD="$7"
PLUGINS_LIST="$8"

# EDIT DEFAULT VALUES HERE
: ${PWD:=$(pwd)"/"}
: ${PROJECT_NAME:="wptest"}
: ${WP_DIR:=${PWD}${PROJECT_NAME}}
: ${DBNAME:="$PROJECT_NAME"}
: ${DBUSER:="dbuser"}
: ${DBPASS:="dbpass"}
: ${WP_URL:="$PROJECT_NAME.dev"}
: ${ADMIN_EMAIL:="admin@email.com"}
: ${ADMIN_USER:="admin"}
: ${ADMIN_PASSWORD:="password"}
: ${PLUGINS_LIST:="none"}

clear
echo "============================================"
echo "            WordPress Installer             "
echo "============================================"
echo ""

#Create directory.
if [[ -d $WP_DIR ]]; then
  echo -e "$ERROR_MSG The directory $WP_DIR already exists."
  echo "Aborting the installation."
  exit
else
  mkdir $WP_DIR
  echo -e "$SUCCESS_MSG Project directory created."
fi

echo "cd $WP_DIR"
cd $WP_DIR

# Download WordPress.
wp core download

# Generate the wp-config.php file.
wp core config --dbname=$DBNAME --dbuser=$DBUSER --dbpass=$DBPASS --extra-php <<PHP
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
//define('SCRIPT_DEBUG', true);
PHP

# Create database.
wp db create

# Install WordPress.
wp core install --url=$WP_URL --title="WordPress Site" --admin_user=$ADMIN_USER --admin_password=$ADMIN_PASSWORD  --admin_email=$ADMIN_EMAIL

# Change permalinks to Post Name.
wp rewrite structure '/%postname%/'

# Turn off the Search Engine Visibility.
wp option update blog_public "0"

# Delete twentytwelve and twentythirteen themes.
wp theme delete twentytwelve
wp theme delete twentythirteen

# Delete Hello Dolly and Akismet plugins.
wp plugin uninstall hello akismet

# Install plugins.
if [[ $PLUGINS_LIST != "none" && -f $PLUGINS_LIST ]]; then
  PLUGINS=$($CAT $PLUGINS_LIST | $GREP -v ^# )

  for p in $PLUGINS
  do
    echo "Installing $p plugin..."
    wp plugin install --activate $p
  done
fi

# Import Theme Unit Test data.
echo -n "Import Theme Unit Test data? [y/n]: "
read IMPORT_TEST_DATA

if [[ $IMPORT_TEST_DATA == "y" ]]; then
  # Install WordPress Importer plugin.
  wp plugin install wordpress-importer --activate

  # Gets and import the Theme Unit Test data.
  curl -O https://wpcom-themes.svn.automattic.com/demo/theme-unit-test-data.xml
  wp import theme-unit-test-data.xml --authors=create
  rm theme-unit-test-data.xml
  wp plugin uninstall wordpress-importer
fi

# Create virtualhost.
echo -n "Create Apache2 Virtualhost? [y/n]: "
read CREATE_VH

if [[ $CREATE_VH == "y" ]]; then
  (sudo sh -c "echo '\n<VirtualHost *:80>
    ServerName $WP_URL
    ServerAlias $WP_URL
    DocumentRoot "$WP_DIR"
    DirectoryIndex index.php
    <Directory "$WP_DIR">
      AllowOverride All
      Options FollowSymLinks
      Order deny,allow
      Allow from All     
    </Directory>
  </VirtualHost>
  ' > /etc/apache2/sites-available/$PROJECT_NAME.conf")

  (sudo sh -c "a2ensite $PROJECT_NAME")

  (sudo sh -c "service apache2 restart")

  (sudo sh -c "echo '\n127.0.0.1 $WP_URL' >> /etc/hosts" )

  echo -e "$SUCCESS_MSG Virtualhost $WP_URL created."
fi

echo -e "\nBlog installed in http://$WP_URL\n"

echo ""
echo "============================================"
echo "          Installation Completed            "
echo "============================================"