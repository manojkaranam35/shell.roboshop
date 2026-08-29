#!/bin/bash

START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$pwd

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

if [ $USERID -ne 0 ]
then
       echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

echo "please enter root password to setup"
read -s MYSQL_ROOT_PASSWORD

dnf install maven -y &>>$LOG_FILE
VALIDATE $? "installing maven"

id roboshop
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
    VALIDATE $? "creating roboshop user add"
else
echo -e "Roboshop user already created $Y SKIPPING $N"
fi

mkdir -p /app &>>$LOG_FILE
VALIDATE $? "creating app directory"

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip 
VALIDATE $? "downloading shipping"

rm -rf /app/*
cd /app 
unzip /tmp/shipping.zip &>>$LOG_FILE
VALIDATE $? "unzipping shipping"

mvn clean package &>>$LOG_FILE
VALIDATE $? "downloading dependencies"

mv target/shipping-1.0.jar shipping.jar &>>$LOG_FILE
VALIDATE $? "Re-naming shipping jar"

cp "$SCRIPT_DIR/shipping.service" /etc/systemd/system/shipping.service &>>$LOG_FILE
VALIDATE $? "copying shipping services"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "daemon reload"

systemctl enable shipping 
systemctl start shipping &>>$LOG_FILE
VALIDATE $? "starting shipping"

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "installing mysql"

mysql -h mysql.karanam.site -uroot -p$MYSQL_ROOT_PASSWORD -e 'use cities' &>>$LOG_FILE
if [ $? - ne 0 ]
then
    mysql -h mysql.karanam.site -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/schema.sql
    mysql -h mysql.karanam.site -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/app-user.sql 
    mysql -h mysql.karanam.site -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/master-data.sql
else
    echo -e "DATA is already loaded in mysql... $Y SKIPPING $N"
fi

systemctl restart shipping &>>$LOG_FILE
VALIDATE $? "restarting shipping"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script exection completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE