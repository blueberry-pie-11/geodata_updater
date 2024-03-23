#!/bin/bash

# 设置默认变量
LOG_FILE="./updater.log"
RULES_DIR="rules"
DOWNLOAD_DIR="download"
GEO_SET_DIR="/docker/mosdns/data/geo_set"
GEOIP_TAGS_URL="./tags/geoip_tags.txt"
GEOSITE_TAGS_URL="./tags/geosite_tags.txt"
GEOIP_NAME="geoip.dat"
GEOSITE_NAME="geosite.dat"
GEOIP_SHA_NAME="geoip.dat.sha256sum"
GEOSITE_SHA_NAME="geosite.dat.sha256sum"
GEOIP_SHA_DL_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat.sha256sum"
GEOSITE_SHA_DL_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat.sha256sum"
GEOIP_DL_URL=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
GEOSITE_DL_URL=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
# 从文件geoip_tags.txt中读取数组GEOIP_TAGS，从geosite_tags.txt中读取数组GEOSITE_TAGS
GEOIP_TAGS=()
GEOSITE_TAGS=()

# check sha256 of geoip/geosite data, if the sha256 is not matched,
# download the new data file, and update the local data file and sha256 file
#
# @param geo_category: geoip or geosite
# @param geo_sha_dl_url: url to download sha256 file
#
# @return: 0 for not up to date, 1 for up to date
function check_update() {
    # geo category, such as geoip or geosite
    local geo_category="$1"
    # sha256 file name, such as geoip.dat.sha256
    local geo_sha="$1.dat.sha256sum"
    # data file name, such as geoip.dat
    local geo="$1.dat"
    # url to download sha256 file
    local geo_sha_dl_url="$2"

    echo "[NOTICE] check $geo_category sha256" >>"$LOG_FILE"

    # download sha256 file from url
    wget --timeout=30 --waitretry=5 --tries=3 -q "$geo_sha_dl_url" -O "$DOWNLOAD_DIR/$geo_sha"

    # if download sha256 file successfully
    if [ $? -eq 0 ]; then

        echo "[NOTICE] get $geo_category sha256 successfully!" >>"$LOG_FILE"

        # if both sha256 file and data file exist
        if [ -f "$DOWNLOAD_DIR/$geo" ]; then

            # if the downloaded sha256 is matched with the local sha256
            if [ "$(sha256sum $DOWNLOAD_DIR/$geo | awk '{print $1}')" == "$(grep "$geo" $DOWNLOAD_DIR/$geo_sha | awk '{print $1}')" ]; then
                echo "[NOTICE] $geo_category is not up to date!" >>"$LOG_FILE"
                # return not up to date
                return 0
            else
                echo "[NOTICE] $geo_category is up to date!" >>"$LOG_FILE"
                # return up to date
                return 1
            fi
        else
            echo "[NOTICE] $geo_category data file does not exist!" >>"$LOG_FILE"
            echo "[NOTICE] $geo_category is up to date!" >>"$LOG_FILE"
            # return up to date
            return 1
        fi
    else
        echo "[NOTICE] get $geo_category sha256 failed!" >>"$LOG_FILE"
        # return up to date
        return 1
    fi
}

# download geodata, return 0 if download successfully, otherwise return 1
#
# @param geo_category the geo category, such as geoip or geosite
# @param geo_dl_url url to download data file
#
# @return 0 if download successfully, otherwise return 1
function download_geodata() {
    # geo category, such as geoip or geosite
    local geo_category="$1"

    # geo data file name, such as geoip.dat
    local geo="$1.dat"

    # url to download geo data file
    local geo_dl_url="$2"

    # log download start
    echo "[NOTICE] download $geo_category" >>"$LOG_FILE"

    # download geodata
    wget --timeout=30 --waitretry=5 --tries=3 -q --show-progress "$geo_dl_url" -O "$DOWNLOAD_DIR/$geo"

    # if download successfully
    if [ $? -eq 0 ]; then
        echo "[NOTICE] get $geo_category successfully!" >>"$LOG_FILE"

        # return 0
        return 0
    else
        # log download failed
        echo "get $geo_category failed! please check your network!" >>"$LOG_FILE"

        # return 1
        return 1
    fi
}

# unpack downloaded geodata to rules directory
#
# @param geo_category the geo category, such as geoip or geosite
function unpack_geodata() {
    # geo category, such as geoip or geosite
    local geo_category="$1"

    # geo data file name, such as geoip.dat
    local geo="$1.dat"

    # geo data file tags, such as geosite_tags or geoip_tags
    local geo_tags=()
    if [ "$geo_category" == "geosite" ]; then
        geo_tags=("${GEOSITE_TAGS[@]}")
    else
        geo_tags=("${GEOIP_TAGS[@]}")
    fi

    # log unpack start
    echo "[NOTICE] unpack $geo_category" >>"$LOG_FILE"

    # unpack each tag
    for tag in "${geo_tags[@]}"; do
        # unpack geodata
        ./v2dat unpack "$geo_category" -o "$RULES_DIR" -f "$tag" "$DOWNLOAD_DIR/$geo"
    done
}

# create rules directory
#
# This function is used to create the rules directory and the download directory.
# It also creates the updater.log file if necessary and sets the execute permission of v2dat.
function create_dir() {
    # Check if the updater.log file size exceeds 10kB and delete it if necessary
    if [ $(stat -c%s "$LOG_FILE") -gt 102400 ]; then
        echo "Deleting the old $LOG_FILE file..." >>$LOG_FILE
        rm $LOG_FILE -rf
    fi

    # create rules directory
    mkdir -p $RULES_DIR $DOWNLOAD_DIR >>$LOG_FILE
    chmod +x ./v2dat >>$LOG_FILE
}

# Read geoip and geosite tags from the corresponding files.
#
# This function reads the geoip and geosite tags from the files geoip_tags.txt and
# geosite_tags.txt respectively. The function stores the tags in the arrays GEOIP_TAGS
# and GEOSITE_TAGS respectively.
#
# The function also prints the tags to the log file.
function get_tags() {
    echo "[INFO] Reading geoip tags from $GEOIP_TAGS_URL..." >>$LOG_FILE
    while IFS= read -r line; do
        # 排除\r 和 \n
        if [[ $line != $'\n' ]] && [[ $line != $'\r' ]]; then
            line=$(echo "$line" | sed 's/\r$//')
            GEOIP_TAGS+=("$line")
        fi
    done <"$GEOIP_TAGS_URL"

    echo "[INFO] Reading geosite tags from $GEOSITE_TAGS_URL..." >>$LOG_FILE
    while IFS= read -r line; do
        if [[ $line != $'\n' ]] && [[ $line != $'\r' ]]; then
            line=$(echo "$line" | sed 's/\r$//')
            GEOSITE_TAGS+=("$line")
        fi
    done <"$GEOSITE_TAGS_URL"

    echo "[NOTICE] GEOIP_TAGS: ${GEOIP_TAGS[@]}" >>$LOG_FILE
    echo "[NOTICE] GEOSITE_TAGS: ${GEOSITE_TAGS[@]}" >>$LOG_FILE
}

#
#
# starting updater...
#
#
echo "$(date +'%Y-%m-%d %H:%M:%S'): starting updater..." >>$LOG_FILE
create_dir
get_tags
#
#
# 调用函数更新geoip.dat和geosite.dat
#
#
# 更新geoip
check_update "geoip" "$GEOIP_SHA_DL_URL"
if [ $? -eq 1 ]; then
    download_geodata "geoip" "$GEOIP_DL_URL"
    unpack_geodata "geoip"
fi

# 更新geosite
check_update "geosite" "$GEOSITE_SHA_DL_URL"
if [ $? -eq 1 ]; then
    download_geodata "geosite" "$GEOSITE_DL_URL"
    unpack_geodata "geosite"
fi

# 覆盖目录geo_set下geo文件，删除rules下临时文件
echo "[NOTICE] copy geo files to geo_set" >>$LOG_FILE
cp $RULES_DIR/*.txt $GEO_SET_DIR/ -Rf
# rm -rf $RULES_DIR/*.txt

# 重启mosdns
echo "[NOTICE] restart mosdns" >>$LOG_FILE
docker restart mosdns

echo "$(date +'%Y-%m-%d %H:%M:%S'): updater finished!" >>$LOG_FILE
echo "===============================================" >>$LOG_FILE
echo "" >>$LOG_FILE
echo "" >>$LOG_FILE
echo "" >>$LOG_FILE
echo "===============================================" >>$LOG_FILE
