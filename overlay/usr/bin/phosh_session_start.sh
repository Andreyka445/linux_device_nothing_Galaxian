#!/bin/sh
# 1. Start Secret Service (gnome-keyring)
eval $(gnome-keyring-daemon --start --components=secrets 2>/dev/null)
export SSH_AUTH_SOCK

# 2. Start on-screen keyboard (Stevia OSK)
if [ -x /usr/bin/phosh-osk-stevia ]; then
    /usr/bin/phosh-osk-stevia --allow-replacement > /tmp/stevia.log 2>&1 &
fi

# 3. Run Phosh shell in foreground
exec /usr/libexec/phosh
