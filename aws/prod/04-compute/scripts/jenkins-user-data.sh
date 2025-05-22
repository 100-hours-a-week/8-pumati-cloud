#!/bin/bash
set -e

apt update && apt upgrade -y
apt install -y openjdk-21-jdk

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5BA31D57EF5975CA
sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

apt update -y
apt install -y jenkins

systemctl enable jenkins
systemctl start jenkins
