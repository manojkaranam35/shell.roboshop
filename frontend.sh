#!/bin/bash

START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# check the user has root priveleges or not
if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf module disable nginx -y
VALIDATE $? "disable nginx"

dnf module enable nginx:1.24 -y
VALIDATE $? "enable nginx"

dnf install nginx -y
VALIDATE $? "INSTALL NGINX"

systemctl enable nginx
VALIDATE $? "ENABLE NGINX"

systemctl start nginx
VALIDATE $? "STSRT NGINX"

rm -rf /usr/share/nginx/html/* 
VALIDATE $? "REMOVING DEFAULT USER"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip
VALIDATE $? "DOWNLOADING ROBOSHOPN FORN FRONTEND"

cd /usr/share/nginx/html 
unzip /tmp/frontend.zip
VALIDATE $? "UNZIPING IN HTML"

rm -rf /etc/nginx/nginx.conf
VALIDATE $? "Removing default ngonx conf"

cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf
VALIDATE $? "COPYING NGINX"

systemctl restart nginx 
VALIDATE $? "RESTART NGINX"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script exection completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE