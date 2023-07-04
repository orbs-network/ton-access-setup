# ton-access-nodes
config of yaml, nginx and env for all nodes.
each /node/[hostname] stands for production node. 

## install
- ssh to target machine
- create liteserver config
- ssh-keygen -t rsa
- add pubkey to deployment keys in this repo on github
- clone this repo
- run ```install.sh```
    - copies ```ton-access``` folder to ```/home/ubuntu```
- ```cd ton-access```
- ```./get-global-config.sh```
- ```sudo docker compose up -d```

## create litserver config
- run mytonctrl
    - installer
    - clcf
- cp from source to ```ton-access/config```

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
