#!/bin/bash
if [ -x /usr/sbin/redis-server ]; then
	/usr/sbin/redis-server --port 7777
else
	echo "Redis nicht installiert. Kümmer dich darum!"
fi
