/* LanguaLens Browser - inline bilingual reading.
 *
 * Injected into every page the browser loads. Walks the visible text and puts a
 * translation on the line underneath, then talks to the app over the LL bridge
 * so the translating itself happens in Kotlin, on device, through ML Kit.
 *
 * Two modes:
 *   paragraph (default) - one translation per block element. Reliable everywhere,
 *                         because the block is never taken apart.
 *   sentence            - a translation after each sentence, but only inside
 *                         blocks that are plain text. A block containing links or
 *                         other markup falls back to paragraph handling, which is
 *                         what stops it producing chopped-up fragments.
 */
(function () {
  if (window.__llLoaded) { return; }
  window.__llLoaded = true;

  var MODE = window.__llMode || 'paragraph';
  var HIDDEN = !!window.__llHidden;
  var HINT = window.__llHint || 'tap to reveal';
  var LIGHT = window.__llLight || '#0072B2';
  var DARK = window.__llDark || '#7FB2FF';

  /* How long the selection popup stays up, how long to wait for a selection to
   * settle before translating it, and the longest selection translated without
   * being asked. Anything longer does not fit in a popup, so it waits for the
   * button. */
  var POPUP_MS = 3200;
  var AUTO_LOOKUP_DELAY_MS = 400;
  var AUTO_LOOKUP_MAX = 400;

  var SKIP_TAGS = {
    SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, CODE: 1, PRE: 1, TEXTAREA: 1,
    SELECT: 1, OPTION: 1, IFRAME: 1, SVG: 1, CANVAS: 1, INPUT: 1,
    BUTTON: 1, NAV: 1, FOOTER: 1, HEADER: 1, ASIDE: 1, FORM: 1
  };
  var BLOCK_SELECTOR = 'p, li, blockquote, dd, dt, h1, h2, h3, h4, figcaption, td, summary';
  /* Inline tags that do not stop a block counting as plain text. */
  var INLINE_OK = {
    B: 1, I: 1, EM: 1, STRONG: 1, SPAN: 1, U: 1, SMALL: 1, MARK: 1,
    SUB: 1, SUP: 1, ABBR: 1, TIME: 1, BR: 1, WBR: 1, FONT: 1
  };

  var counter = 0;
  var pending = {};
  var queue = [];
  var total = 0;
  var done = 0;

  /* ------------------------------ colour ------------------------------ */
  /* Which of the two colours to use is decided by measuring the page's own
   * background, not by the system theme. A light page read on a dark-themed
   * phone otherwise gets the dark-page colour and the contrast collapses. */
  function luminanceOf(color) {
    var m = String(color || '').match(/rgba?\(([^)]+)\)/);
    if (!m) { return 1; }
    var parts = m[1].split(',').map(function (n) { return parseFloat(n); });
    if (parts.length > 3 && parts[3] === 0) { return -1; }  /* transparent */
    return (0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]) / 255;
  }

  function pageIsDark() {
    var nodes = [document.body, document.documentElement];
    for (var i = 0; i < nodes.length; i++) {
      if (!nodes[i]) { continue; }
      var lum = luminanceOf(window.getComputedStyle(nodes[i]).backgroundColor);
      if (lum >= 0) { return lum < 0.5; }
    }
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  function activeColor() { return pageIsDark() ? DARK : LIGHT; }

  /* ---------------------------- styling ---------------------------- */
  var style = document.createElement('style');
  /* Colour, italics and a left bar all mark the translation at once, so colour
   * is never the only signal and the page still reads for someone who cannot
   * use hue. */
  function css(c) {
    return '' +
      '.ll-tr{display:block !important;color:' + c + ';font-style:italic;' +
      'font-size:0.92em;line-height:1.45;margin:4px 0 14px 0;' +
      'border-left:3px solid ' + c + '59;padding-left:10px;' +
      'font-family:inherit;text-align:left;font-weight:400;}' +
      '.ll-tr:empty{display:none !important;}' +
      '.ll-tr.ll-veil{color:transparent;background:' + c + '22;' +
      'border-radius:5px;cursor:pointer;-webkit-user-select:none;user-select:none;}' +
      '.ll-tr.ll-veil::after{content:attr(data-hint);color:' + c + ';' +
      'font-size:.8em;opacity:.7;}' +
      '.ll-tr.ll-veil.ll-open{color:' + c + ';background:transparent;}' +
      '.ll-tr.ll-veil.ll-open::after{content:"";}' +
      '#ll-progress{position:fixed;top:0;left:0;height:3px;width:0;' +
      'background:' + c + ';z-index:2147483647;pointer-events:none;' +
      'transition:width .25s ease,opacity .4s ease;}' +
      '#ll-bar{position:fixed;left:0;right:0;bottom:0;z-index:2147483647;' +
      'display:none;gap:8px;padding:10px 12px;background:rgba(20,24,33,.96);' +
      'font-family:-apple-system,Roboto,sans-serif;box-shadow:0 -2px 12px rgba(0,0,0,.4);}' +
      '#ll-bar button{flex:1;border:none;border-radius:10px;padding:12px 8px;' +
      'font-size:15px;font-weight:600;background:#2f6fe4;color:#fff;}' +
      '#ll-bar button.sec{background:#2c3446;color:#dbe4f5;}' +
      '#ll-pop{position:fixed;left:12px;right:12px;bottom:78px;z-index:2147483647;' +
      'display:none;opacity:0;padding:16px 18px;border-radius:14px;' +
      'background:rgba(20,24,33,.97);color:#fff;line-height:1.35;text-align:center;' +
      'font-family:-apple-system,Roboto,sans-serif;font-weight:500;' +
      'max-height:42vh;overflow:auto;box-shadow:0 4px 24px rgba(0,0,0,.45);' +
      'transition:opacity .3s ease;-webkit-user-select:none;user-select:none;}';
  }
  style.textContent = css(activeColor());
  (document.head || document.documentElement).appendChild(style);

  window.llSetColor = function (light, dark) {
    LIGHT = light || LIGHT;
    DARK = dark || DARK;
    style.textContent = css(activeColor());
  };

  var progress = document.createElement('div');
  progress.id = 'll-progress';
  document.documentElement.appendChild(progress);

  /* ---------------------- selection action bar ---------------------- */
  var bar = document.createElement('div');
  bar.id = 'll-bar';
  bar.innerHTML =
    '<button id="ll-save">&#9733;</button>' +
    '<button id="ll-look" class="sec">&#8644;</button>' +
    '<button id="ll-say" class="sec">&#9835;</button>';
  document.documentElement.appendChild(bar);

  /* ------------------------- selection popup ------------------------- */
  /* The bar keeps offering save / translate / speak, but the translation fires
   * on its own so the common case needs no tap. Shown at 1.5x the page's own
   * body size, which is readable without leaning in. */
  var pop = document.createElement('div');
  pop.id = 'll-pop';
  document.documentElement.appendChild(pop);

  var popHide = null;
  var popClear = null;

  window.llPopup = function (text) {
    if (!text) { return; }
    var base = parseFloat(window.getComputedStyle(document.body).fontSize) || 18;
    pop.style.fontSize = (base * 1.5) + 'px';
    pop.textContent = text;
    pop.style.display = 'block';
    void pop.offsetWidth;   /* force reflow so the fade runs on a re-show */
    pop.style.opacity = '1';

    if (popHide) { clearTimeout(popHide); }
    if (popClear) { clearTimeout(popClear); }
    popHide = setTimeout(function () {
      pop.style.opacity = '0';
      popClear = setTimeout(function () { pop.style.display = 'none'; }, 320);
    }, POPUP_MS);
  };

  pop.addEventListener('click', function () {
    if (popHide) { clearTimeout(popHide); }
    if (popClear) { clearTimeout(popClear); }
    pop.style.opacity = '0';
    setTimeout(function () { pop.style.display = 'none'; }, 320);
  });

  function selectedText() {
    var s = window.getSelection();
    return s ? String(s).trim() : '';
  }

  function bridge() {
    return typeof LL !== 'undefined' ? LL : null;
  }

  function requestLookup(text) {
    var b = bridge();
    if (b && text) { try { b.lookup(text); } catch (e) { /* detached */ } }
  }

  var lastLookup = '';
  var selTimer = null;

  document.addEventListener('selectionchange', function () {
    var text = selectedText();
    bar.style.display = text.length > 0 ? 'flex' : 'none';

    if (selTimer) { clearTimeout(selTimer); selTimer = null; }
    if (!text) { lastLookup = ''; return; }

    /* Debounced so it fires once the drag handle settles, not on every
     * intermediate selection. */
    selTimer = setTimeout(function () {
      var current = selectedText();
      if (!current || current.length > AUTO_LOOKUP_MAX || current === lastLookup) { return; }
      lastLookup = current;
      requestLookup(current);
    }, AUTO_LOOKUP_DELAY_MS);
  });

  bar.addEventListener('mousedown', function (e) { e.preventDefault(); });

  document.getElementById('ll-save').addEventListener('click', function () {
    var t = selectedText();
    var b = bridge();
    if (!t || !b) { return; }
    b.save(t, contextFor(), document.title + ' | ' + location.href);
    bar.style.display = 'none';
    var s = window.getSelection(); if (s) { s.removeAllRanges(); }
  });

  /* Still explicit, for selections too long to fire on their own and for
   * bringing back a popup that has already faded. */
  document.getElementById('ll-look').addEventListener('click', function () {
    var t = selectedText();
    if (t) { lastLookup = t; requestLookup(t); }
  });

  document.getElementById('ll-say').addEventListener('click', function () {
    var t = selectedText();
    var b = bridge();
    if (t && b) { b.speak(t); }
  });

  function contextFor() {
    var s = window.getSelection();
    if (!s || s.rangeCount === 0) { return ''; }
    var node = s.getRangeAt(0).startContainer;
    var el = node.nodeType === 3 ? node.parentElement : node;
    var host = el && el.closest ? el.closest('.ll-src, p, li, blockquote, td, h1, h2, h3') : null;
    var ctx = host ? host.textContent.trim() : '';
    return ctx.length > 400 ? ctx.slice(0, 400) : ctx;
  }

  /* ------------------------ sentence splitting ------------------------ */
  var ABBR = ['dhr', 'mevr', 'mw', 'bijv', 'bv', 'enz', 'nr', 'art', 'blz', 'ca',
    'dr', 'prof', 'ir', 'drs', 'mr', 'st', 'nl', 'zgn', 'evt', 'tel', 'fig',
    'incl', 'excl', 'max', 'min', 'vs', 'etc', 'jr', 'sr', 'ong', 'resp', 'pag',
    'ill', 'usw', 'bzw', 'ggf', 'aprox'];

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
    if (tok.length === 1) { return true; }   /* "J. Bakker" */
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

  /** A block counts as plain text when every child element is harmless inline markup. */
  function isPlainTextBlock(el) {
    var kids = el.children;
    for (var i = 0; i < kids.length; i++) {
      if (!INLINE_OK[kids[i].tagName]) { return false; }
    }
    return true;
  }

  function makeSlot() {
    var id = 'n' + (++counter);
    var slot = document.createElement('span');
    slot.className = 'll-tr' + (HIDDEN ? ' ll-veil' : '');
    slot.setAttribute('data-hint', HINT);
    slot.setAttribute('data-ll', id);
    slot.addEventListener('click', function () {
      if (slot.classList.contains('ll-veil')) { slot.classList.toggle('ll-open'); }
    });
    pending[id] = slot;
    return { id: id, node: slot };
  }

  function appendBlockTranslation(el, text) {
    var slot = makeSlot();
    el.appendChild(slot.node);
    queue.push({ id: slot.id, text: text });
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
        frag.appendChild(slot.node);
        slots.push({ id: slot.id, text: trimmed });
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

      /* Skip wrappers whose text belongs to a nested block handled anyway. */
      if (el.querySelector(BLOCK_SELECTOR)) { continue; }

      if (MODE === 'sentence' && isPlainTextBlock(el)) {
        splitBlockIntoSentences(el);
      } else {
        appendBlockTranslation(el, text.length > 1800 ? text.slice(0, 1800) : text);
      }
    }
  }

  /* ------------------------ talking to the app ------------------------ */
  function flush() {
    if (!queue.length) { return; }
    var b = bridge();
    if (!b) { return; }
    var batch = queue.splice(0, 25);
    total += batch.length;
    try { b.requestTranslate(JSON.stringify(batch)); } catch (e) { return; }
    if (queue.length) { setTimeout(flush, 60); }
  }

  window.llApply = function (json) {
    var map;
    try { map = JSON.parse(json); } catch (e) { return; }
    for (var id in map) {
      var slot = pending[id];
      if (slot) {
        slot.textContent = map[id];
        delete pending[id];
        done++;
      }
    }
    var pct = total ? Math.round((done / total) * 100) : 100;
    progress.style.width = pct + '%';
    if (pct >= 100) {
      setTimeout(function () { progress.style.opacity = '0'; }, 600);
    }
  };

  /** Returns a sample of the page's text, for language detection. */
  window.llSample = function () {
    var t = (document.body && document.body.innerText) || '';
    return t.replace(/\s+/g, ' ').trim().slice(0, 1200);
  };

  window.llRun = function () {
    style.textContent = css(activeColor());
    progress.style.opacity = '1';
    collect();
    flush();
  };

  /** Removes every translation, leaving the page as the site served it. */
  window.llClear = function () {
    var els = document.querySelectorAll('.ll-tr');
    for (var i = 0; i < els.length; i++) {
      if (els[i].parentNode) { els[i].parentNode.removeChild(els[i]); }
    }
    pending = {};
    queue = [];
    total = 0;
    done = 0;
    progress.style.width = '0';
    progress.style.opacity = '0';
  };

  window.llSetHidden = function (hidden) {
    HIDDEN = !!hidden;
    var els = document.querySelectorAll('.ll-tr');
    for (var i = 0; i < els.length; i++) {
      if (HIDDEN) {
        els[i].classList.add('ll-veil');
        els[i].classList.remove('ll-open');
      } else {
        els[i].classList.remove('ll-veil', 'll-open');
      }
    }
  };

  /* Infinite scroll and single-page navigation both add text after load. */
  var rescan = null;
  var autoRescan = false;
  window.llWatch = function (on) { autoRescan = !!on; };
  try {
    new MutationObserver(function () {
      if (!autoRescan) { return; }
      if (rescan) { clearTimeout(rescan); }
      rescan = setTimeout(function () { collect(); flush(); }, 900);
    }).observe(document.body, { childList: true, subtree: true });
  } catch (e) { /* no body yet */ }
})();
