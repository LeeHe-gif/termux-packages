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
	echo "Entering custom install step using your direct path..."

	# --- 1. Define the EXACT Path You Found ---
	# This is the "simple method" - no searching, just go straight to the location.
	local BUILD_DIR_EXACT="$HOME/.termux-build/containerd/build/go/src/github.com/containerd/containerd/bin"

	# A safety check to make sure the directory exists
	if [ ! -d "$BUILD_DIR_EXACT" ]; then
		echo "ERROR: The expected build output directory does not exist!"
		echo "Expected path: $BUILD_DIR_EXACT"
		exit 1
	fi
	
	echo "Found binaries in: $BUILD_DIR_EXACT"

	# --- 2. Purify Binaries in Place ---
	echo "Purifying compiled binaries with patchelf..."
	for binary in "$BUILD_DIR_EXACT"/*; do
		# Check if it's a file and not a directory or zip file
		if [ -f "$binary" ] && [[ "$binary" != *.zip ]]; then
			echo "Purifying $(basename "$binary")..."
			patchelf --remove-rpath "$binary"
			patchelf --set-rpath '/system/lib64:/vendor/lib64' "$binary"
		fi
	done
	echo "Purification complete."

	# --- 3. Package into a Zip File (Your Exact Method) ---
	echo "Creating zip archive from $BUILD_DIR_EXACT..."
	# We cd into the directory, zip everything, then cd back.
	(cd "$BUILD_DIR_EXACT" && zip "$HOME/containerd.zip" ./*)
	echo "containerd.zip has been created in your home directory (~/)!"
	
	# --- 4. Appease the Build System ---
	# We still copy the purified files to the massage dir to avoid the final error.
	local MASSAGE_BIN_DIR="$TERMUX_PKG_MASSAGEDIR/system/bin"
	mkdir -p "$MASSAGE_BIN_DIR"
	cp -v "$BUILD_DIR_EXACT"/* "$MASSAGE_BIN_DIR/"
}

termux_step_create_debscripts() {
    # 确保 postinst 脚本是空的，将所有初始化留给 Magisk
    cat <<- EOF > postinst
        #!/system/bin/sh
        exit 0
EOF
}
