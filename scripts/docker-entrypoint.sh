#!/bin/sh
set -e

# Capture runtime UID/GID from environment variables, defaulting to 1000
PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}

# Adjust the node user's UID/GID if they differ from the runtime request
# and fix volume ownership only when a remap is needed
changed=0

if [ "$(id -u node)" -ne "$PUID" ]; then
    echo "Updating node UID to $PUID"
    usermod -o -u "$PUID" node
    changed=1
fi

if [ "$(id -g node)" -ne "$PGID" ]; then
    echo "Updating node GID to $PGID"
    groupmod -o -g "$PGID" node
    usermod -g "$PGID" node
    changed=1
fi

# Railway-friendly: always ensure /paperclip is owned by node.
# Railway mounts volumes as root by default; the original condition only
# chowned on UID/GID remap, leaving the volume unwritable for the node user.
chown -R node:node /paperclip || true

# Sync agent instructions from image to volume (combines _shared.md + each agent)
INST_SRC="/app/agent-instructions"
INST_DST="/paperclip/instances/default/agent-instructions"
if [ -d "$INST_SRC" ] && [ -f "$INST_SRC/_shared.md" ]; then
    mkdir -p "$INST_DST"
    cp "$INST_SRC/_shared.md" "$INST_DST/_shared.md"
    SHARED=$(cat "$INST_SRC/_shared.md")
    for f in "$INST_SRC"/*.md; do
        slug=$(basename "$f" .md)
        [ "$slug" = "_shared" ] && continue
        printf '%s\n\n---\n\n%s\n' "$SHARED" "$(cat "$f")" > "$INST_DST/$slug.md"
        echo "Synced agent instructions: $slug.md"
    done
    chown -R node:node "$INST_DST" || true
fi

exec gosu node "$@"
