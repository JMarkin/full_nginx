#!/bin/sh

/usr/local/sbin/download_geo
/notify.sh &
nginx -g "daemon off;"
