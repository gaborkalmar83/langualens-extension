# LanguaLens Browser

A small Android browser that puts the translation on the line underneath every
paragraph, so you can read a foreign-language site in the original and check
yourself as you go.

Everything is translated **on the phone**. No account, no analytics, no server
sees what you read.

When you hit something you should be typing a password into, one button hands the
page over to Chrome and this app stays out of it.

This is the third piece of [LanguaLens](https://github.com/gaborkalmar83/Langualens):

| | |
|---|---|
| [`Langualens`](https://github.com/gaborkalmar83/Langualens) | The Android app: reader, selection menu in every app, floating bubble, Anki. |
| [`langualens-extension`](https://github.com/gaborkalmar83/langualens-extension) | The Chrome extension, for desktop. |
| **this repository** | The Android browser. Read anywhere, translated, without switching apps. |

---

## What it does

**Every page, translated in place.** Load a site and each paragraph keeps its
original text with the translation underneath in colour and italics. Nothing is
replaced; you read the original and the translation together.

**It works out the page's language itself.** You tell it once which language *you*
understand. Every page after that is identified on the fly, so moving between a
Dutch news site and a Spanish one needs no setting change. The page's own `lang`
attribute is only the fallback, because plenty of sites declare `lang="en"` and
then serve something else.

**Hand over to Chrome.** The button at the bottom right opens the current page in
Chrome, on the same URL. That is the answer to logins, passkeys, saved cards and
anything else a small browser has no business handling. It targets Chrome by name
rather than firing a plain "open link", which would come straight back here
whenever this app is the default browser.

**Select anything.** Selecting text brings up save, translate and speak, and
translates the selection on its own into a large popup. You do not have to press
anything for the common case.

**Hide until tapped.** Veils every translation so you read the original first and
only check yourself when you are stuck.

**Per sentence or per paragraph.** Sentence mode only splits blocks that are plain
text; anything containing links or other markup falls back to paragraph mode,
which is what stops it producing chopped-up fragments.

**Saved words.** Star a selection and it is kept with the sentence it came from and
the page it came from. Export gives you a tab separated file that Anki imports
directly.

**Never-translate list.** One switch per site, in Settings. On an excluded site the
app is completely inert: no pass, no selection bar, no popup.

59 languages, any pair among them.

---

## The parts nobody enjoys

**It is a WebView, and that is the point.** Android's WebView *is* Chromium, the
same engine Chrome renders with, kept current by the system rather than by this
app. Building a browser here means the frame around it and the script inside the
page, not a rendering engine, and pretending otherwise would mean shipping
something years behind on security patches.

**What a WebView does not give you** is Chrome's password manager, passkeys, sync,
or its extension support. That is exactly why the handoff button exists rather
than a login form of our own.

**The page can see the bridge.** The reader talks to the app through a JavaScript
object called `LL` with four methods on it: translate a batch, translate a
selection, save a word, speak a word. Any site you visit can call those, because
Android has no way to expose an interface to only your own script. The worst a
hostile site can do with them is put junk in your saved words or make the phone
speak; there is no file access, no storage access and no way to reach your other
tabs. It is a real trade and worth knowing about.

**Twelve tabs.** Each one holds a live WebView so switching is instant, which is
also what caps the number. Past twelve the oldest is closed.

---

## Where your text goes

**Translation is on device.** Google ML Kit's on-device models. The sentences you
read, the words you select and the vocabulary you save are never sent to a
translation service, and once a model is downloaded translation works in airplane
mode.

**Three things touch the network, and nothing else:**

1. **Loading a page.** It is a browser. The site sees an ordinary visit.
2. **Downloading a language model,** once per language, from Google's model
   service, roughly 30 MB in one direction. Your text is not part of that request.
3. **Speaking text aloud.** The speak button hands text to whichever
   text-to-speech engine your system has. Some synthesise locally, some in the
   cloud. This app cannot tell which yours does; check your TTS engine in system
   settings if it matters.

No analytics, no crash reporting, no advertising identifiers. See
[PRIVACY.md](PRIVACY.md).

---

## Using it

1. On first run, pick the language you understand. That is the only required
   setting.
2. Type an address. The page loads and translates itself.
3. First time in a new language it downloads that model, once, and says so.
4. Select text for save / translate / speak.
5. The button at the bottom right hands the page to Chrome.

Everything else lives behind the menu: reload, share, saved words, and Settings
for the reading mode, the veil, the colour, the search engine and the
never-translate list.

### Making it the default browser

Menu → *Make this my default browser*, or Settings → *Default browser*. On
Android 10 and newer this is a single system prompt. On older versions it opens
the settings screen where the choice lives.

Links from other apps then open here, translated, and the handoff button is
always one tap away when you need the real thing.

---

## Building

CI builds on every push to `main`, see
[`.github/workflows/build.yml`](.github/workflows/build.yml). The APK lands in the
run's artifacts and in a GitHub release. The workflow needs `contents: write` and
the repository setting Actions → General → Workflow permissions set to read and
write.

Locally:

```
gradle assembleRelease
```

Needs JDK 17 and the Android SDK with platform 34. The APK comes out at
`app/build/outputs/apk/release/`.

### Signing

The upload keystore is not in this repository. Without it `assembleRelease` still
works, falling back to the debug signing key, which is all a sideloaded APK needs.

To build with a real key locally, put `langualens-browser.jks` in `app/` and create
`keystore.properties` at the repository root (both are gitignored):

```
storePassword=...
keyAlias=...
keyPassword=...
```

For CI, add four repository secrets: `KEYSTORE_BASE64` (the `.jks`, base64
encoded), `KEYSTORE_PASSWORD`, `KEY_ALIAS` and `KEY_PASSWORD`. The workflow skips
the signing step when `KEYSTORE_BASE64` is absent.

---

## Layout of the code

| | |
|---|---|
| `BrowserActivity.kt` | The whole browser: address bar, WebView setup, the translation pass, the bridge the page talks to. |
| `Tabs.kt` | Open tabs and which one is on screen. |
| `assets/inline.js` | What runs inside the page: finds the text, inserts the lines, handles selection. |
| `translate/Translate.kt` | ML Kit, model downloads, the batch translator. |
| `translate/Detect.kt` | Which language the page is actually in. |
| `util/Handoff.kt` | Sending the page to Chrome. |
| `util/DefaultBrowser.kt` | Asking for the browser role. |
| `ui/Sheets.kt` | Every panel: menu, settings, tabs, first run. |
| `ui/SavedActivity.kt` | Saved words and the Anki export. |

---

## Deliberately not here

**No flip.** The extension turns a page that is already in your own language into
the language you are learning. It is a good feature and it needs a second language
setting to work, which doubles the questions this app asks. One setting was worth
more than the flip.

**No AnkiDroid push.** Export gives you the file; the phone app does the
ContentProvider handoff. Doing it in two places means two things to keep working.

**No history, no bookmarks.** The address bar and Chrome both already have them.
