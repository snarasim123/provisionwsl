#!/usr/bin/env bash

# Different functions generate different parts (segments) of the PS1 prompt.
# Each function should leave the colors in a clean state (e.g. call reset if they changed any colors).

__mkps1_debian_chroot() {
    # This string is intentionally single-quoted:
    # It will be evaluated when $PS1 is evaluated to generate the prompt each time.
    echo '${debian_chroot:+($debian_chroot)}';
}

__mkps1_inject_exitcode() {
    local code=$1

    if [ "$code" -ne "0" ]; then
        echo " $code "
    fi
}

__mkps1_exitcode() {
    local bg_red=`tput setab 1`;
    local white=`tput setaf 15`;
    local reset=`tput sgr0`;

    # We need to run a function at runtime to evaluate the exitcode.
    echo "\[${bg_red}${white}\]\$(__mkps1_inject_exitcode \$?)\[${reset}\]"
}

__mkps1_time() {
    local BG_GRAY=`tput setab 240`;
    local BG_NEW=`tput setab 33`;
    local white=`tput setaf 7`;
    local reset=`tput sgr0`;

    echo "\[${BG_NEW}${white}\] \t\[${reset}\]"
}

__mkps1_arrows() {
    local bold=`tput bold`;
    local red=`tput setaf 1`;
    local green=`tput setaf 34`;
    local reset=`tput sgr0`;

    echo "\[${bold}${red}\]🮥🮥\[${green}\]🮥\[${reset}\]";
}

__mkps1_workdir() {
    local bold=`tput bold`;
    local cyan=`tput setaf 45`;
    local NEWBLUE=`tput setab 33`;
    local GRAY=`tput setab 240`;
    local reset=`tput sgr0`;

    echo "\[${NEWBLUE}${white}\]\w\[${reset}\]";
}

__mkps1_colon() {
    local bold=`tput bold`;
    local cyan=`tput setaf 45`;
    local NEWBLUE=`tput setab 33`;
    local GRAY=`tput setab 240`;
    local reset=`tput sgr0`;

    echo "\[${NEWBLUE}${white}\]:\[${reset}\]";
}

__mkps1_box_top() {
    local cyan=`tput setaf 45`;
    local reset=`tput sgr0`;
    echo "\[${cyan}\]╭\[${reset}\]"
}

__mkps1_box_bottom() {
    local NEWBLUE=`tput setab 33`;
    local cyan=`tput setaf 45`;
    local reset=`tput sgr0`;
    echo "\[${cyan}\]-\[${reset}\]"    
}


__mkps1_user_prompt() {
    local bold=`tput bold`;
    local reset=`tput sgr0`;
    
    echo "\[${bold}\]\$\[${reset}\]";
}

__mkps1() {
    local ps1="$(__mkps1_box_top)$(__mkps1_debian_chroot)$(__mkps1_exitcode)$(__mkps1_time)$(__mkps1_colon)$(__mkps1_workdir) $(__mkps1_user_prompt)";
    echo "$ps1";
}

PS1="$(__mkps1)"
export LS_COLORS=$LS_COLORS:'di=1;37:' ;
export LS_COLORS=$LS_COLORS:'ex=1;31:' ;
export LS_COLORS=$LS_COLORS:'ln=1;33:' ;

# stty erase '^?'
# export HISTSIZE=5000
# export PS1='\[\e]0;\W\a\]\n\[\e[37m\]\u@\h \[\e[37m\]\W\[\e[0m\]\n\$ '