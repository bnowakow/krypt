#!/bin/bash

# copied from https://webcache.googleusercontent.com/search?q=cache%3Ahttps%3A%2F%2Fkrypt.co%2Fkr&sca_esv=3ccb936e91fffbe3&sca_upv=1&sxsrf=ADLYWIILWCbrd7MK6HJ5Q6xK_2FYqOe5rg%3A1718994189036

VERSION=2.4.13

install_darwin() {
	command -v brew &>/dev/null && test "$1" = "brew"
	if [ "$?" != "0" ]; then
		say Installing Krypton...
		install_darwin_manual
	else
		#	Check if already installed with brew
		ls -l `command -v kr` | grep Cellar &>/dev/null
		if [ "$?" = "0" ]; then
			say Upgrading Krypton with Homebrew...
			ensure brew update -v
			ensure brew upgrade kryptco/tap/kr && brew link --overwrite kryptco/tap/kr
		else
			say "Installing Krypton with Homebrew. If Homebrew is too slow or fails, try \"curl https://krypt.co/kr | sh\""
			ensure brew update -v
			ensure brew install kryptco/tap/kr && brew link --overwrite kryptco/tap/kr
			if [ "$?" != "0"  ]; then
				echo 
				read -p "Krypton Homebrew install failed. Try manual installation?" -n 1 -r < /dev/tty

				if [ $REPLY != ^[Yy]$ ]
				then
					install_darwin_manual
				fi
			fi
		fi
	fi
}

verify_bottle_hash() {
	say OpenSSL command line found, verifying downloaded binary hash...
	DOWNLOADED_HASH=`openssl dgst -sha256 -hex /tmp/$BOTTLE_FILE | awk '{print $2}'`
	test "$DOWNLOADED_HASH" = "$BOTTLE_HASH" || (say "Downloaded binary hash incorrect. Aborting."; rm /tmp/$BOTTLE_FILE; exit 1) || exit 1
	say "Binary verified."
}

install_darwin_manual() {
	need_cmd mv
	need_cmd cp
	need_cmd curl
	need_cmd rm
	need_cmd tar
	need_cmd launchctl
	need_cmd perl
	need_cmd mkdir
	need_cmd touch
	need_cmd printf

	MAJOR_MAC_VERSION=$(sw_vers -productVersion | awk -F '.' '{print $1 "." $2}')
	case $MAJOR_MAC_VERSION in
		#10.10 NO LONGER SUPPORTED
		10.11) BOTTLE_FILE=kr-2.4.13.el_capitan.bottle.2.tar.gz;	BOTTLE_HASH=c7ff5433486daa1654ec79806b0fcb9aafcc7dc052e166c5c68fa707ed49e2b4;;
		10.12) BOTTLE_FILE=kr-2.4.13.sierra.bottle.2.tar.gz;	BOTTLE_HASH=2285ce4eebb3ee75ab9678676c15bf133d5a3d24d2b7a4dc4da31179de699462; USE_KRBTLE=1;;
		10.13) BOTTLE_FILE=kr-2.4.13.high_sierra.bottle.2.tar.gz; BOTTLE_HASH=b5278156184a7f50ed04790ecc7081be5c3f3d82c07da64d9683bf5db19472cb; USE_KRBTLE=1;;
		10.14) BOTTLE_FILE=kr-2.4.13.mojave.bottle.2.tar.gz; BOTTLE_HASH=8901218264de65fdbf2dc258f00557e456416f9f32fb9511956d546fea0a804a; USE_KRBTLE=1;;
		10.15) BOTTLE_FILE=kr-2.4.13.mojave.bottle.2.tar.gz; BOTTLE_HASH=8901218264de65fdbf2dc258f00557e456416f9f32fb9511956d546fea0a804a; USE_KRBTLE=1;;
		10.16) BOTTLE_FILE=kr-2.4.13.mojave.bottle.2.tar.gz; BOTTLE_HASH=8901218264de65fdbf2dc258f00557e456416f9f32fb9511956d546fea0a804a; USE_KRBTLE=1;;
		11.0) BOTTLE_FILE=kr-2.4.13.mojave.bottle.2.tar.gz; BOTTLE_HASH=8901218264de65fdbf2dc258f00557e456416f9f32fb9511956d546fea0a804a; USE_KRBTLE=1;;
		*) say "Unsupported OS X version $MAJOR_MAC_VERSION. Krypton requires 10.11+" && exit 1 ;;
	esac
	say Downloading Krypton.
	ensure curl -# -o /tmp/$BOTTLE_FILE -L https://github.com/KryptCo/bottles/raw/master/$BOTTLE_FILE

	command -v openssl &>/dev/null && verify_bottle_hash
	PREFIX=${PREFIX:-$HOMEBREW_PREFIX}
	PREFIX=${PREFIX:-/usr/local}

	ensure mk_owned_dir_if_not_exists $PREFIX/lib
	ensure mk_owned_dir_if_not_exists $PREFIX/bin

	if [ "$USE_KRBTLE" = '1' ]; then
		ensure mk_owned_dir_if_not_exists $PREFIX/Frameworks
	fi

	ignore rm -rf /tmp/kr
	ensure tar xf /tmp/$BOTTLE_FILE -C /tmp/
	ensure mv_maybe_sudo "/tmp/kr/$VERSION/bin/*" $PREFIX/bin/
	ensure mv_maybe_sudo "/tmp/kr/$VERSION/lib/*" $PREFIX/lib/
	if [ "$USE_KRBTLE" = '1' ]; then
		ensure rmrf_maybe_sudo "$PREFIX/Frameworks/krbtle.framework"
		ensure mv_maybe_sudo "/tmp/kr/$VERSION/Frameworks/krbtle.framework" $PREFIX/Frameworks/
	fi

	ensure mkdir -p ~/.ssh
	ensure touch ~/.ssh/config
	
	say Krypton installed successfully. Type \"kr pair\" to pair with the Krypton mobile app.
	kr restart &>/dev/null
}

set_os() {
	#!/bin/bash
	# Check for FreeBSD in the uname output
	# If it's not FreeBSD, then we move on!
	if [ "$(uname -s)" = 'FreeBSD' ]; then
	  OS='freebsd'
	# Check for a redhat-release file and see if we can
	# tell which Red Hat variant it is
	elif [ -f "/etc/redhat-release" ]; then
	  RHV=$(egrep -o 'Fedora|CentOS|Red\ Hat|Red.Hat' /etc/redhat-release)
	  case $RHV in
	    Fedora)  OS='fedora';;
	    CentOS)  OS='centos';;
	   Red\ Hat)  OS='redhat';;
	   Red.Hat)  OS='redhat';;
	  esac
	# Check for debian_version
	elif [ -f "/etc/debian_version" ]; then
	  OS='debian'
	# Check for arch-release
	elif [ -f "/etc/arch-release" ]; then
	  OS='arch'
	# Check for SuSE-release
	elif [ -f "/etc/SuSE-release" ]; then
	  OS='suse'
	fi
}

install_linux() {
        set_os
          case $OS in
            fedora)  install_yum "yum config-manager";;
            centos)  need_cmd yum-config-manager && install_yum "yum-config-manager";;
            redhat)  need_cmd yum-config-manager && install_yum "yum-config-manager";;
            *) install_debian
          esac
}

install_yum() {
        export YUM_CONFIG_MANAGER=$1

        need_cmd yum
        need_cmd rpm
        need_cmd gpg

		
        ensure gpg --keyserver=hkp://keyserver.ubuntu.com:80 --recv-keys "C4A05888A1C4FA02E1566F859F2A29A569653940"
        ensure gpg --export --armor C4A05888A1C4FA02E1566F859F2A29A569653940 > /tmp/kryptco.key
		echo Importing KryptCo GPG key...
        ensure sudo rpm --import /tmp/kryptco.key
        ignore rm /tmp/kryptco.key

		ignore sudo yum clean expire-cache 1>/dev/null 2>/dev/null
        ensure sudo $YUM_CONFIG_MANAGER --add-repo https://kryptco.github.io/yum
        ensure sudo yum install kr -y
}

is_kali() {
	cat /etc/*-release | head -1 | grep "Kali" && KALI="yes"
}

install_debian() {
	need_cmd apt-get
	ensure sudo apt-get install software-properties-common dirmngr apt-transport-https -y
	need_cmd apt-add-repository
	need_cmd apt-key
	need_cmd sleep
	say Adding KryptCo signing key...
	ensure sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C4A05888A1C4FA02E1566F859F2A29A569653940
	which kr && say Removing old version of kr...
	ignore sudo apt-get remove kr -y &>/dev/null
	say Adding KryptCo repository...
	ignore sudo add-apt-repository --remove "deb http://kryptco.github.io/deb beta beta" &>/dev/null
	sleep 1
	is_kali
	if [ "$KALI" = 'yes' ]; then
		# Kali linux add-apt-repository checks for kali-rolling template
		grep "deb http://kryptco.github.io/deb kryptco main" "/etc/apt/sources.list" || ensure sudo printf "deb http://kryptco.github.io/deb kryptco main" >> /etc/apt/sources.list
	else
		ensure sudo add-apt-repository "deb http://kryptco.github.io/deb kryptco main"
	fi
	sleep 1
	ignore sudo apt-get update
	say Installing kr...
	ensure sudo apt-get install kr -y
}

install() {
	unamestr=`uname`
	if [ "$unamestr" = 'Linux' ]; then
		install_linux "$@"
	elif [ "$unamestr" = 'Darwin' ]; then
		install_darwin "$@"
	else
		say "OS $unamestr Unsupported"
		exit 1
	fi
}

is_my_dir() {
	test "`ls -ld $1 | awk 'NR==1 {print $3}'`" = "$USER"
}

#	mv $1 to $2, using sudo if necessary
#	$2 must be a directory, not the new file name
mv_maybe_sudo() {
	(is_my_dir $2 && ensure mv -f $1 $2) || ensure warn_sudo mv -f $1 $2
}

#	rm $1 using sudo if necessary, failing gracefully if not present
rmrf_maybe_sudo() {
	(is_my_dir `dirname $1` && ensure rm -rf $1) || ensure warn_sudo rm -rf $1
}

warn_sudo() {
	sudo -n true 2>/dev/null || say "sudo required for command $@"
	sudo "$@"
}

mk_owned_dir_if_not_exists() {
	if [ ! -d "$1" ]; then
		mkdir -p $1 &> /dev/null || (ensure warn_sudo mkdir -p $1 && ensure warn_sudo chown $USER $1)
	fi
}

# Copyright 2016 The Rust Project Developers. See the COPYRIGHT
# file at the top-level directory of this distribution and at
# http://rust-lang.org/COPYRIGHT.
#
# Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
# http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
# <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
# option. This file may not be copied, modified, or distributed
# except according to those terms.
say() {
    echo "kr: $@"
}

say_err() {
    say "$@" >&2
}

err() {
    say "$@" >&2
    exit 1
}

need_cmd() {
    if ! command -v "$1" > /dev/null 2>&1
    then err "need '$1' (command not found)"
    fi
}

need_ok() {
    if [ $? != 0 ]; then err "$1"; fi
}

assert_nz() {
    if [ -z "$1" ]; then err "assert_nz $2"; fi
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing
# command.
ensure() {
    "$@"
    need_ok "command failed: $*"
}

# This is just for indicating that commands' results are being
# intentionally ignored. Usually, because it's being executed
# as part of error handling.
ignore() {
    run "$@"
}

# Runs a command and prints it to stderr if it fails.
run() {
    "$@"
    local _retval=$?
    if [ $_retval != 0 ]; then
        say_err "command failed: $*"
    fi
    return $_retval
}

install "$@"
