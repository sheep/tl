#!/bin/bash
function vhd-create()
{
    vhd-util create -n ${image} -s ${size}
}

function raw-create()
{
    truncate -s "${size}"M "${image}"
}

function qcow2-create()
{
    qemu-img create -f qcow2 "${image}" "${size}"M
}

function image-create()
{
    $arg_parse

    [[ -z "${overwrite}" ]] && overwrite=false

    $requireargs format image size

    if [[ -e $image ]] ; then
	if "${overwrite}" ; then
	    info "${image} exists; overwriting"
	    rm -f ${image}
	else
	    fail "${image} exists.  Use overwrite=true to overwrite"
	fi
    fi

    ${format}-create
}

function image-get-blockspec()
{
    local _s

    $arg_parse

    $requireargs dev format image var

    _s="vdev=${dev},format=${format},target=${image}"

    [[ -n "$backendtype" ]] && _s="backendtype=${backendtype},${_s}"

    eval "$var=\"$_s\""
}

function image-attach()
{
    local blockspec

    $arg_parse

    image-get-blockspec var=blockspec

    xl block-attach 0 ${blockspec}
    # !!!!
    usleep 100000
}

function image-detach()
{
    $arg_parse

    $requireargs dev

    xl block-detach 0 $dev
}

function image-partition()
{
    $arg_parse

    $requireargs dev

    local devp="${dev}1"

    # Make partitions
    parted -a optimal /dev/$dev mklabel msdos

    parted -a optimal -- /dev/$dev unit compact mkpart primary ext3 "1" "-1" 

    # Make filesystem
    mkfs.ext4 /dev/$devp
}