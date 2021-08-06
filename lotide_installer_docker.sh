#!/bin/bash 
#
# 01/14/2021 - nixfu
#
# This script automates the whole download/install/configuration process and at the end you get 
# postgres installed/setup, and lotide/hitide setup as systemd services all on the same system. 
# The script assumes you are running it as root or via sudo.
#
# You can tweak the settings using the environment variables at the top. 
# The default settings I used are good for getting an install working on a test vm on your local network.
# WARNING: This is rough script, basically made by copying all my steps as I did them manually the first time, 
# and then trying it out on a new vm a couple of times just to make sure it worked.   There is no error checking, 
# or checking to see what steps are already completed to skip them etc. so re-running it could mess some things up(DB).

# this will create a service account for the daemons and install 
# into that home directory eg /home/$SERVICE_USER
SERVICE_USER=lotide
useradd -m ${SERVICE_USER}
SERVICE_DIR=/home/${SERVICE_USER}

#SETUP VARS
LOTIDE_DB_NAME=lotidedb
LOTIDE_DB_USER=lotide
LOTIDE_DB_PASS=lotide

# NOTE: I think it must be ip/hostname of system running postgres
# don't use localhost/127.0.0.1 or lotide docker won't be 
# able to connect because it will look for a port INSIDE itself
LOTIDE_DB_HOSTNAME=dev.home

LOTIDE_PORT=3333
LOTIDE_HOSTNAME=dev.home
HITIDE_PORT=4333
HITIDE_HOSTNAME=dev.home
PGPASSWORD=pgdocker



# install prereqs
apt-get update
apt-get -y remove docker docker-engine docker.io containerd runc
apt -y install snapd postgresql-client
snap install docker

# docker postgress setup
docker pull postgres
mkdir -p ${SERVICE_DIR}/docker/volumes/postgres
docker run --name pg-docker -d --rm -e POSTGRES_PASSWORD=${PGPASSWORD} -p 5432:5432 -v ${SERVICE_DIR}/docker/volumes/postgres:/var/lib/postgresql/data postgres
PGPASSWORD=${PGPASSWORD} psql -h localhost -U postgres -d postgres -c "create database ${LOTIDE_DB_NAME};"
PGPASSWORD=${PGPASSWORD} psql -h localhost -U postgres -d postgres -c "create user ${LOTIDE_DB_USER} with encrypted password '${LOTIDE_DB_PASS}'"
PGPASSWORD=${PGPASSWORD} psql -h localhost -U postgres -d postgres -c "grant all privileges on database ${LOTIDE_DB_NAME} to ${LOTIDE_DB_USER};"

# docker lotide setup
docker pull lotide/lotide
docker run --name lotide-migrate-setup --rm -e RUST_BACKTRACE=1 -p 3333:3333 -e HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub -e HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api -e DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME} lotide/lotide lotide migrate setup
docker run --name lotide-migrate --rm -e RUST_BACKTRACE=1 -p 3333:3333 -e HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub -e HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api -e DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME} lotide/lotide lotide migrate
docker run --name lotide-docker -d --rm -e RUST_BACKTRACE=1 -p 3333:3333 -e HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub -e HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api -e DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME} lotide/lotide

# docker hitide setup
docker pull lotide/hitide
docker run --name hitide-docker -d --rm -e RUST_BACKTRACE=1 -p 4333:4333 -e BACKEND_HOST=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT} lotide/hitide

# show running
docker ps

# done
echo "###### DONE ########"
echo "Try http://<myip>:4333 for hitide"
echo "Try http://<myip>:3333/api for lotide"
