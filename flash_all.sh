#!/data/data/com.termux/files/usr/bin/bash
# termux-fastboot 批量刷入所有分区脚本
# 用法: ./flash_all.sh <USB设备路径>

set -e

# 显示帮助
if [ -z "$1" ]; then
    echo "用法: $0 <USB设备路径>"
    echo "获取设备路径: termux-usb -l"
    echo "示例: $0 /dev/bus/usb/001/002"
    exit 1
fi

DEVICE="$1"

# 定义跳过刷写的分区（无法通过 fastboot 刷写或会导致硬砖）
SKIP_PARTITIONS=(
    "preloader_raw" "preloader" "lk" "spmfw" "scp" "sspm" "gz" "ccu"
    "dpm" "gpueb" "mcupm" "mvpu_algo" "vcp" "pi_img" "cdt_engineering"
    "md1img" "mcf_ota"
)

# 检查是否存在 img 文件
shopt -s nullglob
IMGS=(*.img)
if [ ${#IMGS[@]} -eq 0 ]; then
    echo "错误: 当前目录下没有找到任何 .img 文件"
    exit 1
fi

# 测试 fastboot 连接
echo "测试 fastboot 连接..."
if ! termux-usb -r -e "fastboot devices" -E "$DEVICE" | grep -q "fastboot"; then
    echo "错误: 未检测到 fastboot 设备，请确认手机已进入 fastboot 模式并已授权 USB 权限"
    exit 1
fi

# 逐个刷写
for img in "${IMGS[@]}"; do
    partition="${img%.img}"
    SKIP=0
    for skip in "${SKIP_PARTITIONS[@]}"; do
        if [ "$partition" = "$skip" ]; then
            echo "跳过 $partition (不安全或不可用 fastboot 刷写)"
            SKIP=1
            break
        fi
    done
    if [ $SKIP -eq 1 ]; then
        continue
    fi

    echo "正在刷写 $partition -> $img ..."
    termux-usb -r -e "fastboot flash $partition $img" -E "$DEVICE"
    if [ $? -ne 0 ]; then
        echo "错误: 刷写 $partition 失败"
        exit 1
    fi
    echo "$partition 刷写完成"
done

echo "所有分区刷写完毕！"
echo "可以执行重启命令: termux-usb -r -e \"fastboot reboot\" -E $DEVICE"
