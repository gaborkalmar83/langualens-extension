/* Shared language list. Mirrors Languages.kt in the Android app so both halves
 * of LanguaLens offer the same pairs. Loaded as a plain script by the content
 * script and imported as a module by the popup and the service worker. */
(function (root) {
  var PINNED = ['nl', 'en', 'hu', 'de', 'es', 'fr', 'mk', 'hr', 'it', 'pl'];

  var ALL = [
    ['af', 'Afrikaans', 'Afrikaans'], ['ar', 'Arabic', 'العربية'],
    ['be', 'Belarusian', 'Беларуская'], ['bg', 'Bulgarian', 'Български'],
    ['bn', 'Bengali', 'বাংলা'], ['ca', 'Catalan', 'Català'],
    ['cs', 'Czech', 'Čeština'], ['cy', 'Welsh', 'Cymraeg'],
    ['da', 'Danish', 'Dansk'], ['de', 'German', 'Deutsch'],
    ['el', 'Greek', 'Ελληνικά'], ['en', 'English', 'English'],
    ['eo', 'Esperanto', 'Esperanto'], ['es', 'Spanish', 'Español'],
    ['et', 'Estonian', 'Eesti'], ['fa', 'Persian', 'فارسی'],
    ['fi', 'Finnish', 'Suomi'], ['fr', 'French', 'Français'],
    ['ga', 'Irish', 'Gaeilge'], ['gl', 'Galician', 'Galego'],
    ['gu', 'Gujarati', 'ગુજરાતી'], ['he', 'Hebrew', 'עברית'],
    ['hi', 'Hindi', 'हिन्दी'], ['hr', 'Croatian', 'Hrvatski'],
    ['ht', 'Haitian Creole', 'Kreyòl ayisyen'], ['hu', 'Hungarian', 'Magyar'],
    ['id', 'Indonesian', 'Bahasa Indonesia'], ['is', 'Icelandic', 'Íslenska'],
    ['it', 'Italian', 'Italiano'], ['ja', 'Japanese', '日本語'],
    ['ka', 'Georgian', 'ქართული'], ['kn', 'Kannada', 'ಕನ್ನಡ'],
    ['ko', 'Korean', '한국어'], ['lt', 'Lithuanian', 'Lietuvių'],
    ['lv', 'Latvian', 'Latviešu'], ['mk', 'Macedonian', 'Македонски'],
    ['mr', 'Marathi', 'मराठी'], ['ms', 'Malay', 'Bahasa Melayu'],
    ['mt', 'Maltese', 'Malti'], ['nl', 'Dutch', 'Nederlands'],
    ['no', 'Norwegian', 'Norsk'], ['pl', 'Polish', 'Polski'],
    ['pt', 'Portuguese', 'Português'], ['ro', 'Romanian', 'Română'],
    ['ru', 'Russian', 'Русский'], ['sk', 'Slovak', 'Slovenčina'],
    ['sl', 'Slovenian', 'Slovenščina'], ['sq', 'Albanian', 'Shqip'],
    ['sv', 'Swedish', 'Svenska'], ['sw', 'Swahili', 'Kiswahili'],
    ['ta', 'Tamil', 'தமிழ்'], ['te', 'Telugu', 'తెలుగు'],
    ['th', 'Thai', 'ไทย'], ['tl', 'Tagalog', 'Tagalog'],
    ['tr', 'Turkish', 'Türkçe'], ['uk', 'Ukrainian', 'Українська'],
    ['ur', 'Urdu', 'اردو'], ['vi', 'Vietnamese', 'Tiếng Việt'],
    ['zh', 'Chinese', '中文']
  ].map(function (row) {
    return { tag: row[0], english: row[1], native: row[2] };
  });

  var byTag = {};
  ALL.forEach(function (l) { byTag[l.tag] = l; });

  var ORDERED = PINNED.map(function (t) { return byTag[t]; })
    .filter(Boolean)
    .concat(
      ALL.filter(function (l) { return PINNED.indexOf(l.tag) < 0; })
        .sort(function (a, b) { return a.english < b.english ? -1 : 1; })
    );

  root.LLLanguages = {
    ALL: ALL,
    ORDERED: ORDERED,
    nameOf: function (tag) { return byTag[tag] ? byTag[tag].native : String(tag).toUpperCase(); },
    labelOf: function (tag) {
      var l = byTag[tag];
      if (!l) { return String(tag).toUpperCase(); }
      return l.english === l.native ? l.english : l.native + '  ·  ' + l.english;
    }
  };
})(typeof self !== 'undefined' ? self : this);
