#!/bin/bash
set -e

SYSTEM_PROPERTIES=${SYSTEM_PROPERTIES:-"/usr/lib/unifi/data/system.properties"}

# Configure external MongoDB if DB_URI is provided
if [ -n "$DB_URI" ]; then
    echo "Configuring external MongoDB connection..."   

    # Ensure data directory exists
    mkdir -p /usr/lib/unifi/data

    # Create properties file if it doesn't exist
    touch "$SYSTEM_PROPERTIES"

    # Function to update or add a property
    update_property() {
        local key="$1"
        local value="$2"
        local file="$3"

        if grep -q "^${key}=" "$file" 2>/dev/null; then
            # Property exists, update it
            sed -i "s|^${key}=.*|${key}=${value}|" "$file"
        else
            # Property doesn't exist, append it
            echo "${key}=${value}" >> "$file"
        fi
    }

    # Update MongoDB configuration properties
    update_property "db.mongo.uri" "${DB_URI}" "$SYSTEM_PROPERTIES"
    update_property "db.mongo.local" "false" "$SYSTEM_PROPERTIES"
    update_property "statdb.mongo.uri" "${DB_URI}" "$SYSTEM_PROPERTIES"
    update_property "statdb.mongo.local" "false" "$SYSTEM_PROPERTIES"
    update_property "unifi.db.name" "${DB_NAME:-unifi}" "$SYSTEM_PROPERTIES"

    echo "MongoDB configuration updated in $SYSTEM_PROPERTIES"
elif ! grep -q db.mongo.uri ${SYSTEM_PROPERTIES}; then
    echo "No DB_URI provided, UniFi will use embedded MongoDB"
fi

# Start UniFi with the original ENTRYPOINT command
exec /usr/bin/java \
    -Dfile.encoding=UTF-8 \
    -Djava.awt.headless=true \
    -Dapple.awt.UIElement=true \
    -Dunifi.core.enabled=false \
    -Xmx1024M \
    -XX:+UseParallelGC \
    -XX:+ExitOnOutOfMemoryError \
    -XX:+CrashOnOutOfMemoryError \
    -XX:ErrorFile=/var/run/unifi/hs_err_pid%p.log \
    -Dunifi.datadir=/usr/lib/unifi/data/ \
    -Dunifi.logdir=/logs \
    -Dunifi.rundir=/var/run/unifi \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    --add-opens java.base/java.time=ALL-UNNAMED \
    --add-opens java.base/sun.security.util=ALL-UNNAMED \
    --add-opens java.base/java.io=ALL-UNNAMED \
    --add-opens java.rmi/sun.rmi.transport=ALL-UNNAMED \
    -Dlog4j2.formatMsgNoLookups=true \
    -jar /usr/lib/unifi/lib/ace.jar \
    start
