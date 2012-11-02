#!/bin/sh

set -e

# Author: Steve Langasek <steve.langasek@canonical.com>
#
# Mark as not-for-autoremoval those kernel packages that are:
#  - the currently booted version
#  - the kernel version we've been called for
#  - the latest kernel version (determined using rules copied from the grub
#    package for deciding which kernel to boot)
# In the common case, this results in exactly two kernels saved, but it can
# result in three kernels being saved.  It's better to err on the side of
# saving too many kernels than saving too few.
#
# We generate this list and save it to /etc/apt/apt.conf.d instead of marking
# packages in the database because this runs from a postinst script, and apt
# will overwrite the db when it exits.

config_file=/etc/apt/apt.conf.d/01autoremove-kernels

installed_version="$1"
running_version="$(uname -r)"


version_test_gt ()
{
	local version_test_gt_sedexp="s/[._-]\(pre\|rc\|test\|git\|old\|trunk\)/~\1/g"
	local version_a="`echo "$1" | sed -e "$version_test_gt_sedexp"`"
	local version_b="`echo "$2" | sed -e "$version_test_gt_sedexp"`"
	dpkg --compare-versions "$version_a" gt "$version_b"
	return "$?"
}

list=$(dpkg -l 'linux-image-[0-9]*'|awk '/^ii/ { print $2 }' | sed -e's/linux-image-//')

latest_version=""
for i in $list; do
	if version_test_gt "$i" "$latest_version"; then
		latest_version="$i"
	fi
done

kernels=$(sort -u <<EOF
$latest_version
$installed_version
$running_version
EOF
)

cat > "$config_file".dpkg-new <<EOF
# File autogenerated by $0, do not edit
APT
{
  NeverAutoRemove
  {
EOF
for kernel in $kernels; do
	echo "    \"^linux-image-$kernel.*\";" >> "$config_file".dpkg-new
	echo "    \"^linux-image-extra-$kernel.*\";" >> "$config_file".dpkg-new
	echo "    \"^linux-signed-image-$kernel.*\";" >> "$config_file".dpkg-new
done
cat >> "$config_file".dpkg-new <<EOF
  };
};
EOF
mv "$config_file".dpkg-new "$config_file"
