#!/sbin/busybox sh

# LuPuS Script JB (v1)

BUSYBOX=/sbin/busybox
TIME=`$BUSYBOX date +"%d-%m-%Y %r"`
export PATH="/sbin:/system/xbin:/system/bin"
MOUNT="/system"

	$BUSYBOX mount -o remount rw /
	# add to existing lupuslog
	$BUSYBOX echo "" >> /lupus.log
	$BUSYBOX echo "===========================================" >> /lupus.log
	$BUSYBOX echo "" >> /lupus.log
	$BUSYBOX echo "      Running LuPuS Script JellyBean" >> /lupus.log
	$BUSYBOX echo "-------------------------------------------" >> /lupus.log
	$BUSYBOX echo "" >> /lupus.log

	# check if /system exist as mountpoint.
	$BUSYBOX grep -qs $MOUNT /proc/mounts
	if [[ $? == "0" ]]; then
		$BUSYBOX echo "[CONTINUE] Mounting system as R/W" >> /lupus.log
		# mount system and create lupuslog
		$BUSYBOX mount -o remount rw /system
	fi

	$BUSYBOX echo "" >> /lupus_log
	$BUSYBOX echo "[WIFI] Checking for LuPuS wifi modules " >> /lupus.log
	WiFi_OK=1;

	for mdl in `$BUSYBOX find /res/modules -name *.ko`; do
	if [ "`$BUSYBOX readlink /system/lib/modules/${mdl#/res/modules/}`" != "$mdl" ]; then
		WiFi_OK=0;
	fi
	done

	if [ "$WiFi_OK" -eq 0 ]; then
		$BUSYBOX echo "[*] Setting up wifi modules.." >> /lupus.log
		#remove old modules, and create links to right ones
		if [ -e /system/lib/modules ]; then
			$BUSYBOX echo "[*] Backing up old modules as modules.old" >> /lupus.log
			$BUSYBOX rm -rf /system/lib/modules.old 2>/dev/null
			$BUSYBOX mv -f /system/lib/modules /system/lib/modules.old
			$BUSYBOX rm -rf /system/lib/modules 2>/dev/null
		fi
		#create dirs
		$BUSYBOX echo "[*] Making modules directory.." >> /lupus.log
		$BUSYBOX mkdir -p /system/lib/modules
		$BUSYBOX chmod -R 755 /system/lib/modules
		#link proper modules
		$BUSYBOX ln -sf /res/modules/wl12xx_sdio.ko /system/lib/modules/wl12xx_sdio.ko
		$BUSYBOX ln -sf /res/modules/wl12xx.ko /system/lib/modules/wl12xx.ko
		$BUSYBOX insmod /system/lib/modules/wl12xx_sdio.ko
		$BUSYBOX insmod /system/lib/modules/wl12xx.ko		
	else
		$BUSYBOX echo "[*] Existing modules found.." >> /lupus.log
	fi


	$BUSYBOX echo "" >> /lupus.log
	$BUSYBOX echo "[*] Permissions set on lupus menu" >> /lupus.log
	$BUSYBOX chmod 0755 /lupus

	$BUSYBOX echo "" >> /lupus.log
	# Remount as Read ONLY
	$BUSYBOX echo "" >> /lupus.log
	$BUSYBOX echo "[END] Mounting system as R/O" >> /lupus.log
	$BUSYBOX mount -o remount ro /system
	$BUSYBOX echo "-------------------------------------------" >> /lupus.log
	$BUSYBOX echo "[---Finished @:$TIME---]" >> /lupus.log
	$BUSYBOX echo "*******************************************" >> /lupus.log
	$BUSYBOX cat /lupus.log > /data/local/tmp/lupus.log
	$BUSYBOX rm -f /lupus.log
	$BUSYBOX mount -o remount ro /
	# copy the log to /data/local/tmp/ for longer period keeping
	$BUSYBOX mount -o remount ro /system
	return 0
