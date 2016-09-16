#!/bin/bash

# Getting options
while getopts ":u:p:h:r:e:" opt; do
  case $opt in
    u)
      echo ":: User: $OPTARG" >&2
      user="$OPTARG"
      ;;
    p)
      echo ":: Password: $OPTARG" >&2
      password="$OPTARG"
      ;;
    h)
      host_url="$OPTARG"
      host=`echo $host_url | awk -F/ '{print $3}' | awk -F: '{print $1}'`
      echo ":: Host: $OPTARG ($host)" >&2
      ;;
    e)
      mail="$OPTARG"
      echo ":: Send by mail at end"
      ;;
    r)
      echo ":: Rotate $OPTARG backups"
      rotate=`echo $(($OPTARG+1))`
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Check
if [ "$rotate" == "" ]
then
  rotate=7
fi

# Doing backup
echo "Getting CSRF Token"
wget -qO- --keep-session-cookies --save-cookies cookies.txt --no-check-certificate $host_url/diag_backup.php \
  | grep "name='__csrf_magic'" | sed 's/.*value="\(.*\)".*/\1/' > csrf.txt
echo "Login"
wget -qO- --keep-session-cookies --load-cookies cookies.txt --save-cookies cookies.txt --no-check-certificate \
  --post-data "login=Login&usernamefld=$user&passwordfld=$password&__csrf_magic=$(cat csrf.txt)" \
  $host_url/diag_backup.php  | grep "name='__csrf_magic'" \
  | sed 's/.*value="\(.*\)".*/\1/' > csrf2.txt
echo "Saving backup"
mkdir -p $host
xml_file="config-$host-`date +%Y%m%d%H%M%S`.xml"
wget --keep-session-cookies --load-cookies cookies.txt --no-check-certificate \
  --post-data "Submit=download&donotbackuprrd=yes&__csrf_magic=$(head -n 1 csrf2.txt)" \
  $host_url/diag_backup.php -O $host/$xml_file
exit=`echo $?`
if [ "$exit" == "0" ]
then
    gzip $host/$xml_file
    cd $host
    ls -1t | tail -n +$rotate | xargs rm > /dev/null 2>&1 
    cd ..
    echo "Success backup"
    if [ "$mail" != "" ]
    then
      echo "Backup successfully completed at `date` to host $host" > message.txt
      echo `ls -l $host` >> message.txt
      mutt -s "Backup of $host ($xml_file)" -a "$host/$xml_file.gz" -- $mail < message.txt
    fi
else
    echo "Error backup"
fi 

# Cleaning garbage
rm -f csrf.txt 2> /dev/null
rm -f csrf2.txt 2> /dev/null
rm -f cookies.txt 2> /dev/null
rm -f message.txt  2> /dev/null