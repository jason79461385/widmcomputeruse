#!/bin/bash

# 修正版啟動腳本 - 解決 D-Bus 和共享記憶體問題
export DISPLAY=:1

echo "=== 設定使用者和密碼 ==="
# 設定 VNC 密碼
echo "WIDM:${USER_PASSWORD:-password}" | chpasswd
su - WIDM -c "mkdir -p ~/.vnc && x11vnc -storepasswd ${VNC_PASSWORD:-vncpass} ~/.vnc/passwd"

echo "=== 啟動 D-Bus 服務 ==="
# 啟動 D-Bus 服務 (XFCE 必需)
service dbus start
mkdir -p /run/dbus
dbus-daemon --system --fork

echo "=== 啟動 Xvfb 虛擬顯示器 ==="
# 清理並啟動 Xvfb
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null
Xvfb :1 -screen 0 ${SCREEN_RESOLUTION:-1366x768x24} -ac +extension GLX +render -noreset -nolisten tcp &
XVFB_PID=$!

# 等待 Xvfb 完全啟動
echo "等待 Xvfb 啟動..."
for i in {1..10}; do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "Xvfb 已成功啟動"
        break
    fi
    sleep 1
done

echo "=== 啟動 XFCE 桌面環境 ==="
# 為 WIDM 使用者啟動 D-Bus session
su - WIDM -c "
    export DISPLAY=:1
    # 啟動使用者 D-Bus session
    eval \$(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
    # 啟動 XFCE 桌面環境
    xfce4-session &
" &

# 等待桌面環境啟動
echo "等待桌面環境啟動..."
sleep 8

echo "=== 建立桌面快捷方式 ==="
# 執行桌面設定腳本
/desktop-setup.sh

echo "=== 啟動 VNC 服務器 ==="
# 啟動 VNC 服務器，禁用共享記憶體以避免權限問題
# su - WIDM -c "
#     export DISPLAY=:1
#     x11vnc -forever -usepw -shared -rfbauth ~/.vnc/passwd -rfbport 5901 -display :1 \
#            -quiet -noxdamage -noxfixes -noxrandr -wait 10 \
#            -noshm -nodpms -nomodtweak &
# " &
su - WIDM -c "
    export DISPLAY=:1
    x11vnc -forever -shared -rfbport 5901 -display :1 \
           -quiet -noxdamage -noxfixes -noxrandr -wait 10 \
           -noshm -nodpms -nomodtweak -nopw &
" &
VNC_PID=$!

# 等待並驗證 VNC 服務器
echo "等待 VNC 服務器啟動..."
for i in {1..15}; do
    if netstat -tlnp 2>/dev/null | grep -q ":5901 "; then
        echo "VNC 服務器已成功啟動在埠口 5901"
        break
    fi
    echo "等待 VNC 服務器... ($i/15)"
    sleep 2
done

# 最終驗證 VNC 連接
echo "測試 VNC 連接..."
if nc -z localhost 5901 2>/dev/null; then
    echo "VNC 連接測試成功"
else
    echo "警告: VNC 連接測試失敗"
    # 顯示除錯資訊
    echo "當前進程:"
    ps aux | grep -E "(Xvfb|x11vnc|xfce)" | grep -v grep
    echo "埠口狀態:"
    netstat -tlnp | grep -E "(5901|8081)"
fi

echo "=== 啟動 noVNC Web 介面 ==="
# 啟動 noVNC 的 websockify 在 8091，供 Nginx 反代
cd /usr/share/novnc
websockify --web . --heartbeat=30 8091 localhost:5901 &
NOVNC_PID=$!

echo "=== 啟動 PTY WebSocket 服務 ==="
export PTY_PORT=8092
python3 /opt/pty-server.py &
PTY_PID=$!

echo "=== 啟動 Nginx 反向代理（提供 8081） ==="
nginx -g 'daemon off;' &
NGINX_PID=$!

echo "=== 服務啟動完成 ==="
echo "所有服務已啟動："
echo "- Xvfb PID: $XVFB_PID"  
echo "- VNC PID: $VNC_PID"
echo "- noVNC PID: $NOVNC_PID"
echo "- 存取網址: http://localhost:8081"
echo "- VNC 密碼: ${VNC_PASSWORD:-vncpass}"

# 監控關鍵服務並保持運行
while true; do
    # 檢查 Xvfb
    if ! kill -0 $XVFB_PID 2>/dev/null; then
        echo "Xvfb 停止，重新啟動..."
        Xvfb :1 -screen 0 ${SCREEN_RESOLUTION:-1366x768x24} -ac +extension GLX +render -noreset -nolisten tcp &
        XVFB_PID=$!
    fi
    
    # 檢查 VNC（僅檢查，不自動重啟以避免循環錯誤）
    if ! netstat -tlnp 2>/dev/null | grep -q ":5901 "; then
        echo "VNC 服務器已停止"
    fi
    
    # 檢查 noVNC/websockify
    if ! kill -0 $NOVNC_PID 2>/dev/null; then
        echo "noVNC 停止，重新啟動..."
        cd /usr/share/novnc && websockify --web . --heartbeat=30 8091 localhost:5901 &
        NOVNC_PID=$!
    fi

    # 檢查 PTY 服務
    if ! kill -0 $PTY_PID 2>/dev/null; then
        echo "PTY 服務停止，重新啟動..."
        export PTY_PORT=8092
        python3 /opt/pty-server.py &
        PTY_PID=$!
    fi

    # 檢查 Nginx
    if ! kill -0 $NGINX_PID 2>/dev/null; then
        echo "Nginx 停止，重新啟動..."
        nginx -g 'daemon off;' &
        NGINX_PID=$!
    fi
    
    sleep 30
done