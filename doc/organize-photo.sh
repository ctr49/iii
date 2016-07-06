#!/bin/bash

# Set variables
export targetroot=/backup/pictures
export EYEFI_LOG="/var/log/iii/upload.log"

while [[ $# -gt 0 ]]; do

    export EYEFI_UPLOADED="${1}"

    source ./on-upload-photo.bash

    shift

done