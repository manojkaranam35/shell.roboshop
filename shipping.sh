```bash
#!/bin/bash

START_TIME=$(date +%s)
USERID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

# Get the directory where shipping.sh is located
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$LOGS_FOLDER"

echo "Script started executing at: $(date)" | tee -a "$LOG_FILE"

# Check root access
if [ "$USERID" -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a "$LOG_FILE"
    exit 1
else
    echo "You are running with root access" | tee -a "$LOG_FILE"
fi

echo "Please enter root password to setup"
read -s MYSQL_ROOT_PASSWORD

VALIDATE() {
    if [ "$1" -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a "$LOG_FILE"
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Install Maven
dnf install maven -y &>> "$LOG_FILE"
VALIDATE $? "Installing Maven and Java"

# Create roboshop user
id roboshop &>> "$LOG_FILE"

if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin \
        --comment "roboshop system user" roboshop &>> "$LOG_FILE"

    VALIDATE $? "Creating roboshop system user"
else
    echo -e "System user roboshop already created ... $Y SKIPPING $N" | tee -a "$LOG_FILE"
fi

# Create application directory
mkdir -p /app
VALIDATE $? "Creating app directory"

# Download shipping application
curl -o /tmp/shipping.zip \
    https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>> "$LOG_FILE"

VALIDATE $? "Downloading shipping"

# Clean old application
rm -rf /app/*

# Extract application
cd /app || exit 1

unzip /tmp/shipping.zip &>> "$LOG_FILE"
VALIDATE $? "Unzipping shipping"

# Package application
mvn clean package &>> "$LOG_FILE"
VALIDATE $? "Packaging the shipping application"

# Rename JAR
mv target/shipping-1.0.jar shipping.jar &>> "$LOG_FILE"
VALIDATE $? "Moving and renaming Jar file"

# Copy service file from GitHub repository directory
cp "$SCRIPT_DIR/shipping.service" /etc/systemd/system/shipping.service &>> "$LOG_FILE"
VALIDATE $? "Copying shipping service"

# Reload systemd
systemctl daemon-reload &>> "$LOG_FILE"
VALIDATE $? "Daemon Reload"

# Enable shipping
systemctl enable shipping &>> "$LOG_FILE"
VALIDATE $? "Enabling Shipping"

# Start shipping
systemctl start shipping &>> "$LOG_FILE"
VALIDATE $? "Starting Shipping"

# Install MySQL client
dnf install mysql -y &>> "$LOG_FILE"
VALIDATE $? "Installing MySQL client"

# Check whether database already exists
mysql -h mysql.kimidi.site \
    -u root \
    -p"$MYSQL_ROOT_PASSWORD" \
    -e "USE cities" &>> "$LOG_FILE"

if [ $? -ne 0 ]
then
    mysql -h mysql.karanam.site \
        -uroot \
        -p"$MYSQL_ROOT_PASSWORD" \
        < /app/db/schema.sql &>> "$LOG_FILE"

    mysql -h mysql.karanam.site \
        -uroot \
        -p"$MYSQL_ROOT_PASSWORD" \
        < /app/db/app-user.sql &>> "$LOG_FILE"

    mysql -h mysql.karanam.site \
        -uroot \
        -p"$MYSQL_ROOT_PASSWORD" \
        < /app/db/master-data.sql &>> "$LOG_FILE"

    VALIDATE $? "Loading data into MySQL"
else
    echo -e "Data is already loaded into MySQL ... $Y SKIPPING $N" | tee -a "$LOG_FILE"
fi

# Restart shipping
systemctl restart shipping &>> "$LOG_FILE"
VALIDATE $? "Restarting Shipping"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo -e "Script execution completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a "$LOG_FILE"
```
