(function () {
  const layout = document.getElementById('layout');
  const chatLog = document.getElementById('chat-log');
  const msgInput = document.getElementById('msg');
  const sendBtn = document.getElementById('send');
  const cmdInput = document.getElementById('cmd');
  const runBtn = document.getElementById('run');
  const ptyOut = document.getElementById('pty-out');
  const leftPanel = document.getElementById('left');
  const toggleBtn = document.getElementById('toggle-chat');
  const openBtn = document.getElementById('open-chat');

  // 不覆寫 CSS 設定，佈局比例以 styles.css 的 grid-template-columns 為準（3:7）

  function appendChat(role, text) {
    const div = document.createElement('div');
    div.textContent = `${role}: ${text}`;
    chatLog.appendChild(div);
    chatLog.scrollTop = chatLog.scrollHeight;
  }

  // 你的 Agent API 位址（若為外部，請設定完整 URL 並處理 CORS）
  const AGENT_API = window.AGENT_API || '/agent/echo'; // 先以假路徑表示，可改為你的 API

  sendBtn.addEventListener('click', async () => {
    const text = msgInput.value.trim();
    if (!text) return;
    appendChat('You', text);
    msgInput.value = '';
    try {
      // 此處僅作為範例呼叫；請改為你的 Agent 端點
      const res = await fetch(AGENT_API, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: text })
      });
      const data = await res.json().catch(() => ({ reply: '[invalid json]' }));
      appendChat('Agent', data.reply ?? JSON.stringify(data));
    } catch (e) {
      appendChat('Agent', '[error connecting to agent]');
    }
  });

  msgInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') sendBtn.click();
  });

  // PTY WebSocket 連線
  let ptyWs;
  function connectPty() {
    try {
      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      ptyWs = new WebSocket(`${proto}://${location.host}/ws/pty`);
      ptyWs.onopen = () => {
        appendChat('System', 'PTY connected');
      };
      ptyWs.onmessage = (ev) => {
        ptyOut.textContent += ev.data;
        ptyOut.scrollTop = ptyOut.scrollHeight;
      };
      ptyWs.onclose = () => {
        appendChat('System', 'PTY disconnected');
      };
      ptyWs.onerror = () => {
        appendChat('System', 'PTY error');
      };
    } catch (e) {
      appendChat('System', 'PTY connect failed');
    }
  }
  connectPty();

  runBtn.addEventListener('click', () => {
    const cmd = cmdInput.value.trim();
    if (!cmd || !ptyWs || ptyWs.readyState !== WebSocket.OPEN) return;
    ptyWs.send(cmd + '\n');
    cmdInput.value = '';
  });

  cmdInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') runBtn.click();
  });

  // 聊天面板顯示/隱藏（預設開啟，記住使用者選擇）
  try {
    const saved = localStorage.getItem('chatVisible');
    let visible = saved !== 'false'; // 預設 true
    function applyVisible() {
      if (visible) {
        leftPanel.classList.remove('hidden');
        document.getElementById('layout').classList.remove('fullwidth');
        toggleBtn.textContent = '\u21E4'; // ↤
        openBtn.style.display = 'none';
      } else {
        leftPanel.classList.add('hidden');
        document.getElementById('layout').classList.add('fullwidth');
        toggleBtn.textContent = '\u21E5'; // ↦
        openBtn.style.display = '';
      }
    }
    applyVisible();
    toggleBtn?.addEventListener('click', () => {
      visible = !visible;
      localStorage.setItem('chatVisible', String(visible));
      applyVisible();
    });
    openBtn?.addEventListener('click', () => {
      visible = true;
      localStorage.setItem('chatVisible', 'true');
      applyVisible();
    });
  } catch {}
})();
