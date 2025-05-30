#!/bin/sh
if [ "$1" = "ia" ]; then
    shift
    exec ia "$@"
else
    exec python3 /app/upload.py "$@"
fi
