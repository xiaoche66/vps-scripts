先拉下来再执行（更安全）

适合比较谨慎的用户 👇

wget https://raw.githubusercontent.com/你的用户名/你的仓库名/main/vps_traffic_alert.sh
chmod +x vps_traffic_alert.sh
nano vps_traffic_alert.sh   # 或 vim 编辑配置
./vps_traffic_alert.sh

四、脚本安装后会做什么？（工作模式说明）
🔹 1️⃣ 自动识别主网卡
ip route | awk '/default/ {print $5}'


无需手动填写 eth0 / ens3 / enp1s0

🔹 2️⃣ 安装并启用 vnStat

统计 真实网卡流量

不依赖 iptables

重启不丢数据

🔹 3️⃣ 每小时自动检查（cron）
0 * * * * /root/traffic_alert.sh


你可以随时改成：

每 30 分钟：*/30 * * * *

每 6 小时：0 */6 * * *

🔹 4️⃣ 多级提醒（只提醒一次）
阶段	触发条件
80%	提前预警
90%	严重警告
100%	达到上限

提醒状态记录在：

/root/.traffic_alert_state


避免 Telegram 刷屏

五、测试是否正常工作（强烈建议）
🔧 快速测试方法

临时修改：

MONTHLY_LIMIT=10


然后执行：

/root/traffic_alert.sh


应立即收到 Telegram 提醒。

六、如何卸载 / 停用
停止监控
crontab -e


删除包含 traffic_alert.sh 的那一行

删除文件
rm -f /root/traffic_alert.sh
rm -f /root/.traffic_alert_state

七、适用场景

✔ 月流量 1TB / 2TB VPS
✔ 不想超额才发现
✔ Telegram 常用
✔ 多台 VPS 可复制使用
✔ 轻量（常驻内存几乎为 0）
