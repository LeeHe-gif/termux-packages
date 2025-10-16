TERMUX_PKG_HOMEPAGE=https://invisible-island.net/ncurses/
TERMUX_PKG_DESCRIPTION="Library for text-based user interfaces in a terminal-independent manner"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
# This references a commit in https://github.com/ThomasDickey/ncurses-snapshots, specifically
# https://github.com/ThomasDickey/ncurses-snapshots/commit/${_SNAPSHOT_COMMIT}
# Check the commit description to see which version a commit belongs to - correct version
# is checked in termux_step_pre_configure(), so the build will fail on a mistake.
# Using this simplifies things (no need to avoid downloading and applying patches manually),
# and uses github is a high available hosting.
_SNAPSHOT_COMMIT=a480458efb0662531287f0c75116c0e91fe235cb

# The subshell leaving the value in the outer scope unchanged is the point here.
# shellcheck disable=SC2031
TERMUX_PKG_VERSION=(6.5.20240831
                    9.31
                    "$(. "$TERMUX_SCRIPTDIR/x11-packages/kitty/build.sh"; echo "$TERMUX_PKG_VERSION")"
                    "$(. "$TERMUX_SCRIPTDIR/x11-packages/alacritty/build.sh"; echo "$TERMUX_PKG_VERSION")"
                    "$(. "$TERMUX_SCRIPTDIR/x11-packages/foot/build.sh"; echo "$TERMUX_PKG_VERSION")")
TERMUX_PKG_REVISION=3
# shellcheck disable=SC2031
TERMUX_PKG_SRCURL=("https://github.com/ThomasDickey/ncurses-snapshots/archive/${_SNAPSHOT_COMMIT}.tar.gz"
                   "https://dist.schmorp.de/rxvt-unicode/Attic/rxvt-unicode-${TERMUX_PKG_VERSION[1]}.tar.bz2"
                   "$(. "$TERMUX_SCRIPTDIR/x11-packages/kitty/build.sh"; echo "$TERMUX_PKG_SRCURL")"
                   "$(. "$TERMUX_SCRIPTDIR/x11-packages/alacritty/build.sh"; echo "$TERMUX_PKG_SRCURL")"
                   "$(. "$TERMUX_SCRIPTDIR/x11-packages/foot/build.sh"; echo "$TERMUX_PKG_SRCURL")")
# shellcheck disable=SC2031
TERMUX_PKG_SHA256=(ec6122c3b8ab930d1477a1dbfd90299e9f715555a98b6e6805d5ae1b0d72becd
                   aaa13fcbc149fe0f3f391f933279580f74a96fd312d6ed06b8ff03c2d46672e8
                   "$(. "$TERMUX_SCRIPTDIR/x11-packages/kitty/build.sh"; echo "$TERMUX_PKG_SHA256")"
                   "$(. "$TERMUX_SCRIPTDIR/x11-packages/alacritty/build.sh"; echo "$TERMUX_PKG_SHA256")"
                   "$(. "$TERMUX_SCRIPTDIR/x11-packages/foot/build.sh"; echo "$TERMUX_PKG_SHA256")")
TERMUX_PKG_AUTO_UPDATE=false

# ncurses-utils: tset/reset/clear are moved to package 'ncurses'.
TERMUX_PKG_BREAKS="ncurses-dev, ncurses-utils (<< 6.1.20190511-4)"
TERMUX_PKG_REPLACES="ncurses-dev, ncurses-utils (<< 6.1.20190511-4)"

# --disable-stripping to disable -s argument to install which does not work when cross compiling:
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
ac_cv_header_locale_h=no
am_cv_langinfo_codeset=no
--disable-opaque-panel
--disable-stripping
--enable-const
--enable-ext-colors
--enable-ext-mouse
--enable-overwrite
--enable-pc-files
--enable-termcap
--enable-widec
--without-ada
--without-cxx-binding
--without-debug
--without-tests
--with-normal
--with-static
--with-shared
--with-termpath=/etc/termcap
"

TERMUX_PKG_RM_AFTER_INSTALL="
share/man/man5
share/man/man7
"

# shellcheck disable=SC2031
termux_step_pre_configure() {
	:
}
termux_step_post_make_install() {
	cd /data/data/com.termux/files/usr/share/terminfo
	zip -r termuxinfo.zip *
	mv termuxinfo.zip ~
}
