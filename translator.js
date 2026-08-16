/* Thin wrapper over Chrome's built-in Translator API.
 *
 * This is the browser counterpart of ML Kit in the Android app: the model runs
 * locally, the text never leaves the machine, and the first use of a pair
 * downloads a model once. If the API is not present the wrapper reports why,
 * so the UI can say something useful instead of silently doing nothing.
 */
(function (root) {
  var clients = {};      /* "src>tgt" -> Promise<Translator> */
  var cache = new Map(); /* "src>tgt|text" -> translation */
  var CACHE_MAX = 4000;

  function supported() {
    return typeof root.Translator !== 'undefined';
  }

  /** 'available' | 'downloadable' | 'downloading' | 'unavailable' | 'unsupported' */
  async function availability(source, target) {
    if (!supported()) { return 'unsupported'; }
    if (source === target) { return 'available'; }
    try {
      return await root.Translator.availability({
        sourceLanguage: source,
        targetLanguage: target
      });
    } catch (e) {
      return 'unavailable';
    }
  }

  /**
   * Creates (and caches) a translator. onProgress receives 0..1 while a model
   * downloads. Chrome requires a user gesture for the first download of a pair,
   * which is why the popup's Download button exists.
   */
  function client(source, target, onProgress) {
    var key = source + '>' + target;
    if (clients[key]) { return clients[key]; }

    var promise = root.Translator.create({
      sourceLanguage: source,
      targetLanguage: target,
      monitor: function (monitor) {
        monitor.addEventListener('downloadprogress', function (e) {
          if (typeof onProgress === 'function') { onProgress(e.loaded); }
        });
      }
    }).catch(function (error) {
      delete clients[key];
      throw error;
    });

    clients[key] = promise;
    return promise;
  }

  async function translate(text, source, target, onProgress) {
    var trimmed = String(text == null ? '' : text).trim();
    if (!trimmed) { return ''; }
    if (source === target) { return trimmed; }
    if (!supported()) { return ''; }

    var key = source + '>' + target + '|' + trimmed;
    if (cache.has(key)) { return cache.get(key); }

    try {
      var t = await client(source, target, onProgress);
      var out = await t.translate(trimmed);
      if (cache.size >= CACHE_MAX) { cache.clear(); }
      cache.set(key, out);
      return out;
    } catch (e) {
      return '';
    }
  }

  /** Translates a batch preserving order, a few at a time to stay responsive. */
  async function translateAll(texts, source, target) {
    var out = new Array(texts.length);
    var BATCH = 8;
    for (var i = 0; i < texts.length; i += BATCH) {
      var slice = texts.slice(i, i + BATCH);
      /* eslint-disable no-await-in-loop */
      var done = await Promise.all(slice.map(function (t) {
        return translate(t, source, target);
      }));
      for (var j = 0; j < done.length; j++) { out[i + j] = done[j]; }
    }
    return out;
  }

  root.LLTranslator = {
    supported: supported,
    availability: availability,
    prepare: function (source, target, onProgress) {
      if (!supported()) { return Promise.reject(new Error('unsupported')); }
      if (source === target) { return Promise.resolve(null); }
      return client(source, target, onProgress);
    },
    translate: translate,
    translateAll: translateAll
  };
})(typeof self !== 'undefined' ? self : this);
