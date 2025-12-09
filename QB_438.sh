#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

USER=$1
PASSWORD=$2
PORT=${3:-8080}

# 生成 25000-65000 之间的随机端口
if [ -z "$4" ]; then
    # 使用系统随机数生成器，确保在指定范围内
    RANDOM_PORT=$(( (RANDOM % 40001) + 25000 ))
    UP_PORT=$RANDOM_PORT
    echo "使用随机上传端口: $UP_PORT"
else
    UP_PORT=$4
fi

RAM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((RAM / 8))

bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.3.9 -l v1.2.20 -x
apt install -y curl htop vnstat
systemctl stop qbittorrent-nox@$USER
#systemctl disable qbittorrent-nox@$USER
systemARCH=$(uname -m)
if [[ $systemARCH == x86_64 ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
elif [[ $systemARCH == aarch64 ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
fi
chmod +x /usr/bin/qbittorrent-nox

# 修改配置文件
QB_CONFIG="/home/$USER/.config/qBittorrent/qBittorrent.conf"

# 修改端口设置
sed -i "s/WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" $QB_CONFIG
sed -i "s/Connection\\\\PortRangeMin=[0-9]*/Connection\\\\PortRangeMin=$UP_PORT/" $QB_CONFIG

# 设置中文界面和禁用预分配等
sed -i "/\\[Preferences\\]/a General\\\\Locale=zh" $QB_CONFIG
sed -i "/\\[Preferences\\]/a Downloads\\\\PreAllocation=false" $QB_CONFIG
sed -i "/\\[Preferences\\]/a WebUI\\\\CSRFProtection=false" $QB_CONFIG

# 设置下载速度限制为 164000KB/s (约 160MB/s)
# 先删除可能存在的现有设置
sed -i '/Session\\GlobalMaxDownloadSpeed=/d' $QB_CONFIG
sed -i '/Session\\GlobalMaxUploadSpeed=/d' $QB_CONFIG

# 添加速度限制到 [BitTorrent] 部分
if grep -q "^\[BitTorrent\]" $QB_CONFIG; then
    # 如果 [BitTorrent] 部分存在，在它后面添加
    sed -i "/^\[BitTorrent\]/a Session\\\GlobalMaxDownloadSpeed=164000" $QB_CONFIG
    sed -i "/^\[BitTorrent\]/a Session\\\GlobalMaxUploadSpeed=0" $QB_CONFIG
else
    # 如果 [BitTorrent] 部分不存在，在文件末尾添加
    echo -e "\n[BitTorrent]\nSession\\GlobalMaxDownloadSpeed=164000\nSession\\GlobalMaxUploadSpeed=0" >> $QB_CONFIG
fi

# 其他配置
sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh
echo "systemctl enable qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "systemctl start qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "shutdown -r +1" >> /root/BBRx.sh

# 调整文件系统预留空间
ROOT_DEVICE=$(df -h / | awk 'NR==2 {print $1}')
if [ -n "$ROOT_DEVICE" ]; then
    tune2fs -m 1 "$ROOT_DEVICE" 2>/dev/null || echo "无法调整文件系统预留空间"
fi

echo "=========================================="
echo "配置完成！"
echo "WebUI 端口: $PORT"
echo "上传端口范围起始: $UP_PORT"
echo "下载速度限制: 164000 KB/s (约 160 MB/s)"
echo "=========================================="
echo "接下来将自动重启 2 次，流程预计 5-10 分钟..."
