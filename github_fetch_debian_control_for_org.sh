#!/bin/bash
#
# Gets a debian/control file for every repository in the given organization.
# Based on https://gist.github.com/caniszczyk/3856584#gistcomment-1888281
# (@boussou)
#
# Requirements: curl

error() {
	echo "E: $@" >&2
	exit 1
}

curl_retry() {
	for try in 1 2 3 4; do
		curl $@ && break
	done
}

ORGANIZATION=hybris-mobian
BRANCH=bullseye

TARGET="${1}"
[ -n "${TARGET}" ] || error "You should specify the target directory! (may be non existent)"

[ -e "${TARGET}" ] || mkdir -p "${TARGET}"

for i in `curl -s https://api.github.com/orgs/$ORGANIZATION/repos?per_page=200 |grep html_url|awk 'NR%2 == 0'|cut -d ':'  -f 2-3|tr -d '",'`; do
	target_url=${i/github.com/raw.githubusercontent.com}/${BRANCH}/debian/control

	if curl_retry -I "${target_url}" | head -n 1 | grep -q 200; then
		target_name="$(basename ${i})"
		echo "Found $target_name"
		mkdir -p "${TARGET}/$target_name/debian"
		curl_retry "${target_url}" -o "${TARGET}/$target_name/debian/control"
	fi
done
