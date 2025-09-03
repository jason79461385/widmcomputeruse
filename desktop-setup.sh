#!/bin/bash

# 為 WIDM 使用者建立桌面快捷方式的腳本

# 建立桌面目錄
mkdir -p /home/WIDM/Desktop

# 建立 Chrome 桌面快捷方式
cat > /home/WIDM/Desktop/chrome.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Google Chrome
Comment=Access the Internet
Exec=/usr/bin/google-chrome-stable --no-sandbox --disable-dev-shm-usage
Icon=google-chrome
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;
EOF

# 建立 VS Code 桌面快捷方式
cat > /home/WIDM/Desktop/code.desktop << 'EOF'
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=/usr/bin/code --no-sandbox --disable-dev-shm-usage --unity-launch
Icon=vscode
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;
EOF

# 建立 Terminal 桌面快捷方式
cat > /home/WIDM/Desktop/terminal.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Terminal
Comment=Use the command line
Keywords=shell;prompt;command;commandline;cmd;
TryExec=xfce4-terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
Categories=System;TerminalEmulator;
EOF

# 建立 File Manager 桌面快捷方式
cat > /home/WIDM/Desktop/filemanager.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=File Manager
Comment=Browse the file system
Keywords=folder;manager;explore;disk;filesystem;
Exec=thunar
Icon=system-file-manager
Type=Application
Categories=System;FileManager;
EOF

# 設定權限和所有者
chmod +x /home/WIDM/Desktop/*.desktop
chown -R WIDM:WIDM /home/WIDM/Desktop