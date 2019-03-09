#!/usr/bin/env bash

POSTFIX_CONFIG_DIR=/etc/postfix
POSTFIX_MAIN_CONFIG=$POSTFIX_CONFIG_DIR/main.cf
POSTFIX_MASTER_CONFIG=$POSTFIX_CONFIG_DIR/master.cf

POSTFIX_VMAIL_BOXES_DB=$POSTFIX_CONFIG_DIR/vmail_mailboxes
POSTFIX_VDOMAIN_DB=$POSTFIX_CONFIG_DIR/vmail_domains
POSTFIX_VMAIL_ALIAS_DB=$POSTFIX_CONFIG_DIR/vmail_alias

POSTFIX_VMAIL_BASE=/var/mail/vhosts

VMAIL_USER=vmail
VMAIL_GROUP=vmail

POSTFIX_VMAIL_UID=5000
POSTFIX_VMAIL_GID=5000


#Dovecot
DOVECOT_CONFIG_DIR=/etc/dovecot


EMAIL_ADDRESS=$(whiptail --inputbox "Enter The domain part of the email?" 20 60  --title "Enter Domain" 3>&1 1>&2 2>&3)

emailExitstatus=$?

if [[ $emailExitstatus != 0 || -z "$EMAIL_ADDRESS" ]]; then
    echo "EMail Address is required"
    exit;
fi

#password
PASSWORD=$(whiptail --passwordbox "Please enter password" 20 60  --title "Password" 3>&1 1>&2 2>&3)
 
passwordExitstatus=$?

if [[ $passwordExitstatus != 0 || -z "$PASSWORD" ]]; then
   whiptail --title "Password" --infobox "Password is required" 8 78
    exit;
fi


CONFIRM_PASSWORD=$(whiptail --passwordbox "Please confirm password" 20 60  --title "Confirm Password" 3>&1 1>&2 2>&3)
 
confirmPasswordExitstatus=$?

if [[ $confirmPasswordExitstatus != 0 || -z "$CONFIRM_PASSWORD" || $PASSWORD != $CONFIRM_PASSWORD ]]; then
    whiptail --title "Confrim Password" --infobox "Passwords do not match" 8 78
    exit;
fi

IFS="@" read EMAIL_USERNAME EMAIL_DOMAIN <<< "$EMAIL_ADDRESS"


#Check if group exists
if [ $(getent group $VMAIL_GROUP) ]; then
  
  echo "Group $VMAIL_GROUP exists already"
  VMAIL_GID="$(getent group cdrom | cut -d: -f3)"

  echo "-->>Using GID $VMAIL_GID" 

else
      echo "Group $VMAIL_GROUP does not exists, adding group"  
      groupadd -g $POSTFIX_VMAIL_GID $VMAIL_GROUP

fi

# Craete vmail user if account doesnt exists
if ! [ $(getent passwd $VMAIL_USER) ] ; then

    echo "User $VMAIL_USER not found, adding one"

    mkdir -p $POSTFIX_VMAIL_BASE

    useradd -r -g $VMAIL_GROUP -u $POSTFIX_VMAIL_UID $VMAIL_USER -d $POSTFIX_VMAIL_BASE -c "virtual mail user"

    chown -R $VMAIL_USER:dovecot $DOVECOT_CONFIG_DIR
    chmod -R o-rwx $DOVECOT_CONFIG_DIR
fi



#add virtual files 
if ! grep -q "relay_domains[ ]*=[ ]*" "$POSTFIX_MAIN_CONFIG"; then

    timestamp=$date +"%T"

   cp $POSTFIX_MAIN_CONFIG "${POSTFIX_MAIN_CONFIG}.backup-$timestamp" 
   
   echo "Enabling relay_domains  in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "relay_domains = *" >> $POSTFIX_MAIN_CONFIG

fi

if ! grep -q "virtual_mailbox_domains" "$POSTFIX_MAIN_CONFIG"; then

   echo "Setting up virtual_mailbox_domains  in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "virtual_mailbox_domains = hash:$POSTFIX_VDOMAIN_DB" >> $POSTFIX_MAIN_CONFIG

fi

if ! grep -q "virtual_mailbox_domains" "$POSTFIX_MAIN_CONFIG"; then

   echo "Setting up virtual_mailbox_domains  in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "virtual_mailbox_domains = hash:$POSTFIX_VDOMAIN_DB" >> $POSTFIX_MAIN_CONFIG

fi


#if ! grep -q "virtual_alias_maps[ ]*=[ ]*hash:$POSTFIX_VMAIL_ALIAS_DB" "$POSTFIX_MAIN_CONFIG"; then
 #  echo "Setting up virtual_alias_map  in $POSTFIX_MAIN_CONFIG" 
  # echo " " >>  $POSTFIX_MAIN_CONFIG
   #echo "virtual_alias_map = hash:$POSTFIX_VMAIL_ALIAS_DB" >> $POSTFIX_MAIN_CONFIG
    
#fi

if ! grep -q "virtual_mailbox_maps" "$POSTFIX_MAIN_CONFIG"; then
   echo "Setting up virtual_mailbox_maps  in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "virtual_mailbox_maps = hash:$POSTFIX_VMAIL_BOXES_DB" >> $POSTFIX_MAIN_CONFIG
    
fi

if ! grep -q "virtual_mailbox_base" "$POSTFIX_MAIN_CONFIG"; then
   echo "Setting up virtual_mailbox_base  in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "virtual_mailbox_base = $POSTFIX_VMAIL_BASE" >> $POSTFIX_MAIN_CONFIG
    
fi


#Append entry if it does not exist
echo "Adding $EMAIL_DOMAIN entry to $POSTFIX_VDOMAIN_DB"
grep -qF -- "$EMAIL_DOMAIN" "$POSTFIX_VDOMAIN_DB" || echo "$EMAIL_DOMAIN" >> "$POSTFIX_VDOMAIN_DB"


#Append entry if it does not exist
echo "Adding $EMAIL_ADDRESS entry to $POSTFIX_VMAIL_BOXES_DB"
VMAIL_BOX_ENTRY="$EMAIL_ADDRESS     $EMAIL_DOMAIN/$EMAIL_USERNAME"
grep -qF -- "$EMAIL_ADDRESS" "$POSTFIX_VMAIL_BOXES_DB" || echo "$VMAIL_BOX_ENTRY" >> "$POSTFIX_VMAIL_BOXES_DB"



#Append entry if it does not exist
echo "Adding $EMAIL_DOMAIN entry to $POSTFIX_VALIAS_DB"
ALIAS_ENTRY="$EMAIL_ADDRESS      $EMAIL_ADDRESS"
grep -qF -- "$ALIAS_ENTRY" "$POSTFIX_VMAIL_ALIAS_DB" || echo "$ALIAS_ENTRY" >> "$POSTFIX_VMAIL_ALIAS_DB"


postmap $POSTFIX_VDOMAIN_DB
postmap $POSTFIX_VMAIL_BOXES_DB
#postmap $POSTFIX_VMAIL_ALIAS_DB

###
### POSTFIX SASL CONFIG FOR DOVECOT
##

if ! grep -q "smtpd_sasl_auth_enable" "$POSTFIX_MAIN_CONFIG"; then

   echo "Enabling smtpd_sasl_auth_enable in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "smtpd_sasl_auth_enable = yes" >> $POSTFIX_MAIN_CONFIG

fi

if ! grep -q "smtpd_sasl_type" "$POSTFIX_MAIN_CONFIG"; then

   echo "Enabling smtpd_sasl_type in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "smtpd_sasl_type = dovecot" >> $POSTFIX_MAIN_CONFIG

fi

if ! grep -q "smtpd_sasl_path" "$POSTFIX_MAIN_CONFIG"; then

   echo "Enabling smtpd_sasl_path in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "smtpd_sasl_path = private/auth" >> $POSTFIX_MAIN_CONFIG

fi

if ! grep -q "smtpd_sasl_security_options" "$POSTFIX_MAIN_CONFIG"; then

   echo "Enabling smtpd_sasl_security_options in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "smtpd_sasl_security_options = noanonymous" >> $POSTFIX_MAIN_CONFIG

fi

if ! grep -q "virtual_transport" "$POSTFIX_MAIN_CONFIG"; then

   echo "Enabling virtual_transport in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "virtual_transport =  lmtp:unix:private/dovecot-lmtp" >> $POSTFIX_MAIN_CONFIG

fi



##
### END SASL CONFIG
##

#Fix myDestination
if ! grep -qw "mydestination[ ]*=[ ]*localhost" "$POSTFIX_MAIN_CONFIG"; then

   #Replace the existing line 
   sed -i '/^mydestination[ ]*=[ ]*/s/^/#/' $POSTFIX_MAIN_CONFIG
 
   echo "Changing mydestination in $POSTFIX_MAIN_CONFIG" 
   echo " " >>  $POSTFIX_MAIN_CONFIG
   echo "mydestination = localhost" >> $POSTFIX_MAIN_CONFIG

fi

##Add postfix network entry, chek missing or commented
INET_PATTERN="submission[ ]*inet[ ]*n[ ]*-[ ]*n[ ]*-[ ]*-[ ]*smtpd"
if ! grep -q "$INET_PATTERN" "$POSTFIX_MASTER_CONFIG" || grep -q "#[ ]*$INET_PATTERN"; then

   echo "adding submission inet in $POSTFIX_MASTER_CONFIG" 
   echo " " >>  $POSTFIX_MASTER_CONFIG
   echo "submission inet n       -       n       -       -       smtpd" >> $POSTFIX_MASTER_CONFIG

fi 

