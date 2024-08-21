#!/usr/bin/env bash

# PS1="$(__mkps1)"
function nonzero_return() {
	RETVAL=$?
	[ $RETVAL -ne 0 ] && echo "($RETVAL Err) "
}

function prompt_shortpath(){
# export PS1="\[\e[105m\]\D{%m/%d/%y}@\[\e[97m\]\t<\[\e[39m\]\u@\[\e[97m\]\w>\[\e[0m\]"	
export PS1="\[\e[48;5;57m\]\D{%m/%d/%y}-\[\e[97m\]\t<\u\[\e[39m\]:\[\e[97m\]\W>\[\e[0m\]"
}

function prompt_fullpath(){
# export PS1="\[\e[106m\]\D{%m/%d/%y}@\[\e[97m\]\t<\[\e[39m\]\u@\[\e[97m\]\W>\[\e[0m\]"	
export PS1="\[\e[48;5;57m\]\D{%m/%d/%y}-\[\e[97m\]\t<\u\[\e[39m\]:\[\e[97m\]\w>\[\e[0m\]"
}

# export PS1="\[\e[105m\]\D{%m/%d/%y}@\[\e[97m\]\t<\[\e[39m\]\u@\[\e[97m\]\W>\[\e[0m\]"
prompt_shortpath()

export LS_COLORS=$LS_COLORS:'di=1;37:' ;
export LS_COLORS=$LS_COLORS:'ex=1;31:' ;
export LS_COLORS=$LS_COLORS:'ln=1;33:' ;


# export 	PS1="\[\e[41m\]\`nonzero_return\`\[\e[m\]\[\e[45m\]\D{%m/%d/%y}\[\e[m\]\[\e[45m\]@\[\e[m\]\[\e[37;45m\]\t\[\e[m\]\[\e[45m\]>\[\e[m\]\[\e[45m\]\W\[\e[m\] "
# stty erase '^?'
# export HISTSIZE=5000
# export PS1='\[\e]0;\W\a\]\n\[\e[37m\]\u@\h \[\e[37m\]\W\[\e[0m\]\n\$ '