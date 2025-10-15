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
	echo "Entering custom install and purification step..."

	# --- 1. Define the Binaries to Purify and Package ---
	# These are the files you found in the build output directory.
	local -a BINARIES=(
		"containerd"
		"containerd-shim"
		"containerd-shim-runc-v1"
		"containerd-shim-runc-v2"
		"containerd-stress"
		"ctr"
	)

	# --- 2. Locate the Build Directory ---
	# This is the path where the compiled binaries are located.
	local BUILD_DIR="${TERMUX_PKG_BUILDDIR}/bin"
	
	# --- 3. Purify Binaries with patchelf ---
	echo "Purifying compiled binaries with patchelf..."
	for binary in "${BINARIES[@]}"; do
		if [ -f "$BUILD_DIR/$binary" ]; then
			echo "Purifying $binary..."
			# First, remove the old, incorrect RPATH set by the build system.
			patchelf --remove-rpath "$BUILD_DIR/$binary"
			# Then, set a new, correct RPATH for a native Android system.
			patchelf --set-rpath '/system/lib64:/vendor/lib64' "$BUILD_DIR/$binary"
		else
			echo "Warning: Binary $binary not found in $BUILD_DIR, skipping."
		fi
	done
	echo "Purification complete."

	# --- 4. Package into a Zip File ---
	local ZIP_DIR="$HOME/containerd-build"
	mkdir -p "$ZIP_DIR"
	echo "Copying purified binaries to $ZIP_DIR..."
	for binary in "${BINARIES[@]}"; do
		if [ -f "$BUILD_DIR/$binary" ]; then
			cp -v "$BUILD_DIR/$binary" "$ZIP_DIR/"
		fi
	done

	echo "Creating zip archive..."
	(cd "$ZIP_DIR" && zip -r "$HOME/containerd-build.zip" ./*)
	echo "containerd-build.zip has been created in your home directory (~/)!"
	
	# --- 5. Appease the Build System to Avoid Errors ---
	# We copy some files to the official installation directory so that the
	# build script doesn't complain about an empty package.
	local MASSAGE_BIN_DIR="$TERMUX_PKG_MASSAGEDIR/system/bin"
	mkdir -p "$MASSAGE_BIN_DIR"
	for binary in "${BINARIES[@]}"; do
		if [ -f "$BUILD_DIR/$binary" ]; then
			cp -v "$BUILD_DIR/$binary" "$MASSAGE_BIN_DIR/"
		fi
	done
}

termux_step_create_debscripts() {
    # 确保 postinst 脚本是空的，将所有初始化留给 Magisk
    cat <<- EOF > postinst
        #!/system/bin/sh
        exit 0
EOF
}
