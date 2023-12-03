# ton-access-setup
config of yaml, nginx and env for all nodes.

## install
- ssh to target machine
- create liteserver config
- ssh-keygen -t rsa
- clone this repo
- set fastly keys ```ton-access/fastly.env```
- run ```install.sh```
    - copies ```ton-access``` folder to ```/home/ubuntu```
- ```cd ton-access```
- ```./get-global-config.sh```
- ```sudo docker compose up -d```

## create litserver config
- run mytonctrl
    - installer
    - clcf
- (DEPRECATED?)cp from source to ```ton-access/config```

## ton-access folder 
- docker-compose.yaml
- nginx.conf
- .env (copied from node folder)
- config/
    - testnet.json
    - mainnet.json

## ton-access/config
- content is different on each node
- share same config.json files amongst all nodes is a good practice to apply a fallback quickly
