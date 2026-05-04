#!/bin/bash
#
# Send one example ntfy message for each message type used by git-hop.
# Usage: test-ntfy.sh <ntfy-channel>

GITHOP_NTFY_CHANNEL="$1"

[ -z "$GITHOP_NTFY_CHANNEL" ] && { echo "Usage: $0 <ntfy-channel>" >&2; exit 1; }

ntfy_send() {
   echo "  title:    $1"
   echo "  tags:     $2"
   echo "  priority: $3"
   echo "  body:     $4"
   curl -s \
      -H "Title: $1" \
      -H "Tags: $2" \
      -H "Priority: $3" \
      -H "Markdown: yes" \
      -d "$4" \
      ntfy.sh/$GITHOP_NTFY_CHANNEL >/dev/null 2>&1
}

send() {
   echo "--- $1"
   shift
   ntfy_send "$@"
}

send "push ok" \
   "↑ push · work" "arrow_up,white_check_mark" "3" \
   "**playground** pushed, **notes** pushed | 1 up-to-date"

send "push failed" \
   "↑ push · work" "arrow_up,warning" "4" \
   "**playground** pushed | 1 up-to-date | 1 FAILED"

send "pull ok" \
   "↓ pull · home" "arrow_down,white_check_mark" "3" \
   "**playground** pulled, **work** merged | 1 up-to-date"

send "pull failed" \
   "↓ pull · home" "arrow_down,warning" "4" \
   "**notes** pulled | 2 up-to-date | 1 FAILED"

send "error: merge conflict on pull" \
   "⚠ git-hop error · work" "rotating_light" "5" \
   "pull: merge conflict in **playground**"$'\n'"Manual fix required!"

send "error: stash pop conflict" \
   "⚠ git-hop error · home" "rotating_light" "5" \
   "pull: stash pop conflict in **notes**"$'\n'"Manual fix required!"

send "error: merge conflict on push" \
   "⚠ git-hop error · work" "rotating_light" "5" \
   "push: merge conflict in **work**"$'\n'"Manual fix required!"
