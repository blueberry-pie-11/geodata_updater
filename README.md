# geodata_updater
自动下载geoip和geosite，并根据tag导出文本文件，用于mosdns使用

##1.安装curl以及wget

##2.tags.txt文件中最后一行必须回车，使光标进入下一行

##3.设置crontab -e
```
    0 */12 * * *  cd /docker/geodata_updater/data/ && bash updater.sh
```
