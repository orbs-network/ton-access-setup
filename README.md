# ton-access-setup
config of yaml, nginx and env for all nodes.

## node setup
- install docker & docker-compose
- make sure docker is accessible by ubuntu user 
- ssh to target machine
- install mytonctrl/validator ```https://github.com/ton-blockchain/mytonctrl/blob/master/scripts/install.sh```
- make sure to download uninstaller as well

## create litserver config
- run mytonctrl
    - installer
    - clcf

## install ton-access
- clone this repo
- set fastly keys ```ton-access/fastly.env```
- run ```install.sh```
    - copies ```ton-access``` folder to ```/home/ubuntu```
- ```cd /home/ubuntu/cd ton-access```
- ```./get-global-config.sh```
- ```sudo docker compose up -d```

## ton-access folder 
- docker-compose.yaml
- nginx.conf
- ```env``` - general to entire docker-compose
    - .env 
- ```env``` compose service specific
    - ```v2.env``` 
    - ```fastly.env```
- config/
    - ```testnet.json```
    - ```mainnet.json```
