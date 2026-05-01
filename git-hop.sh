#!/bin/bash
#
# git-hop: sync git repositories at login/logout via systemd user service

### for debug:
# $ systemctl --user list-jobs
# $ systemd-analyze --user plot > file.svg

CONFDIR=$HOME/.config/git-hop
CONF=$CONFDIR/repos

source "$CONFDIR/config" 2>/dev/null

# log_info/log_err echo to stderr only when running interactively (not as a service)
log_info()    { logger -t git-hop "$1";             [ -t 2 ] && echo "$1" >&2; }
log_err()     { logger -p user.err -t git-hop "$1"; [ -t 2 ] && echo "ERROR: $1" >&2; }
ntfysend() {
   # ntfysend TITLE TAGS PRIORITY BODY
   [ -z "$NTFY_CHANNEL" ] && return
   curl -s \
      -H "Title: $1" \
      -H "Tags: $2" \
      -H "Priority: $3" \
      -H "Markdown: yes" \
      -d "$4" \
      ntfy.sh/$NTFY_CHANNEL >/dev/null 2>&1
}
log_ntfy_err() { ntfysend "⚠ git-hop error · $HOSTNAME" "rotating_light" "5" "$1"; }
log_desktop() { notify-send "git-hop" "$1" 2>/dev/null; }

repos() {
   grep -Ev '^\s*(#|$)' "$CONF" 2>/dev/null
}

fetch() {
   git rev-parse @{u} >/dev/null 2>&1 || { log_err "no upstream configured in `pwd`"; return 1; }
   git fetch -q 2>/dev/null            || { log_err "fetch failed (no network?) in `pwd`"; return 1; }
   LOCAL=`git rev-parse HEAD`
   REMOTE=`git rev-parse @{u}`
   BASE=`git merge-base HEAD @{u}`
   if   [ "$LOCAL" = "$REMOTE" ]; then echo "even"
   elif [ "$LOCAL" = "$BASE"   ]; then echo "behind"
   elif [ "$REMOTE" = "$BASE"  ]; then echo "ahead"
   else                                echo "diverged"
   fi
}

pull() {
   REPO="$HOME/$1"
   log_info "pull: $REPO"
   cd "$REPO" || { log_err "pull: repo not found: $REPO"; return 1; }

   STASHED=0
   if [ -n "`git status --porcelain`" ]; then
      git stash -q 2>/dev/null || { log_err "pull: stash failed in $REPO"; return 1; }
      STASHED=1
   fi

   STATE=`fetch` || {
      [ $STASHED -eq 1 ] && git stash pop -q 2>/dev/null
      return 1
   }
   log_info "pull: $STATE in $REPO"

   case $STATE in
      even)
         RESULT="up-to-date"
         ;;
      behind)
         git merge --ff-only -q FETCH_HEAD 2>/dev/null \
            || { log_err "pull: fast-forward failed in $REPO"; return 1; }
         RESULT="pulled"
         ;;
      ahead)
         git push -q 2>/dev/null \
            || { log_err "pull: push failed in $REPO"; return 1; }
         RESULT="pushed"
         ;;
      diverged)
         git merge --no-edit -q FETCH_HEAD 2>/dev/null \
            || {
               log_err "pull: merge conflict in $REPO — manual fix required"
               log_ntfy_err "merge conflict in **$REPO** — manual fix required"
               log_desktop "Merge conflict in $REPO — manual fix required"
               return 1
            }
         git push -q 2>/dev/null \
            || { log_err "pull: push after merge failed in $REPO"; return 1; }
         RESULT="merged"
         ;;
   esac

   if [ $STASHED -eq 1 ]; then
      git stash pop -q 2>/dev/null || {
         log_err "pull: stash pop conflict in $REPO — manual fix required"
         log_ntfy_err "stash pop conflict in **$REPO** — manual fix required"
         log_desktop "Stash pop conflict in $REPO — manual fix required"
         return 1
      }
   fi

   log_info "pull: done $REPO ($RESULT)"
}

push() {
   REPO="$HOME/$1"
   log_info "push: $REPO"
   cd "$REPO" || { log_err "push: repo not found: $REPO"; return 1; }

   git add -q . 2>/dev/null
   git commit -q -a -m "git-hop $HOSTNAME" >/dev/null 2>&1

   STATE=`fetch` || { log_ntfy_err "no network — changes committed locally in $REPO"; return 1; }
   log_info "push: $STATE in $REPO"

   case $STATE in
      even)
         RESULT="up-to-date"
         ;;
      ahead)
         git push -q 2>/dev/null \
            || { log_err "push: push failed in $REPO"; return 1; }
         RESULT="pushed"
         ;;
      behind|diverged)
         git merge --no-edit -q FETCH_HEAD 2>/dev/null \
            || {
               log_err "push: merge conflict in $REPO — manual fix required"
               log_ntfy_err "merge conflict in **$REPO** — manual fix required"
               return 1
            }
         git push -q 2>/dev/null \
            || { log_err "push: push after merge failed in $REPO"; return 1; }
         RESULT="merged"
         ;;
   esac

   log_info "push: done $REPO ($RESULT)"
}

status() {
   REPO="$HOME/$1"
   cd "$REPO" || { printf "%-40s  ERROR: not found\n" "$1"; return 1; }
   INFO=`git status -sb 2>/dev/null`
   BRANCH=`echo "$INFO" | head -1 | sed 's/^## //'`
   NCHANGED=`echo "$INFO" | tail -n +2 | grep -c .` || true
   case "$BRANCH" in
      *\[*) ;;
      *)    [ "$NCHANGED" -eq 0 ] && BRANCH="up-to-date" ;;
   esac
   if [ "$NCHANGED" -gt 0 ]; then
      printf "%-40s  %s  (%d changed)\n" "$1" "$BRANCH" "$NCHANGED"
   else
      printf "%-40s  %s\n" "$1" "$BRANCH"
   fi
}

add() {
   REPO=`realpath "$1" 2>/dev/null` || { log_err "add: directory not found: $1"; return 1; }
   git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 \
      || { log_err "add: not a git repo: $REPO"; return 1; }
   URL=`git -C "$REPO" remote get-url origin 2>/dev/null` \
      || { log_err "add: no origin remote in $REPO"; return 1; }
   case "$REPO" in
      $HOME/*) RELDIR="${REPO#$HOME/}" ;;
      *) log_err "add: repo must be under $HOME: $REPO"; return 1 ;;
   esac
   grep -q "^$RELDIR" "$CONF" 2>/dev/null \
      && { log_err "add: already in config: $RELDIR"; return 1; }
   mkdir -p "$CONFDIR"
   echo "$RELDIR  $URL" >> "$CONF"
   log_info "add: $RELDIR  $URL"
}

summarize() {
   # args: CHANGED NUPTODATE NFAILED
   MSG=""
   [ -n "$1" ]    && MSG="$1"
   [ "$2" -gt 0 ] && MSG="${MSG:+$MSG | }${2} up-to-date"
   [ "$3" -gt 0 ] && MSG="${MSG:+$MSG | }${3} FAILED"
   echo "$MSG"
}

case $1 in
   push)
      NUPTODATE=0; NFAILED=0; CHANGED=""
      while read DIR URL; do
         RESULT=""
         if push "$DIR"; then
            [ "$RESULT" = "up-to-date" ] \
               && NUPTODATE=$((NUPTODATE+1)) \
               || CHANGED="${CHANGED:+$CHANGED, }**${DIR##*/}** $RESULT"
         else
            NFAILED=$((NFAILED+1))
         fi
      done < <(repos)
      MSG=`summarize "$CHANGED" $NUPTODATE $NFAILED`
      if [ $NFAILED -eq 0 ]; then
         ntfysend "↑ push · $HOSTNAME" "arrow_up,white_check_mark" "3" "$MSG"
      else
         ntfysend "↑ push · $HOSTNAME" "arrow_up,warning" "4" "$MSG"
      fi
      ;;
   pull)
      NUPTODATE=0; NFAILED=0; CHANGED=""
      while read DIR URL; do
         RESULT=""
         if pull "$DIR"; then
            [ "$RESULT" = "up-to-date" ] \
               && NUPTODATE=$((NUPTODATE+1)) \
               || CHANGED="${CHANGED:+$CHANGED, }**${DIR##*/}** $RESULT"
         else
            NFAILED=$((NFAILED+1))
         fi
      done < <(repos)
      MSG=`summarize "$CHANGED" $NUPTODATE $NFAILED`
      if [ $NFAILED -eq 0 ]; then
         ntfysend "↓ pull · $HOSTNAME" "arrow_down,white_check_mark" "3" "$MSG"
         log_desktop "$MSG"
      else
         ntfysend "↓ pull · $HOSTNAME" "arrow_down,warning" "4" "$MSG"
         log_desktop "$MSG — check journal"
      fi
      ;;
   status)
      while read DIR URL; do
         status "$DIR"
      done < <(repos)
      ;;
   add)
      add "$2"
      ;;
   list)
      repos | while read DIR URL; do
         echo "$DIR  $URL"
      done
      ;;
   service)
      systemctl --user status git-hop
      ;;
   log)
      journalctl --user -t git-hop "${@:2}"
      ;;
   *)
      echo "Usage: git-hop <command>"
      echo ""
      echo "Commands:"
      echo "  pull      pull all repos (run at login)"
      echo "  push      commit and push all repos (run at logout)"
      echo "  status    show one-line status for each repo"
      echo "  list      list configured repos"
      echo "  add DIR   add a repo to the config"
      echo "  service   show systemd service status"
      echo "  log       show journal log (extra args passed to journalctl)"
      ;;
esac
