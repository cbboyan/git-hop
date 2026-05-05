#!/bin/bash
#
# git-hop: sync git repositories at login/logout via systemd user service

### for debug:
# $ systemctl --user list-jobs
# $ systemd-analyze --user plot > file.svg

CONFDIR=$HOME/.config/git-hop
CONF=$CONFDIR/repos
GITHOP_DEBUG_LOG=/dev/null

source "$CONFDIR/config" 2>/dev/null

log_debug()   { echo "$1" >> "$GITHOP_DEBUG_LOG" 2>/dev/null; }

# log_info/log_err echo to stderr only when running interactively (not as a service)
log_info()    { logger -t git-hop "$1";             [ -t 2 ] && echo "$1" >&2;        log_debug "$1"; }
log_err()     { logger -p user.err -t git-hop "$1"; [ -t 2 ] && echo "ERROR: $1" >&2; log_debug "ERROR: $1"; }
ntfy_send() {
   # ntfy_send TITLE TAGS PRIORITY BODY
   [ -z "$GITHOP_NTFY_CHANNEL" ] && return
   curl -s \
      -H "Title: $1" \
      -H "Tags: $2" \
      -H "Priority: $3" \
      -H "Markdown: yes" \
      -d "$4" \
      ntfy.sh/$GITHOP_NTFY_CHANNEL >/dev/null 2>&1
}
ntfy_err()    { ntfy_send "⚠ git-hop error · $HOSTNAME" "rotating_light" "5" "$1"; }
log_desktop() { notify-send "git-hop" "$1" 2>/dev/null || true; }
log_error()   { PLAIN="${1//\*\*/}"; PLAIN="${PLAIN//$'\n'/ - }"; log_err "$PLAIN"; ntfy_err "$1"; log_desktop "$PLAIN"; }

git_stash()   { git stash -u -q >>"$GITHOP_DEBUG_LOG" 2>&1; }
git_unstash() { git stash pop -q >>"$GITHOP_DEBUG_LOG" 2>&1; }
git_ff()      { git merge --ff-only -q FETCH_HEAD >>"$GITHOP_DEBUG_LOG" 2>&1; }
git_merge()   { git merge --no-edit -q FETCH_HEAD >>"$GITHOP_DEBUG_LOG" 2>&1; }
git_push()    { git push -q >>"$GITHOP_DEBUG_LOG" 2>&1; }
git_add()     { git add . >>"$GITHOP_DEBUG_LOG" 2>&1; }
git_commit()  { git commit -q -a -m "git-hop $USER@$HOSTNAME" >>"$GITHOP_DEBUG_LOG" 2>&1; }
git_clone()   { git clone -q "$1" "$2" >>"$GITHOP_DEBUG_LOG" 2>&1; }

repos() {
   grep -Ev '^\s*(#|$)' "$CONF" 2>/dev/null
}

git_fetch() {
   git rev-parse @{u} >>"$GITHOP_DEBUG_LOG" 2>&1 || { log_err "no upstream configured in `pwd`"; return 1; }
   git fetch -q >>"$GITHOP_DEBUG_LOG" 2>&1        || { log_err "fetch failed (no network?) in `pwd`"; return 1; }
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
   URL="$2"
   log_info "pull: ${REPO##*/} in $1"
   if [ ! -d "$REPO" ]; then
      [ -z "$URL" ] && { log_err "pull: repo not found: $REPO"; return 1; }
      mkdir -p "`dirname "$REPO"`"
      git_clone "$URL" "$REPO" || { log_err "pull: clone failed: $URL"; return 1; }
      RESULT="cloned"
      log_info "pull: done ${REPO##*/} ($RESULT)"
      return 0
   fi
   cd "$REPO" || { log_err "pull: repo not found: $REPO"; return 1; }

   STASHED=0
   if [ -n "`git status --porcelain`" ]; then
      git_stash || { log_err "pull: stash failed in $REPO"; return 1; }
      STASHED=1
   fi

   STATE=`git_fetch` || {
      [ $STASHED -eq 1 ] && git_unstash
      return 1
   }
   log_info "pull: ${REPO##*/} is $STATE"

   case $STATE in
      even)
         RESULT="up-to-date"
         ;;
      behind)
         git_ff    || { log_err "pull: fast-forward failed in $REPO"; return 1; }
         RESULT="pulled"
         ;;
      ahead)
         git_push  || { log_err "pull: push failed in $REPO"; return 1; }
         RESULT="pushed"
         ;;
      diverged)
         git_merge || { log_error "pull: merge conflict in **${REPO##*/}**"$'\n'"Manual FIX REQUIRED"; return 1; }
         git_push  || { log_err "pull: push failed in $REPO"; return 1; }
         RESULT="merged"
         ;;
   esac

   if [ $STASHED -eq 1 ]; then
      git_unstash || { log_error "pull: stash pop conflict in **${REPO##*/}**"$'\n'"Manual FIX REQUIRED"; return 1; }
   fi

   [ $STASHED -eq 1 ] && [ "$RESULT" = "up-to-date" ] && RESULT="stashed"
   [ $STASHED -eq 1 ] && [ "$RESULT" != "stashed"   ] && RESULT="stashed+$RESULT"

   log_info "pull: done ${REPO##*/} ($RESULT)"
}

push() {
   REPO="$HOME/$1"
   log_info "push: ${REPO##*/} in $1"
   cd "$REPO" || { log_err "push: repo not found: $REPO"; return 1; }

   git_add
   if [ -n "`git status --porcelain`" ]; then
      git_commit || { log_err "push: commit failed in $REPO"; return 1; }
   fi

   STATE=`git_fetch` || { log_err "no network — changes committed locally in $REPO"; return 1; }
   log_info "push: ${REPO##*/} is $STATE"

   case $STATE in
      even)
         RESULT="up-to-date"
         ;;
      ahead)
         git_push  || { log_err "push: push failed in $REPO"; return 1; }
         RESULT="pushed"
         ;;
      behind|diverged)
         git_merge || { log_error "push: merge conflict in **${REPO##*/}**"$'\n'"Manual FIX REQUIRED"; return 1; }
         git_push  || { log_err "push: push after merge failed in $REPO"; return 1; }
         RESULT="merged"
         ;;
   esac

   log_info "push: done ${REPO##*/} ($RESULT)"
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

clone() {
   URL="$1"
   REPONAME=`basename "$URL" .git`
   git clone "$URL" || { log_err "clone: failed: $URL"; return 1; }
   add "$REPONAME"
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

log_debug ""
log_debug "@@@ $HOSTNAME @@@ `date` @@@ $@"
log_debug ""

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
         ntfy_send "↑ push · $HOSTNAME" "arrow_up,white_check_mark" "3" "$MSG"
      else
         ntfy_send "↑ push · $HOSTNAME" "arrow_up,warning" "4" "$MSG"
      fi
      exit 0
      ;;
   pull)
      NUPTODATE=0; NFAILED=0; CHANGED=""
      while read DIR URL; do
         RESULT=""
         if pull "$DIR" "$URL"; then
            [ "$RESULT" = "up-to-date" ] \
               && NUPTODATE=$((NUPTODATE+1)) \
               || CHANGED="${CHANGED:+$CHANGED, }**${DIR##*/}** $RESULT"
         else
            NFAILED=$((NFAILED+1))
         fi
      done < <(repos)
      MSG=`summarize "$CHANGED" $NUPTODATE $NFAILED`
      if [ $NFAILED -eq 0 ]; then
         ntfy_send "↓ pull · $HOSTNAME" "arrow_down,white_check_mark" "3" "$MSG"
         log_desktop "$MSG"
      else
         ntfy_send "↓ pull · $HOSTNAME" "arrow_down,warning" "4" "$MSG"
         log_desktop "$MSG — check journal"
      fi
      exit 0
      ;;
   status)
      while read DIR URL; do
         status "$DIR"
      done < <(repos)
      ;;
   clone)
      clone "$2"
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
      case $2 in
         start|stop|enable|disable) systemctl --user "$2" git-hop ;;
         status|"") systemctl --user status git-hop ;;
         *) echo "Usage: git-hop service [start|stop|enable|disable|status]" >&2; exit 1 ;;
      esac
      ;;
   log)
      journalctl --user -b USER_UNIT=git-hop.service + SYSLOG_IDENTIFIER=git-hop "${@:2}"
      ;;
   *)
      echo "Usage: git-hop <command>"
      echo ""
      echo "Commands:"
      echo "  pull      pull all repos (run at login)"
      echo "  push      commit and push all repos (run at logout)"
      echo "  status    show one-line status for each repo"
      echo "  list      list configured repos"
      echo "  clone URL clone a repo into current dir and add it to the config"
      echo "  add DIR   add a repo to the config"
      echo "  service   manage systemd service [start|stop|enable|disable|status]"
      echo "  log       show journal log (extra args passed to journalctl)"
      ;;
esac
