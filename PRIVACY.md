# LanguaLens privacy policy

_Last updated: 21 August 2026_

LanguaLens does not collect, transmit, sell or share any personal data. There is no
account, no server operated by this extension, no analytics and no advertising.

## What the extension does with your data

**The pages you read.** LanguaLens reads the text of the page you are on in order to
insert translations underneath it. That text is processed entirely inside your
browser and is written back into the same page. It is never sent anywhere.

**Text you select.** Selecting text triggers a translation, shown in a popup. The
selected text is processed locally, exactly like page text.

**Words you save.** Saving a word stores it, its translation, the surrounding
sentence and the page title and URL it came from, in Chrome's local extension
storage (`chrome.storage.local`) on your own computer. It is not synced to any
server by the extension. It stays there until you export it or press Clear.

**Your settings.** Language pair and options are stored the same way.

## Translation

Translation uses **Chrome's built-in Translator API**, which runs a translation model
locally on your machine. Your text is not sent to a translation service by this
extension.

Chrome itself downloads the translation model, once per language pair, from Google.
That download transfers the model to you; it does not contain your text. This
download is performed by Chrome, not by LanguaLens, and is governed by
[Google's privacy policy](https://policies.google.com/privacy).

## Text to speech

The speak button uses your browser's Web Speech API, which hands the text to a voice
installed in your system or supplied by your browser. **Some voices synthesise speech
in the cloud rather than locally.** LanguaLens cannot tell which kind yours is. If
that matters to you, do not use the speak button, or check which voices your system
provides.

## Permissions

| Permission | Why it is needed |
|---|---|
| `storage` | Stores your settings and saved words locally. |
| `contextMenus` | Adds the two right-click menu entries. |
| Access to the sites you visit | The extension inserts translations into the page you are reading, which requires reading and modifying that page. Nothing read from a page is transmitted off your machine. |

## Remote code

The extension executes no remote code. All of its code is contained in the package
you install from the Chrome Web Store.

## Changes

If this policy changes, the updated version will be published in the extension's
repository alongside the release that changes it.

## Contact

<!-- Chrome Web Store requires a contact address on the listing. Put yours here
     before publishing; it will be publicly visible. -->
CONTACT_EMAIL_HERE
