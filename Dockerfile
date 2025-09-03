FROM --platform=linux/amd64 ubuntu:22.04

# 最小化安裝，避免互動式提示
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1
ENV DEBIAN_PRIORITY=high

# 一次性安裝所有必要套件並清理
RUN apt-get update && apt-get install -y \
    # 最小 XFCE 桌面環境
    xfce4-session \
    xfce4-panel \
    xfce4-terminal \
    xfce4-goodies \
    xfce4-appfinder \
    xfwm4 \
    thunar \
    xfdesktop4 \
    # X11 相關
    xvfb \
    x11vnc \
    x11-utils \
    # D-Bus 服務 (XFCE 必需)
    dbus-x11 \
    # noVNC 相關
    novnc \
    websockify \
    # 基本工具
    curl \
    netcat-openbsd \
    net-tools \
    ca-certificates \
    wget \
    gnupg \
    software-properties-common \
    unzip \
    sudo \
    # 文字編輯器
    vim \
    # 字體支援
    fonts-liberation \
    fonts-dejavu \
    # 清理快取和不必要檔案
    && apt-get -y remove light-locker xfce4-screensaver xfce4-power-manager || true \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /tmp/*

# 安裝 nginx 與 Python 3（供前端反代與 PTY WS 服務）
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx python3 python3-pip \
    && pip3 install --no-cache-dir websockets \
    && rm -rf /var/lib/apt/lists/* /root/.cache/pip

# # 安裝 Visual Studio Code （can Work)
# RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg \
#     && echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
#     && apt-get update \
#     && apt-get install -y --no-install-recommends code \
#     && rm -rf /var/lib/apt/lists/*
# # 安裝 firefox (can work)
# RUN add-apt-repository ppa:mozillateam/ppa \
#  && apt-get update \
#  && apt-get install -y --no-install-recommends firefox-esr \
#  && update-alternatives --set x-www-browser /usr/bin/firefox-esr \
#  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV USERNAME=WIDM
ENV HOME=/home/$USERNAME
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers


# 建立最小使用者環境
RUN useradd -m -s /bin/bash WIDM \
    && mkdir -p /home/WIDM/.vnc \
    && mkdir -p /home/WIDM/.config/xfce4 \
    && chown -R WIDM:WIDM /home/WIDM


# 複製最小啟動腳本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 設定 noVNC 默認頁面重導向 (can work)
RUN echo '<!DOCTYPE html>\n\
<html>\n\
<head>\n\
    <meta charset="utf-8">\n\
    <title>Ubuntu Desktop</title>\n\
    <meta http-equiv="refresh" content="0; url=/vnc.html">\n\
</head>\n\
<body>\n\
    <p>Redirecting to VNC...</p>\n\
    <p>If not redirected, <a href="/vnc.html">click here</a></p>\n\
</body>\n\
</html>' > /usr/share/novnc/index.html

# 佈署自訂首頁、Nginx 設定與 PTY 服務程式
COPY nginx.conf /etc/nginx/nginx.conf
COPY web/ /opt/web/
COPY pty-server.py /opt/pty-server.py


# 僅暴露必要埠口
EXPOSE 8081

# 啟動腳本
CMD ["/start.sh"]