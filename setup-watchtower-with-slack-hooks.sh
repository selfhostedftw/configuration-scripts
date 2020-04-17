# Download Docker before you run this

docker run -d --restart=always --name watchtower -v \
/var/run/docker.sock:/var/run/docker.sock containrrr/watchtower
