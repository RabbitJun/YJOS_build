#!/bin/sh
#
# Copyright (C) 2017 OVH OverTheBox
# Copyright (C) 2017-2025 Ycarus (Yannick Chabanois) <ycarus@zugaina.org> for OpenMPTCProuter project
# Copyright (C) 2025-2026 RabbitJun build
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

set -e

umask 0022
unset GREP_OPTIONS SED

_get_repo() (
	mkdir -p "$1"
	cd "$1"
	[ -d .git ] || git init
	if git remote get-url origin >/dev/null 2>/dev/null; then
		git remote set-url origin "$2"
	else
		git remote add origin "$2"
	fi
	git fetch origin -f
	git fetch origin --tags -f
	git checkout -f "origin/$3" -B "build" 2>/dev/null || git checkout -f "$3" -B "build"
)

OMR_DIST=${OMR_DIST:-openmptcprouter}
OMR_HOST=${OMR_HOST:-$(curl -sS ifconfig.co)}
OMR_PORT=${OMR_PORT:-80}
OMR_KEEPBIN=${OMR_KEEPBIN:-no}
OMR_IMG=${OMR_IMG:-yes}
OMR_LOG=${OMR_LOG:-no}

OMR_PACKAGES=${OMR_PACKAGES:-full}
OMR_ALL_PACKAGES=${OMR_ALL_PACKAGES:-no}
OMR_TARGET=${OMR_TARGET:-x86_64}
OMR_TARGET_CONFIG="config-$OMR_TARGET"
UPSTREAM=${UPSTREAM:-no}

SYSLOG=${SYSLOG:-logd}
OMR_KERNEL=${OMR_KERNEL:-6.12}
SHORTCUT_FE=${SHORTCUT_FE:-no}
DISABLE_FAILSAFE=${DISABLE_FAILSAFE:-no}

OMR_RELEASE=${OMR_RELEASE:-$(git describe --tags `git rev-list --tags --max-count=1` | tail -1)}
OMR_REPO=${OMR_REPO:-http://$OMR_HOST:$OMR_PORT/release/$OMR_RELEASE-$OMR_KERNEL/$OMR_TARGET}

OMR_FEED_URL="${OMR_FEED_URL:-https://github.com/ysurac/openmptcprouter-feeds}"
OMR_FEED_SRC="${OMR_FEED_SRC:-develop}"

CUSTOM_FEED_URL="${CUSTOM_FEED_URL}"
CUSTOM_FEED_URL_BRANCH="${CUSTOM_FEED_URL_BRANCH:-main}"

OMR_OPENWRT=${OMR_OPENWRT:-default}
OMR_OPENWRT_GIT=${OMR_OPENWRT_GIT:-https://github.com}
OMR_FORCE_DSA=${OMR_FORCE_DSA:-0}

OMR_LIBC=${OMR_LIBC:-musl}

# For custom builds, use OMR_TARGET directly as OMR_REAL_TARGET
OMR_REAL_TARGET=${OMR_TARGET}

if [ "$ONLY_PREPARE" != "yes" ]; then

	if [ "$OMR_OPENWRT" = "default" ]; then
		if [ "$OMR_KERNEL" = "6.12" ] || [ "$OMR_KERNEL" = "6.18" ]; then
			_get_repo "$OMR_TARGET/${OMR_KERNEL}/source" ${OMR_OPENWRT_GIT}/openwrt/openwrt "openwrt-25.12"
			_get_repo feeds/${OMR_KERNEL}/packages ${OMR_OPENWRT_GIT}/openwrt/packages "openwrt-25.12"
			_get_repo feeds/${OMR_KERNEL}/luci ${OMR_OPENWRT_GIT}/openwrt/luci "openwrt-25.12"
			_get_repo feeds/${OMR_KERNEL}/routing ${OMR_OPENWRT_GIT}/openwrt/routing "openwrt-25.12"
		fi
	elif [ "$OMR_OPENWRT" = "master" ]; then
		_get_repo "$OMR_TARGET/${OMR_KERNEL}/source" ${OMR_OPENWRT_GIT}/openwrt/openwrt "main"
		_get_repo feeds/${OMR_KERNEL}/packages ${OMR_OPENWRT_GIT}/openwrt/packages "main"
		_get_repo feeds/${OMR_KERNEL}/luci ${OMR_OPENWRT_GIT}/openwrt/luci "main"
		_get_repo feeds/${OMR_KERNEL}/routing ${OMR_OPENWRT_GIT}/openwrt/routing "main"
	else
		_get_repo "$OMR_TARGET/${OMR_KERNEL}/source" ${OMR_OPENWRT_GIT}/openwrt/openwrt "${OMR_OPENWRT}"
		_get_repo feeds/${OMR_KERNEL}/packages ${OMR_OPENWRT_GIT}/openwrt/packages "${OMR_OPENWRT}"
		_get_repo feeds/${OMR_KERNEL}/luci ${OMR_OPENWRT_GIT}/openwrt/luci "${OMR_OPENWRT}"
		_get_repo feeds/${OMR_KERNEL}/routing ${OMR_OPENWRT_GIT}/openwrt/routing "${OMR_OPENWRT}"
	fi
fi

if [ -z "$OMR_FEED" ]; then
	OMR_FEED=feeds/openmptcprouter
	[ "$ONLY_PREPARE" != "yes" ] && _get_repo "$OMR_FEED" "$OMR_FEED_URL" "$OMR_FEED_SRC"
fi

if [ -n "$CUSTOM_FEED_URL" ] && [ -z "$CUSTOM_FEED" ]; then
	CUSTOM_FEED=feeds/${OMR_KERNEL}/${OMR_DIST}
	[ "$ONLY_PREPARE" != "yes" ] && _get_repo "$CUSTOM_FEED" "$CUSTOM_FEED_URL" "$CUSTOM_FEED_URL_BRANCH"
fi

if [ -n "$1" ] && [ -f "$OMR_FEED/$1/Makefile" ]; then
	OMR_DIST=$1
	shift 1
fi

if [ "$OMR_KEEPBIN" = "no" ]; then 
	rm -rf "$OMR_TARGET/${OMR_KERNEL}/source/bin"
fi
if [ "$ONLY_GET_REPO" = "yes" ]; then
	exit 0
fi
rm -rf "$OMR_TARGET/${OMR_KERNEL}/source/files" "$OMR_TARGET/${OMR_KERNEL}/source/tmp"

echo "rm -rf $OMR_TARGET/${OMR_KERNEL}/source/package/boot/uboot-mvebu"
rm -rf "${OMR_TARGET}/${OMR_KERNEL}/source/package/boot/uboot-mvebu"
[ "${OMR_KERNEL}" = "6.12" ] && {
	echo "rm -rf $OMR_TARGET/${OMR_KERNEL}/source/package/boot/uboot-ipq40xx"
	rm -rf "${OMR_TARGET}/${OMR_KERNEL}/source/package/boot/uboot-ipq40xx"
}

echo "cp -rf common/* $OMR_TARGET/${OMR_KERNEL}/source"
cp -rf common/* "$OMR_TARGET/${OMR_KERNEL}/source"
echo "cp -rf ${OMR_KERNEL}/* $OMR_TARGET/${OMR_KERNEL}/source"
cp -rf ${OMR_KERNEL}/* "$OMR_TARGET/${OMR_KERNEL}/source"

if [ -n "$CUSTOM_FEED" ] && [ -d ${CUSTOM_FEED}/source/${OMR_TARGET}/${OMR_KERNEL} ]; then
	echo "Copy ${CUSTOM_FEED}/source/${OMR_TARGET}/${OMR_KERNEL}/* to $OMR_TARGET/${OMR_KERNEL}/source"
	cp -rf ${CUSTOM_FEED}/source/${OMR_TARGET}/${OMR_KERNEL}/* "$OMR_TARGET/${OMR_KERNEL}/source"
fi

cat >> "$OMR_TARGET/${OMR_KERNEL}/source/package/base-files/files/etc/banner" <<EOF
-----------------------------------------------------
 PACKAGE:     $OMR_DIST
 VERSION:     $OMR_RELEASE
 TARGET:      $OMR_TARGET
 ARCH:        $OMR_REAL_TARGET

 BUILD REPO:  $(git config --get remote.origin.url)
 BUILD DATE:  $(date -u)
-----------------------------------------------------
EOF

cat > "$OMR_TARGET/${OMR_KERNEL}/source/feeds.conf" <<EOF
src-link packages $(readlink -f feeds/${OMR_KERNEL}/packages)
src-link luci $(readlink -f feeds/${OMR_KERNEL}/luci)
src-link openmptcprouter $(readlink -f "$OMR_FEED")
EOF

if [ -n "$CUSTOM_FEED" ]; then
	echo "src-link ${OMR_DIST} $(readlink -f ${CUSTOM_FEED})" >> "$OMR_TARGET/${OMR_KERNEL}/source/feeds.conf"
fi

if [ "$OMR_KERNEL" != "6.12" ] && [ "$OMR_KERNEL" != "6.18" ]; then
	if [ "$OMR_DIST" = "openmptcprouter" ]; then
		cat > "$OMR_TARGET/${OMR_KERNEL}/source/package/system/opkg/files/customfeeds.conf" <<-EOF
		src/gz openwrt_luci http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/luci
		src/gz openwrt_packages http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/packages
		src/gz openwrt_base http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/base
		src/gz openwrt_routing http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/routing
		src/gz openwrt_telephony http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/telephony
		EOF
	elif [ -n "$OMR_PACKAGES_URL" ]; then
		cat > "$OMR_TARGET/${OMR_KERNEL}/source/package/system/opkg/files/customfeeds.conf" <<-EOF
		src/gz openwrt_luci ${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/luci
		src/gz openwrt_packages ${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/packages
		src/gz openwrt_base ${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/base
		src/gz openwrt_routing ${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/routing
		src/gz openwrt_telephony ${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/telephony
		EOF
	else

		cat > "$OMR_TARGET/${OMR_KERNEL}/source/package/system/opkg/files/customfeeds.conf" <<-EOF
		src/gz openwrt_luci http://downloads.openwrt.org/releases/packages-24.10/${OMR_REAL_TARGET}/luci
		src/gz openwrt_packages http://downloads.openwrt.org/releases/packages-24.10/${OMR_REAL_TARGET}/packages
		src/gz openwrt_base http://downloads.openwrt.org/releases/packages-24.10/${OMR_REAL_TARGET}/base
		src/gz openwrt_routing http://downloads.openwrt.org/releases/packages-24.10/${OMR_REAL_TARGET}/routing
		src/gz openwrt_telephony http://downloads.openwrt.org/releases/packages-24.10/${OMR_REAL_TARGET}/telephony
		EOF
	fi
else
	if [ "$OMR_DIST" = "openmptcprouter" ]; then
		cat > "$OMR_TARGET/${OMR_KERNEL}/source/package/system/apk/files/customfeeds.list" <<-EOF
		http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/luci/packages.adb
		http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/packages/packages.adb
		http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/base/packages.adb
		http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/routing/packages.adb
		http://packages.openmptcprouter.com/${OMR_RELEASE}/${OMR_REAL_TARGET}/telephony/packages.adb
		EOF
	elif [ -n "$OMR_PACKAGES_URL" ]; then
		cat > "$OMR_TARGET/${OMR_KERNEL}/source/package/system/apk/files/customfeeds.list" <<-EOF
		${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/luci/packages.adb
		${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/packages/packages.adb
		${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/base/packages.adb
		${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/routing/packages.adb
		${OMR_PACKAGES_URL}/${OMR_RELEASE}/${OMR_REAL_TARGET}/telephony/packages.adb
		EOF
	else
		cat > "$OMR_TARGET/${OMR_KERNEL}/source/package/system/apk/files/customfeeds.list" <<-EOF
		http://downloads.openwrt.org/snapshots/packages/${OMR_REAL_TARGET}/luci/packages.adb
		http://downloads.openwrt.org/snapshots/packages/${OMR_REAL_TARGET}/packages/packages.adb
		http://downloads.openwrt.org/snapshots/packages/${OMR_REAL_TARGET}/base/packages.adb
		http://downloads.openwrt.org/snapshots/packages/${OMR_REAL_TARGET}/routing/packages.adb
		http://downloads.openwrt.org/snapshots/packages/${OMR_REAL_TARGET}/telephony/packages.adb
		EOF
	fi

fi

if [ -f $OMR_TARGET_CONFIG ]; then
	cat "$OMR_TARGET_CONFIG" config -> "$OMR_TARGET/${OMR_KERNEL}/source/.config" <<-EOF
	CONFIG_IMAGEOPT=y
	CONFIG_VERSIONOPT=y
	CONFIG_VERSION_DIST="$OMR_DIST"
	CONFIG_VERSION_REPO="$OMR_REPO"
	CONFIG_VERSION_NUMBER="${OMR_RELEASE}-${OMR_KERNEL}"
	EOF
else
	cat config -> "$OMR_TARGET/${OMR_KERNEL}/source/.config" <<-EOF
	CONFIG_IMAGEOPT=y
	CONFIG_VERSIONOPT=y
	CONFIG_VERSION_DIST="$OMR_DIST"
	CONFIG_VERSION_REPO="$OMR_REPO"
	CONFIG_VERSION_NUMBER="${OMR_RELEASE}-${OMR_FEED_SRC}-$(git -C "$OMR_FEED" rev-parse --short HEAD)"
	EOF
fi

if [ "$OMR_ALL_PACKAGES" = "yes" ]; then
	echo 'CONFIG_ALL=y' >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo 'CONFIG_ALL_NONSHARED=y' >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi
if [ "$OMR_IMG" = "yes" ] && [ "$OMR_TARGET" = "x86_64" ]; then 
	echo 'CONFIG_VDI_IMAGES=y' >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo 'CONFIG_VMDK_IMAGES=y' >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo 'CONFIG_VHDX_IMAGES=y' >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi

if [ "$OMR_LOG" = "yes" ]; then 
	echo 'CONFIG_BUILD_LOG=y' >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi

if [ "$DISABLE_FAILSAFE" = "yes" ]; then
	rm -f "$OMR_TARGET/${OMR_KERNEL}/source/package/base-files/files/lib/preinit/30_failsafe_wait"
	rm -f "$OMR_TARGET/${OMR_KERNEL}/source/package/base-files/files/lib/preinit/40_run_failsafe_hook"
fi

echo "CONFIG_PACKAGE_${OMR_DIST}-${OMR_PACKAGES}=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"

if [ "$SYSLOG" = "busybox-syslogd" ]; then
	echo "CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOG=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOGD_CFG=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOGD_PRECISE_TIMESTAMP=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_BUSYBOX_CONFIG_FEATURE_SYSLOGD_READ_BUFFER_SIZE=256" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_BUSYBOX_CONFIG_FEATURE_REMOTE_LOG=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_BUSYBOX_CONFIG_SYSLOGD=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_BUSYBOX_CONFIG_LOGREAD=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_PACKAGE_syslogd=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
elif [ "$SYSLOG" = "syslog-ng" ]; then
	echo "CONFIG_DEFAULT_syslog-ng=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_PACKAGE_syslog-ng=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
elif [ "$SYSLOG" = "logd" ]; then
	echo "CONFIG_DEFAULT_logd=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_PACKAGE_logd=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi

if [ "$OMR_LIBC" = "glibc" ]; then
	echo "CONFIG_LIBC_USE_GLIBC=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "# CONFIG_LIBC_MUSL is not set" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_USE_GLIBC=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo 'CONFIG_LIBC="glibc"' >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi

if [ "$SHORTCUT_FE" = "yes" ]; then
	echo "CONFIG_PACKAGE_kmod-fast-classifier=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_PACKAGE_kmod-shortcut-fe=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_PACKAGE_kmod-shortcut-fe-cm=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "CONFIG_PACKAGE_shortcut-fe-drv=y" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
else
	echo "# CONFIG_PACKAGE_kmod-fast-classifier is not set" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "# CONFIG_PACKAGE_kmod-shortcut-fe-cm is not set" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "# CONFIG_PACKAGE_kmod-shortcut-fe is not set" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
	echo "# CONFIG_PACKAGE_shortcut-fe is not set" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi
if [ "$OMR_TARGET" != "x86_64" ] && [ "$OMR_TARGET" != "x86" ]; then
	echo "# CONFIG_PACKAGE_kmod-r8125 is not set" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"

	echo "CONFIG_PACKAGE_kmod-r8168=m" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi
if [ "$OMR_KERNEL" = "6.12" ]; then
	echo "# CONFIG_PACKAGE_kmod-rtl8812au-ct is not set" >> "$OMR_TARGET/${OMR_KERNEL}/source/.config"
fi

cd "$OMR_TARGET/${OMR_KERNEL}/source"

if [ "$OMR_KERNEL" != "6.12" ] && [ "$OMR_KERNEL" != "6.18" ]; then
	echo "Checking if No check patch is set or not"
	if ! patch -Rf -N -p1 -s --dry-run < ../../../patches/nocheck.patch; then
		echo "apply..."
		patch -N -p1 -s < ../../../patches/nocheck.patch
	fi
	echo "Done"
else
	echo "Checking if No check patch is set or not"
	if ! patch -Rf -N -p1 -s --dry-run < ../../../patches/nocheck.6.6.patch; then
		echo "apply..."
		patch -N -p1 -s < ../../../patches/nocheck.6.6.patch
	fi
	echo "Done"
fi

if [ "$OMR_KERNEL" != "6.18" ]; then
	echo "Checking if Nanqinlang patch is set or not"
	if ! patch -Rf -N -p1 -s --dry-run < ../../../patches/nanqinlang.patch; then
		echo "apply..."
		patch -N -p1 -s < ../../../patches/nanqinlang.patch
	fi
	echo "Done"
fi

echo "Checking if smsc75xx patch is set or not"
if ! patch -Rf -N -p1 -s --dry-run < ../../../patches/smsc75xx.patch; then
	echo "apply..."
	patch -N -p1 -s < ../../../patches/smsc75xx.patch
fi
echo "Done"

if [ -f package/boot/uboot-rockchip/patches/100-rockchip-rk3328-Add-support-for-FriendlyARM-NanoPi-R.patch ]; then
	rm -f package/boot/uboot-rockchip/patches/100-rockchip-rk3328-Add-support-for-FriendlyARM-NanoPi-R.patch
fi

NOT_SUPPORTED="0"

if [ "$OMR_KERNEL" = "6.12" ]; then
	echo "Set to kernel 6.12 for x86 arch"
	find target/linux/x86 -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.6%KERNEL_PATCHVER:=6.12%g' {} \;
	echo "Done"
	echo "Set to kernel 6.12 for mediatek"
	find target/linux/mediatek -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.6%KERNEL_PATCHVER:=6.12%g' {} \;
	echo "Done"
	echo "Set to kernel 6.12 for bcm27xx"
	find target/linux/bcm27xx -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.6%KERNEL_PATCHVER:=6.12%g' {} \;
	echo "Done"
	echo "Set to kernel 6.12 for qualcommax"
	find target/linux/qualcommax -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.6%KERNEL_PATCHVER:=6.12%g' {} \;
	echo "Done"
	echo "Set to kernel 6.12 for ipq40xx"
	find target/linux/ipq40xx -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.6%KERNEL_PATCHVER:=6.12%g' {} \;
	echo "Done"
	echo "Set to kernel 6.12 for ipq806x"
	find target/linux/ipq806x -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.6%KERNEL_PATCHVER:=6.12%g' {} \;
	echo "Done"
	echo "CONFIG_VERSION_CODE=6.12" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-gpio-button-hotplug is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-meraki-mx100 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-gpio-nct5104d is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8168 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8125 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8125-rss is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8126 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8126-rss is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-button-hotplug is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-cryptodev is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-trelay is not set" >> ".config"
	echo "# CONFIG_PACKAGE_464xlat is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-nat46 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-ath10k-ct-smallbuffers is not set" >> ".config"
	echo "CONFIG_BPF_TOOLCHAIN=y" >> ".config"
	echo "CONFIG_BPF_TOOLCHAIN_HOST=y" >> ".config"
	echo "CONFIG_KERNEL_BPF_EVENTS=y" >> ".config"
	echo "CONFIG_KERNEL_DEBUG_INFO=y" >> ".config"
	echo "CONFIG_KERNEL_DEBUG_INFO_BTF=y" >> ".config"
	echo "CONFIG_KERNEL_DEBUG_INFO_BTF_MODULES=y" >> ".config"
	echo "# CONFIG_KERNEL_DEBUG_INFO_REDUCED is not set" >> ".config"
	echo "CONFIG_KERNEL_MODULE_ALLOW_BTF_MISMATCH=y" >> ".config"
	echo 'CONFIG_EXTRA_OPTIMIZATION="-fno-caller-saves -fno-plt -Wno-stringop-truncation -Wno-stringop-overread -Wno-calloc-transposed-args"' >> ".config"
	echo 'CONFIG_PACKAGE_apk-openssl=y' >> ".config"
	if [ ! -d target/linux/`sed -nE 's/CONFIG_TARGET_([a-z0-9]*)=y/\1/p' ".config" | tr -d "\n"`/patches-6.12 ]; then
		echo "Sorry but kernel 6.12 is not supported on your arch yet"
		NOT_SUPPORTED="1"
	fi
fi
if [ "$OMR_KERNEL" = "6.18" ]; then
	echo "Set to kernel 6.18 for x86 arch"
	find target/linux/x86 -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.6%KERNEL_PATCHVER:=6.18%g' {} \;
	find target/linux/x86 -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.12%KERNEL_PATCHVER:=6.18%g' {} \;
	echo "Done"
	echo "Set to kernel 6.18 for mediatek"
	find target/linux/mediatek -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.12%KERNEL_PATCHVER:=6.18%g' {} \;
	echo "Done"
	echo "Set to kernel 6.18 for bcm27xx"
	find target/linux/bcm27xx -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.12%KERNEL_PATCHVER:=6.18%g' {} \;
	echo "Done"
	echo "Set to kernel 6.18 for qualcommax"
	find target/linux/qualcommax -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.12%KERNEL_PATCHVER:=6.18%g' {} \;
	echo "Done"
	echo "Set to kernel 6.18 for ipq40xx"
	find target/linux/ipq40xx -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.12%KERNEL_PATCHVER:=6.18%g' {} \;
	echo "Done"
	echo "Set to kernel 6.18 for ipq806x"
	find target/linux/ipq806x -type f -name Makefile -exec sed -i 's%KERNEL_PATCHVER:=6.12%KERNEL_PATCHVER:=6.18%g' {} \;
	echo "Done"
	echo "CONFIG_VERSION_CODE=6.18" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-gpio-button-hotplug is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-meraki-mx100 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-gpio-nct5104d is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8168 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8125 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8125-rss is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8126 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-r8126-rss is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-button-hotplug is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-cryptodev is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-trelay is not set" >> ".config"
	echo "# CONFIG_PACKAGE_464xlat is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-nat46 is not set" >> ".config"
	echo "# CONFIG_PACKAGE_kmod-ath10k-ct-smallbuffers is not set" >> ".config"
	echo "CONFIG_BPF_TOOLCHAIN=y" >> ".config"
	echo "CONFIG_BPF_TOOLCHAIN_HOST=y" >> ".config"
	echo "CONFIG_KERNEL_BPF_EVENTS=y" >> ".config"
	echo "CONFIG_KERNEL_DEBUG_INFO=y" >> ".config"
	echo "CONFIG_KERNEL_DEBUG_INFO_BTF=y" >> ".config"
	echo "CONFIG_KERNEL_DEBUG_INFO_BTF_MODULES=y" >> ".config"
	echo "# CONFIG_KERNEL_DEBUG_INFO_REDUCED is not set" >> ".config"
	echo "CONFIG_KERNEL_MODULE_ALLOW_BTF_MISMATCH=y" >> ".config"
	echo 'CONFIG_EXTRA_OPTIMIZATION="-fno-caller-saves -fno-plt -Wno-stringop-truncation -Wno-stringop-overread -Wno-calloc-transposed-args"' >> ".config"

	rm -rf package/kernel/rtl8812au-ct
	rm -rf package/kernel/r8101
	
	echo 'CONFIG_PACKAGE_apk-openssl=y' >> ".config"
	if [ ! -d target/linux/`sed -nE 's/CONFIG_TARGET_([a-z0-9]*)=y/\1/p' ".config" | tr -d "\n"`/patches-6.18 ]; then
		echo "Sorry but kernel 6.18 is not supported on your arch yet"
		NOT_SUPPORTED="1"
	fi
fi


cd "../../.."
rm -rf feeds/${OMR_KERNEL}/luci/modules/luci-mod-network

if [ -d feeds/${OMR_KERNEL}/${OMR_DIST}/luci-mod-status ]; then
	rm -rf feeds/${OMR_KERNEL}/luci/modules/luci-mod-status
elif [ "$OMR_KERNEL" = "6.12" ] || [ "$OMR_KERNEL" = "6.18" ]; then
	cd feeds/${OMR_KERNEL}
	if ! patch -Rf -N -p1 -s --dry-run < ../../patches/luci-syslog-6.10.patch; then
		patch -N -p1 -s < ../../patches/luci-syslog-6.10.patch
	fi
	cd -
fi

[ -d feeds/${OMR_KERNEL}/${OMR_DIST}/luci-app-statistics ] && rm -rf feeds/${OMR_KERNEL}/luci/applications/luci-app-statistics
[ -d feeds/${OMR_KERNEL}/${OMR_DIST}/luci-proto-modemmanager ] && rm -rf feeds/${OMR_KERNEL}/luci/protocols/luci-proto-modemmanager

[ -d ${OMR_FEED}/libgpiod ] && rm -rf feeds/${OMR_KERNEL}/packages/libs/libgpiod
[ -d ${OMR_FEED}/iperf3 ] && rm -rf feeds/${OMR_KERNEL}/packages/net/iperf3
[ -d ${OMR_FEED}/golang ] && {
	rm -rf feeds/${OMR_KERNEL}/packages/lang/golang
	cp -r ${OMR_FEED}/golang feeds/${OMR_KERNEL}/packages/lang/
}
[ -d ${OMR_FEED}/openvpn ] && rm -rf feeds/${OMR_KERNEL}/packages/net/openvpn
[ -d ${OMR_FEED}/iproute2 ] && rm -rf feeds/${OMR_KERNEL}/packages/network/utils/iproute2
[ -d ${CUSTOM_FEED}/syslog-ng ] && rm -rf feeds/${OMR_KERNEL}/packages/admin/syslog-ng

echo "Add Occitan translation support"
cd feeds/${OMR_KERNEL}
if ! patch -Rf -N -p1 -s --dry-run < ../../patches/luci-occitan.patch; then
	patch -N -p1 -s < ../../patches/luci-occitan.patch

fi

cd ../..
[ -d $OMR_FEED/luci-base/po/oc ] && cp -rf $OMR_FEED/luci-base/po/oc feeds/${OMR_KERNEL}/luci/modules/luci-base/po/
echo "Done"

cd "$OMR_TARGET/${OMR_KERNEL}/source"
echo "Update feeds index"
cp .config .config.keep
scripts/feeds clean
scripts/feeds update -a

if [ "$OMR_ALL_PACKAGES" = "yes" ]; then
	scripts/feeds install -a -d m -p packages
	scripts/feeds install -a -d m -p luci
fi
if [ -n "$CUSTOM_FEED" ]; then
	scripts/feeds install -a -d m -p openmptcprouter
	scripts/feeds install -a -d y -f -p ${OMR_DIST}
else
	scripts/feeds install -a -d y -f -p openmptcprouter
fi


cp .config.keep .config
scripts/feeds install kmod-macremapper
echo "Done"

if [ ! -f "../../../$OMR_TARGET_CONFIG" ] || [ "$NOT_SUPPORTED" = "1" ]; then
	echo "Target $OMR_TARGET not found ! You have to configure and compile your kernel manually."
	exit 1
fi
[ "$ONLY_PREPARE" = "yes" ] && exit 0
echo "Building $OMR_DIST for the target $OMR_TARGET with kernel ${OMR_KERNEL}"
make defconfig
make IGNORE_ERRORS=m "$@"
echo "Done"
