TERMUX_PKG_HOMEPAGE=https://containerd.io/
TERMUX_PKG_DESCRIPTION="An open and reliable container runtime"
TERMUX_PKG_LICENSE="Apache-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION=1.6.21
TERMUX_PKG_REVISION=5
TERMUX_PKG_SRCURL=git+https://github.com/containerd/containerd
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_DEPENDS="runc"
TERMUX_PKG_CONFFILES="etc/containerd/config.toml"

termux_step_post_get_source() {
	echo "github.com/cpuguy83/go-md2man/v2" >> vendor/modules.txt
}

termux_step_make() {
	# setup go build environment
	termux_setup_golang
	go env -w GO111MODULE=auto
	export GOPATH="${PWD}/go"
	mkdir -p "${GOPATH}/src/github.com/containerd"
	ln -sf "${TERMUX_PKG_SRCDIR}" "${GOPATH}/src/github.com/containerd/containerd"
	cd "${GOPATH}/src/github.com/containerd/containerd"

	# issue the build command
	export BUILDTAGS=no_btrfs
	SHIM_CGO_ENABLED=1 make -j ${TERMUX_PKG_MAKE_PROCESSES}
	(unset GOOS GOARCH CGO_LDFLAGS CC CXX CFLAGS CXXFLAGS LDFLAGS
	make -j ${TERMUX_PKG_MAKE_PROCESSES} man)

}

termux_step_make_install() {
        local binaries_to_package=(containerd containerd-shim-runc-v1 containerd-stress ctr containerd-shim containerd-shim-runc-v2)

        echo "Purifying compiled binaries with patchelf..."
        for bin in "${binaries_to_package[@]}"; do
                if [ -f "$TERMUX_PKG_BUILDDIR/$bin" ]; then
                        echo "Purifying $bin..."
                        # 强行擦除硬编码的 Termux RPATH，替换为安卓系统的标准库路径
                        patchelf --set-rpath "/system/lib64:/vendor/lib64" "$TERMUX_PKG_BUILDDIR/$bin"
                fi
        done
        echo "Purification complete."

        local user_zip_dir=~/containerd-build
        mkdir -p "$user_zip_dir"
        local system_check_dir="$TERMUX_PKG_MASSAGEDIR/system/bin"
        mkdir -p "$system_check_dir"

        echo "Copying purified binaries..."
        for bin in "${binaries_to_package[@]}"; do
                if [ -f "$TERMUX_PKG_BUILDDIR/$bin" ]; then
                        cp -v "$TERMUX_PKG_BUILDDIR/$bin" "$user_zip_dir/"
                        cp -v "$TERMUX_PKG_BUILDDIR/$bin" "$system_check_dir/"
                else
                        echo "Warning: Binary '$bin' not found in build directory."
                fi
        done

        echo "Creating zip archive..."
        cd "$user_zip_dir"
        zip -r ~/containerd-build.zip .

        echo "containerd.zip has been created in your home directory (~/)!"
}

termux_step_create_debscripts() {
    # 确保 postinst 脚本是空的，将所有初始化留给 Magisk
    cat <<- EOF > postinst
        #!/system/bin/sh
        exit 0
EOF
}
