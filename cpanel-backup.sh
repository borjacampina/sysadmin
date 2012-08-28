#!/bin/bash
#
# A script to backup a entire hosted filesystem and database from a web site
# using cPanel interface.
#
# Author: borjacampina

# Instructions:
#     1º - Edit configurable parameters
#     2º - Add this script to /etc/crontab file, ex. all saturdays at 3:30:
#           30 3 * * 6  <path_to_this_script_file>


# -- Configurable parameters

# domain name
DOMAIN=""
# database name
DATABASE=""
# cpanel username
USER=""
# cpanel password
PASS=""
# folder to store backup files (must exist)
BACKUP_FOLDER="."
# mail to notificacion
MAIL_NOTIFICATION_ADDRESS=""
# how many backups to store (ex: the last 2)
MAX_BACKUP_FILES="2"
# notification mail subject
SUBJECT="[cpbackup] $DOMAIN"

# -- Other parameters

MAIL_BIN="mail"
WGET_BIN="wget"
# log filename
LOG_FILE="$DOMAIN-cpanelbackup.log"
# cpanel https port number
PORT="2083"
DATE="$(date +'%Y-%m-%d')"

# -- Prints message to stdout and writes it to the log file

function log
{
    echo "$DATE: $*"
    echo "$DATE: $*" >> $LOG_FILE
}

# -- Downloads backups, rotates them and sends a notification mail

function doBackup
{
    cd $BACKUP_FOLDER

    log "Downloading $DATABASE database backup from $DOMAIN"
    $WGET_BIN --no-check-certificate --progress=dot:giga -c -t 3 --http-user=$USER --http-password=$PASS https://$DOMAIN:$PORT/getsqlbackup/$DATABASE.sql.gz -O $DOMAIN-$DATE.sql.gz 2>> $LOG_FILE
    if [ $? -eq 0 ]; then
        log "$DATABASE backup complete successfuly: $(du -h $DOMAIN-$DATE.sql.gz)"
        SUBJECT="$SUBJECT db: $(echo $(du -h $DOMAIN-$DATE.sql.gz) | awk '{ print $1 }')"
    else
        log "$DATABASE backup finished with errors"
    fi

    log "Downloading home directory for domain $DOMAIN"
    $WGET_BIN --no-check-certificate --progress=dot:giga -c -t 3 --http-user=$USER --http-password=$PASS https://$DOMAIN:$PORT/getbackup/$DOMAIN-$DATE.tar.gz 2>> $LOG_FILE
    if [ $? -eq 0 ]; then
	log "home directory backup for domain $DOMAIN complete successfuly: $(du -sh $DOMAIN-$DATE.tar.gz)"
	SUBJECT="$SUBJECT www: $(echo $(du -h $DOMAIN-$DATE.tar.gz) | awk '{ print $1 }')"
     else
        log "home directory backup for domain $DOMAIN finished with errors"
    fi

    log "Rotating database backups"
    dir=`ls -t $DOMAIN-*.sql.gz 2> /dev/null`
    if [ $? -eq 0 ]; then
        N=0
        for file in $dir; do
            if [ $N -lt $MAX_BACKUP_FILES ]; then
                let N++
            else
                log "Removing old file $file"
                rm -f $file
            fi
        done
    else
        log "No database backup file found on $BACKUP_FOLDER"
    fi

    log "Rotating home directory backups"
    dir=`ls -t $DOMAIN-*.tar.gz 2> /dev/null`
    if [ $? -eq 0 ]; then
        N=0
        for file in $dir; do
            if [ $N -lt $MAX_BACKUP_FILES ]; then
                let N++
            else
                log "Removing old file $file"
                rm -f $file
            fi
        done
    else
        log "No home directory backup file found on $BACKUP_FOLDER"
    fi

    cat "$LOG_FILE" | $MAIL_BIN -s "$SUBJECT" $MAIL_NOTIFICATION_ADDRESS
    rm -f $LOG_FILE
}

doBackup
