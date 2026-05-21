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

_ta_completions() {
    local sessions
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    COMPREPLY=($(compgen -W "${sessions}" -- "${COMP_WORDS[COMP_CWORD]}"))
}
complete -F _ta_completions ta

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

git-clonewtb() {
  local repo_url="${1:?Usage: clonewtb <repo-url> [branch] [--target-dir <dir>]}"
  local branch=""
  local target_dir=""

  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target-dir)
        target_dir="${2:?--target-dir requires an argument}"
        shift 2
        ;;
      -*)
        echo "clonewtb: unknown option '$1'" >&2
        return 1
        ;;
      *)
        if [[ -z "$branch" ]]; then
          branch="$1"
        else
          echo "clonewtb: unexpected argument '$1'" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  target_dir="${target_dir:-$(basename "$repo_url" .git)}"

  git clone --bare "$repo_url" "$target_dir/.bare" || return 1
  echo "gitdir: ./.bare" > "$target_dir/.git"

  # Fall back to the repo's default branch if none specified
  if [[ -z "$branch" ]]; then
    branch=$(git -C "$target_dir/.bare" symbolic-ref --short HEAD 2>/dev/null) \
      || { echo "clonewtb: could not detect default branch" >&2; return 1; }
  fi

  git -C "$target_dir/.bare" worktree add "../$branch" "$branch" || return 1

  echo "✓ $target_dir/"
  echo "    .bare/       (bare repo)"
  echo "    $branch/     (worktree — $branch)"
}

check-ssh-access() {
  local target_path="${1:?Usage: check_ssh_access <path> <user> [r|w|x]}"
  local username="${2:?Usage: check_ssh_access <path> <user> [r|w|x]}"
  local mode="${3:-r}"
  local uid gid groups
  local found_issues=0

  uid=$(id -u "$username" 2>/dev/null) \
    || { echo "check_ssh_access: user '$username' not found" >&2; return 1; }
  gid=$(id -g "$username")
  groups=$(id -G "$username")

  [[ "$mode" =~ ^[rwx]$ ]] \
    || { echo "check_ssh_access: mode must be r, w, or x" >&2; return 1; }

  # Convert mode letter to bit: r=4 w=2 x=1
  local mode_bit
  case "$mode" in
    r) mode_bit=4 ;;
    w) mode_bit=2 ;;
    x) mode_bit=1 ;;
  esac

  _csa_check_component() {
    local check_path="$1"
    local needed_bit="$2"
    local label="$3"
    local issues=()

    local owner owner_gid perms mode_str
    owner=$(stat -c '%U' "$check_path" 2>/dev/null)
    owner_gid=$(stat -c '%g' "$check_path")
    perms=$(stat -c '%a' "$check_path")
    mode_str=$(stat -c '%A' "$check_path")

    local applicable_bits perm_source
    if [[ "$username" == "$owner" ]]; then
      applicable_bits=$(( (8#$perms >> 6) & 7 ))
      perm_source="owner"
    elif echo "$groups" | grep -qw "$owner_gid"; then
      applicable_bits=$(( (8#$perms >> 3) & 7 ))
      perm_source="group"
    else
      applicable_bits=$(( 8#$perms & 7 ))
      perm_source="other"
    fi

    if (( (applicable_bits & needed_bit) == 0 )); then
      issues+=("permission denied ($perm_source bits: $mode_str)")
    fi

    if command -v getfacl &>/dev/null; then
      local acl_out
      acl_out=$(getfacl -p "$check_path" 2>/dev/null)

      local acl_user_entry
      acl_user_entry=$(echo "$acl_out" | grep -E "^user:${username}:")
      if [[ -n "$acl_user_entry" ]]; then
        local acl_perms
        acl_perms=$(echo "$acl_user_entry" | cut -d: -f3)
        case "$mode" in
          r) [[ "$acl_perms" != *r* ]] && issues+=("ACL user entry denies 'r': $acl_user_entry") ;;
          w) [[ "$acl_perms" != *w* ]] && issues+=("ACL user entry denies 'w': $acl_user_entry") ;;
          x) [[ "$acl_perms" != *x* ]] && issues+=("ACL user entry denies 'x': $acl_user_entry") ;;
        esac
      fi

      local mask_entry
      mask_entry=$(echo "$acl_out" | grep -E "^mask::")
      if [[ -n "$mask_entry" ]]; then
        local mask_perms
        mask_perms=$(echo "$mask_entry" | cut -d: -f3)
        case "$mode" in
          r) [[ "$mask_perms" != *r* ]] && issues+=("ACL mask restricts 'r': $mask_entry") ;;
          w) [[ "$mask_perms" != *w* ]] && issues+=("ACL mask restricts 'w': $mask_entry") ;;
          x) [[ "$mask_perms" != *x* ]] && issues+=("ACL mask restricts 'x': $mask_entry") ;;
        esac
      fi
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
      printf "  ✗ %s\n" "$label"
      for issue in "${issues[@]}"; do
        printf "      → %s\n" "$issue"
      done
      found_issues=1
    else
      printf "  ✓ %s\n" "$label"
    fi
  }

  # Walk every component of a path, checking traverse (x) on directories
  # and the requested mode on the final target.
  # Recursively called when a symlink is encountered.
  _csa_walk_path() {
    local walk_path="$1"
    local final_mode_bit="$2"
    local final_mode_label="$3"
    local depth="${4:-0}"

    local indent
    indent=$(printf '%*s' $(( depth * 2 )) '')

    local parts current
    IFS='/' read -ra parts <<< "$walk_path"
    [[ "$walk_path" == /* ]] && current="/" || current="."

    local components=()
    for part in "${parts[@]}"; do
      [[ -n "$part" ]] && components+=("$part")
    done

    local i
    for (( i=0; i<${#components[@]}; i++ )); do
      local part="${components[$i]}"
      [[ "$current" == "/" ]] && current="/$part" || current="$current/$part"

      if [[ ! -e "$current" && ! -L "$current" ]]; then
        printf "  ✗ %s%s  → does not exist\n" "$indent" "$current"
        found_issues=1
        return
      fi

      local is_last=$(( i == ${#components[@]} - 1 ))

      # Detect symlink before deciding what to check
      if [[ -L "$current" ]]; then
        local link_target
        link_target=$(readlink -f "$current")
        if (( is_last )); then
          printf "  ↳ %s%s  (symlink → %s)\n" "$indent" "$current" "$link_target"
        else
          printf "  ↳ %s%s  (symlink → %s, following...)\n" "$indent" "$current" "$link_target"
        fi

        # Walk the symlink target path from its root
        _csa_walk_path "$link_target" "$final_mode_bit" "$final_mode_label" $(( depth + 1 ))

        # If it was a mid-path symlink the rest of the original path is already
        # absorbed into the resolved target by readlink -f, so we're done.
        return
      fi

      if (( is_last )); then
        _csa_check_component "$current" "$final_mode_bit" \
          "${indent}${current}  (target — ${final_mode_label})"
      else
        _csa_check_component "$current" 1 \
          "${indent}${current}  (directory — traverse)"
      fi
    done
  }

  echo "Checking '$mode' access to '$target_path' for user '$username' (uid=$uid)"
  echo ""

  local mode_label
  case "$mode" in
    r) mode_label="read" ;;
    w) mode_label="write" ;;
    x) mode_label="execute" ;;
  esac

  _csa_walk_path "$target_path" "$mode_bit" "$mode_label" 0

  echo ""
  if [[ $found_issues -eq 0 ]]; then
    echo "✓ No issues found — '$username' can $mode_label '$target_path'"
  else
    echo "✗ Access problems found for '$username' on '$target_path'"
  fi

  # Clean up inner functions
  unset -f _csa_check_component _csa_walk_path
}


monitor-disk() {
	watch -n 3 "df -h | grep -v 'snap\|tmpfs'"
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
    if [ -z "$CONDA_PREFIX" ]; then
        echo "Error: not inside a conda environment." >&2
        return 1
    fi
    mkdir -p "$CONDA_PREFIX/etc/conda/activate.d/"
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
  result=$(ANTHROPIC_API_KEY=$_ANTHROPIC_API_KEY MAX_THINKING_TOKENS=0 claude -p --bare --model haiku \
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

vscode-to-cmd() {
    # Usage: launch-to-cmd <config-name> [path/to/launch.json]
    local config_name="$1"
    local json_path="${2:-.vscode/launch.json}"
    python3 - "$json_path" "$config_name" <<'PYEOF'
import sys, re, json, shlex

json_path, config_name = sys.argv[1], sys.argv[2]
try:
    with open(json_path) as f:
        text = f.read()
except FileNotFoundError:
    print(f"Error: '{json_path}' not found", file=sys.stderr)
    sys.exit(1)

def strip_jsonc(s):
    out, i, in_str = [], 0, False
    while i < len(s):
        ch = s[i]
        if ch == '\\' and in_str:
            out += [ch, s[i + 1] if i + 1 < len(s) else '']
            i += 2
            continue
        if ch == '"':
            in_str = not in_str
        elif not in_str and s[i:i + 2] == '//':
            while i < len(s) and s[i] != '\n':
                i += 1
            continue
        out.append(ch)
        i += 1
    return ''.join(out)

text = re.sub(r',(\s*[}\]])', r'\1', strip_jsonc(text))
data = json.loads(text)

cfg = next((c for c in data['configurations'] if c['name'] == config_name), None)
if cfg is None:
    available = [c['name'] for c in data['configurations']]
    print(f"Error: config '{config_name}' not found", file=sys.stderr)
    print(f"Available: {available}", file=sys.stderr)
    sys.exit(1)

parts = [f'{k}={shlex.quote(v)}' for k, v in cfg.get('env', {}).items()]
parts.append(shlex.quote(cfg.get('python', 'python')))
parts.append(shlex.quote(cfg.get('program', '')))
for arg in cfg.get('args', []):
    parts.append(shlex.quote(arg) if arg else "''")
print(' '.join(parts))
PYEOF
}

cmd-to-vscode() {
    # Usage: cmd-to-launch [command...]  or  echo "cmd" | cmd-to-launch
    local -a _args
    if [ $# -eq 0 ]; then
        _args=(0 "$(cat)")
    else
        _args=("$#" "$@")
    fi
    python3 - "${_args[@]}" <<'PYEOF'
import sys, re, json, shlex

mode = int(sys.argv[1])
tokens = shlex.split(sys.argv[2]) if mode == 0 else list(sys.argv[2:])

env = {}
while tokens and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', tokens[0]):
    k, v = tokens.pop(0).split('=', 1)
    env[k] = v

python_field = None
if tokens and re.match(r'.*python[\d.]*$', tokens[0]):
    interp = tokens.pop(0)
    if interp not in ('python', 'python3'):
        python_field = interp

program = tokens.pop(0) if tokens else ''

args_entries = []
i = 0
while i < len(tokens):
    tok = tokens[i]
    if tok.startswith('-') and i + 1 < len(tokens) and not tokens[i + 1].startswith('-'):
        args_entries.append((tok, tokens[i + 1]))
        i += 2
    else:
        args_entries.append((tok,))
        i += 1

ind = '    '
lines = ['{']
lines.append(f'{ind}"name": "My Config",')
lines.append(f'{ind}"type": "debugpy",')
lines.append(f'{ind}"request": "launch",')
if python_field:
    lines.append(f'{ind}"python": {json.dumps(python_field)},')
lines.append(f'{ind}"program": {json.dumps(program)},')
if args_entries:
    lines.append(f'{ind}"args": [')
    for j, entry in enumerate(args_entries):
        comma = ',' if j < len(args_entries) - 1 else ''
        if len(entry) == 2:
            lines.append(f'{ind}{ind}{json.dumps(entry[0])}, {json.dumps(entry[1])}{comma}')
        else:
            lines.append(f'{ind}{ind}{json.dumps(entry[0])}{comma}')
    lines.append(f'{ind}],')
lines.append(f'{ind}"console": "integratedTerminal"{"," if env else ""}')
if env:
    lines.append(f'{ind}"env": {{')
    items = list(env.items())
    for j, (k, v) in enumerate(items):
        comma = ',' if j < len(items) - 1 else ''
        lines.append(f'{ind}{ind}{json.dumps(k)}: {json.dumps(v)}{comma}')
    lines.append(f'{ind}}}')
lines.append('}')
print('\n'.join(lines))
PYEOF
}

# Add projects here. Keys are what you type after `workon`.
declare -A WORKON_PROJECTS=(
[scripts]="$HOME/dev/scripts"
[ai-defect-detection]="/media/ai-ubuntu/DATA/projects/Yuri/ai-defect-detection"
[repos]="$HOME/Repos"
)

# Snapshot any pre-existing `workon` (e.g. from virtualenvwrapper) as `_workon_venv`.
# Idempotent: only runs the first time, so re-sourcing .bashrc won't wrap our own function.
# NOTE: if you later add `source virtualenvwrapper.sh` to this file, put it ABOVE this block
# so the snapshot picks up its `workon` definition.
if declare -F workon >/dev/null 2>&1 && ! declare -F _workon_venv >/dev/null 2>&1; then
	eval "$(declare -f workon | sed '1 s/^workon /_workon_venv /')"
fi

# Merge entries from the user-editable env file ($WORKON_ENVS_LIST) into the
# caller's associative array (passed by name). Lines look like `name=/path`;
# `#` comments and blank lines are skipped. On a name collision with the
# caller's array, the file value wins; a one-shot warning per name per shell
# is emitted to stderr.
_workon_load_envs() {
    local -n _out="$1"
    local file="${WORKON_ENVS_LIST:-$HOME/.workon_envs}"
    [[ -z "$file" || ! -f "$file" ]] && return 0
    local line name path guard
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        [[ "$line" != *=* ]] && continue
        name="${line%%=*}"
        path="${line#*=}"
        [[ -z "$name" ]] && continue
        if [[ -n "${_out[$name]:-}" && "${_out[$name]}" != "$path" ]]; then
            guard="_WORKON_WARNED_${name//[^A-Za-z0-9_]/_}"
            if [[ -z "${!guard:-}" ]]; then
                printf 'workon: %s from %s overrides built-in (%s)\n' \
                    "$name" "$file" "${_out[$name]}" >&2
                printf -v "$guard" '%s' 1
            fi
        fi
        _out[$name]="$path"
    done < "$file"
}

workon() {
    local name="$1"
    local -A _envs
    local k
    for k in "${!WORKON_PROJECTS[@]}"; do _envs[$k]="${WORKON_PROJECTS[$k]}"; done
    _workon_load_envs _envs

    if [[ -n "$name" && -n "${_envs[$name]:-}" ]]; then
        cd -- "${_envs[$name]}" || return
        return 0
    fi
    if declare -F _workon_venv >/dev/null 2>&1; then
        _workon_venv "$@"
        return $?
    fi
    if [[ -z "$name" ]]; then
        printf 'Projects:\n'
        for k in "${!_envs[@]}"; do
            printf '  %s -> %s\n' "$k" "${_envs[$k]}"
        done | sort
        return 0
    fi
    printf 'workon: unknown project %q (and no virtualenvwrapper fallback found)\n' "$name" >&2
    return 1
}

# Tab completion: project names (array + file) + virtualenvwrapper venvs.
_workon_complete() {
    [[ $COMP_CWORD -eq 1 ]] || return 0
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local -A _envs
    local k
    for k in "${!WORKON_PROJECTS[@]}"; do _envs[$k]="${WORKON_PROJECTS[$k]}"; done
    _workon_load_envs _envs 2>/dev/null
    local -a opts=( "${!_envs[@]}" )
    if [[ -n "${WORKON_HOME:-}" && -d "$WORKON_HOME" ]]; then
        local d
        for d in "$WORKON_HOME"/*/; do
            [[ -d "$d" ]] || continue
            opts+=( "$(basename "$d")" )
        done
    fi
    COMPREPLY=( $(compgen -W "${opts[*]}" -- "$cur") )
}
complete -F _workon_complete workon

# Register the current directory as a workon env. With no arg, the name is the
# basename of $PWD; pass an explicit name to override. Initializes
# $WORKON_ENVS_LIST to ~/.workon_envs if unset.
workon-add() {
    local name="${1:-$(basename "$PWD")}"
    local path="$PWD"
    if [[ ! "$name" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        printf 'workon-add: invalid name %q (use [A-Za-z0-9_.-])\n' "$name" >&2
        return 1
    fi
    if [[ -z "${WORKON_ENVS_LIST:-}" ]]; then
        export WORKON_ENVS_LIST="$HOME/.workon_envs"
    fi
    touch -- "$WORKON_ENVS_LIST" || return 1

    if [[ -n "${WORKON_PROJECTS[$name]:-}" ]]; then
        printf 'workon-add: %s already in WORKON_PROJECTS (%s); file entry will override.\n' \
            "$name" "${WORKON_PROJECTS[$name]}" >&2
    fi
    if grep -q "^${name}=" -- "$WORKON_ENVS_LIST" 2>/dev/null; then
        printf 'workon-add: replacing existing entry for %s\n' "$name" >&2
        sed -i.bak "/^${name}=/d" -- "$WORKON_ENVS_LIST" && rm -f -- "$WORKON_ENVS_LIST.bak"
    fi
    printf '%s=%s\n' "$name" "$path" >> "$WORKON_ENVS_LIST"
    unset "_WORKON_WARNED_${name//[^A-Za-z0-9_]/_}"
    printf 'workon-add: %s -> %s (in %s)\n' "$name" "$path" "$WORKON_ENVS_LIST"
}

# Remove a workon env by name from $WORKON_ENVS_LIST. Entries hardcoded in
# WORKON_PROJECTS can only be removed by editing this script.
workon-rm() {
    local name="${1:?usage: workon-rm <name>}"
    if [[ ! "$name" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        printf 'workon-rm: invalid name %q\n' "$name" >&2
        return 1
    fi
    local file="${WORKON_ENVS_LIST:-$HOME/.workon_envs}"
    if [[ ! -f "$file" ]]; then
        printf 'workon-rm: %s does not exist\n' "$file" >&2
        return 1
    fi
    if ! grep -q "^${name}=" -- "$file"; then
        if [[ -n "${WORKON_PROJECTS[$name]:-}" ]]; then
            printf 'workon-rm: %s is hardcoded in WORKON_PROJECTS; edit set_env_yuri.sh to remove it.\n' "$name" >&2
        else
            printf 'workon-rm: no entry named %s in %s\n' "$name" "$file" >&2
        fi
        return 1
    fi
    sed -i.bak "/^${name}=/d" -- "$file" && rm -f -- "$file.bak"
    unset "_WORKON_WARNED_${name//[^A-Za-z0-9_]/_}"
    printf 'workon-rm: removed %s from %s\n' "$name" "$file"
}

_workon_rm_complete() {
    [[ $COMP_CWORD -eq 1 ]] || return 0
    local file="${WORKON_ENVS_LIST:-$HOME/.workon_envs}"
    [[ -f "$file" ]] || return 0
    local names
    names=$(sed -n 's/^\([A-Za-z0-9_.-]\+\)=.*/\1/p' -- "$file")
    COMPREPLY=( $(compgen -W "$names" -- "${COMP_WORDS[COMP_CWORD]}") )
}
complete -F _workon_rm_complete workon-rm

stty stop ^J
