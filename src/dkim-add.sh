#!/usr/bin/env bash

# Inspirations and References
# https://www.digitalocean.com/community/tutorials/how-to-use-gpg-to-encrypt-and-sign-messages
# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy
#
#


DOMAIN="$1"
OPEN_DKIM_CONFIG=/etc/opendkim.conf
OPEN_DKIM_DIR=/etc/opendkim
DKIM_KEYS_DIR=$OPEN_DKIM_DIR/keys
DKIM_KEY_TABLE=$OPEN_DKIM_DIR/KeyTable
DKIM_TRUSTED_HOSTS_FILE=$OPEN_DKIM_DIR/TrustedHosts
DKIM_SIGNING_TABLE=$OPEN_DKIM_DIR/SigningTable
DKIM_USER="opendkim"
DKIM_SELECTOR="default"

if [ -z $DOMAIN ]; then
  echo "Domain is required"
  echo "usage: dkim-add example.com"
  exit;
fi

if ! [ -d $OPEN_DKIM_DIR ]; then
    mkdir -p $OPEN_DKIM_DIR
    chown -R $DKIM_USER:$DKIM_USER  $OPEN_DKIM_DIR
fi 

DOMAIN_KEY_PATH=$DKIM_KEYS_DIR/$DOMAIN

mkdir -p  $DOMAIN_KEY_PATH

opendkim-genkey -t -s mail -d  $DOMAIN -D $DOMAIN_KEY_PATH

chown -R  $DKIM_USER:$DKIM_USER  $DOMAIN_KEY_PATH


if ! [ -e $DKIM_KEY_TABLE ]; then
  echo "Creating KeyTable File -> $DKIM_KEY_TABLE"
  touch  $DKIM_KEY_TABLE 
  chown $DKIM_USER:$DKIM_USER  $DKIM_KEY_TABLE
fi

#APPEND TO SignTable 
SIGNING_TABLE_ENTRY="*@$DOMAIN $DKIM_SELECTOR._domainkey.$DOMAIN"

#Append entry if it does not exist
echo "Adding $DOMAIN entry to $DKIM_SIGNING_TABLE"
grep -qF -- "$SIGNING_TABLE_ENTRY" "$DKIM_SIGNING_TABLE" || echo "$SIGNING_TABLE_ENTRY" >> "$DKIM_SIGNING_TABLE"


KEYTABLE_ENTRY="$DKIM_SELECTOR._domainkey.$DOMAIN $DOMAIN:$DKIM_SELECTOR:$DOMAIN_KEY_PATH/$DKIM_SELECTOR.private"

# Append DB key entry into file
echo "Adding $DOMAIN entry to $DKIM_KEY_TABLE"
grep -qF -- "$KEYTABLE_ENTRY" "$DKIM_KEY_TABLE" || echo "$KEYTABLE_ENTRY" >> "$DKIM_KEY_TABLE"


if ! [ -e $DKIM_TRUSTED_HOSTS_FILE ]; then
 
  echo "Creating File -> $DKIM_TRUSTED_HOSTS_FILE"
  
  touch  $DKIM_TRUSTED_HOSTS_FILE 
  
  chown  $DKIM_USER:$DKIM_USER  $DKIM_TRUSTED_HOSTS_FILE

  #add local hosts 
  echo "127.0.0.1" >>  $DKIM_TRUSTED_HOSTS_FILE
  echo "localhost" >>  $DKIM_TRUSTED_HOSTS_FILE

fi

#add trusted host for our domain
echo "Adding $DOMAIN entry to $DKIM_TRUSTED_HOSTS_FILE"
grep -qF -- "$DOMAIN" "$DKIM_TRUSTED_HOSTS_FILE" || echo "$DOMAIN" >> "$DKIM_TRUSTED_HOSTS_FILE"


#check if the required config is set in opendkim config 
if ! grep -q "KeyTable [ ]* refile:/etc/opendkim/KeyTable" "$OPEN_DKIM_CONFIG"; then
    
    echo "Enabling KeyTable in $OPEN_DKIM_CONFIG" 
    echo " " >>  $OPEN_DKIM_CONFIG
    echo "KeyTable      refile:/etc/opendkim/KeyTable" >> $OPEN_DKIM_CONFIG

fi


if ! grep -q "SigningTable [ ]* refile:/etc/opendkim/SigningTable" "$OPEN_DKIM_CONFIG"; then

   echo "Enabling SigningTable in $OPEN_DKIM_CONFIG" 
   echo " " >>  $OPEN_DKIM_CONFIG
   echo "SigningTable    refile:/etc/opendkim/SigningTable" >> $OPEN_DKIM_CONFIG

fi


if ! grep -q "ExternalIgnoreList [ ]* refile:/etc/opendkim/TrustedHosts" "$OPEN_DKIM_CONFIG"; then

   echo "Enabling ExternalIgnoreList in $OPEN_DKIM_CONFIG" 
   echo " " >>  $OPEN_DKIM_CONFIG
   echo "ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts" >> $OPEN_DKIM_CONFIG

fi


if ! grep -q "InternalHosts [ ]* refile:/etc/opendkim/TrustedHosts" "$OPEN_DKIM_CONFIG"; then

   echo "Enabling InternalHosts in $OPEN_DKIM_CONFIG" 
   echo " " >>  $OPEN_DKIM_CONFIG
   echo "InternalHosts    refile:/etc/opendkim/TrustedHosts" >> $OPEN_DKIM_CONFIG

fi

echo "Restarting opendkim"
service opendkim restart

#KeyTable                refile:/etc/opendkim/KeyTable
#SigningTable            refile:/etc/opendkim/SigningTable
#ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
#InternalHosts           refile:/etc/opendkim/TrustedHosts