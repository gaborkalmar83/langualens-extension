/* LanguaLens bilingual reader for Chrome.
 *
 * Port of the Android reader (app/src/main/assets/reader.js) with the same two
 * modes and the same behaviour on selection:
 *
 *   paragraph (default) - one translation per block element. Reliable on every
 *                         site, because the block is never taken apart.
 *   sentence            - a translation after each sentence, but only inside
 *                         blocks that are plain text. Blocks containing links
 *                         or other inline elements fall back to paragraph
 *                         handling.
 *
 * Selecting text pops up the three options (save, translate, speak) and fires
 * the translation on its own, showing it at 1.5x the page's text size for
 * three seconds.
 */
(function () {
  if (window.__llLoaded) { return; }
  window.__llLoaded = true;

  var POPUP_MS = 3000;
  var AUTO_LOOKUP_DELAY_MS = 400;
  var AUTO_LOOKUP_MAX = 400;

  var settings = {
    source: 'nl',
    target: 'en',
    mode: 'paragraph',
    hide: false,
    autoLookup: true,
    autoTranslate: false,
    autoReverse: true,
    hint: 'tap to reveal'
  };

  var SKIP_TAGS = {
    SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, CODE: 1, PRE: 1, TEXTAREA: 1,
    SELECT: 1, OPTION: 1, IFRAME: 1, SVG: 1, CANVAS: 1, INPUT: 1,
    BUTTON: 1, NAV: 1, FOOTER: 1, HEADER: 1, ASIDE: 1, FORM: 1
  };
  var BLOCK_SELECTOR = 'p, li, blockquote, dd, dt, h1, h2, h3, h4, figcaption, td, summary';
  var INLINE_OK = {
    B: 1, I: 1, EM: 1, STRONG: 1, SPAN: 1, U: 1, SMALL: 1, MARK: 1,
    SUB: 1, SUP: 1, ABBR: 1, TIME: 1, BR: 1, WBR: 1, FONT: 1
  };

  var counter = 0;
  var queue = [];
  var total = 0;
  var done = 0;
  var running = false;
  var chrome_ = window.chrome;

  /* ------------------------------ chrome ------------------------------ */
  var progress = document.createElement('div');
  progress.id = 'll-progress';

  var bar = document.createElement('div');
  bar.id = 'll-bar';
  bar.innerHTML =
    '<button id="ll-save" title="Save">&#9733;</button>' +
    '<button id="ll-look" class="sec" title="Translate">&#8644;</button>' +
    '<button id="ll-say" class="sec" title="Speak">&#9835;</button>';

  var pop = document.createElement('div');
  pop.id = 'll-pop';

  var toastEl = document.createElement('div');
  toastEl.id = 'll-toast';

  function mount() {
    var host = document.body || document.documentElement;
    [progress, bar, pop, toastEl].forEach(function (el) {
      if (!el.isConnected) { host.appendChild(el); }
    });
  }
  mount();

  var toastTimer = null;
  function toast(message) {
    mount();
    toastEl.textContent = message;
    toastEl.style.display = 'block';
    if (toastTimer) { clearTimeout(toastTimer); }
    toastTimer = setTimeout(function () { toastEl.style.display = 'none'; }, 2600);
  }

  /* --------------------------- popup --------------------------- */
  var popHide = null;
  var popClear = null;

  function showPopup(text) {
    if (!text) { return; }
    mount();
    var base = parseFloat(window.getComputedStyle(document.body).fontSize) || 16;
    pop.style.fontSize = (base * 1.5) + 'px';
    pop.textContent = text;
    pop.style.display = 'block';
    void pop.offsetWidth;
    pop.style.opacity = '1';

    if (popHide) { clearTimeout(popHide); }
    if (popClear) { clearTimeout(popClear); }
    popHide = setTimeout(function () {
      pop.style.opacity = '0';
      popClear = setTimeout(function () { pop.style.display = 'none'; }, 320);
    }, POPUP_MS);
  }

  pop.addEventListener('click', function () {
    if (popHide) { clearTimeout(popHide); }
    if (popClear) { clearTimeout(popClear); }
    pop.style.opacity = '0';
    setTimeout(function () { pop.style.display = 'none'; }, 320);
  });

  /* -------------------------- direction -------------------------- */
  /* If you are learning Dutch with English as your target, an English page is
   * the one you want turned into Dutch, not left alone. So when the page is
   * already written in the target language the pair is flipped for that page.
   * Controlled by the autoReverse setting, on by default. */

  var activeDir = null;   /* { source, target, reversed } for this page */
  var dirPromise = null;

  function baseTag(tag) {
    return String(tag || '').toLowerCase().split(/[-_]/)[0];
  }

  function pageSample() {
    var text = (document.body && document.body.innerText) || '';
    return text.trim().slice(0, 1200);
  }

  /** The page's own declaration first; Chrome's detector only as a fallback. */
  async function detectLanguage() {
    var declared = baseTag(document.documentElement.getAttribute('lang'));
    if (declared) { return declared; }

    if (typeof self.LanguageDetector === 'undefined') { return null; }
    var sample = pageSample();
    if (sample.length < 40) { return null; }
    try {
      if (await self.LanguageDetector.availability() === 'unavailable') { return null; }
      var detector = await self.LanguageDetector.create();
      var results = await detector.detect(sample);
      if (results && results.length && results[0].confidence >= 0.5) {
        return baseTag(results[0].detectedLanguage);
      }
    } catch (e) { /* fall through */ }
    return null;
  }

  function direction() {
    if (activeDir) { return Promise.resolve(activeDir); }
    if (dirPromise) { return dirPromise; }

    dirPromise = (async function () {
      var source = settings.source;
      var target = settings.target;
      var reversed = false;

      if (settings.autoReverse && baseTag(source) !== baseTag(target)) {
        var lang = await detectLanguage();
        if (lang && lang === baseTag(target)) {
          source = settings.target;
          target = settings.source;
          reversed = true;
        }
      }

      activeDir = { source: source, target: target, reversed: reversed };
      return activeDir;
    })();

    return dirPromise;
  }

  /** Called when the pair or the toggle changes, so the page is judged again. */
  function resetDirection() {
    activeDir = null;
    dirPromise = null;
  }

  /* ------------------------ selection actions ------------------------ */
  function selectedText() {
    var s = window.getSelection();
    return s ? String(s).trim() : '';
  }

  function contextFor() {
    var s = window.getSelection();
    if (!s || s.rangeCount === 0) { return ''; }
    var node = s.getRangeAt(0).startContainer;
    var el = node.nodeType === 3 ? node.parentElement : node;
    var host = el && el.closest ? el.closest('.ll-src, p, li, blockquote, td, h1, h2, h3') : null;
    var ctx = host ? host.textContent.trim() : '';
    return ctx.length > 400 ? ctx.slice(0, 400) : ctx;
  }

  async function lookup(text) {
    if (!text) { return; }
    if (!self.LLTranslator.supported()) {
      toast('This Chrome has no built-in translator. See the extension popup.');
      return;
    }
    var dir = await direction();
    var out = await self.LLTranslator.translate(text, dir.source, dir.target);
    showPopup(out || 'No translation. Open the LanguaLens popup and download the model.');
  }

  var lastLookup = '';
  var selTimer = null;

  document.addEventListener('selectionchange', function () {
    var text = selectedText();
    bar.style.display = text.length > 0 ? 'flex' : 'none';

    if (selTimer) { clearTimeout(selTimer); selTimer = null; }
    if (!text) { lastLookup = ''; return; }
    if (!settings.autoLookup) { return; }

    /* Debounced so it fires once the selection settles. Long passages are left
     * to the button, because they do not fit in a popup. */
    selTimer = setTimeout(function () {
      var current = selectedText();
      if (!current || current.length > AUTO_LOOKUP_MAX || current === lastLookup) { return; }
      lastLookup = current;
      lookup(current);
    }, AUTO_LOOKUP_DELAY_MS);
  });

  bar.addEventListener('mousedown', function (e) { e.preventDefault(); });

  bar.querySelector('#ll-save').addEventListener('click', function () {
    var t = selectedText();
    if (!t) { return; }
    save(t);
    bar.style.display = 'none';
    var s = window.getSelection(); if (s) { s.removeAllRanges(); }
  });

  bar.querySelector('#ll-look').addEventListener('click', function () {
    var t = selectedText();
    if (t) { lastLookup = t; lookup(t); }
  });

  bar.querySelector('#ll-say').addEventListener('click', function () {
    var t = selectedText();
    if (t) { speak(t); }
  });

  async function save(text) {
    var dir = await direction();
    var translation = await self.LLTranslator.translate(text, dir.source, dir.target);
    chrome_.runtime.sendMessage({
      type: 'll-save',
      item: {
        text: text,
        translation: translation,
        context: contextFor(),
        origin: document.title + ' | ' + location.href,
        source: dir.source,
        target: dir.target
      }
    }, function (reply) {
      toast(reply && reply.saved ? 'Saved: ' + text : 'Already saved');
    });
  }

  function speak(text) {
    try {
      window.speechSynthesis.cancel();
      var u = new SpeechSynthesisUtterance(text);
      u.lang = activeDir ? activeDir.source : settings.source;
      window.speechSynthesis.speak(u);
    } catch (e) {
      toast('Speech is not available here');
    }
  }

  /* ------------------------ sentence splitting ------------------------ */
  var ABBR = ['dhr', 'mevr', 'mw', 'bijv', 'bv', 'enz', 'nr', 'art', 'blz', 'ca',
    'dr', 'prof', 'ir', 'drs', 'mr', 'st', 'nl', 'zgn', 'evt', 'tel', 'fig',
    'incl', 'excl', 'max', 'min', 'vs', 'etc', 'jr', 'sr', 'ong', 'resp', 'pag',
    'ill', 'kb', 'zb', 'ua', 'usw', 'bzw', 'ggf', 'ejem', 'aprox'];

  function splitSentences(text) {
    var out = [];
    var buf = '';
    for (var i = 0; i < text.length; i++) {
      var c = text.charAt(i);
      buf += c;
      if (c === '.' || c === '!' || c === '?' || c === '…') {
        var j = i + 1;
        while (j < text.length && '"”\')».!?'.indexOf(text.charAt(j)) >= 0) {
          buf += text.charAt(j); j++;
        }
        var next = j < text.length ? text.charAt(j) : null;
        var boundary = next === null || next === ' ' || next === '\n' || next === '\t';
        if (boundary && !endsAbbr(buf)) {
          out.push(buf);
          buf = '';
        }
        i = j - 1;
      }
    }
    if (buf.trim().length) { out.push(buf); }
    return out;
  }

  function endsAbbr(s) {
    var t = s.replace(/\s+$/, '');
    if (t.charAt(t.length - 1) !== '.') { return false; }
    var m = t.slice(0, -1).match(/([A-Za-zÀ-ɏ.]+)$/);
    if (!m) { return false; }
    var tok = m[1].toLowerCase();
    if (tok.length === 1) { return true; }
    return ABBR.indexOf(tok) >= 0;
  }

  /* --------------------------- collecting --------------------------- */
  function isVisible(el) {
    if (!el) { return false; }
    var s = window.getComputedStyle(el);
    return !!s && s.display !== 'none' && s.visibility !== 'hidden';
  }

  function hasLetters(s) { return /[A-Za-zÀ-ɏͰ-ӿ]/.test(s); }

  function skipped(el) {
    if (!el || SKIP_TAGS[el.tagName]) { return true; }
    if (el.closest && (el.closest('.ll-tr') || el.closest('#ll-bar'))) { return true; }
    if (el.querySelector && el.querySelector('.ll-tr')) { return true; }
    return !isVisible(el);
  }

  function isPlainTextBlock(el) {
    var kids = el.children;
    for (var i = 0; i < kids.length; i++) {
      if (!INLINE_OK[kids[i].tagName]) { return false; }
    }
    return true;
  }

  function makeSlot() {
    var slot = document.createElement('span');
    slot.className = 'll-tr' + (settings.hide ? ' ll-veil' : '');
    slot.setAttribute('data-hint', settings.hint);
    slot.setAttribute('data-ll', 'n' + (++counter));
    slot.addEventListener('click', function () {
      if (slot.classList.contains('ll-veil')) { slot.classList.toggle('ll-open'); }
    });
    return slot;
  }

  function appendBlockTranslation(el, text) {
    var slot = makeSlot();
    el.appendChild(slot);
    queue.push({ node: slot, text: text });
  }

  function splitBlockIntoSentences(el) {
    var raw = (el.textContent || '').trim();
    var sentences = splitSentences(raw);
    if (sentences.length < 2) {
      appendBlockTranslation(el, raw);
      return;
    }
    var frag = document.createDocumentFragment();
    var slots = [];
    for (var k = 0; k < sentences.length; k++) {
      var piece = sentences[k];
      var trimmed = piece.trim();
      var host = document.createElement('span');
      host.className = 'll-src';
      host.appendChild(document.createTextNode(piece));
      frag.appendChild(host);
      if (trimmed.length >= 12 && hasLetters(trimmed)) {
        var slot = makeSlot();
        frag.appendChild(slot);
        slots.push({ node: slot, text: trimmed });
      }
    }
    el.innerHTML = '';
    el.appendChild(frag);
    for (var q = 0; q < slots.length; q++) { queue.push(slots[q]); }
  }

  function collect() {
    var blocks = document.querySelectorAll(BLOCK_SELECTOR);
    for (var i = 0; i < blocks.length; i++) {
      var el = blocks[i];
      if (skipped(el)) { continue; }

      var text = (el.innerText || el.textContent || '').trim();
      if (text.length < 25 || !hasLetters(text)) { continue; }
      if (el.querySelector(BLOCK_SELECTOR)) { continue; }

      if (settings.mode === 'sentence' && isPlainTextBlock(el)) {
        splitBlockIntoSentences(el);
      } else {
        appendBlockTranslation(el, text.length > 1800 ? text.slice(0, 1800) : text);
      }
    }
  }

  /* ---------------------------- running ---------------------------- */
  async function flush() {
    var dir = await direction();
    while (queue.length) {
      var batch = queue.splice(0, 8);
      total += batch.length;
      /* eslint-disable no-await-in-loop */
      var results = await self.LLTranslator.translateAll(
        batch.map(function (b) { return b.text; }),
        dir.source,
        dir.target
      );
      batch.forEach(function (item, i) {
        item.node.textContent = results[i] || '';
        done++;
      });
      var pct = total ? Math.round((done / total) * 100) : 100;
      progress.style.width = pct + '%';
    }
    progress.style.width = '100%';
    setTimeout(function () { progress.style.opacity = '0'; }, 600);
  }

  async function run() {
    if (running) { return; }
    if (!self.LLTranslator.supported()) {
      toast('This Chrome has no built-in translator. See the extension popup.');
      return;
    }
    var dir = await direction();
    var state = await self.LLTranslator.availability(dir.source, dir.target);
    if (state === 'unavailable') {
      toast('This language pair is not available in Chrome.');
      return;
    }
    if (state === 'downloadable') {
      toast(
        'Open the LanguaLens popup and download the ' +
        self.LLLanguages.nameOf(dir.source) + ' to ' +
        self.LLLanguages.nameOf(dir.target) + ' model first.'
      );
      return;
    }
    if (dir.reversed) {
      toast(
        'This page is in ' + self.LLLanguages.nameOf(dir.source) +
        ', translating into ' + self.LLLanguages.nameOf(dir.target) + '.'
      );
    }

    running = true;
    mount();
    progress.style.opacity = '1';
    progress.style.width = '0';
    collect();
    await flush();
    running = false;
  }

  function setHidden(hidden) {
    settings.hide = !!hidden;
    var els = document.querySelectorAll('.ll-tr');
    for (var i = 0; i < els.length; i++) {
      if (settings.hide) {
        els[i].classList.add('ll-veil');
        els[i].classList.remove('ll-open');
      } else {
        els[i].classList.remove('ll-veil', 'll-open');
      }
    }
  }

  /* Pick up content added by infinite scroll, but only once translation has
   * been asked for at least once on this page. */
  var rescan = null;
  var observed = false;
  function observe() {
    if (observed || !document.body) { return; }
    observed = true;
    try {
      new MutationObserver(function () {
        if (rescan) { clearTimeout(rescan); }
        rescan = setTimeout(function () {
          if (total === 0) { return; }
          collect();
          flush();
        }, 900);
      }).observe(document.body, { childList: true, subtree: true });
    } catch (e) { /* no body yet */ }
  }

  /* --------------------------- messaging --------------------------- */
  function applySettings(next) {
    if (!next) { return; }
    var before = settings.source + '>' + settings.target + '|' + settings.autoReverse;
    Object.keys(next).forEach(function (k) {
      if (k in settings) { settings[k] = next[k]; }
    });
    if (before !== settings.source + '>' + settings.target + '|' + settings.autoReverse) {
      resetDirection();
    }
  }

  chrome_.storage.local.get('settings', function (data) {
    applySettings(data && data.settings);
    if (settings.autoTranslate) { run(); }
  });

  chrome_.runtime.onMessage.addListener(function (message, sender, reply) {
    if (!message) { return; }
    switch (message.type) {
      case 'll-run':
        applySettings(message.settings);
        observe();
        run();
        reply({ ok: true });
        break;
      case 'll-settings':
        applySettings(message.settings);
        setHidden(settings.hide);
        reply({ ok: true });
        break;
      case 'll-veil':
        setHidden(!settings.hide);
        reply({ hidden: settings.hide });
        break;
      case 'll-lookup-selection':
        applySettings(message.settings);
        lookup(selectedText() || message.text || '');
        reply({ ok: true });
        break;
      case 'll-reset':
        location.reload();
        reply({ ok: true });
        break;
      default:
        break;
    }
    return true;
  });
})();
