#!/bin/sh
set -x
if [ -z $REALM ]; then
    if [ -z $KRB5_CONFIG ]; then
	KRB5_CONFIG=/etc/krb5.conf
    fi
    REALM=`grep default_realm $KRB5_CONFIG | awk '{print $3}'`
fi

if [ -z $REALM ]; then
    echo "could not figure out your default Kerberos realm: check your /etc/krb5.conf file."
    exit 1
fi

rm -f `pwd`/`whoami`.keytab
KADMIN_LOCAL="sudo kadmin.local"
echo "ktadd -e \"DES-CBC-CRC:NORMAL\" -k `pwd`/`whoami`.keytab `whoami`@$REALM" | $KADMIN_LOCAL
sudo chown `whoami` `pwd`/`whoami`.keytab
