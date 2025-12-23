#!/bin/bash
# =========================================
# VPS 月流量监控（多级提醒版）
# vnStat + Telegram + Email（可选）
# 自动识别主网卡
# =========================================

# --------- 配置项 ----------
MONTHLY_LIMIT=1024          # 月流量上限（GB）
EMAIL=""                     # 邮件，不需要留空 ""
TG_BOT_TOKEN="YOUR_BOT_TOKEN"
TG_CHAT_ID="YOUR_CHAT_ID"
CRON_INTERVAL="0 * * * *"    # 每小时检查

# 多级提醒百分比
LEVEL1=80
LEVEL2=90
LEVEL3=100

# --------- 自动获取主网卡 ----------
INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
[ -z "$INTERFACE" ] && echo "❌ 获取网卡失败" && exit 1
echo "✅ 主网卡：$INTERFACE"

# --------- 安装依赖 ----------
if [ -f /etc/debian_version ]; then
    apt update && apt install -y vnstat curl mailutils
elif [ -f /etc/redhat-release ]; then
    yum install -y epel-release
    yum install -y vnstat curl mailx
else
    echo "❌ 不支持的系统"
    exit 1
fi

# --------- 启动 vnStat ----------
systemctl enable vnstat
systemctl start vnstat
vnstat -u -i $INTERFACE
systemctl restart vnstat

# --------- 生成监控脚本 ----------
ALERT_SCRIPT="/root/traffic_alert.sh"
STATE_FILE="/root/.traffic_alert_state"

cat > $ALERT_SCRIPT <<EOF
#!/bin/bash
INTERFACE="$INTERFACE"
MONTHLY_LIMIT=$MONTHLY_LIMIT
TG_BOT_TOKEN="$TG_BOT_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
EMAIL="$EMAIL"

LEVEL1=$LEVEL1
LEVEL2=$LEVEL2
LEVEL3=$LEVEL3

STATE_FILE="$STATE_FILE"

USED=\$(vnstat -i \$INTERFACE --oneline | awk -F';' '{print \$10}' | sed 's/[^0-9.]//g' | cut -d. -f1)
[ -z "\$USED" ] && exit 0

PERCENT=\$(( USED * 100 / MONTHLY_LIMIT ))

touch \$STATE_FILE

send_msg() {
    MSG="\$1"
    if [ -n "\$TG_BOT_TOKEN" ] && [ -n "\$TG_CHAT_ID" ]; then
        curl -s -X POST https://api.telegram.org/bot\$TG_BOT_TOKEN/sendMessage \
            -d chat_id=\$TG_CHAT_ID \
            -d text="\$MSG" >/dev/null
    fi
    if [ -n "\$EMAIL" ]; then
        echo "\$MSG" | mail -s "VPS 流量告警" \$EMAIL
    fi
}

check_level() {
    LEVEL=\$1
    TAG="LEVEL_\$LEVEL"
    if [ "\$PERCENT" -ge "\$LEVEL" ] && ! grep -q "\$TAG" \$STATE_FILE; then
        send_msg "⚠️ VPS 流量提醒（\$LEVEL%）
已使用：\$USED GB
使用率：\$PERCENT%
月上限：\$MONTHLY_LIMIT GB
网卡：\$INTERFACE"
        echo "\$TAG" >> \$STATE_FILE
    fi
}

check_level \$LEVEL1
check_level \$LEVEL2
check_level \$LEVEL3
EOF

chmod +x $ALERT_SCRIPT

# --------- 设置 cron ----------
(crontab -l 2>/dev/null; echo "$CRON_INTERVAL $ALERT_SCRIPT") | crontab -

echo "====================================="
echo "✅ 多级流量监控部署完成"
echo "网卡：$INTERFACE"
echo "月流量：${MONTHLY_LIMIT}GB"
echo "提醒：${LEVEL1}% / ${LEVEL2}% / ${LEVEL3}%"
echo "Cron：每小时检测"
echo "====================================="
