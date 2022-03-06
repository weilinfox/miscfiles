#!/usr/bin/bash
# build cutefish desktop on Debian
# use mk-build-deps to check dependencies
# you can easily uninstall dependencies after use this script
# for more information, run "man mk-build-deps"
# weilinfox <weilin.king@qq.com>

script_path=$(cd $(dirname $0); pwd)
package_dir=cutefish_packages
build_dir=build
deb_dir=debs
dbgsym_dir=dbgsym
cache_file=build.cache

# build commands
mk_build_deps_cmd="mk-build-deps --install \
			--root-cmd sudo \
			--tool \"apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y\" \
			--remove"
dpkg_buildpackage_cmd="dpkg-buildpackage -b -uc -us"

case $# in 
	0)
		;;
	1)
		if [[ $1 == "--noparallel" ]]; then
			dpkg_buildpackage_cmd="${dpkg_buildpackage_cmd} -J1"
		else
			echo Invalid option $1
			echo Use option --noparallel to build in single thread
			exit 1
		fi
		;;
	*)
		echo Invalid options
		echo Script accept at most one option
		;;
esac

function check_commands() {
	local com_arr=(
		mk-build-deps
		dpkg-buildpackage
		dpkg-checkbuilddeps
		equivs-build
		equivs-control
		unzip
		git
		sudo
	)
	local arr_len=${#com_arr[@]}
	for com in ${com_arr[*]}; do
		# echo ${com_arr[i]} 
		if ! command -v ${com} > /dev/null 2>&1; then
			echo command ${com} not found >&2
			echo Maybe did not install devscripts and build-essential package?
			echo For Ubuntu, equivs package is needed.
			exit 1
		fi
	done
}

function package_build() {
	local build_path=${script_path}/${package_dir}/${build_dir}
	local git_path=${build_path}/$2
	# local build_cmd="${mk_build_deps_cmd} && ${dpkg_buildpackage_cmd}"

	# if git repo exists, make it up to date
	if [[ -d ${git_path} ]]; then
		cd ${git_path} && git pull
	else
		cd ${build_path} && git clone $1/$2.git
	fi
	
	# build the package
	if [[ $? -eq 0 && -d ${git_path} ]]; then
		echo Start to build $2
		cd ${git_path}

		eval ${mk_build_deps_cmd} || ( echo Error: nable to solve dependencies >&2; exit 1 )
		eval ${dpkg_buildpackage_cmd}

		# if build succeed, copy the package and clean the workspace
		if [[ $? -eq 0 ]]; then
			cd ${build_path}
			#for dep_pkg in `find ${build_path} -regex "^.*?-build-deps.*?deb$"`; do
			#	rm -v ${dep_pkg}
			#done
			for dbg_pkg in `find ${build_path} -regex "^.*?dbgsym.*?\.deb$"`; do
				mv -v $dbg_pkg ${script_path}/${package_dir}/${dbgsym_dir}/
			done
			for deb_pkg in `find ${build_path} -regex "^.*?\.deb$"`; do
				mv -v $deb_pkg ${script_path}/${package_dir}/${deb_dir}/
			done
			echo rm -rf ${build_path}/$2
			rm -rf ${build_path}/$2
			for trashf in `find ${build_path} -maxdepth 1 -type f`; do
				rm -v ${trashf}
			done
			echo Package $2 built successfully
			echo $2 >> ${script_path}/${package_dir}/${cache_file}
		else
			# quit when error occured
			echo Error: unable to build package $2 >&2
			# build in parallel may cause strange build error on Debian 11 and Ubuntu 20.04
			echo Try to use --noparallel option?

			exit 1
		fi
		
	else
		echo Git clone $2 failed >&2
	fi

	cd ${script_path}
}

if grep -Eqi Debian /etc/issue || grep -Eq Debian /etc/*-release; then
	distro=Debian
	pkgmn=apt
elif grep -Eqi Ubuntu /etc/issue || grep -Eq Ubuntu /etc/*-release; then
	distro=Ubuntu
	pkgmn=apt
# package on Loongnix is too old to build cutefish
#elif grep -Eqi Loongnix /etc/issue || grep -Eq Loongnix /etc/*-release; then
#	distro=Loongnix
#	pkgmn=apt
else
	echo This script does not support your distribution
	exit 1
fi

echo Build for $distro

echo Check needed commands
check_commands

echo Make build dirs
if [[ ! -d ${package_dir} ]]; then
	mkdir ${package_dir}
fi
cd ${package_dir}
[[ -e ${cache_file} ]] || touch ${cache_file}
[[ -d ${build_dir} ]] || mkdir ${build_dir}
[[ -d ${deb_dir} ]] || mkdir ${deb_dir}
[[ -d ${dbgsym_dir} ]] || mkdir ${dbgsym_dir}


# ${CutefishUrl}/${GitRepos[@]}.git
cutefish_url=https://github.com/cutefishos
git_repos=(
	core
	launcher
	dock
	statusbar
	screenlocker
	daemon
	libcutefish
	settings
	updator
	fishui
	kwin-plugins
	sddm-theme
	appmotor
	qt-plugins
	icons
	gtk-themes
	cursor-themes
	filemanager
	debinstaller
	texteditor
	terminal
	screenshot
	calculator
	videoplayer
	calamares
	plymouth-theme
	wallpapers
)

echo Check built packages in cache_file
repo_len=${#git_repos[@]}
for (( i = 0; i  < ${repo_len}; i++ )); do
	if grep -Eqi ${git_repos[i]} ${cache_file}; then
		echo Found package ${git_repos[i]} was built
		unset git_repos[i]
	fi
done

echo Packages need to build: ${git_repos[*]}
for repo in ${git_repos[*]}; do
	package_build ${cutefish_url} ${repo}
done

echo
echo Run "apt-cache search --names-only ^.*?-build-deps$" to find build-dependencies to remove

