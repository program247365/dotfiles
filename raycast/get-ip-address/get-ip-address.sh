#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Get IP Address
# @raycast.mode inline
# @raycast.refreshTime 1h

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName utils

# Documentation:
# @raycast.description Get local, router and public IP address
# @raycast.author John Buckley
# @raycast.authorURL https://github.com/nhojb

PUBLIC_IP=`curl -s https://ifconfig.me/ip &2> /dev/null`
ROUTER_IP=`route get default | grep gateway | awk '{print $2}'`
LOCAL_IP=`ifconfig | grep inet | grep -v inet6 | cut -d " " -f2 | tail -1`

echo "Local: $LOCAL_IP, Public: $PUBLIC_IP, Router: $ROUTER_IP"
