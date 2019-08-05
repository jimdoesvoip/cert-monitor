#/bin/bash

## make sure to update the SPTH with the path of the cert-monitor script if not /root/certmonitor (a few lines below)
## make sure to update the email address for the report (at the bottom)

#set -x #echo on

SHELL=/bin/bash

MAIL=/var/spool/mail/root
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/mssql-tools/bin:/opt/mssql-tools/bin:/root/bin:/opt/mssql-tools/bin:/opt/mssql-tools/bin
PWD=/root/cert-monitor

SPTH='/root/cert-monitor'

SOURCEFILE=sites-to-check.csv
SITEFILE=sites-to-check-clean.csv
grep -v '#' $SPTH/$SOURCEFILE > $SPTH/$SITEFILE

RAND=$(mktemp)
RANDSOON=$(mktemp)

pushd $SPTH >/dev/null

adddate() {
    while IFS= read -r line; do
        echo "$(date) $line "
    done
}

echo "starting certificate verification run" | adddate >> $SPTH/cert_runner.log

echo "   " >> $RANDSOON
echo "Sever Requiring Attention:" >> $RANDSOON
echo "-------------------------- " >> $RANDSOON
echo "   " >> $RAND
echo "Full Sever List:" >> $RAND
echo "-------------------------- " >> $RAND


while IFS= read i
#for i in "${ssl_sites[@]}"
do
   echo "$i"
   SERVER=$(echo $i | awk -F',' '{print $1}')
   HOST=$(echo $i | awk -F',' '{print $2}')
   PORT=$(echo $i | awk -F',' '{print $3}')
   echo "server: " $SERVER " host: " $HOST " port: " $PORT
   echo "server: " $SERVER " host: " $HOST " port: " $PORT >> $SPTH/cert_runner.log

expirationdate=$(  openssl s_client -servername $SERVER -connect $HOST:$PORT 2>/dev/null < /dev/null | openssl x509 -noout -enddate | cut -d= -f 2)
echo "expires: " $expirationdate

if [ -z "$expirationdate" ]
then
    echo "$SERVER:$HOST:$PORT is unreachable"
    echo "$SERVER:$HOST:$PORT is unreachable" >> $SPTH/cert_runner.log
    echo "$SERVER:$HOST:$PORT is unreachable" >> $RAND
    continue
fi

expirationday=`date --date="$expirationdate" --iso-8601`
echo "expires day: " $expirationday
expiresdate=$(date --date="$expirationday" +%s)
echo "expires linux: "$expiresdate
echo "today: " $( date --iso-8601)
echo "today linux: " $( date +%s)
echo "+28 days: " $( date -d "+ 28 days" )
watchdate=$( date -d "+ 28 days" +%s )
echo "watch date linux: "$watchdate

if [[ $watchdate -ge $expiresdate ]];
then
    echo "$SERVER:$HOST:$PORT is expiring on $expirationdate WHICH IS SOON!!"
    echo "$SERVER:$HOST:$PORT is expiring on $expirationdate WHICH IS SOON!!" >> $SPTH/cert_runner.log
    echo "$SERVER:$HOST:$PORT is expiring on $expirationdate WHICH IS SOON!!" >> $RAND
    echo "$SERVER:$HOST:$PORT is expiring on $expirationdate WHICH IS SOON!!" >> $RANDSOON
else
    echo "$SERVER:$HOST:$PORT is expiring on $expirationdate which is not soon"
    echo "$SERVER:$HOST:$PORT is expiring on $expirationdate which is not soon" >> $SPTH/cert_runner.log
    echo "$SERVER:$HOST:$PORT is expiring on $expirationdate which is not soon" >> $RAND
fi

#done
done <"$SPTH/$SITEFILE"

echo $RAND
SOONCONUNT=$( cat $RAND | grep -c "SOON")
echo "SOONCOUNT: " $SOONCONUNT

cat $RANDSOON $RAND | mail -s "SSL Cert Checks - $SOONCONUNT hosts close to expiration" -r sender.email@address.com receiver.email@address.com

rm $RAND
rm $RANDSOON
rm $SPTH/$SITEFILE

popd >/dev/null
exit
