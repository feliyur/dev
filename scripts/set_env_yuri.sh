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

docker-start-with-proxy() {
    docker run --network="host" -it --rm -e http_proxy=$http_proxy -e https_proxy=$https_proxy -e ftp_proxy=$ftp_proxy -e no_proxy="$no_proxy" -u $(id -u):$(id -g) ${@:1}
#--name extract_athena_images bcr-de01.inside.bosch.cloud/perkit/dst-lh5-converter:latest bash
}

alias tls="tmux ls"
alias ta="tmux attach-session -t"

tkill() {
    for var in "$@"
    do
        tmux kill-session -t $var
    done
}

alias dfs="df -h | grep -v snap"

register-ipykernel() {
	pip install ipykernel
	python -m ipykernel install --user --name ${VIRTUAL_ENV##*\/}
}

kill-pulse() {
	ps -ae | grep pulse | grep tty | cut -d" " -f1 | xargs kill -9
}


git-status() {
	watch --color -n 1 git -c color.status=always status "${@}"
}

git-log() {
    git log --oneline --pretty=format:"%h %an %s" "${@}"
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

nvidia-list-gpus() {
    nvidia-smi --query-gpu=name --format=csv,noheader
}


clone-directory-structure() {
	from="$1"

	# Resolve real path to prevent weird things such as recursive copy
	to="`realpath ""$2""`"

	parentdirname=$(basename -- "$from")
	pushd "$from" > /dev/null
	find . -type d -exec mkdir -p -- "$to/$parentdirname/{}" \;
	popd > /dev/null
}

upgrade-vscode-version() {
    commit_id=$1
    pushd ~/.vscode-server/
    mkdir -p "cli/servers/" && cd cli/servers
    rm -rf "Stable-$commit_id*"
    mkdir "Stable-$commit_id" && cd "Stable-$commit_id"
    internet-on
    wget  https://update.code.visualstudio.com/commit:${commit_id}/server-linux-x64/stable
    tar -xf stable 
    mv vscode-server-linux-x64 "server" 
    rm stable
    popd
}

git-branch() {
	git rev-parse --abbrev-ref HEAD ${@}
}

git-root() {
	git rev-parse --show-toplevel
}

git-modified() {
	git status --porcelain | grep ^M | trim-whitespace | cut -d' ' -f2
}

git-switch() {
    # Get current branch name
    local current_branch=$(git branch --show-current)
    
    # Check if there are any changes to stash
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Stashing changes on branch '$current_branch'..."
        git stash push -m "Auto-stash from $current_branch"
        local stashed=true
    else
        local stashed=false
    fi
    
    # Perform git switch with all provided parameters
    echo "Switching branch..."
    if ! git switch "$@"; then
        echo "Error: Failed to switch branch"
        return 1
    fi
    
    # Get the new branch name after switch
    local new_branch=$(git branch --show-current)
    
    # Try to pop the most recent stash that matches the new branch
    if [[ "$stashed" == "false" ]]; then
        # Look for existing stash for this branch
        local stash_entry=$(git stash list | grep "$new_branch" | head -n1 | cut -d: -f1)
        if [[ -n "$stash_entry" ]]; then
            echo "Found existing stash for branch '$new_branch', applying..."
            git stash pop "$stash_entry"
        fi
    else
        # If we just stashed and switched to the same branch, don't pop
        if [[ "$current_branch" != "$new_branch" ]]; then
            # Look for existing stash for the new branch
            local stash_entry=$(git stash list | grep "$new_branch" | head -n1 | cut -d: -f1)
            if [[ -n "$stash_entry" ]]; then
                echo "Found existing stash for branch '$new_branch', applying..."
                git stash pop "$stash_entry"
            fi
        fi
    fi
}

# Completion function for git-switch
_git_switch_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Get git switch options
    opts="--create -c --force-create -C --detach -d --guess --no-guess --force -f --discard-changes --merge -m --conflict --quiet -q --progress --no-progress --track -t --no-track --orphan --ignore-other-worktrees --recurse-submodules --no-recurse-submodules"

    # If the current word starts with -, complete with options
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    # For branch names, get local and remote branches
    case "${prev}" in
        --create|-c|--force-create|-C|--orphan)
            # For branch creation, don't complete with existing branches
            return 0
            ;;
        *)
            # Complete with branch names (local and remote)
            local branches
            branches=$(git branch --all --format="%(refname:short)" 2>/dev/null | sed 's|^origin/||' | sort -u)
            COMPREPLY=( $(compgen -W "${branches}" -- ${cur}) )
            return 0
            ;;
    esac
}

# Register the completion function
complete -F _git_switch_completion git-sw

trim-whitespace() {
    awk '{$1=$1};1'
}

pushas() {
    git commit -m "$1" && git push
}

conda-env-dir() {
	conda info --envs | grep '*' | awk '{print $3}'
}

# activate a conda environment. Completion based on ~/.conda/envs directory content
conda-workon() {
	if [ $# -eq 0 ]; then
		if [ -d "$HOME/.conda/envs" ]; then
			ls -1 "$HOME/.conda/envs"
		fi
		return
	fi
	conda activate "$1"
}

_conda-workon_completions()
{
	if [ "${#COMP_WORDS[@]}" -gt 2 ]; then
        return 
	fi

    environments_txt=""
    if [ -f "$HOME/.conda/environments.txt" ]; then
        environments_txt="$(while read -r file; do echo "${file##*/}"; done < "$HOME/.conda/environments.txt")"
    fi

    environments_dir=""
    if [ -d "$HOME/.conda/envs" ]; then
        environments_dir="$(ls "$HOME/.conda/envs")"
    fi

    envs_options="$environments_txt $environments_dir"
	COMPREPLY=($(compgen -W "${envs_options}" "${COMP_WORDS[1]}"))
	# COMPREPLY=($(compgen -W "now tomorrow never" "${COMP_WORDS[1]}"))
}
complete -F '_conda-workon_completions' 'conda-workon'

conda-setvirtualenvproject()
{
    echo "cd \"$( readlink -f `pwd` )\"" > $CONDA_PREFIX/etc/conda/activate.d/cwd.sh
}

alias dus='du -sh * | sort -k1 -rh'


cluster-launch-interactive-node() {
	# bs = 60 sets higher priority for interactive job (50 is the default)
	#bsub -I -q inter_v100 -J 484654846546847 -n 8 -M 16384 -W 9:00 -gpu "num=1" -R "span[hosts=1]" /bin/bash
	bsub -Is -q inter_v100 -J 2371349357 -n 8 -M 32768 -W 09:00 -gpu "num=1" -R "span[hosts=1]" /bin/bash 
}

_bkill_completions()
{
	# if [ "${#COMP_WORDS[@]}" != "2" ]; then
        # return 
	# fi
	
    running_job_ids="`bjobs | cut -d' ' -f1 | tail -n+2`"
	COMPREPLY=($(compgen -W "${running_job_ids}" "${COMP_WORDS[-1]}"))
}
complete -F '_bkill_completions' 'bkill'

git-worktree-link()
{
    repo="$1"
    version="$2"

    repo_worktree_dir="$repo.git"
    if [ ! -e "$repo_worktree_dir" ]; then
        echo "ERROR: Worktree directory $repo_worktree_dir does not exist at current working directory"
        return
    fi
    echo "worktree dir: $repo_worktree_dir"

    repo_version_dir="$repo_worktree_dir/$version"
    if [ ! -e "$repo_version_dir" ]; then
        echo "ERROR: Version directory $repo_version_dir does not exist."
        return
    fi
    echo "version dir: $repo_version_dir"

    # Try to delete repo link (will fail if repo is directory)
    if [ -e "$repo" ]; then
        rm $repo
    fi

    if [ -e "$repo" ]; then
        echo "ERROR: Unable to delete $repo. Is it a link?"
        return
    fi

    echo "Creating link $repo -> $repo_version_dir"
    ln -s "$repo_version_dir" $repo
}

git-worktree-link-multiple()
{
    version="$1"
    repos="${@:2}"
    echo "linking repos $repos to version $version"

    for repo in $repos; do
        git-worktree-link "$repo" "$version"
    done
    
}

git-repo-to-worktree()
{
    repo="$1"
    cp -r "$repo" "$repo.git"
    pushd $repo.git
    git config --bool core.bare true
    popd

    branch_name=`git -C "${repo}" rev-parse --abbrev-ref HEAD ${@}`
    echo "Moving $repo to $repo.git/$branch_name"
    mv "$repo" "${repo}.git/${branch_name}"
}

cluster-kill-batch() {
	bkill `bjobs | grep batch | cut -f1 -d' '`
}

attach-interactive() {
	interactive_job_id=`bjobs | grep inter_ | cut -f1 -d' '`
	battach -L `which bash` $interactive_job_id
}

alias activate-ros='source /opt/ros/noetic/setup.bash'


# Show git branch in prompts
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
export PS1="\u@\h \[\e[32m\]\w \[\e[91m\]\$(parse_git_branch)\[\e[00m\]$ "


format_and_test() {
	parent_dir=`dirname "$1"`
	black "$1" && isort "$1" && black "$parent_dir/tests" && isort "$parent_dir/tests" && pytest "$parent_dir/tests" && pylint "$1" && pylint "$parent_dir/tests"
}

which-gpu() {
	nvidia-smi -L | grep "$1"
}

# Claude CLI completion via Ctrl+G
_claude_suggest() {
  local prompt="${READLINE_LINE}"
  if [[ -z "$prompt" ]]; then return; fi

  # Print below the current line without disrupting readline
  tput sc       # save cursor
  tput cud1     # move down one line
  tput el       # clear to end of line
  echo -n "(claude thinking...)"

  local result
  result=$(claude -p --model haiku \
    "Give me a single shell command (no explanation, no markdown, no backticks) that does: $prompt" \
    2>/dev/null)

  tput rc       # restore cursor position (clears the "thinking..." line)
  tput el       # clear to end of line

  if [[ -z "$result" ]]; then
    tput cud1; echo -n "claude error: no response"; tput rc
    return 1
  fi

  # Replace the current line with the result
  READLINE_LINE="$result"
  READLINE_POINT=${#result}
}

bind -x '"\C-g": _claude_suggest'

alias blims="blimits -u $USER"

function cd_up() {
  cd $(printf "%0.s../" $(seq 1 $1 ));
}
alias 'cd..'='cd_up'

stty stop ^J
