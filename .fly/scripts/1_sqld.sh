#!/bin/bash

# This has to be your app's .internal domain name on fly
CHECK_URL="${FLY_APP_NAME}.internal"
PRIMARY_FLAGS="--http-listen-addr=[::]:8082 --grpc-listen-addr=[::]:5001 --enable-bottomless-replication"
CONFIG_FILE="/etc/supervisor/conf.d/sqld.conf"

#Grabs all the possible machine names that are up
urls=$(dig +short AAAA $CHECK_URL)

if [ -z "$urls" ]; then
echo "No IPv6 records found"
exit 1
fi

#For each URL that could host a SQLd server
for url in $urls; do
#Try and connect to SQLd, and if found, be a replica
if curl -s --connect-timeout 5 -6 "[$url]:8082" > /dev/null; then
echo "Primary found, connecting to primary as replica"

REPLICA_FLAGS="--http-primary-url=http://[${url}]:8082 --http-listen-addr=[::]:8082 --primary-grpc-url=grpc://[${url}]:5001"

SELECTED_FLAGS="$REPLICA_FLAGS"
break
fi
done

#if no primaries were found, become the primary
if [ -z "$SELECTED_FLAGS" ]; then
echo "primary not found, becoming sqld primary."
    SELECTED_FLAGS="$PRIMARY_FLAGS"
fi

# Create a Supervisord configuration and put it the supervisor folder so supervisord can maintain it.
cat > "$CONFIG_FILE" << EOF
[program:sqld]
command=/usr/local/bin/sqld $SELECTED_FLAGS
autostart=true
autorestart=true
stderr_logfile=/var/log/sqld.err.log
stdout_logfile=/var/log/sqld.out.log
EOF
