#!/bin/bash

set -e

# Ensure that the .hal folder is owned by the Spinnaker user
chown -R spinnaker:spinnaker /home/spinnaker/.hal

# Install VIM
mkdir /var/cache/apk
apk add vim
rm -rf /var/cache/apk
