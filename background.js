/* Service worker: settings defaults, the saved-word store and the right-click
 * entry point. No network calls of any kind happen here. */

const DEFAULTS = {
  source: 'nl',
  target: 'en',
  mode: 'paragraph',
  hide: false,
  autoLookup: true,
  autoTranslate: false,
  hint: 'tap to reveal'
};

chrome.runtime.onInstalled.addListener(async () => {
  const data = await chrome.storage.local.get(['settings', 'saved']);
  await chrome.storage.local.set({
    settings: { ...DEFAULTS, ...(data.settings || {}) },
    saved: data.saved || []
  });

  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: 'll-translate-selection',
      title: 'Translate with LanguaLens',
      contexts: ['selection']
    });
    chrome.contextMenus.create({
      id: 'll-translate-page',
      title: 'Translate this page with LanguaLens',
      contexts: ['page']
    });
  });
});

async function settings() {
  const data = await chrome.storage.local.get('settings');
  return { ...DEFAULTS, ...(data.settings || {}) };
}

/** Fire and forget: the tab may not have a content script (chrome:// pages). */
function send(tabId, message) {
  chrome.tabs.sendMessage(tabId, message).catch(() => {});
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab || tab.id == null) { return; }
  const current = await settings();
  if (info.menuItemId === 'll-translate-selection') {
    send(tab.id, {
      type: 'll-lookup-selection',
      text: info.selectionText || '',
      settings: current
    });
  } else if (info.menuItemId === 'll-translate-page') {
    send(tab.id, { type: 'll-run', settings: current });
  }
});

chrome.commands.onCommand.addListener(async (command) => {
  if (command !== 'translate-page') { return; }
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab && tab.id != null) {
    send(tab.id, { type: 'll-run', settings: await settings() });
  }
});

chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (message && message.type === 'll-save') {
    (async () => {
      const data = await chrome.storage.local.get('saved');
      const saved = data.saved || [];
      const key = (message.item.text || '').trim().toLowerCase();
      if (!key) { reply({ saved: false }); return; }
      if (saved.some((s) => (s.text || '').trim().toLowerCase() === key)) {
        reply({ saved: false });
        return;
      }
      saved.push({ ...message.item, addedAt: Date.now() });
      await chrome.storage.local.set({ saved });
      reply({ saved: true });
    })();
    return true;
  }
  return false;
});
