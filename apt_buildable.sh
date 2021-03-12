#!/bin/bash
#
# Builds a list of buildable packages present in a directory, given
# a list of deb+deb-src repositories.
#
# Background: following the OVH SBG blaze [0], we lost control of
# the hybris-mobian repository.
# No backups were made, since things were still experimental and
# the service is easy to rebuild (software is inside a public Docker
# image, signing keys were backed up, actual source is in GitHub and
# in a bunch of hard drives :D).
# This script has been helpful to get a list of which packages can be
# rebuilt straight away.
#
# [0] https://help.ovhcloud.com/en/faq/strasbourg-incident/
#
# Requirements: apt, devscripts, equivs
#
# Usage: modify your script to your liking, add your repositories (keep
# in mind that both deb and deb-src repositories must be present), then
# run it.
# The packages printed in the output are safe to rebuild as-is, as it means
# that every dependency can be satisfied with what is present on the
# repositories.
#
# Run the script multiple times until no packages are printed anymore.
#
# Current state is stored in $PWD/REGISTRY. Remove it to start over.
#
# Do a double-check afterwards, as some complex packages might have been
# skipped.

error() {
	echo "E: $@" >&2
	exit 1
}

DIRECTORY_TO_SCAN="${1}"
# Status of already parsed packages will be stored here. Remove this
# file to start over.
REGISTRY="${PWD}/REGISTRY"

[ -e "${DIRECTORY_TO_SCAN}" ] || error "You should specify a directory to scan!"
[ -e "${REGISTRY}" ] || touch "${REGISTRY}"

tmpdir="$(mktemp -d)"
apt_config_dir="${tmpdir}/apt_config"
cache_dir="${tmpdir}/cache"
state_dir="${tmpdir}/state"
bin_dir="${tmpdir}/bin"
dpkg_root="${tmpdir}/root"

mkdir -p ${dpkg_root}/var/lib/dpkg/{updates,info}

touch "${dpkg_root}/var/lib/dpkg/status"

mkdir -p "${apt_config_dir}/sources.list.d" "${cache_dir}" "${state_dir}" "${bin_dir}"
cat > "${apt_config_dir}/sources.list" <<EOF
deb [trusted=yes] http://deb.debian.org/debian/ bullseye main contrib non-free
deb-src [trusted=yes] http://deb.debian.org/debian/ bullseye main contrib non-free
deb [trusted=yes] http://production.repo.hybris-mobian.org/ bullseye main
deb-src [trusted=yes] http://production.repo.hybris-mobian.org/ bullseye main
EOF

clean() {
	rm -rf "${tmpdir}"
}
trap clean EXIT

# Create fake dpkg executable
cat > "${bin_dir}/dpkg" <<EOF
#!/bin/sh

exec /usr/bin/dpkg \
	--force-not-root \
	--root "${dpkg_root}" \
	--log "${tmpdir}/dpkg.log" \
	\${@}
EOF

chmod +x ${bin_dir}/dpkg

export PATH="${bin_dir}:/bin:/sbin:/usr/bin:/usr/sbin"

/usr/bin/apt-get \
	--option "dir::etc=${apt_config_dir}" \
	--option "dir::cache=${cache_dir}" \
	--option "dir::state=${state_dir}" \
	--option "dir::state::status=${dpkg_root}/var/lib/dpkg/status" \
	--option "Debug::NoLocking=1" \
	update

echo -e "\n\n\n\n"

for pkg in $(find "${DIRECTORY_TO_SCAN}" -path "*debian/control"); do
	pkgname="$(basename $(dirname $(dirname ${pkg})))"

	if grep -q "^${pkgname}$" "${REGISTRY}"; then
		continue
	fi

	if [ -n "${MISSING}" ]; then
		echo ${pkgname}
		continue
	fi

	# Always recreate dpkg status file
	> "${dpkg_root}/var/lib/dpkg/status"

	mk-build-deps \
		--root fakeroot \
		--install \
		--remove \
		--tool "apt-get --option dir=${tmpdir} --option dir::etc=${apt_config_dir} --option dir::cache=${cache_dir} --option dir::state=${state_dir} --option Debug::NoLocking=1 --option dir::state::status=${dpkg_root}/var/lib/dpkg/status --yes --simulate" \
		${pkg} \
		2>&1 \
	| grep -q 'Conf .*-build-deps'
	# We need to grep on the apt-get output since the check mk-build-deps
	# does afterwards can't work since packages don't actually get installed!
	status="${?}"

	if [ "${status}" == "0" ]; then
		echo $pkgname | tee -a "${REGISTRY}"
	fi
done
