#!/bin/bash

# 设置默认变量
TMP_GEOIP="geoip.dat"
TMP_GEOSITE="geosite.dat"
GEOIP_TAGS_DIR="./tags/geoip_tags.txt"
GEOSITE_TAGS_DIR="./tags/geosite_tags.txt"
RULES_DIR="rules"
DOWNLOAD_DIR="download"
GEO_SET_DIR="/docker/mosdns/data/geo_set"
GEOIP_URL=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
GEOSITE_URL=https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat


# create rules directory
echo "creating rules directory..."
mkdir -p $RULES_DIR
mkdir -p $DOWNLOAD_DIR
chmod +x ./v2dat

# 获取导出参数
echo "start updating..."
# 从文件geoip_tags.txt中读取数组GEOIP_TAGS，从geosite_tags.txt中读取数组GEOSITE_TAGS
GEOIP_TAGS=()
GEOSITE_TAGS=()

# 读取文件geoip_tags.txt
while IFS= read -r line; do
    line=$(echo "$line" | tr -d '[:space:]')
    GEOIP_TAGS+=("$line")
done <$GEOIP_TAGS_DIR

# 读取文件geosite_tags.txt
while IFS= read -r line; do
    line=$(echo "$line" | tr -d '[:space:]')
    GEOSITE_TAGS+=("$line")
done <$GEOSITE_TAGS_DIR

echo "GEOIP_TAGS: ${GEOIP_TAGS[@]}"
echo "GEOSITE_TAGS: ${GEOSITE_TAGS[@]}"


# download geoip.dat
echo "[NOTICE] download geoip.dat"
wget --timeout=30 --waitretry=5 --tries=3 -q --show-progress $GEOIP_URL -O $DOWNLOAD_DIR/$TMP_GEOIP

# 判断是否下载成功
if [ $? -eq 0 ]; then
    echo "[NOTICE] get geoip.dat successfully!"
    # unpack geoip.dat
    echo "[NOTICE] unpack geoip.dat"
    for tag in ${GEOIP_TAGS[@]}; do
        ./v2dat unpack geoip -o $RULES_DIR -f $tag $DOWNLOAD_DIR/$TMP_GEOIP
    done
else
    echo "get geoip.dat failed! please check your network!"
    # exit 1
fi

# download geosite.dat
echo "[NOTICE] download geosite.dat"
wget --timeout=30 --waitretry=5 --tries=3 -q $GEOSITE_URL -O $DOWNLOAD_DIR/$TMP_GEOSITE

# 判断是否下载成功
if [ $? -eq 0 ]; then
    echo "[NOTICE] get geosite.dat successfully!"
    # unpack geosite.dat
    echo "[NOTICE] unpack geosite.dat"
    for tag in ${GEOSITE_TAGS[@]}; do
        ./v2dat unpack geosite -o $RULES_DIR -f $tag $DOWNLOAD_DIR/$TMP_GEOSITE
    done
else
    echo "get geosite.dat failed! please check your network!"
    exit 1
fi

# 覆盖目录geo_set下geo文件，删除rules下临时文件
echo "[NOTICE] copy geo files to geo_set"
cp $RULES_DIR/*.txt $GEO_SET_DIR/ -Rf
# rm -rf $RULES_DIR/*.txt

# 重启mosdns
echo "[NOTICE] restart mosdns"
docker restart mosdns
