#!/usr/bin/bash
# this script check the latest version of nvm and download the official install script
# for security consideration, the script will let you read the install script first

script_path=$(cd $(dirname $0); pwd)

function check_commands() {
        local com_arr=(
                git
		jq
		curl
        )
        local arr_len=${#com_arr[@]}
        for com in ${com_arr[*]}; do
                # echo ${com_arr[i]}
                if ! command -v ${com} > /dev/null 2>&1; then
                        echo command ${com} not found >&2
                        exit 1
                fi
        done
}

check_commands

nvm_path=${script_path}/nvm_cache
[[ -d ${nvm_path} ]] || mkdir -v ${nvm_path}; cd ${nvm_path}


# get the latest release tag
nvm_repo=https://api.github.com/repos/nvm-sh/nvm/releases/latest
release_info=$(curl -s ${nvm_repo})
if [[ ! $? -eq 0 ]]; then
	echo Get release message failed, check your internet connection
	echo ${nvm_repo}
	exit 1
fi
tag_name=$(echo ${release_info} | jq -r ".tag_name")

# download official script and run
script_file=install.sh
script_url=https://raw.githubusercontent.com/nvm-sh/nvm/${tag_name}/${script_file}
echo Select tag ${tag_name}
echo curl --silent -L ${script_url} -o ${script_file}

if [[ -e ${script_file} ]]; then
	echo ${script_file} already exists
else
	if curl --silent -L ${script_url} -o ${script_file}; then
		less ${script_file}
	else
		echo Download failed
		exit 1
	fi
fi

echo
echo \"y\" to run the script, \"n\" to delete the script, \"q\" to keep the script and exit now.
read -p "How to deal with the script? [yNq]: " input
case $input in
	[yY]*)
		echo Run the script now
		if bash ${script_file}; then
			echo
			echo ===========================================
			echo Read the output above carefully
		else
			echo
			echo ===========================================
			echo It seems that the script failed? Check the output and run again
			exit
		fi
		;;
	[qQ*])
		echo Exit the installation
		exit
		;;
	*)
		;;
esac

# clean up
echo Delete the script
rm -rvf ${nvm_path}

