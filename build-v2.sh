#!/bin/bash

# Clone the Git repository
git clone https://github.com/toncenter/ton-http-api
cd ton-http-api

# copy .env for building
cp ../build-v2.env ./.env

# Checkout to the specific branch/tag (v3 in this case)
git checkout v3

function build() {
    # Function parameters
    local tag="$1"
    local branch="$2"

    # Set the environment variable    
    export IMAGE_TAG="$tag"
    export TON_BRANCH="$branch"

    # Run docker compose build
    docker compose build
}

# build mainnet
build "mainnet" "master"
# build testnet
#build testnet testnet