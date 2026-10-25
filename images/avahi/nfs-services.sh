#!/bin/sh
# Usage: nfs-services.sh ETAB DIR
#
# Replaces the nfs-*.service files in DIR with one Avahi service per path
# exported in ETAB, the export table exportfs keeps in /var/lib/nfs/etab.
# A missing ETAB leaves no NFS services.
set -eu

etab=$1
dir=$2

rm -f "$dir"/nfs-*.service
[ -r "$etab" ] || exit 0

# Each line is a path and one client's options, so a path exported to several
# clients repeats. exportfs escapes whitespace in paths as octal, as in \040.
awk '!seen[$1]++ { print $1 }' "$etab" | while IFS= read -r escaped; do
	path=$(printf '%b' "$escaped")
	xml=$(printf '%s' "$path" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
	file=$dir/nfs$(printf '%s' "$path" | tr -c 'A-Za-z0-9' '-').service
	# One service per path: clients read only the first path key of a TXT
	# record (RFC 6763 section 6.4).
	cat >"$file.tmp" <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h $xml</name>
  <service>
    <type>_nfs._tcp</type>
    <port>2049</port>
    <txt-record>path=$xml</txt-record>
  </service>
</service-group>
EOF
	mv "$file.tmp" "$file"
done
