# LanguaLens for Chrome

Read any web page in the language you are learning, with the translation directly
underneath, and save what you highlight as vocabulary for Anki.

Translation runs **on your own machine** through Chrome's built-in translator. The
pages you read are never sent to a translation server. No account, no analytics, no
advertising.

This is the browser half of [LanguaLens](https://github.com/gaborkalmar83/Langualens),
which is also an Android app.

---

## What it does

**Bilingual reading.** Every paragraph keeps its original text and gets its
translation underneath in blue italics. Two modes: one translation per paragraph, or
one after every sentence. Sentence mode only splits blocks that are plain text;
anything containing links or other markup falls back to paragraph mode, which is what
stops it producing chopped-up fragments.

**Hide until clicked.** Veils each translation so you read the original first and only
check yourself when stuck.

**Selection.** Selecting text raises three buttons — save, translate, speak — and
translates the selection on its own, showing it in a popup at 1.5x the page's text
size for three seconds. You do not have to press anything for the common case. The
translate button is still there for selections over 400 characters, which are skipped
by the automatic pass because they do not fit in a popup, and for bringing a popup
back after it has faded.

**Original first or translation first.** By default the original leads and the
translation sits underneath. Flip it in the popup if you would rather read the
translation and check the original.

**Automatic language detection, on by default.** Rather than trusting the From
setting, LanguaLens detects what the page is actually written in and translates from
that, so you do not have to change the pair when you move between sites. It prefers
Chrome's on-device detector over the page's `lang` attribute, since plenty of sites
declare `lang="en"` and then serve something else, and falls back to the declaration
when the detector is unavailable or unsure. Turn it off to always translate from the
From language.

**Per-site exclusions.** Add any site to a never-translate list from the popup and
LanguaLens stays completely inert there: no page pass, no selection bar, no popup.
Excluding `example.com` also covers its subdomains.

**Direction flips on pages already in your target language.** If you are learning
Dutch and read with *From: Dutch, To: English*, an English page is the one you want
turned into Dutch. LanguaLens detects this from the page's own `lang` attribute,
falling back to Chrome's on-device language detector, and flips the pair for that
page, telling you it did. It is a checkbox, on by default.

**Vocabulary.** Saved words keep the sentence they came from and the page they came
from, and export as a tab separated file that Anki imports directly.

**Adjustable translation colour.** Five presets plus any custom colour, in the popup.
Which of a preset's two values applies is decided by measuring the page's own
background rather than by your OS theme, because a light page read on a dark-themed
system otherwise gets the dark-mode colour and the contrast collapses.
Each preset carries a separate value for light and dark pages, since a colour that
reads well on white rarely reads well on black; the swatch shows both halves. The
preset hues come from the Okabe-Ito palette, which stays distinguishable from ordinary
body text under the common forms of colour blindness, and there is a maximum contrast
option for anyone who cannot use hue at all. Colour is never the only cue in any case:
translations are also italic and carry a left bar.

59 languages, any pair among them.

---

## Requirements

Chrome **138 or newer**, the first version with the built-in on-device `Translator`
API. The extension checks and tells you in the popup if your Chrome is too old.

There is deliberately no cloud fallback. Falling back to a web translation API would
break the promise that your text stays on your machine.

---

## Installing from source

1. Open `chrome://extensions`
2. Turn on **Developer mode**, top right
3. Click **Load unpacked** and select this folder

Developer mode is what Chrome requires to run an extension that did not come from the
Web Store. Nothing in the extension needs it beyond installation.

## Using it

1. Click the LanguaLens icon and pick **From** and **To**.
2. If it says a model is missing, click **Download model**. Chrome requires a click
   before it will fetch one, which is what that button is for. With the direction flip
   enabled both directions are used, so two models download.
3. Click **Translate this page**, or press **Alt+L**, or right-click the page.
4. Select text for the three buttons and the automatic popup.
5. **Export for Anki** in the popup gives you the tab separated file.

---

## Privacy

See [PRIVACY.md](PRIVACY.md). In short: your text is translated locally and never
transmitted. Two things touch the network, neither carrying your text — Chrome
downloading a translation model once per pair, and the speak button, which hands text
to whichever voice your system provides, and some voices are cloud based.

---

## Packaging for the Chrome Web Store

```
powershell -ExecutionPolicy Bypass -File package.ps1
```

Produces `dist/langualens-chrome-<version>.zip`. See [STORE-LISTING.md](STORE-LISTING.md)
for the listing copy, the permission justifications and the submission checklist.
