#! /bin/bash


connect-develop() {
	target=$1
	map_id=$2
	echo ${@:3:4}
	ssh $target -L ${map_id}022:localhost:22 -L ${map_id}006:localhost:6006 -L ${map_id}888:localhost:8888 -L ${map_id}097:localhost:8097 ${@:3:4}
}

connect-vpn() {
    #command='openconnect -b --protocol=nc --user=yurif@campus.technion.ac.il https://132.68.237.250'
    command='openconnect -b --protocol=nc --user=yurif@campus.technion.ac.il SSLVPN-CLUSTER.technion.ac.il'
    if [ "$#" -ge 1 ]; then
        host="$1"
        #echo executing command \'sudo -S ${command}\'
        ssh "$host" -C "sudo -S ${command}; exit" 
    else
        sudo $command 
    fi
    
}

disconnect-vpn() {
    command='sudo -S kill -9 `pidof openconnect` > /dev/null 2>&1; sleep 2; sudo -S service network-manager reload > /dev/null 2>&1; sudo -S service networking reload > /dev/null 2>&1'
    if [ "$#" -ge 1 ]; then
        host="$1"
        #echo executing command \'sudo -S ${command}\'
        ssh "$host" -C "${command}; exit"
    else
        $( $command )
    fi
#     command_list=('kill -9 `pidof openconnect` > /dev/null' 'service network-manager reload')
# 
#     for (( ii = 0; ii < ${#command_list[@]}; ii++ )); do 
#         if [ "$#" -ge 1 ]; then
#             host="$1"
#             #echo executing command \'sudo -S ${command}\'
#             ssh "$host" -C "sudo -S ${command}; exit"
#         else
#             sudo $command
#         fi
# 
#         echo "${command_list[ii]}"; 
#     done
#     #restart_service_command=
#     #sudo kill -9 `pidof openconnect` > /dev/null
#     #sudo service network-manager reload
}

restart-vpn() {
	sudo pkill openconnect 
	nmcli radio wifi off
	sleep 2
	nmcli radio wifi on
	sleep 5
	connect-vpn
}

alias tls="tmux ls"
alias ta="tmux attach-session -t"
alias dfs="df -h | grep -v snap"

tb() {
	#echo num arguments $# 
	if (( $# < 1 )); then
		# logdir="`ls | tail -1`" 
		export TMPDIR=/tmp/$USER; mkdir -p $TMPDIR; tensorboard serve
	else
		logdir="$1"
		#echo logdir $logdir 
		export TMPDIR=/tmp/$USER; mkdir -p $TMPDIR; tensorboard serve --logdir="$logdir" "${@:2}"
	fi
}

kill-pulse() {
	ps -ae | grep pulse | grep tty | cut -d" " -f1 | xargs kill -9
}


git-status() {
	watch --color -n 1 git -c color.status=always status "${@}"
}

send-version() {
	target_host="$1"
	version="$2"

	version_prefix="/home/yuri/Research/data/lightning_logs/lsmi_trainer/"

	tempdir=`mktemp -d`

	local_version_dir="${version_prefix}/$version"

	if [[ ! -d "$local_version_dir" ]]; then
		echo "Version does not exist at ${local_version_dir}"
		return 1
	fi

	tar_name="${version##*/}.tar.gz"
	tar_loc="${version%/*}"

	pushd "$tempdir"
	tar --exclude "plots" --exclude "training" --exclude "validation" --exclude "*tfevents*" -cvzf "${tar_name}" -C "${local_version_dir}/.." "${version##*/}"

	popd

	ssh ${target_host} -C "mkdir -p \"${version_prefix}/${tar_loc}\""
	rsync -av --progress "${tempdir}/$tar_name" "${target_host}:${version_prefix}/${tar_loc}"

	rm -rf "${tempdir}"

	ssh ${target_host} -C "pushd \"${version_prefix}/${tar_loc}\"; tar -xvf \"$tar_name\"; rm \"$tar_name\""
}



monitor-disk() {
	watch -n 3 'df -h | grep -v snap'	
}

monitor-nvidia-smi() {
    watch -n "$1" nvidia-smi
}

alias dus='du -sh * | sort -k1 -h'

alias git-branch='git rev-parse  --abbrev-ref HEAD'

parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
export PS1="\u@\h \[\e[32m\]\w \[\e[91m\]\$(parse_git_branch)\[\e[00m\]$ "


