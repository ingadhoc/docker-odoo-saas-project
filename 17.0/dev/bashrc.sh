adhoc_promp_git_branch(){
    local git_branch="$(git branch --show-current 2>/dev/null)";
    local git_ps1_style="";
    local reset='\e(B\e[0m'
    if [ -n "$git_branch" ]; then
        git diff-index --quiet HEAD -- 2>/dev/null
        local git_changed=$?
        if [ "$git_changed" == 0 ]; then
            git_ps1_style='\e[1;32m'; # Light Green
        else
            git_ps1_style='\e[1;91m'; # red
        fi
        git_ps1_style=$git_ps1_style"⫱"$git_branch" "$reset
    fi
    echo -en $git_ps1_style
}

PS1=$PS1"\$(adhoc_promp_git_branch)"