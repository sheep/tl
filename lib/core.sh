#!/bin/bash

: ${dry_run:=false}

TESTLIB_HELP=()

arg_parse_cmd=\
"local -a args;
local _a;
local _vn;
local _m;

_m=true;

for _a in \"\$@\" ; do
    false && echo \"Evaluating \${_a} [[ \"\${_a/=}\" = \"\${_a}\" ]]\";
    if \$_m && [[ \"\${_a/=}\" != \"\${_a}\" ]] ; then
        false && echo Parameter;
        _vn=\${_a%%=*};
        eval \"local \$_vn\";
        eval \"\$_a\";
    else
        false && echo Argument;
        _m=false;
        args+=(\"\$_a\");
    fi;
done"

arg_parse="eval $arg_parse_cmd"

# FIXME: Get rid of this?
function pop()
{
    local _var
    _var="$1";

    eval "${_var}=(\"\${${_var}[@]:1}\")"
}

function die()
{
   echo FATAL $@
   exit 1
}

function fail()
{
   echo FATAL $@
   [[ -n "$fail_cleanup" ]] && $fail_cleanup
   exit 1
}

function info()
{
   echo INFO $@ 1>&2
}

function error()
{
   echo ERROR $@ 1>&2
}

function status()
{
   echo STATUS $@ 1>&2
   $status_popup && (zenity --info --text="$@" &)
   return 0
}

function parse-separator-array()
{
    local _pca_array_var="$2"
    local _pca_list="$3"
    local -a _pca_internal
    local OLD_IFS

    OLD_IFS=${IFS}
    IFS="$1"
    _pca_internal=($_pca_list)
    IFS="${OLD_IFS}"

    eval "${_pca_array_var}=(${_pca_internal[@]})"
}

function parse-comma-array()
{
    parse-separator-array "," "$1" "$2"
}

function test-parse-comma-array()
{
    local vars
    local out
    local i

    vars="a,b,c"
    parse-comma-array out $vars

    for i in ${out[@]} ; do
	echo "X $i";
    done
}

function test-parse-colon-array()
{
    local vars
    local out
    local i

    vars="kodo2:c6-test:c6-vm"
    parse-separator-array ":" out $vars

    for i in ${out[@]} ; do
	echo "X $i";
    done
}

function parse-config-array()
{
    local _pcfga_array_var="$1"
    local _pcfga_reset_array_var="$2"
    local _pcfga_list="$3"
    local -a _pcfga_internal
    local -a _pcfgr_internal
    local _j
    local _varname
    local _value

    echo "About to parse list"
    parse-comma-array _pcfga_internal ${_pcfga_list}

    echo Reset values
    for _j in ${_pcfga_internal[@]} ; do
	_varname=$(expr match "${_j}" '\([^=]*\)')
	_value=$(eval echo \$$_varname)
	echo " $_varname=$_value"
	_pcfgr_internal=(${_pcfgr_internal[@]} "${_varname}=${_value}")
    done

    eval "${_pcfga_array_var}=(${_pcfga_internal[@]})"
    eval "${_pcfga_reset_array_var}=(${_pcfgr_internal[@]})"
}

# Pass in either the current function name, or the name of the script
requireargs="eval _func=\"\$FUNCNAME\" ; eval [[ -n \\\"\$_func\\\" ]] || _func=\$0 ; eval _require-args \$_func"

function _require-args()
{
    local _arg
    local _args
    local fail_popup

    _args=($@)

    fail_popup=false

    for _arg in ${_args[@]:1} ; do
	eval "[[ -n \"\${$_arg}\" ]] || fail \"${_args[0]}: Missing $_arg\""
    done
}

# Used to make a local cfg_ variable overriding the global one if
# a given argument is given; otherwise, set the local variable to the
# global one.
#
# For example, you can pass isosr_path to host-install, and it will
# create a local variable cfg_isosr_path and set it to iso-sr, so that
# host-install-post will get that value without having to pass it in;
# Alternately, you can set iso_sr to cfg_isosr_path.
#
# Use like this: cfg_override [global_var] [local_var] ; eval $ret_eval
function cfg_override()
{
    unset ret_eval
    if eval "[[ -n \"\$$2\" ]]" ; then
	ret_eval="local $1=\$$2"
    else
	ret_eval="$2=\$$1"
    fi
}

# Used to run commands that must be done inside a network through a gateway
# 
# To use, set TESTLIB_REMOTE=true and TESTLIB_GATEWAY to the ssh gateway to use.
: ${TESTLIB_REMOTE:=false}
function gateway-cmd
{
    $requireargs TESTLIB_GATEWAY

    echo ssh "${TESTLIB_GATEWAY}" tl $_cmd "$@"
    ssh "${TESTLIB_GATEWAY}" tl $_cmd "$@"
}

gateway_cmd="if \"\${TESTLIB_REMOTE}\" ; then _cmd=\"\$FUNCNAME\" ; gateway-cmd \"\$@\" ; return ; fi"
gateway_override="eval $gateway_cmd"

function help()
{
    for i in "${TESTLIB_HELP[@]}" ; do
	echo "$i"
    done
}

function cmdline()
{
    local cmd;

    if [[ "$#" -eq "0" ]] ; then
	echo "Usage: $0 function-name [arguments...]"
	exit 1
    fi

    $arg_parse
    info Running "${args[0]}"
    "${args[0]}" "${args[@]:1}" || exit 1

    if ! [[ -z "$RET" ]] ; then
	echo $RET
    fi
}