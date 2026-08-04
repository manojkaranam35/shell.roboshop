#!/bin/bash

USERID=$(ID -U)
R="e[31m
G="e[32m
Y="e[33m
N="e[0m

LOGS_FOLDER="var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

mkdir -p $LOGS_FOLDER
echo "script started at : $(date)" | tee -a $LOG_FILE

if [ $USERID -ne 0 ]
then 
  echo -e "$R error: run the script with root user $N" | tee -a $LOG_FILE
  exit 1
else
  echo -e "$G running the script with root user nothing to user $N" | tee -a $LOG_FILE
fi

VALIDATE (){
if [ $1 -eq 0 ]
then
  echo -e "$2 is ...$G success $N" | tee -a $LOG_FILE
else 
  echo -e "$2 is .... $R failure $N" | tee -a $LOG_FILE
  exit 1
fi  
}

cp mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "coping mongodb repo"

dnf install mongodb-org -y &>>$LOG_FILE
VALIDATE $? "installing mongodb"

systemctl enable mongod &>>$LOG_FILE
VALIDATE $? "enabling mongodb"

systemctl start mongod &>>$LOG_FILE
VALIDATE $? "start mongodb"

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
VALIDATE $? "Editing MongoDB conf file for remote connections"

systemctl restart mongod
VALIDATE $? "restart mongod"