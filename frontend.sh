#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
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
VALIDATE $? "Disabling nginx"

dnf module enable nginx:1.24 -y
VALIDATE $? "Enabling Nginx1.24"

dnf install nginx -y
VALIDATE $? "installing nginx"

systemctl enable nginx 
systemctl start nginx
VALIDATE $? "start nginx"

rm -rf /usr/share/nginx/html/* 
VALIDATE $? "Removing default content"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip
VALIDATE $? "Donwload frontend"

cd /usr/share/nginx/html 
unzip /tmp/frontend.zip
VALIDATE $? "Unzipping the fornted code"

rm -rf /etc/nginx/nginx.conf
VALIDATE $? "Removing default ngonx conf"

cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf
VALIDATE $? "Copying nginx"

systemctl restart nginx
VALIDATE $? "Restarting nginx"