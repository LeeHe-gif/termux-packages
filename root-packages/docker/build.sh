TERMUX_PKG_HOMEPAGE=https://docker.com
TERMUX_PKG_DESCRIPTION="Set of products that use OS-level virtualization to deliver software in packages called containers."
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION=1:24.0.6
TERMUX_PKG_REVISION=4
LIBNETWORK_COMMIT=67e0588f1ddfaf2faf4c8cae8b7ea2876434d91c
DOCKER_GITCOMMIT=ed223bc
TERMUX_PKG_SRCURL=(https://github.com/moby/moby/archive/v${TERMUX_PKG_VERSION:2}.tar.gz
		https://github.com/docker/cli/archive/v${TERMUX_PKG_VERSION:2}.tar.gz
		https://github.com/moby/libnetwork/archive/${LIBNETWORK_COMMIT}.tar.gz)
TERMUX_PKG_DEPENDS="containerd, libdevmapper, resolv-conf"
TERMUX_PKG_SHA256=(29a8ee54e9ea008b40eebca42dec8b67ab257eb8ac175f67e79c110e4187d7d2
		c1a4a580ced3633e489c5c9869a20198415da44df7023fdc200d425cdf5fa652
		4ab6f6c97db834c2eedc053d06c4d32d268f33051b8148098b4a0e8eee51e97b)
TERMUX_PKG_CONFFILES="etc/docker/daemon.json"
TERMUX_PKG_SERVICE_SCRIPT=("dockerd" "exec su -c \"PATH=\$PATH $TERMUX_PREFIX/bin/dockerd 2>&1\"")
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_SKIP_SRC_EXTRACT=true

termux_step_get_source() {
	local PKG_SRCURL=(${TERMUX_PKG_SRCURL[@]})
	local PKG_SHA256=(${TERMUX_PKG_SHA256[@]})

	if [ ${#PKG_SRCURL[@]} != ${#PKG_SHA256[@]} ]; then
		termux_error_exit "Error: length of TERMUX_PKG_SRCURL isn't equal to length of TERMUX_PKG_SHA256."
	fi

	# download and extract packages into its own folder inside $TERMUX_PKG_SRCDIR
	mkdir -p "$TERMUX_PKG_CACHEDIR"
	mkdir -p "$TERMUX_PKG_SRCDIR"
	for i in $(seq 0 $(( ${#PKG_SRCURL[@]} - 1 ))); do
		# Archives from moby/moby and docker/cli have same name, so cache them as {moby,cli}-v...
		local file="${TERMUX_PKG_CACHEDIR}/$(echo ${PKG_SRCURL[$i]}|cut -d"/" -f 5)-$(basename ${PKG_SRCURL[$i]})"
		termux_download "${PKG_SRCURL[$i]}" "$file" "${PKG_SHA256[$i]}"
		tar xf "$file" -C "$TERMUX_PKG_SRCDIR"
	done

	# delete trailing -$TERMUX_PKG_VERSION from folder name
	# so patches become portable across different versions
	cd "$TERMUX_PKG_SRCDIR"
	for folder in $(ls); do
		if [ ! $folder == ${folder%%-*} ]; then
			mv $folder ${folder%%-*}
		fi
	done
}

termux_step_pre_configure() {
	# setup go build environment
	termux_setup_golang
	export GO111MODULE=auto
}

termux_step_make() {
	# BUILD DOCKERD DAEMON
	echo -n "Building dockerd daemon..."
	(
	set -e
	cd moby

	# issue the build command
	export DOCKER_GITCOMMIT
	export DOCKER_BUILDTAGS='exclude_graphdriver_btrfs exclude_graphdriver_devicemapper exclude_graphdriver_quota selinux exclude_graphdriver_aufs'
	AUTO_GOPATH=1 PREFIX='' hack/make.sh dynbinary
	)
	echo " Done!"

	# BUILD DOCKER-PROXY BINARY FROM LIBNETWORK
	echo -n "Building docker-proxy from libnetwork..."
	(
	set -e

	# fix path locations to build with go
	mkdir -p go/src/github.com/docker
	mv libnetwork go/src/github.com/docker
	mkdir libnetwork
	mv go libnetwork
	export GOPATH="${PWD}/libnetwork/go"
	cd "${GOPATH}/src/github.com/docker/libnetwork"

	# issue the build command
	go build -o docker-proxy github.com/docker/libnetwork/cmd/proxy
	)
	echo " Done!"

	# BUILD DOCKER-CLI CLIENT
	echo -n "Building docker-cli client..."
	(
	set -e

	# fix path locations to build with go
	mkdir -p go/src/github.com/docker
	mv cli go/src/github.com/docker
	mkdir cli
	mv go cli
	export GOPATH="${PWD}/cli/go"
	cd "${GOPATH}/src/github.com/docker/cli"

	# issue the build command
	export VERSION=v${TERMUX_PKG_VERSION}-ce
	export DISABLE_WARN_OUTSIDE_CONTAINER=1
	# 移除所有可能指向 TERMUX_PREFIX 的 LDFLAGS 引用
	# export LDFLAGS="-L ${TERMUX_PREFIX}/lib -r ${TERMUX_PREFIX}/lib" 
	make -j ${TERMUX_PKG_MAKE_PROCESSES} dynbinary
	unset GOOS GOARCH CGO_LDFLAGS CC CXX CFLAGS CXXFLAGS LDFLAGS
	make -j ${TERMUX_PKG_MAKE_PROCESSES} manpages
	)
	echo " Done!"
}

termux_step_make_install() {
	# 安装路径修正：使用 /system/bin 和 /data/docker 绝对路径

	local DOCKER_DATA_ROOT="/data/docker"
	local DOCKER_RUN_ROOT="/data/docker/run"
	local DOCKER_ETC_ROOT="/system/etc/docker"
	local MAGISK_BIN_ROOT="${TERMUX_PREFIX}/bin" # 最终在 Magisk 模块中的 /system/bin

	# 1. 安装核心二进制文件到模块的 /system/bin
	install -Dm 700 moby/bundles/dynbinary-daemon/dockerd ${TERMUX_PREFIX}/libexec/dockerd
	install -Dm 700 libnetwork/go/src/github.com/docker/libnetwork/docker-proxy ${MAGISK_BIN_ROOT}/docker-proxy
	install -Dm 700 cli/go/src/github.com/docker/cli/build/docker-android-* ${MAGISK_BIN_ROOT}/docker

	# 2. 创建 /system/etc/docker 配置目录 (Magisk Overlay)
	mkdir -p "${DOCKER_ETC_ROOT}"

	# 3. 修正 daemon.json 并安装
	sed -e "s|@TERMUX_PREFIX@|${DOCKER_DATA_ROOT}|g" \
		-e "s|/lib/docker|/|g" \
		-e "s|/var/run/docker|/run|g" \
		"${TERMUX_PKG_BUILDER_DIR}"/daemon.json > "${DOCKER_ETC_ROOT}"/daemon.json
	chmod 600 "${DOCKER_ETC_ROOT}"/daemon.json
	
	# 4. 移除 dockerd 启动脚本的 TERMUX 专用逻辑
	sed -e "s|@TERMUX_PREFIX@|$MAGISK_BIN_ROOT|g" \
		"${TERMUX_PKG_BUILDER_DIR}/dockerd.sh" > "${MAGISK_BIN_ROOT}/dockerd.sh"
	chmod 700 "${MAGISK_BIN_ROOT}/dockerd.sh"

	# 5. 安装 man pages (保留在 Termux 路径，不影响 Magisk 运行)
	install -Dm 600 -t ${TERMUX_PREFIX}/share/man/man1 cli/go/src/github.com/docker/cli/man/man1/*
	install -Dm 600 -t ${TERMUX_PREFIX}/share/man/man5 cli/go/src/github.com/docker/cli/man/man5/*
	install -Dm 600 -t ${TERMUX_PREFIX}/share/man/man8 cli/go/src/github.com/docker/cli/man/man8/*
}

termux_step_post_make_install() {
	# Docker 不需要 Termux 的 runit 服务，我们依赖 Magisk service.sh
	# 移除 Termux 服务的 cleanup 脚本
	rm -rf $TERMUX_PREFIX/var/service/dockerd
}

termux_step_create_debscripts() {
	cat <<- EOF > postinst
		#!${TERMUX_PREFIX}/bin/sh
		echo 'NOTE: Docker files are compiled for Magisk Overlay deployment.'
		echo 'Manual setup via service.sh is required.'
	EOF
}
