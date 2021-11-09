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
LOTIDE_DB_HOSTNAME=localhost
LOTIDE_PORT=3333
LOTIDE_HOSTNAME=localhost
HITIDE_PORT=4333
HITIDE_HOSTNAME=localhost


# env var for lotide
export HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub
export HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api
export DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME}
# env var for hitide
export BACKEND_HOST=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}

# install prereqs
apt-get update
apt -y install curl postgresql libssl-dev pkg-config openssl ca-certificates git build-essential

# install rust
export RUSTUP_INIT_SKIP_PATH_CHECK=yes
export CARGO_HOME=/home/lotide/.cargo
export RUSTUP_HOME=/home/lotide/.rustup
curl https://sh.rustup.rs -sSf | sh -s -- -y
export PATH="/home/lotide/.cargo/bin:$PATH"


# setup postgres
sudo -u postgres /usr/lib/postgresql/13/bin/initdb -D /var/lib/postgresql/data
systemctl restart postgresql
sudo -u postgres psql -c "create database ${LOTIDE_DB_NAME};"
sudo -u postgres psql -c "create user ${LOTIDE_DB_USER} with encrypted password '${LOTIDE_DB_PASS}'"
sudo -u postgres psql -c "grant all privileges on database ${LOTIDE_DB_NAME} to ${LOTIDE_DB_USER};"

# download and build lotide and run db migration/setup
cd ${SERVICE_DIR}
mkdir bin

cd ${SERVICE_DIR}
curl https://git.sr.ht/~vpzom/lotide/archive/v0.8.0.tar.gz | tar -xz 
cd lotide*
cargo build --release
cargo run -- migrate setup
cargo run -- migrate
cp target/release/lotide ${SERVICE_DIR}/bin/.

cd ${SERVICE_DIR}
# download and build hitide
curl https://git.sr.ht/~vpzom/hitide/archive/v0.8.0.tar.gz | tar -xz
cd hitide*
cargo build --release
cp target/release/hitide ${SERVICE_DIR}/bin/.

# create environment variable setup script for lotide
cd ${SERVICE_DIR}/bin
cat << EOF > ${SERVICE_DIR}/bin/lotide_env.sh
# env var for lotide
export HOST_URL_ACTIVITYPUB=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/apub
export HOST_URL_API=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}/api
export DATABASE_URL=postgresql://${LOTIDE_DB_USER}:${LOTIDE_DB_PASS}@${LOTIDE_DB_HOSTNAME}/${LOTIDE_DB_NAME}
# env var for hitide
export BACKEND_HOST=http://${LOTIDE_HOSTNAME}:${LOTIDE_PORT}
EOF

# create systemd service script for lotide
cat << EOF > ${SERVICE_DIR}/bin/lotide.service
[Unit]
Description=lotide server

[Service]
ExecStart=/bin/bash -a -c 'source ${SERVICE_DIR}/bin/lotide_env.sh && exec ${SERVICE_DIR}/bin/lotide'
User=${SERVICE_USER}

[Install]
WantedBy=multi-user.target
EOF

# create systemd service script for hitide
cat << EOF > ${SERVICE_DIR}/bin/hitide.service
[Unit]
Description=hitide server
After=lotide.service

[Service]
ExecStart=/bin/bash -a -c 'source ${SERVICE_DIR}/bin/lotide_env.sh && exec ${SERVICE_DIR}/bin/hitide'
User=${SERVICE_USER}

[Install]
WantedBy=multi-user.target
EOF

chown -R ${SERVICE_USER} ${SERVICE_DIR}/bin
chmod -R a+rx ${SERVICE_DIR}/bin
cp ${SERVICE_DIR}/bin/*.service /etc/systemd/system/.

# enable services
systemctl enable lotide.service
systemctl enable hitide.service
# start services
systemctl start lotide.service
systemctl start hitide.service
# status services
systemctl status lotide.service
systemctl status hitide.service

# done
echo "###### DONE ########"
echo "Try http://<myip>:4333 for hitide"
echo "Try http://<myip>:3333/api for lotide"
