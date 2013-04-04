#!/sbin/busybox sh
# init-links.sh must be run with "source" from init.sh for passing ${load_image}
# you can comment next 2 lines if it works
#exec > /data/!init-links.log 2>&1;
#set -x;

# Setting the variables
sb=/sbin/busybox
xb=/system/xbin/busybox

# Remount / read-write just as precaution
$sb mount -o remount rw /
# Correct permissions on recovery if it exists
if [ -f "/sbin/recovery" ] && [ ! -e $sb ]; then
	$sb chown 0.2000 /sbin/recovery
	$sb chmod 04755 /sbin/recovery
fi
# Correct permissions on kernel busybox
$sb chown 0.2000 $sb
$sb chmod 04755 $sb

# e2fsck workaround for smaller ramdisk
if [ ! -e "/sbin/e2fsck" ]; then $sb mv -f /sbin/e2fsck-cwm /sbin/e2fsck; fi

# sqlite3 set permissions
$sb chown 0.2000 /sbin/sqlite3
$sb chmod 0755 /sbin/sqlite3

# Create a symlink in /sbin for each command kernel busybox knows
for sym in `$sb --list`; do
	# Don't overwrite existing files (non-symlinks) not to mess up recoveries
	# In recovery busybox is linked to recovery so linking everything to ...
	# ... /sbin/busybox is ok and will make ramdisks smaller
	if [ ! -f "/sbin/$sym" ]; then
		$sb ln -sf $sb /sbin/$sym
	fi
done


# Check not to generate user busybox symlinks in recoveries
if [ ! "`$sb echo ${load_image} | $sb grep -i cwm`" ] && [ ! "`$sb echo ${load_image} | $sb grep -i twrp`" ]; then

	# Remount /system read-write as precaution
	$sb mount -o remount rw /system

	# If $xb exists, set permissions before check if its valid
	if [ -e $xb ]; then
		$sb chown 0.2000 $xb
		$sb chmod 04755 $xb
	fi
	# Check if user busybox exists and if it's valid, if not symlink to kernel one
	if [ ! -e $xb ] || [ ! "`$xb | $sb grep "\-\-list"`" ]; then
		$sb rm -f $xb
		$sb ln -sf $sb $xb
		$sb chown 0.2000 $xb
		$sb chmod 04755 $xb
	fi

	# Create a symlink in /system/xbin for each command user busybox knows
	for sym in `$xb --list`; do
		if [ "`$sb readlink /system/xbin/$sym`" != "$xb" ]; then
			$sb ln -sf $xb /system/xbin/$sym
		fi
	done
fi


# Some things busybox can not do...

# pigz symlinks for twrp (only twrp has pigz, and no need for symlinks in xbin)
if [ -e /sbin/pigz ]; then
	$sb ln -sf /sbin/pigz /sbin/unpigz
	$sb ln -sf /sbin/unpigz /sbin/gunzip
	$sb ln -sf /sbin/pigz /sbin/gzip
fi


$sb ln -sf /init /sbin/ueventd
#$sb ln -sf /sbin/lupus /system/xbin/lupus

