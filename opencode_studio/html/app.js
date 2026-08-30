/* OpenCode Studio panel logic. Talks to Ruby via sketchup.* callbacks. */

function $(id) { return document.getElementById(id); }

function appendLog(kind, message) {
  if (kind === 'state') {
    if (message === '__done__') setRunning(false);
    return;
  }
  const entry = document.createElement('div');
  entry.className = 'entry ' + kind;
  entry.textContent = message;
  const log = $('log');
  log.appendChild(entry);
  log.scrollTop = log.scrollHeight;
}

function setState(state) {
  const dot = $('statusDot');
  dot.classList.toggle('ok', !!state.configured);
  if (!state.configured) {
    $('settings').classList.remove('hidden');
    appendLog('info', 'Welcome! Add your OpenCode API key in Settings (⚙) to begin.');
  }
  if (state.base_url) $('baseUrl').value = state.base_url;
  if (state.model) $('model').value = state.model;
}

function setModels(models) {
  const list = $('modelList');
  list.innerHTML = '';
  (models || []).forEach(function (m) {
    const opt = document.createElement('option');
    opt.value = m.id;
    opt.label = m.name || m.id;
    list.appendChild(opt);
  });
}

function setRunning(flag) {
  $('sendBtn').disabled = flag;
  $('stopBtn').disabled = !flag;
  const dot = $('statusDot');
  dot.classList.toggle('busy', flag);
  if (!flag) appendLog('ok', 'Idle.');
}

$('toggleSettings').onclick = function () {
  $('settings').classList.toggle('hidden');
};

$('saveSettings').onclick = function () {
  window.sketchup.save_settings($('apiKey').value, $('baseUrl').value, $('model').value);
  $('apiKey').value = '';
};

$('refreshModels').onclick = function () {
  appendLog('info', 'Fetching model list…');
  window.sketchup.fetch_models();
};

$('sendBtn').onclick = sendTask;

$('stopBtn').onclick = function () {
  window.sketchup.stop_task();
};

$('prompt').addEventListener('keydown', function (e) {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') sendTask();
});

function sendTask() {
  const prompt = $('prompt').value.trim();
  if (!prompt) return;
  $('prompt').value = '';
  window.sketchup.send_task(prompt);
}

window.appendLog = appendLog;
window.setState = setState;
window.setModels = setModels;
window.setRunning = setRunning;

// The Ruby bridge may not be wired until slightly after DOM load — retry.
function notifyReady(attempt) {
  if (window.sketchup && window.sketchup.ready) {
    try { window.sketchup.ready(); } catch (e) { /* retried below */ }
  }
  if (attempt < 5) {
    setTimeout(function () { notifyReady(attempt + 1); }, 300);
  }
}

window.addEventListener('load', function () { notifyReady(0); });
notifyReady(0);
