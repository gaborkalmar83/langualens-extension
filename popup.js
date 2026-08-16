/* Popup: language pair, reading options, model download and the saved list. */

const DEFAULTS = {
  source: 'nl',
  target: 'en',
  mode: 'paragraph',
  hide: false,
  autoLookup: true,
  autoTranslate: false,
  hint: 'tap to reveal'
};

const $ = (id) => document.getElementById(id);
let settings = { ...DEFAULTS };

function fillLanguages(select, selected) {
  select.innerHTML = '';
  self.LLLanguages.ORDERED.forEach((lang) => {
    const option = document.createElement('option');
    option.value = lang.tag;
    option.textContent = self.LLLanguages.labelOf(lang.tag);
    if (lang.tag === selected) { option.selected = true; }
    select.appendChild(option);
  });
}

async function save(patch) {
  settings = { ...settings, ...patch };
  await chrome.storage.local.set({ settings });
  const tab = await activeTab();
  if (tab) {
    chrome.tabs.sendMessage(tab.id, { type: 'll-settings', settings }).catch(() => {});
  }
}

async function activeTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab && tab.id != null ? tab : null;
}

async function refreshStatus() {
  const status = $('status');
  const download = $('download');

  if (!self.LLTranslator.supported()) {
    status.textContent =
      'Chrome 138 or newer with the built-in translator is required. Update Chrome, ' +
      'then reopen this popup.';
    download.classList.add('hidden');
    return;
  }

  const state = await self.LLTranslator.availability(settings.source, settings.target);
  if (state === 'available') {
    status.textContent = 'Model ready. Translation runs on this device.';
    download.classList.add('hidden');
  } else if (state === 'downloadable') {
    status.textContent = 'Model not downloaded yet. Downloads once, then works offline.';
    download.classList.remove('hidden');
  } else if (state === 'downloading') {
    status.textContent = 'Downloading model…';
    download.classList.add('hidden');
  } else {
    status.textContent = 'Chrome cannot translate this pair.';
    download.classList.add('hidden');
  }
}

function renderSaved(saved) {
  $('savedCount').textContent = `${saved.length} saved`;

  const list = $('savedList');
  list.innerHTML = '';
  saved.slice().reverse().slice(0, 40).forEach((item) => {
    const li = document.createElement('li');
    li.textContent = item.text;
    if (item.translation) {
      const em = document.createElement('em');
      em.textContent = item.translation;
      li.appendChild(em);
    }
    list.appendChild(li);
  });

  /* Tab separated, the format desktop Anki imports: front, back, context, origin. */
  const tsv = saved.map((item) => [
    item.text, item.translation || '', item.context || '', item.origin || ''
  ].map((f) => String(f).replace(/[\t\r\n]+/g, ' ')).join('\t')).join('\n');

  $('export').href = URL.createObjectURL(
    new Blob([tsv], { type: 'text/tab-separated-values' })
  );
}

async function loadSaved() {
  const data = await chrome.storage.local.get('saved');
  renderSaved(data.saved || []);
}

async function init() {
  const data = await chrome.storage.local.get('settings');
  settings = { ...DEFAULTS, ...(data.settings || {}) };

  fillLanguages($('source'), settings.source);
  fillLanguages($('target'), settings.target);
  $('mode').checked = settings.mode === 'sentence';
  $('hide').checked = settings.hide;
  $('autoLookup').checked = settings.autoLookup;
  $('autoTranslate').checked = settings.autoTranslate;

  await refreshStatus();
  await loadSaved();

  $('source').addEventListener('change', async (e) => {
    await save({ source: e.target.value });
    refreshStatus();
  });
  $('target').addEventListener('change', async (e) => {
    await save({ target: e.target.value });
    refreshStatus();
  });
  $('swap').addEventListener('click', async () => {
    const { source, target } = settings;
    await save({ source: target, target: source });
    fillLanguages($('source'), settings.source);
    fillLanguages($('target'), settings.target);
    refreshStatus();
  });

  $('mode').addEventListener('change', (e) =>
    save({ mode: e.target.checked ? 'sentence' : 'paragraph' }));
  $('hide').addEventListener('change', (e) => save({ hide: e.target.checked }));
  $('autoLookup').addEventListener('change', (e) => save({ autoLookup: e.target.checked }));
  $('autoTranslate').addEventListener('change', (e) => save({ autoTranslate: e.target.checked }));

  /* Chrome wants a user gesture before it will fetch a model, which is exactly
   * what this button is. */
  $('download').addEventListener('click', async () => {
    $('status').textContent = 'Downloading model…';
    try {
      await self.LLTranslator.prepare(settings.source, settings.target, (loaded) => {
        $('status').textContent = `Downloading model… ${Math.round(loaded * 100)}%`;
      });
      $('status').textContent = 'Model ready. Translation runs on this device.';
      $('download').classList.add('hidden');
    } catch (e) {
      $('status').textContent = 'Download failed. Check your connection and try again.';
    }
  });

  $('run').addEventListener('click', async () => {
    const tab = await activeTab();
    if (!tab) { return; }
    chrome.tabs.sendMessage(tab.id, { type: 'll-run', settings }).catch(() => {
      $('status').textContent = 'LanguaLens cannot run on this page.';
    });
    window.close();
  });

  $('clear').addEventListener('click', async () => {
    await chrome.storage.local.set({ saved: [] });
    loadSaved();
  });
}

init();
