#!/usr/bin/bash
# build cutefish desktop on Debian

script_path=$(cd $(dirname $0); pwd)
package_dir=cutefish_packages
build_dir=build
deb_dir=debs
dbgsym_dir=dbgsym
cache_file=build.cache

function check_commands() {
	local com_arr=(
		mk-build-deps --version
		dpkg-buildpackage --version
		dpkg-checkbuilddeps --version
		unzip -v
		git --version
		sudo --version
	)
	local arr_len=${#com_arr[@]}
	for (( i = 0; i < ${arr_len}; i += 2 )); do
		# echo ${com_arr[i]} 
		if ! command ${com_arr[i]} ${com_arr[i+1]} > /dev/null 2>&1; then
			echo command ${com_arr[i]} not found >&2
			echo Maybe need to install devscripts and build-essential package?
			exit 1
		fi
	done
}

function package_build() {
	local build_path=${script_path}/${package_dir}/${build_dir}
	local git_path=${build_path}/$2

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
		mk-build-deps --install \
			--root-cmd sudo \
			--tool "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y" \
			--remove \
			&& dpkg-buildpackage -b

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
			echo Package $2 build failed >&2
			exit 1
		fi
		
	else
		echo Git clone $2 failed >&2
	fi

	cd ${script_path}
}

if grep -Eqi Debian /etc/issue || grep -Eqi Debian /etc/*-release; then
	distro=Debian
	pkgmn=apt
# package on Loongnix is too old to build cutefish
#elif grep -Eqi Loongnix /etc/issue || grep -Eqi Loongnix /etc/*-release; then
#	distro=Loongnix
#	pkgmn=apt
else
	echo This script does not support your distribution
	exit 1
fi

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