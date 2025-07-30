#!/bin/bash

readonly NFS_SHARE="$1";
sudo apt-get update -qq >/dev/null;

sudo -E apt-get install -y -qq nfs-common >/dev/null;