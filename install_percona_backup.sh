#!/bin/bash

echo "Fetch latest Percona XtraBackup Release";
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb

echo "Install Percona XtraBackup";
dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb

echo "Enable Percona XtraBackup Tools Release Repository";
percona-release enable-only tools release

echo "Update apt";
apt update

echo "Install Percona XtraBackup";
apt install percona-xtrabackup-80