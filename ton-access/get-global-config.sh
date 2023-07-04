#!/bin/bash

# make directory if doesnt exist
mkdir -p config
# fetch
curl -sL https://ton-blockchain.github.io/global.config.json > ./config/global-mainnet.json
curl -sL https://ton-blockchain.github.io/testnet-global.config.json > ./config/global-testnet.json