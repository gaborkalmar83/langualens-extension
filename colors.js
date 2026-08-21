/* Translation text colours.
 *
 * The translation is distinguished from the original by three things at once:
 * colour, italics and a left border. That matters for accessibility — colour is
 * never the only signal, so the reader still works for someone who cannot use
 * hue at all. This file only controls the colour part of it.
 *
 * Each preset carries a light and a dark value, because a colour readable on a
 * white page is rarely readable on a dark one. The light values clear 4.5:1
 * against white and the dark values clear it against a dark page background.
 *
 * The hues are taken from the Okabe-Ito palette, chosen so that they stay
 * distinguishable from ordinary black body text under the common forms of
 * colour blindness.
 */
(function (root) {
  var PRESETS = [
    { id: 'blue',       name: 'Blue',    light: '#0072B2', dark: '#7FB2FF' },
    { id: 'orange',     name: 'Orange',  light: '#B4460B', dark: '#FF9E6B' },
    { id: 'green',      name: 'Green',   light: '#00695C', dark: '#4FD1B0' },
    { id: 'purple',     name: 'Purple',  light: '#8E2F6B', dark: '#F3A0CE' },
    { id: 'contrast',   name: 'Maximum contrast', light: '#111111', dark: '#FFFFFF' }
  ];

  var byId = {};
  PRESETS.forEach(function (p) { byId[p.id] = p; });

  var DEFAULT_ID = 'blue';

  /** Returns { light, dark } for the given settings, falling back to blue. */
  function resolve(settings) {
    settings = settings || {};
    if (settings.colorPreset === 'custom') {
      return {
        light: settings.colorLight || byId[DEFAULT_ID].light,
        dark: settings.colorDark || settings.colorLight || byId[DEFAULT_ID].dark
      };
    }
    var preset = byId[settings.colorPreset] || byId[DEFAULT_ID];
    return { light: preset.light, dark: preset.dark };
  }

  root.LLColors = {
    PRESETS: PRESETS,
    DEFAULT_ID: DEFAULT_ID,
    resolve: resolve
  };
})(typeof self !== 'undefined' ? self : this);
