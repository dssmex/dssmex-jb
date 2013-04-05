#!/sbin/busybox sh
BUSYBOX=/sbin/busybox
TIME=`$BUSYBOX date +"%d-%m-%Y %r"`
export PATH="/sbin:/system/xbin:/system/bin"

# delete old lupus.log
if [ -f /lupus.log ]; then
	$BUSYBOX rm -f /lupus.log
fi

# create directories with the correct permissions
$BUSYBOX mkdir -m 755 -p /system
$BUSYBOX mkdir -m 755 -p /cache
$BUSYBOX mkdir -m 755 -p /proc
$BUSYBOX mkdir -m 755 -p /sys
$BUSYBOX mkdir -m 755 -p /dev/block
$BUSYBOX mkdir -m 755 -p /dev/input

# Remove the init symlink to this script
$BUSYBOX rm -f /init

# start log
$BUSYBOX echo "*******************************************" >> /lupus.log
$BUSYBOX echo "[--Start boot @: $TIME--]" >> /lupus.log
$BUSYBOX echo "-------------------------------------------" >> /lupus.log
$BUSYBOX echo "" >> /lupus.log

#$BUSYBOX echo "[*] Correcting filepermissions in /res" >> /lupus.log
#for file in `find /res -type f`; do
#	$BUSYBOX chmod 0644 $file >> /lupus.log 2>&1
#done

# include device specific vars
source /sbin/bootrec-device

# create device nodes
$BUSYBOX mknod -m 600 /dev/block/mmcblk0 b 179 0
$BUSYBOX mknod -m 600 ${BOOTREC_SYSTEM_NODE}
$BUSYBOX mknod -m 600 ${BOOTREC_CACHE_NODE}
$BUSYBOX mknod -m 666 /dev/null c 1 3
$BUSYBOX mknod -m 600 ${BOOTREC_EVENT_NODE}

# Mount base filesystems
$BUSYBOX mount -t proc proc /proc
$BUSYBOX mount -t sysfs sysfs /sys
$BUSYBOX mount -t yaffs2 ${BOOTREC_SYSTEM} /system
$BUSYBOX mount -t yaffs2 ${BOOTREC_CACHE} /cache

$BUSYBOX echo "[CPU] Fixing frequencies at boot" >> /lupus.log
# fixing CPU clocks to avoid issues in recovery
$BUSYBOX echo 1017600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
$BUSYBOX echo 249600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

# trigger aqua-blue LED
$BUSYBOX echo 0 > ${BOOTREC_LED_RED}
$BUSYBOX echo 125 > ${BOOTREC_LED_GREEN}
$BUSYBOX echo 255 > ${BOOTREC_LED_BLUE}
# trigger double vibration for recovery
$BUSYBOX echo 90 > /sys/class/timed_output/vibrator/enable
$BUSYBOX sleep 0.3
$BUSYBOX echo 90 > /sys/class/timed_output/vibrator/enable


# keycheck
$BUSYBOX cat ${BOOTREC_EVENT} > /dev/keycheck&
$BUSYBOX sleep 1

# create lupus.prop
if [ ! -e /system/lupus.prop ]; then
	$BUSYBOX echo "#" > /system/lupus.prop
	$BUSYBOX echo "# LuPuS KERNEL PROPERTIES" >> /system/lupus.prop
	$BUSYBOX echo "#" >> /system/lupus.prop
	$BUSYBOX echo "recovery.choice=cwm" >> /system/lupus.prop
fi

# android ramdisk
$BUSYBOX echo "[ANDROID] Extracting ramdisk.cpio" >> /lupus.log

# check if SDK version
ramdisk_choice=`$BUSYBOX cat /system/build.prop | $BUSYBOX grep "ro.build.version.sdk=" | $BUSYBOX sed "s/ro.build.version.sdk=//g"`

if [[ $ramdisk_choice == "16" ]]; then
	$BUSYBOX echo "[*] Loading JB 4.1 ramdisk" >> /lupus.log
	load_image=/sbin/ramdisk.cpio.lzma
elif [[ $ramdisk_choice == "17" ]]; then
	$BUSYBOX echo "[*] Loading JB 4.2 ramdisk" >> /lupus.log
	load_image=/sbin/ramdisk-jbft.cpio.lzma
	else
	# fall back to 4.1 ramdisk
	load_image=/sbin/ramdisk.cpio.lzma
fi
$BUSYBOX sleep 2

# check which recovery was selected in LuPuS menu
recover=`$BUSYBOX grep "recovery.choice=" /system/lupus.prop | $BUSYBOX sed "s/recovery.choice=//g"`

# boot decision
if [ -s /dev/keycheck -o -e /cache/recovery/boot ]; then
	$BUSYBOX echo "" >> /lupus.log
	$BUSYBOX echo "[RECOVERY] Entering" >> /lupus.log
	$BUSYBOX rm -fr /cache/recovery/boot
	# trigger purple led
	$BUSYBOX echo 255 > ${BOOTREC_LED_RED}
	$BUSYBOX echo 0 > ${BOOTREC_LED_GREEN}
	$BUSYBOX echo 255 > ${BOOTREC_LED_BLUE}
	# trigger vibration
	$BUSYBOX echo 60 > /sys/class/timed_output/vibrator/enable
	# power off leds
	$BUSYBOX echo 0 > ${BOOTREC_LED_RED}
	$BUSYBOX echo 0 > ${BOOTREC_LED_GREEN}
	$BUSYBOX echo 0 > ${BOOTREC_LED_BLUE}

		# recovery choice
		if [[ $recover == "cwm" ]] || [[ $recover == "CWM" ]]; then
				load_image=/sbin/ramdisk-cwm.cpio.lzma >> /lupus.log
				$BUSYBOX echo 0 > /sys/module/msm_fb/parameters/align_buffer
		elif [[ $recover == "twrp" ]] || [[ $recover == "TWRP" ]]; then
				load_image=/sbin/ramdisk-twrp.cpio.lzma >> /lupus.log
				$BUSYBOX echo 0 > /sys/module/msm_fb/parameters/align_buffer
		else
				load_image=/sbin/ramdisk-cwm.cpio.lzma >> /lupus.log
				$BUSYBOX echo 0 > /sys/module/msm_fb/parameters/align_buffer
		fi

else
	# poweroff LED
	$BUSYBOX echo 0 > ${BOOTREC_LED_RED}
	$BUSYBOX echo 0 > ${BOOTREC_LED_GREEN}
	$BUSYBOX echo 0 > ${BOOTREC_LED_BLUE}
$BUSYBOX echo 1 > /sys/module/msm_fb/parameters/align_buffer
fi

# kill the keycheck process
$BUSYBOX pkill -f "$BUSYBOX cat ${BOOTREC_EVENT}"

# unpack the ramdisk image
$BUSYBOX lzcat ${load_image} | $BUSYBOX cpio -i 2>&1 >> /lupus.log


# unmount filesystems
$BUSYBOX umount /system
$BUSYBOX umount /cache
$BUSYBOX umount /proc
$BUSYBOX umount /sys
$BUSYBOX rm -fr /dev/*

exec /init
