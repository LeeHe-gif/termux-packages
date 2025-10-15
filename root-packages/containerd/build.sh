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
	local -a BINARIES=(
		"containerd"
		"containerd-shim"
		"container-shim-runc-v1" # Corrected typo from previous logs if any
		"containerd-shim-runc-v2"
		"containerd-stress"
		"ctr"
	)

	# --- 2. Create Destination Directories ---
	local ZIP_DIR="$HOME/containerd-build"
	local MASSAGE_BIN_DIR="$TERMUX_PKG_MASSAGEDIR/system/bin"
	mkdir -p "$ZIP_DIR"
	mkdir -p "$MASSAGE_BIN_DIR"

	echo "Searching for, purifying, and copying binaries..."

	# --- 3. Find, Purify, and Copy Each Binary ---
	for binary in "${BINARIES[@]}"; do
		# Use 'find' to locate the binary anywhere within the build directory.
		# The -print -quit makes it stop after the first find, for efficiency.
		local binary_path
		binary_path=$(find "$TERMUX_PKG_BUILDDIR" -name "$binary" -type f -print -quit)

		if [ -n "$binary_path" ]; then
			echo "Found '$binary' at: $binary_path"

			# Purify the binary at its found location
			echo "Purifying $binary..."
			patchelf --remove-rpath "$binary_path"
			patchelf --set-rpath '/system/lib64:/vendor/lib64' "$binary_path"

			# Copy the purified binary to both destinations
			echo "Copying $binary..."
			cp -v "$binary_path" "$ZIP_DIR/"
			cp -v "$binary_path" "$MASSAGE_BIN_DIR/"
		else
			echo "Warning: Binary '$binary' not found in build directory, skipping."
		fi
	done
	echo "Purification and copy complete."

	# --- 4. Package into a Zip File ---
	echo "Creating zip archive..."
	(cd "$ZIP_DIR" && zip -r "$HOME/containerd-build.zip" ./*)
	echo "containerd-build.zip has been created in your home directory (~/)!"
}

termux_step_create_debscripts() {
    # 确保 postinst 脚本是空的，将所有初始化留给 Magisk
    cat <<- EOF > postinst
        #!/system/bin/sh
        exit 0
EOF
}
