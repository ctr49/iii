#!/bin/bash
test -z "$TARGET_ROOT" && TARGET_ROOT="$(dirname "$EYEFI_UPLOADED")"
test -z "$EYEFI_LOG" && EYEFI_LOG="/var/log/iii/iiid.log"
test -z "$FORMAT" && FORMAT="%04d%02d%02d_%02d%02d%02d"
test -z "$S3_BUCKET" && S3_BUCKET="s3://zeven11.cabuki.com/photos/"

# etime needs to have the format "/Y:M:D H:I:S"
make_vars() {
    echo -n "ttype=$1 "
    sed <<<$etime -e 's,^[^/]\+/,,' -e 's, 0*, hour=,' -e 's,^0*,year=,' -e 's,:0*, month=,' -e 's,:0*, day=,' -e 's,:0*, minute=,' -e 's,:0*, second=,'
}

# Use exiftime to try to find the file time
j_time() {
    local j="$1"
    local ttype="$(basename "${j#*.}")"
    local etime="$(exiftime -s / -tg "$j" 2>/dev/null)"
    [[ -z "$etime" ]] && etime="$(exiftime -s / -td "$j" 2>/dev/null)"
    [[ -z "$etime" ]] && etime="$(exiftime -s / -tc "$j" 2>/dev/null)"
    [[ -z "$etime" ]] && return 1
    make_vars "$ttype" <<<$etime
}

# Use iii-extract-riff-chunk to try to find the file time
a_time() {
    local j="$1"
    local ttype="$(basename "${j#*.}")"
    local etime="$(iii-extract-riff-chunk "$a" '/RIFF.AVI /LIST.ncdt/nctg'|dd bs=1 skip=82 count=19 2>/dev/null)"
    [[ -z "$etime" ]] && return 1
    make_vars "$ttype" <<<$etime
}

# Use mediainfo to try to find the file time
m_time() {
    local j="$1"
    local ttype="$(basename "${j#*.}")"
    local etime="$(mediainfo "$j" | grep -i date | cut -d: -f2- | head -n1 | sed -e 's, UTC ,UTC/,' -e 's,-,:,g' 2>/dev/null)"
    [[ -z "$etime" ]] && return 1
    make_vars "$ttype" <<<$etime
}

iii_report()
{
    echo "[$( date +'%Y-%m-%d %H:%M:%S' )] $@" >> "${EYEFI_LOG}"
}

move_file()
{
    local file_in="$1"
    local file_out="$2"
    local dir_dest="$3"
    local ret=""

    mkdir -p "$dir_dest"

    stem="$(basename "${file_out%.*}")"
    ttype="$(basename "${file_out#*.}")"

    for(( i=0; i < 100 ; ++i )) do
        [[ $i = 0 ]] && tf="$stem.$ttype" || tf="$(printf '%s_%02d.%s' "${stem}" "${i}" "${ttype}")"
        new_name="$tf"
        tf="$dir_dest/$tf"

        if ln -T "$ul" "$tf" &>/dev/null && rm "$ul"  ; then
            ret="${new_name}"
            break
        else
            ret=""
        fi
    done

    echo -n "${ret}"
}

ul="$EYEFI_UPLOADED"

if ! vars="$(j_time "$ul"||a_time "$ul"||m_time "$ul")" ; then
    report="Timeless $(basename "$ul") uploaded"

    # Move the file to the unorganized directory for manual handling
    move_file "$ul" "$ul" "$TARGET_ROOT/unorganized"
else
    eval "$vars"
    stem="$(printf "$FORMAT" "$year" "$month" "$day" "$hour" "$minute" "$second")"
    ttype="$(basename "${ul#*.}")"
    targetdir="$(printf "%s/%04d/%02d" "$TARGET_ROOT" "$year" "$month")"

    new_name=$( move_file "$ul" "$stem.$ttype" "$targetdir" )

    if [[ ! -z "$new_name" ]] ; then
        report="${ul} moved to ${targetdir}/${new_name}"
        
        cd "${TARGET_ROOT}"
        sync_dir="$(printf "%04d/%02d" "$year" "$month")"
        iii_report $( /usr/local/bin/s3cmd put --no-progress "${targetdir}/${new_name}" "${S3_BUCKET}${sync_dir}/" )

    else
        report="$(basename "$ul") uploaded, but couldn't move it."
    fi
fi

#echo "$report"

type iii_report &>/dev/null && iii_report "$report"
