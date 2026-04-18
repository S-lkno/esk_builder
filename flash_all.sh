#!/data/data/com.termux/files/usr/bin/bash
# termux-usb fastboot 批量刷写脚本
# 使用方法：bash flash_all.sh [设备路径]
# 如果未提供设备路径，则尝试从环境变量 ANDROID_SERIAL 读取

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取设备路径
DEVICE_PATH="$1"
if [ -z "$DEVICE_PATH" ]; then
    DEVICE_PATH="$ANDROID_SERIAL"
fi
if [ -z "$DEVICE_PATH" ]; then
    echo -e "${RED}错误：未指定设备路径。${NC}"
    echo "用法: $0 /dev/bus/usb/XXX/YYY"
    echo "或先设置环境变量: export ANDROID_SERIAL=/dev/bus/usb/XXX/YYY"
    exit 1
fi

echo -e "${GREEN}使用设备路径: $DEVICE_PATH${NC}"

# 检查 termux-usb 是否可用
if ! command -v termux-usb &> /dev/null; then
    echo -e "${RED}错误：termux-usb 未安装，请运行 pkg install termux-api${NC}"
    exit 1
fi

# 检查 fastboot 是否可用
if ! command -v fastboot &> /dev/null; then
    echo -e "${RED}错误：fastboot 未安装，请运行 pkg install android-tools${NC}"
    exit 1
fi

# 测试连接
echo -e "${YELLOW}测试 fastboot 连接...${NC}"
if ! termux-usb -r -e "fastboot devices" -E "$DEVICE_PATH" | grep -q "fastboot"; then
    echo -e "${RED}无法检测到 fastboot 设备，请确认目标手机已进入 fastboot 模式且 USB 权限已授予。${NC}"
    exit 1
fi
echo -e "${GREEN}设备连接正常。${NC}"

# 获取当前活动 slot（可选）
CURRENT_SLOT=$(termux-usb -r -e "fastboot getvar current-slot" -E "$DEVICE_PATH" 2>/dev/null | grep "current-slot" | awk '{print $2}')
if [ -n "$CURRENT_SLOT" ]; then
    echo -e "${GREEN}当前 active slot: $CURRENT_SLOT${NC}"
fi

# 定义需要跳过的分区（这些分区通常不能单独刷写，或者会导致问题）
SKIP_PARTITIONS="preloader preloader_raw lk lk2 scp spmfw gz md1img mcupm ccu dpm gpueb mcf_ota pi_img mvpu_algo vcp"

# 开始刷写
echo -e "${YELLOW}开始刷写所有 .img 文件...${NC}"
COUNT=0
SUCCESS=0
FAIL=0

for img in *.img; do
    # 跳过如果不是文件
    [ -f "$img" ] || continue

    # 提取分区名（去掉 .img 后缀）
    PARTITION="${img%.img}"

    # 检查是否需要跳过
    if echo "$SKIP_PARTITIONS" | grep -qw "$PARTITION"; then
        echo -e "${YELLOW}跳过危险/保留分区: $PARTITION${NC}"
        continue
    fi

    echo -e "${GREEN}[$((COUNT+1))] 正在刷写 $PARTITION -> $img${NC}"
    set +e  # 临时允许错误，单个分区失败不终止脚本
    termux-usb -r -e "fastboot flash $PARTITION $img" -E "$DEVICE_PATH"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  成功${NC}"
        ((SUCCESS++))
    else
        echo -e "${RED}  失败${NC}"
        ((FAIL++))
    fi
    set -e
    ((COUNT++))
done

echo -e "${YELLOW}刷写完成。成功: $SUCCESS, 失败: $FAIL, 总计: $COUNT${NC}"

# 可选：最后重启设备
read -p "是否重启设备？(y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    termux-usb -r -e "fastboot reboot" -E "$DEVICE_PATH"
    echo -e "${GREEN}设备正在重启...${NC}"
fi
