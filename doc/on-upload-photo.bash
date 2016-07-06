#!/bin/bash
test -z "$targetroot" && targetroot="$(dirname "$EYEFI_UPLOADED")"
test -z "$EYEFI_LOG" && EYEFI_LOG="/var/log/iii/iiid.log"
test -z "$FORMAT" && FORMAT="%04d%02d%02d_%02d%02d%02d"

# etime needs to have the format "/Y:M:D H:I:S"
make_vars() {
    echo -n "ttype=$1 "
    sed <<<$etime -e 's,^[^/]\+/,,' -e 's, 0*, hour=,' -e 's,^0*,year=,' -e 's,:0*, month=,' -e 's,:0*, day=,' -e 's,:0*, minute=,' -e 's,:0*, second=,'
}

# Use exiftime to try to find the file time
j_time() {
    local j="$1"
    local etime="$(exiftime -s / -tg "$j" 2>/dev/null)"
    [[ -z "$etime" ]] && etime="$(exiftime -s / -td "$j" 2>/dev/null)"
    [[ -z "$etime" ]] && etime="$(exiftime -s / -tc "$j" 2>/dev/null)"
    [[ -z "$etime" ]] && return 1
    make_vars JPG <<<$etime
}

# Use iii-extract-riff-chunk to try to find the file time
a_time() {
    local a="$1"
    local etime="$(iii-extract-riff-chunk "$a" '/RIFF.AVI /LIST.ncdt/nctg'|dd bs=1 skip=82 count=19 2>/dev/null)"
    [[ -z "$etime" ]] && return 1
    make_vars AVI <<<$etime
}

# Use mediainfo to try to find the file time
m_time() {
    local j="$1"
    local etime="$(mediainfo "$j" | grep -i date | cut -d: -f2- | head -n1 | sed -e 's, UTC ,UTC/,' -e 's,-,:,g' 2>/dev/null)"
    [[ -z "$etime" ]] && return 1
    make_vars MOV <<<$etime
}

# Use stat to try to find the file time
f_time() {
    local f="$1"
    # etime needs to have the format "/Y:M:D H:I:S"
    local etime="/$(stat -c %y "$j" | cut -d. -f1 | sed -e 's,-,:,g' 2>/dev/null)"
    [[ -z "$etime" ]] && return 1
    make_vars FILE <<<$etime
}

iii_report()
{
    echo "[$( date +'%Y-%m-%d %H:%M:%S' )] ${1}" >> "${EYEFI_LOG}"
}

move_file()
{
    local file_in="$1"
    local dir_dest="$2"
    local success=false

    mkdir -p "$dir_dest"

    stem="$(basename "${file_in%.*}")"
    ttype="$(basename "${file_in#*.}")"

    for(( i=0; i < 100 ; ++i )) do
        [[ $i = 0 ]] && tf="$stem.$ttype" || tf="$(printf '%s_%02d.%s' "${stem}" "${i}" "${ttype}")"
        tf="$dir_dest/$tf"

        if ln -T "$ul" "$tf" &>/dev/null && rm "$ul"  ; then
            success=true
            break
        fi
    done

    return ${success}
}

ul="$EYEFI_UPLOADED"

if ! vars="$(j_time "$ul"||a_time "$ul"||m_time "$ul")" ; then
    report="Timeless $(basename "$ul") uploaded"

    # Move the file to the unorganized directory for manual handling
    move_file "$ul" "$targetroot/unorganized"
else
    eval "$vars"
    stem="$(printf "$FORMAT" "$year" "$month" "$day" "$hour" "$minute" "$second")"
    ttype="$(basename "${ul#*.}")"
    targetdir="$(printf "%s/%04d/%02d" "$targetroot" "$year" "$month")"

    success=$( move_file "$ul" "$targetdir" )

    if $success ; then
        report="$(basename "$tf") uploaded to $targetdir"
    else
        report="$(basename "$ul") uploaded, but couldn't move it."
    fi
fi

echo "$report"

type iii_report &>/dev/null && iii_report "$report"
