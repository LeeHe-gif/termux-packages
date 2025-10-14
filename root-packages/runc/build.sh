TERMUX_PKG_HOMEPAGE=https://www.opencontainers.org/
TERMUX_PKG_DESCRIPTION="A tool for spawning and running containers according to the OCI specification"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_MAINTAINER="Custom Builder"
TERMUX_PKG_VERSION="1.3.0"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL=https://github.com/opencontainers/runc/archive/v${TERMUX_PKG_VERSION}.tar.gz
TERMUX_PKG_SHA256=3262492ce42bea0919ee1a2d000b6f303fd14877295bc38d094876b55fdd448b
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_BUILD_DEPENDS="libseccomp-static"
# 移除 on-device 限制（如果存在）
# TERMUX_PKG_ON_DEVICE_BUILD_NOT_SUPPORTED=true 

termux_step_make() {
	# Runc 需要链接 liblog，这是 Android 独有的。我们使用 Termux 的 stubs 绕过链接错误。
	${CC} -c -o stubs.o "$TERMUX_PKG_BUILDER_DIR/stubs.c"
	${AR} rcs liblog.a stubs.o

	# 确保 CGO 链接器能找到我们创建的 liblog.a
	export CGO_LDFLAGS="-L$TERMUX_PKG_BUILDDIR" 

	termux_setup_golang

	export GOPATH="${PWD}/go"

	mkdir -p "${GOPATH}/src/github.com/opencontainers"
	ln -sf "${TERMUX_PKG_SRCDIR}" "${GOPATH}/src/github.com/opencontainers/runc"

	# 进入源码目录并编译静态二进制文件
	cd "${GOPATH}/src/github.com/opencontainers/runc" && make static
}

termux_step_make_install() {
	cd "${GOPATH}/src/github.com/opencontainers/runc"
    
    # 核心修正：将 runc 安装到 /system/bin 对应的临时目录
	local MAGISK_BIN_DIR="${TERMUX_PREFIX}/bin" 
	
	install -Dm755 runc "${MAGISK_BIN_DIR}/runc"
    
    echo "Runc installed to temporary path: ${MAGISK_BIN_DIR}/runc"
}

termux_step_create_debscripts() {
	# 彻底清空 postinst 脚本，将所有说明留给 Magisk 模块
	{
		echo "#!/system/bin/sh"
		echo "exit 0"
	} > postinst
}
