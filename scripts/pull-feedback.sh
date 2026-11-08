#!/bin/bash
# Copies the feedback reports (report.txt + screenshot.jpg) the app keeps on each connected
# phone into feedback-inbox/<phone>/<time>/. The phone must be unlocked and on USB or the same Wi-Fi.
set -u
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")/.."

BUNDLE=com.DNT.foodtracker.app
PHONES=("daniel:5856B74C-7851-5358-B616-802412137223" "brigitta:23A63C04-C5C9-50D2-A416-206751847BE7")

for phone in "${PHONES[@]}"; do
    name=${phone%%:*}; id=${phone#*:}
    dest="feedback-inbox/$name"
    mkdir -p "$dest"
    if xcrun devicectl device copy from --device "$id" --domain-type appDataContainer \
        --domain-identifier "$BUNDLE" --source Documents/Feedback --destination "$dest" --quiet 2>/dev/null; then
        echo "$name: $(ls "$dest" | wc -l | tr -d ' ') report(s) in $dest"
    else
        echo "$name: not reachable (locked, asleep or away) or no reports yet"
    fi
done
