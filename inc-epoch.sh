#!/bin/bash
# Adds or increments epoch variable in PKGBUILDs for packages that are changed
# from upstream.

set -o nounset
set -o errtrace
set -o errexit
set -o pipefail

die() {
    echo "$1"
    exit 1
}

usage() {
    echo "$0 [--upstream <refspec>] [--] [file] ..."
    exit 0
}

if ! cdup="$(git rev-parse --show-cdup)"; then
    die "No repository here!"
fi

upstream="upstream/master"

while [[ -n "${1:-}" ]]; do
    case "$1" in
        -u|--upstream)
            shift
            upstream="$1" || die "Missing argument"
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
    shift
done

git rev-parse --verify --quiet "$upstream" &>/dev/null || die "Invalid refspec $upstream"

declare -a add=() inc=()
while IFS='' read -r p; do
    if [[ "$(< "$p")" =~ $'\n'epoch=([0-9]*)$'\n' ]]; then
        diff="$(git diff -U0 "$upstream" -- "$p")"
        if [[ ! "$diff" =~ $'\n'\+epoch= ]]; then
            inc+=("$p")
        fi
    else
        add+=("$p")
    fi
done < <(\
    git diff --name-only "$upstream" -- "${@:-.}" \
    | cut -d '/' -f 1 | sort | uniq | sed 's/$/\/PKGBUILD/' \
    | while IFS='' read -r f; do f="${cdup}${f}"; [[ -f "$f" ]] && echo "$f"; done
)
(( ${#inc[@]} )) && sed -ri 's/^epoch=([0-9]+)/echo "epoch=$((\1+1))"/e' "${inc[@]}"
(( ${#add[@]} )) && sed -i '/^pkgrel=/a\'$'\n''epoch=1'$'\n' "${add[@]}"

exit 0

# vim: set ts=4 sw=4 et ai:
