#!/bin/bash
# This script is a customization Script and it is used to set instances launched using openstack. 

# update things.
sudo su
apt-get -y update && apt-get upgrade -y

# install maven, pidstat and htop. 
apt install maven -y
apt install sysstat -y
apt install htop -y

# install wrk2.
apt-get install build-essential libssl-dev git -y
git clone https://github.com/giltene/wrk2.git
cd wrk2
make
cp wrk /usr/local/bin
cd ../

# install openjdk9.
apt-get -o Dpkg::Options::="--force-overwrite" install openjdk-9-jdk -y
