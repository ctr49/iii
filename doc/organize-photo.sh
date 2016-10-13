#!/bin/bash

# Set variables
export TARGET_ROOT=/backup/pictures
export EYEFI_LOG="/var/log/iii/upload.log"
export S3_BUCKET="s3://zeven11.cabuki.com/photos/"


SOURCE="${BASH_SOURCE[0]}"

while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done

DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

while [[ $# -gt 0 ]]; do

    export EYEFI_UPLOADED=$( readlink -f "${1}" )

    source "$DIR"/on-upload-photo.bash

    shift

done