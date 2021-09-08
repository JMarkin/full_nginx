#!/bin/bash

INOTIFY_FOLDER='/etc/nginx'
INOTIFY_COMMAND='nginx -t && nginx -s reload'

watchman --logfile /dev/stdout -- trigger ${INOTIFY_FOLDER} watch -- /bin/sh -c "echo $@ && sleep 5 && ${INOTIFY_COMMAND}";
