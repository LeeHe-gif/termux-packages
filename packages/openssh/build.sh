TERMUX_PKG_HOMEPAGE=https://www.openssh.com/
TERMUX_PKG_DESCRIPTION="Secure shell for logging into a remote machine, customized for Android system paths."
TERMUX_PKG_LICENSE="BSD"
TERMUX_PKG_MAINTAINER="Custom Builder"
TERMUX_PKG_VERSION="10.2p1"
TERMUX_PKG_SRCURL=https://github.com/openssh/openssh-portable/archive/refs/tags/V_$(sed 's/\./_/g; s/p/_P/g' <<< $TERMUX_PKG_VERSION).tar.gz
TERMUX_PKG_SHA256=8d3083bca4864cbc760bfcc3e67d86d401e27faa5eaafa1482c2316f5d5186b3
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_DEPENDS="krb5, ldns, libandroid-support, libedit, openssl, zlib"
TERMUX_PKG_SUGGESTS=""
TERMUX_PKG_CONFLICTS="dropbear"
TERMUX_PKG_ON_DEVICE_BUILD_NOT_SUPPORTED=true 

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--prefix=/system
--bindir=/system/bin
--sbindir=/system/bin
--sysconfdir=/system/etc/sshd
--with-pid-dir=/data/ssh/var/run
--disable-etc-default-login
--disable-lastlog
--disable-libutil
--disable-pututline
--disable-pututxline
--disable-strip
--disable-utmp
--disable-utmpx
--disable-wtmp
--disable-wtmpx
--libexecdir=/system/bin
--with-cflags=-Dfd_mask=int
--with-ldns
--with-libedit
--with-mantype=man
--with-privsep-user=shell
--with-privsep-path=/data/ssh/var/empty
--without-ssh1
--without-stackprotect
--with-xauth=/system/bin/xauth
--with-kerberos5
--with-default-path=/system/bin
--with-default-shell=/system/bin/sh
--with-superuser-path=/system/bin
ac_cv_func_endgrent=yes
ac_cv_func_fmt_scaled=no
ac_cv_func_getlastlogxbyname=no
ac_cv_func_readpassphrase=no
ac_cv_func_strnvis=no
ac_cv_header_sys_un_h=yes
ac_cv_lib_crypt_crypt=no
ac_cv_search_getrrsetbyname=no
ac_cv_func_bzero=yes
"

# 仅构建核心二进制文件
TERMUX_PKG_MAKE_BUILD_TARGET="sshd ssh ssh-keygen scp sftp sftp-server"
TERMUX_PKG_MAKE_INSTALL_TARGET="" 
TERMUX_PKG_RM_AFTER_INSTALL=""
TERMUX_PKG_CONFFILES="" 

termux_pkg_auto_update() {
	local latest_tag version
	latest_tag="$(termux_github_api_get_tag "${TERMUX_PKG_SRCURL}" newest-tag)"
	[[ -z "${latest_tag}" ]] && termux_error_exit "ERROR: Unable to get tag from ${TERMUX_PKG_SRCURL}"
	version="$(sed -E 's/V_([0-9]+)_([0-9]+)_P([0-9]+)/\1.\2p\3/' <<< "${latest_tag}")"
	termux_pkg_upgrade_version "$version"
}

termux_step_pre_configure() {
	autoreconf
	CPPFLAGS+=" -DHAVE_ATTRIBUTE__SENTINEL__=1 -DBROKEN_SETRESGID"
	LD=$CC
}

termux_step_post_configure() { 
	:
}

termux_step_make_install() {
	mkdir -p ~/sshdbuild
	cd ~/.termux-build/openssh/build/
	zip sshdbuild.zip scp sftp sftp-server ssh ssh-add ssh-agent sshd sshd-auth sshd-session ssh-keygen ssh-keyscan ssh-pkcs11-helper ssh-sk-helper
	mv sshdbuild.zip ~/sshdbuild
	echo "ZIP done! check it in ~/sshdbuild !"
	:
}

termux_step_post_make_install() { 
	:
}

termux_step_post_massage() {
	:
}

termux_step_create_debscripts() {
	:
}
