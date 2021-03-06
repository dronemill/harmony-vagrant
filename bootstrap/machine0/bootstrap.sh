#!/bin/bash

set -e

# suppress stdout
# exec 1>/dev/null

#
# Install basics
#

apt-get update
apt-get install -y htop vim screen curl telnet tmux zsh git bridge-utils



#
# Interfaces
#

echo "source /etc/network/interfaces.d/*" >> /etc/network/interfaces
cp /repos/vagrant/bootstrap/machine0/interfaces/* /etc/network/interfaces.d/.
ifup wan0
ifup lan0



#
# Install Docker
#

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
echo "deb https://get.docker.io/ubuntu docker main" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y lxc-docker
ln -sf /usr/bin/docker /usr/local/bin/docker
echo 'DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4 --storage-driver=aufs"' >> /etc/default/docker
service docker restart


#
# MySQL
#
docker create --name harmony-data-container-mysql -v /var/lib/mysql busybox
docker run -d --name harmony-mysql -e MYSQL_DATABASE=harmony -e MYSQL_ROOT_PASSWORD=my-secret-pw --volumes-from=harmony-data-container-mysql mysql:5.6.24

#
# API
#
cd /repos/api
docker build -t harmony/api:dev .
docker run -d --name harmony-api -p 4774:80 --expose 4774 -e EXEC_UNAME="www-data" -e EXEC_UID=1000 -e EXEC_GID=1000 -e MAESTRO_URL=`docker inspect --format '{{ .NetworkSettings.Gateway }}:4775' harmony-mysql` -v /repos/api:/usr/share/nginx/api --link harmony-mysql:mysql harmony/api:dev
docker exec harmony-api /usr/share/nginx/api/artisan migrate --seed

cd /repos/maestro
docker build -t harmony/maestro:dev .
# docker run -it --rm --expose 4775 -p 4775:4775 --name harmony-maestro -v /repos/go:/gocode --link harmony-api:harmony harmony/maestro:dev bash
# echo "192.168.194.10 harmony.dev" >> /etc/hosts
# go build -o maestro && ./maestro -logLevel=debug

cd /repos/batond
docker build -t harmony/batond:dev .
# docker run -it --rm --name harmony-batond -v /repos/go:/gocode -v /var/run/docker.sock:/tmp/docker.sock -e HARMONY_MACHINE_NAME=epicpower -e HARMONY_API="http://192.168.194.10:4774" harmony/batond:dev bash
# echo "192.168.194.10 harmony.dev" >> /etc/hosts
# cd /gocode/src/github.com/dronemill/harmony-batond && go build -o batond && ./batond -machine.name $HARMONY_MACHINE_NAME -logLevel=debug

