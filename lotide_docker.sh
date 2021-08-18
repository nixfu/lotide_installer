#!/bin/bash 
#
# 08/05/2021 - nixfu
#
# This script automates the whole download/install/configuration process and at the end you get 
# postgres installed/setup, and lotide/hitide setup as systemd services all on the same system. 
# The script assumes you are running it as root or via sudo.
# 
# This script also provides a way to stop and start the docker containers.  If you want them to
# auto start then uncomment the unless-stopped option below.
#
# USAGE:
# $0 install - run the install process
# $0 start   - start the docker containers
# $0 stop    - stop the docker containers
# $0 status  - check the status of the docker containers
#
# You can tweak the settings using the environment variables at the top. 
# The default settings I used are good for getting an install working on a test vm on your local network.
# WARNING: This is rough script, basically made by copying all my steps as I did them manually the first time, 
# and then trying it out on a new vm a couple of times just to make sure it worked.   There is no error checking, 
# or checking to see what steps are already completed to skip them etc. so re-running it could mess some things up(DB).

# this will create a service account for the daemons and install 
# into that home directory eg /home/$SERVICE_USER
SERVICE_USER=lotide
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

DOCKER_RESTART=""
# uncomment below to force docker containers to auto-restart
DOCKER_RESTART="--restart unless-stopped"
# uncomment below to force docker containers to remove themselves when stopped
#DOCKER_RESTART="--rw"

PGPASSWORD=pgdocker

install_prereq() {
	# install prereqs for debian 10
	apt-get update
	apt-get -y remove docker docker-engine docker.io containerd runc
	apt -y install snapd postgresql-client
	snap install docker
        # ensure service user account exists
        useradd -m ${SERVICE_USER}
}

install_docker_psql() {
	# docker postgress setup
	docker pull postgres
	mkdir -p ${SERVICE_DIR}/docker/volumes/postgres
	docker run $DOCKER_RESTART --name pg-docker -d -e POSTGRES_PASSWORD=${PGPASSWORD} -p 5432:5432 -v ${SERVICE_DIR}/docker/volumes/postgres:/var/lib/postgresql/data postgres
	PGPASSWORD=${PGPASSWORD} psql -h localhost -U postgres -d postgres -c "create database ${LOTIDE_DB_NAME};"
	PGPASSWORD=${PGPASSWORD} psql -h localhost -U postgres -d postgres -c "create user ${LOTIDE_DB_USER} with encrypted password '${LOTIDE_DB_PASS}'"
	PGPASSWORD=${PGPASSWORD} psql -h localhost -U postgres -d postgres -c "grant all privileges on database ${LOTIDE_DB_NAME} to ${LOTIDE_DB_USER};"
}

remove_docker_psql() {
       # remove postgress docker
        if docker ps -a -f name=pg-docker | grep -q pg-docker; then
            echo "...removing pg-docker"
            docker rm pg-docker
        else
            echo "...pg-docker already removed"
        fi
}

install_docker_lotide() {
	# docker lotide setup
	docker pull lotide/lotide
	docker run --name lotide-migrate-setup -e RUST_BACKTRACE=1 -p 3333:3333 -e HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub -e HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api -e DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME} lotide/lotide lotide migrate setup
	docker run --name lotide-migrate -e RUST_BACKTRACE=1 -p 3333:3333 -e HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub -e HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api -e DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME} lotide/lotide lotide migrate
}

remove_docker_lotide() {
       # remove lotide docker
        if docker ps -a -f name=lotide-docker | grep -q lotide-docker; then
            echo "...removing lotide-docker"
            docker rm lotide-docker
        else
            echo "...lotide-docker already removed"
        fi
}

install_docker_hitide() {
	# docker hitide setup
	docker pull lotide/hitide
}
remove_docker_hitide() {
       # remove hitide docker
        if docker ps -a -f name=hitide-docker | grep -q hitide-docker; then
            echo "...removing hitide-docker"
            docker rm hitide-docker
        else
            echo "...hitide-docker already removed"
        fi
}


run_docker_psql() {
        if docker ps -f name=pg-docker | grep -q pg-docker; then
            echo "...pg-docker already running"
        else
	    docker run $DOCKER_RESTART --name pg-docker -d -e POSTGRES_PASSWORD=${PGPASSWORD} -p 5432:5432 -v ${SERVICE_DIR}/docker/volumes/postgres:/var/lib/postgresql/data postgres
        fi
}


run_docker_lotide() {
        if docker ps -f name=lotide-docker | grep -q lotide-docker; then
            echo "...lotide-docker already running"
        else
	    docker run $DOCKER_RESTART --name lotide-docker -d -e RUST_BACKTRACE=1 -p 3333:3333 -e HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub -e HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api -e DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME} lotide/lotide
        fi
}


run_docker_hitide() {
        if docker ps -f name=hitide-docker | grep -q hitide-docker; then
            echo "...hitide-docker already running"
        else
	    docker run $DOCKER_RESTART --name hitide-docker -d -e RUST_BACKTRACE=1 -p 4333:4333 -e BACKEND_HOST=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT} lotide/hitide
        fi
}

stop_docker_lotide() {
        if docker ps -f name=lotide-docker | grep -q lotide-docker; then
            echo "...stopping lotide-docker"
            docker stop hitide-docker
        else
            echo "...lotide-docker already stopped"
        fi
}
kill_docker_lotide() {
        if docker ps -f name=lotide-docker | grep -q lotide-docker; then
            echo "...kill lotide-docker"
            docker kill hitide-docker
        else
            echo "...lotide-docker already stopped"
        fi
}


stop_docker_hitide() {
        if docker ps -f name=hitide-docker | grep -q hitide-docker; then
            echo "...stopping hitide-docker"
            docker stop hitide-docker
        else
            echo "...hitide-docker already stopped"
        fi
}
kill_docker_hitide() {
        if docker ps -f name=hitide-docker | grep -q hitide-docker; then
            echo "...kill hitide-docker"
            docker kill hitide-docker
        else
            echo "...hitide-docker already stopped"
        fi
}

stop_docker_psql() {
        if docker ps -f name=pg-docker | grep -q pg-docker; then
            echo "...stopping pg-docker"
            docker stop pg-docker
        else
            echo "...pg-docker already stopped"
        fi
}
kill_docker_psql() {
        if docker ps -f name=pg-docker | grep -q pg-docker; then
            echo "...kill pg-docker"
            docker kill pg-docker
        else
            echo "...pg-docker already stopped"
        fi
}



stop_all_dockers() {
        stop_docker_hitide
        stop_docker_lotide
        stop_docker_psql
}

start_all_dockers() {
        run_docker_psql
        run_docker_lotide
        run_docker_hitide
}

kill_all_dockers() {
        kill_docker_hitide
        kill_docker_lotide
        kill_docker_psql
}

remove_all_dockers() {
        remove_docker_hitide
        remove_docker_lotide
        remove_docker_psql
}

status() {
	# show running
	docker ps
}



case "$1" in
  start)
        echo "Starting docker psql/lotide/hitide"
        start_all_dockers
        # done
        status
        echo "###### DONE ########"
        echo "Try http://${HITIDE_HOSTNAME}:4333 for hitide"
        echo "Try http://${LOTIDE_HOSTNAME}:3333/api for lotide"
	;;
  stop)
        echo "STOP docker psql/lotide/hitide"
        stop_all_dockers
	;;
  kill)
        echo "KILL docker psql/lotide/hitide"
        stop_all_dockers
        kill_all_dockers
	;;
  install)
        echo "Intalling psql/lotide/hitide"
        install_prereq
        install_docker_psql
        install_docker_lotite
        install_docker_hitide
        echo "Completed.  Try $0 start."
	;;
  status)
        status
        echo "###### DONE ########"
        echo "Try http://${HITIDE_HOSTNAME}:4333 for hitide"
        echo "Try http://${LOTIDE_HOSTNAME}:3333/api for lotide"
	;;
  clean)
        echo "#### About to CLEAN and WIPE everything!! ####"
        read -p "Are you sure? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "Whew, you came to your senses. Aborting takeoff."
            exit 0
        else
            stop_all_dockers
            sleep 10
            kill_all_dockers
            remove_all_dockers
        fi
	;;
        
  *)
	echo "Usage: "$1" {install|start|stop|status}"
	exit 1
esac


exit 0
