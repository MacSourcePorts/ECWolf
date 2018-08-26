#!/bin/bash
# shellcheck disable=SC2155

# This script is primarily for checking and handling releases. If you are
# looking to build ECWolf then you should build manually.

# This script takes a single argument which specifies which configuration to
# use. Running with no arguments will list out config names, but you can also
# look at the bottom of this script.

# Anything that the configs write out to /results (logs, build artifacts) will
# be copied back to the hosts results directory.

# Infrastructure ---------------------------------------------------------------

# Build our clean environment if we don't have one built already
check_environment() {
	declare -n Config=$1
	shift

	declare DockerTag="${Config[dockerimage]}:${Config[dockertag]}"

	if ! docker image inspect "$DockerTag" &> /dev/null; then
		declare Dockerfile=$(mktemp -p .)
		"${Config[dockerfile]}" > "${Dockerfile}"
		docker build -t "$DockerTag" -f "$Dockerfile" . || {
			rm "$Dockerfile"
			echo 'Failed to create build environment' >&2
			return 1
		}
		rm "$Dockerfile"
	fi
	return 0
}

# Recursively build docker environments
check_environment_prereq() {
	declare ConfigName=$1
	shift

	[[ $ConfigName ]] || return 0

	declare -n Config=$ConfigName
	if [[ ${Config[prereq]} ]]; then
		check_environment_prereq "${Config[prereq]}" || return
	fi

	check_environment "$ConfigName"
}

run_config() {
	declare ConfigName=$1
	shift

	declare -n Config=$ConfigName

	check_environment_prereq "$ConfigName" || return

	declare Container
	Container=$(docker create -i -v "$(pwd):/mnt:ro" "${Config[dockerimage]}:${Config[dockertag]}" bash -s --) || return
	{
		declare -fx
		echo "\"${Config[entrypoint]}\" \"\$@\""
	} | docker start -i "$Container"
	declare Ret=$?

	# Copy out any logs or build artifacts we might be interested in
	mkdir -p "results/${ConfigName}"
	docker cp "$Container:/results/." "results/${ConfigName}"

	docker rm "$Container" > /dev/null

	return "$Ret"
}

main() {
	declare SelectedConfig=$1
	shift

	declare ConfigName

	# List out configs
	if [[ -z $SelectedConfig ]]; then
		declare -A ConfigGroups=([all]=1)
		for ConfigName in "${ConfigList[@]}"; do
			declare -n Config=$ConfigName
			ConfigGroups[${Config[type]}]=1
		done

		echo 'Config list:'
		printf '%s\n' "${ConfigList[@]}" | sort

		echo
		echo 'Config groups:'
		printf '%s\n' "${!ConfigGroups[@]}" | sort
		return 0
	fi

	declare ConfigName
	if [[ -v "$SelectedConfig""[@]" ]]; then
		# Full name
		ConfigName=$SelectedConfig
	else
		# Short name
		ConfigName=${ConfigList[$SelectedConfig]}
	fi

	# Run by type
	if [[ -z $ConfigName ]]; then
		declare -a FailedCfgs=()
		for ConfigName in "${ConfigList[@]}"; do
			declare -n Config=$ConfigName
			if [[ $SelectedConfig == "${Config[type]}" || $SelectedConfig == 'all' ]]; then
				run_config "${ConfigName}" || FailedCfgs+=("$ConfigName")
			fi
		done

		if (( ${#FailedCfgs} > 0 )); then
			echo 'Failed configs:'
			printf '%s\n' "${FailedCfgs[@]}"
			return 1
		else
			echo 'All configs passed!'
			return 0
		fi
	fi

	# Run the specific config
	run_config "${ConfigName}"
}

# Minimum supported configuration ----------------------------------------------

dockerfile_ubuntu_minimum() {
	# libglu deps are to get libsdl2-dev to install
	cat <<-'EOF'
		FROM ubuntu:14.04

		RUN apt-get update && \
		apt-get install g++ cmake mercurial pax-utils lintian \
			libsdl1.2-dev libsdl-net1.2-dev \
			libsdl2-dev libsdl2-net-dev \
			libflac-dev libogg-dev libvorbis-dev libopus-dev libopusfile-dev libmodplug-dev libfluidsynth-dev \
			zlib1g-dev libbz2-dev libgtk2.0-dev \
			libglu1-mesa-dev libglu1-mesa -y && \
		useradd -rm ecwolf && \
		echo "ecwolf ALL=(ALL) NOPASSWD: /usr/bin/make install" >> /etc/sudoers && \
		mkdir /home/ecwolf/results && \
		chown ecwolf:ecwolf /home/ecwolf/results && \
		ln -s /home/ecwolf/results /results

		USER ecwolf
	EOF
}

dockerfile_ubuntu_minimum_i386() {
	dockerfile_ubuntu_minimum | sed 's,FROM ,FROM i386/,'
}

# Performs a build of ECWolf. Extra CMake args can be passed as args.
build_ecwolf() {
	declare SrcDir=/mnt

	cd ~ || return

	# Check for previous invocation
	if [[ -d build ]]; then
		rm -rf build
	fi

	# Only matters on CMake 3.5+
	export CLICOLOR_FORCE=1

	mkdir build &&
	cd build &&
	cmake "$SrcDir" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr "$@" &&
	touch install_manifest.txt && # Prevent root from owning this file
	make -j "$(nproc)" || return
}
export -f build_ecwolf

test_build_ecwolf_cfg() {
	declare BuildCfg=$1
	shift

	build_ecwolf "$@" 2>&1 | tee "/results/buildlog-$BuildCfg.log"
	(( PIPESTATUS[0] == 0 )) || return "${PIPESTATUS[0]}"

	cd ~/build &&
	sudo make install 2>&1 | tee "/results/installlog-$BuildCfg.log"
	(( PIPESTATUS[0] == 0 )) || return "${PIPESTATUS[0]}"

	lddtree /usr/games/ecwolf | tee "/results/lddtree-$BuildCfg.txt"
}
export -f test_build_ecwolf_cfg

# Tests that supported configs compile and install
test_build_ecwolf() {
	declare -a FailedCfgs=()

	test_build_ecwolf_cfg SDL2 || FailedCfgs+=(SDL2)

	test_build_ecwolf_cfg SDL1 -DFORCE_SDL12=ON -DINTERNAL_SDL_MIXER=ON || FailedCfgs+=(SDL1)

	if (( ${#FailedCfgs} > 0 )); then
		echo 'Failed builds:'
		printf '%s\n' "${FailedCfgs[@]}"
		return 1
	else
		echo 'All passed!'
	fi
}
export -f test_build_ecwolf

# shellcheck disable=SC2034
declare -A ConfigUbuntuMinimum=(
	[dockerfile]=dockerfile_ubuntu_minimum
	[dockerimage]='ecwolf-ubuntu'
	[dockertag]=1
	[entrypoint]=test_build_ecwolf
	[prereq]=''
	[type]=test
)

# shellcheck disable=SC2034
declare -A ConfigUbuntuMinimumI386=(
	[dockerfile]=dockerfile_ubuntu_minimum_i386
	[dockerimage]='i386/ecwolf-ubuntu'
	[dockertag]=1
	[entrypoint]=test_build_ecwolf
	[prereq]=''
	[type]=test
)

# Ubuntu packaging -------------------------------------------------------------

dockerfile_ubuntu_package() {
	echo "FROM ${ConfigUbuntuMinimum[dockerimage]}:${ConfigUbuntuMinimum[dockertag]}"

	# Packaging requires CMake 3.11 or newer
	cat <<-'EOF'
		RUN cd ~ && \
		curl https://cmake.org/files/v3.12/cmake-3.12.1.tar.gz | tar xz && \
		cd cmake-3.12.1 && \
		./configure --parallel="$(nproc)" && \
		make -j "$(nproc)" && \
		sudo make install && \
		cd .. && \
		rm -rf cmake-3.12.1
	EOF
}

dockerfile_ubuntu_package_i386() {
	dockerfile_ubuntu_package | sed 's,FROM ,FROM i386/,'
}

package_ecwolf() {
	{
		build_ecwolf &&

		make package &&
		lintian --suppress-tags embedded-library ecwolf_*.deb &&
		cp ecwolf_*.deb /results/
	} 2>&1 | tee '/results/build.log'
	return "${PIPESTATUS[0]}"
}
export -f package_ecwolf

# shellcheck disable=SC2034
declare -A ConfigUbuntuPackage=(
	[dockerfile]=dockerfile_ubuntu_package
	[dockerimage]='ecwolf-ubuntu-package'
	[dockertag]=1
	[entrypoint]=package_ecwolf
	[prereq]=ConfigUbuntuMinimum
	[type]=build
)

# shellcheck disable=SC2034
declare -A ConfigUbuntuPackageI386=(
	[dockerfile]=dockerfile_ubuntu_package_i386
	[dockerimage]='i386/ecwolf-ubuntu-package'
	[dockertag]=1
	[entrypoint]=package_ecwolf
	[prereq]=ConfigUbuntuMinimumI386
	[type]=build
)

# Clang ------------------------------------------------------------------------

dockerfile_clang() {
	# libglu deps are to get libsdl2-dev to install
	cat <<-'EOF'
		FROM ubuntu:14.04

		RUN apt-get update && \
		apt-get install clang-3.9 libc++-dev cmake mercurial pax-utils lintian \
			libsdl2-dev libsdl2-net-dev \
			libflac-dev libogg-dev libvorbis-dev libopus-dev libopusfile-dev libmodplug-dev libfluidsynth-dev \
			zlib1g-dev libbz2-dev libgtk2.0-dev \
			libglu1-mesa-dev libglu1-mesa -y && \
		useradd -rm ecwolf && \
		echo "ecwolf ALL=(ALL) NOPASSWD: /usr/bin/make install" >> /etc/sudoers && \
		mkdir /home/ecwolf/results && \
		chown ecwolf:ecwolf /home/ecwolf/results && \
		ln -s /home/ecwolf/results /results

		USER ecwolf
	EOF
}

# Test that ECWolf is buildable with Clang and libc++
clang_build_ecwolf() {
	CC=clang-3.9 CXX=clang++-3.9 build_ecwolf -DCMAKE_CXX_FLAGS="-stdlib=libc++" 2>&1 | tee "/results/buildlog.log"
	(( PIPESTATUS[0] == 0 )) || return "${PIPESTATUS[0]}"

	cd ~/build &&
	sudo make install 2>&1 | tee "/results/installlog.log"
	(( PIPESTATUS[0] == 0 )) || return "${PIPESTATUS[0]}"

	lddtree /usr/games/ecwolf | tee "/results/lddtree.txt"
}
export -f clang_build_ecwolf

# shellcheck disable=SC2034
declare -A ConfigClang=(
	[dockerfile]=dockerfile_clang
	[dockerimage]='ecwolf-clang'
	[dockertag]=1
	[entrypoint]=clang_build_ecwolf
	[prereq]=''
	[type]=test
)

# Ubuntu MinGW-w64 -------------------------------------------------------------

dockerfile_mingw() {
	cat <<-'EOF'
		FROM ubuntu:18.04

		RUN apt-get update && \
		apt-get install g++ cmake mercurial g++-mingw-w64-i686 g++-mingw-w64-x86-64 \
			libsdl2-dev libsdl2-mixer-dev libsdl2-net-dev zlib1g-dev libbz2-dev libjpeg-turbo8-dev \
			libglu1-mesa-dev libglu1-mesa -y && \
		useradd -rm ecwolf && \
		echo "ecwolf ALL=(ALL) NOPASSWD: /usr/bin/make install" >> /etc/sudoers && \
		mkdir /home/ecwolf/results && \
		chown ecwolf:ecwolf /home/ecwolf/results && \
		ln -s /home/ecwolf/results /results

		USER ecwolf
	EOF
}

build_mingw() {
	declare SrcDir=/mnt

	# Build native tools
	build_ecwolf || return

	declare Arch
	for Arch in i686 x86_64; do
		{
			mkdir ~/build-mgw-"$Arch" &&
			cd ~/build-mgw-"$Arch" &&
			CXX="$Arch-w64-mingw32-g++-posix" CC="$Arch-w64-mingw32-gcc-posix" cmake "$SrcDir" \
				-DCMAKE_BUILD_TYPE=Release \
				-DFORCE_CROSSCOMPILE=ON \
				-DIMPORT_EXECUTABLES=../build/ImportExecutables.cmake \
				-DINTERNAL_SDL{_MIXER,_MIXER_CODECS,_NET}=ON \
				-DCMAKE_SYSTEM_NAME=Windows \
				-DCMAKE_FIND_ROOT_PATH="/usr/$Arch-w64-mingw32" \
				-DCMAKE_RC_COMPILER="$Arch-w64-mingw32-windres" \
				-DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -Wl,-Bstatic,--whole-archive -lpthread -Wl,-Bdynamic,--no-whole-archive" &&
			make -j "$(nproc)" -O &&
			make package &&
			cp ecwolf-*.zip /results/
		} 2>&1 | tee "/results/build-$Arch.log"
		(( PIPESTATUS[0] == 0 )) || return "${PIPESTATUS[0]}"
	done
}
export -f build_mingw

# shellcheck disable=SC2034
declare -A ConfigMinGW=(
	[dockerfile]=dockerfile_mingw
	[dockerimage]='ecwolf-mingw'
	[dockertag]=1
	[entrypoint]=build_mingw
	[prereq]=''
	[type]=build
)

# Ubuntu Android ---------------------------------------------------------------

dockerfile_android() {
	# Need a more sustainable solution for com.bda.controller.jar
	cat <<-'EOF'
		FROM ubuntu:18.04

		RUN dpkg --add-architecture i386 && \
		apt-get update && \
		apt-get install libc6:i386 libstdc++6:i386 zlib1g:i386 \
			g++ cmake mercurial openjdk-8-jdk-headless p7zip-full curl \
			libsdl2-dev libsdl2-mixer-dev libsdl2-net-dev zlib1g-dev libbz2-dev libjpeg-turbo8-dev \
			libglu1-mesa-dev libglu1-mesa -y && \
		useradd -rm ecwolf && \
		echo "ecwolf ALL=(ALL) NOPASSWD: /usr/bin/make install" >> /etc/sudoers && \
		mkdir /home/ecwolf/results && \
		chown ecwolf:ecwolf /home/ecwolf/results && \
		ln -s /home/ecwolf/results /results && \
		mkdir sdk && \
		cd sdk && \
		curl https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -o sdk-tools-linux.zip && \
		curl https://dl.google.com/android/repository/android-ndk-r14b-linux-x86_64.zip -o android-ndk.zip && \
		curl https://raw.githubusercontent.com/emileb/OpenGames/3e8682f24fe223c7065671d0204de639a6d2ec05/touchcontrols/libs/com.bda.controller.jar -o com.bda.controller.jar && \
		7za x sdk-tools-linux.zip && \
		7za x android-ndk.zip && \
		rm sdk-tools-linux.zip android-ndk.zip && \
		mv android-ndk-r14b ndk-bundle && \
		sed -i 's/__USE_FILE_OFFSET64)/__USE_FILE_OFFSET64) \&\& __ANDROID_API__ >= 24/' /sdk/ndk-bundle/sysroot/usr/include/stdio.h && \
		mkdir licenses && \
		printf '\nd56f5187479451eabf01fb78af6dfcb131a6481e' > licenses/android-sdk-license && \
		tools/bin/sdkmanager 'platforms;android-19' 'build-tools;19.1.0' 'extras;android;m2repository' && \
		keytool -genkey -keystore untrusted.keystore -storepass untrusted -keypass untrusted -alias untrusted -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Untrusted,OU=Untrusted,O=Untrusted,L=Untrusted,S=Untrusted,C=US" -noprompt

		USER ecwolf
	EOF
}

build_android() {
	declare SrcDir=/mnt

	# Build native tools
	build_ecwolf || return

	declare Arch
	for Arch in x86 armeabi-v7a; do
		{
			mkdir ~/build-mgw-"$Arch" &&
			cd ~/build-mgw-"$Arch" &&
			cmake "$SrcDir" \
				-DCMAKE_SYSTEM_NAME=Android \
				-DCMAKE_SYSTEM_VERSION=12 \
				-DCMAKE_ANDROID_NDK=/sdk/ndk-bundle \
				-DCMAKE_ANDROID_ARCH_ABI="$Arch" \
				-DCMAKE_BUILD_TYPE=Release \
				-DFORCE_CROSSCOMPILE=ON \
				-DIMPORT_EXECUTABLES=~/build/ImportExecutables.cmake \
				-DANDROID_SDK=/sdk/platforms/android-19 \
				-DANDROID_SDK_TOOLS=/sdk/build-tools/19.1.0 \
				-DANDROID_SIGN_KEYNAME=untrusted \
				-DANDROID_SIGN_KEYSTORE=/sdk/untrusted.keystore \
				-DANDROID_SIGN_STOREPASS=untrusted \
				-DANDROID_MOGA_CONTROLLER_JAR=/sdk/com.bda.controller.jar \
				-DINTERNAL_SDL{_MIXER,_MIXER_CODECS,_NET}=ON
			make -j "$(nproc)" &&
			cp ecwolf.apk /results/ecwolf-"$Arch".apk
		} 2>&1 | tee "/results/build-$Arch.log"
		(( PIPESTATUS[0] == 0 )) || return "${PIPESTATUS[0]}"
	done
}
export -f build_android

# shellcheck disable=SC2034
declare -A ConfigAndroid=(
	[dockerfile]=dockerfile_android
	[dockerimage]='ecwolf-android'
	[dockertag]=1
	[entrypoint]=build_android
	[prereq]=''
	[type]=build
)

# ------------------------------------------------------------------------------

declare -A ConfigList=(
	[android]=ConfigAndroid
	[clang]=ConfigClang
	[mingw]=ConfigMinGW
	[ubuntumin]=ConfigUbuntuMinimum
	[ubuntumini386]=ConfigUbuntuMinimumI386
	[ubuntupkg]=ConfigUbuntuPackage
	[ubuntupkgi386]=ConfigUbuntuPackageI386
)

main "$@"; exit