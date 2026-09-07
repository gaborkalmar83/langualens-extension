# Privacy

LanguaLens Browser collects nothing. There is no account, no analytics, no crash
reporting, no advertising identifier, and no server belonging to this app.

## What stays on the phone

- **The pages you read.** Translation runs through Google ML Kit's on-device
  models. Page text is never sent to a translation service.
- **Your saved words.** A file in the app's own storage. It leaves only when you
  press Export and choose where to send it.
- **Your settings.** The app's own preferences, nothing more.
- **Cookies and site data.** Held by the system WebView for this app alone.
  Clearing the app's storage clears them.

## What touches the network

1. **Loading a page.** It is a browser. Each site you open sees an ordinary visit
   from your device, exactly as it would from any browser.
2. **Downloading a language model.** Once per language, from Google's model
   service. Roughly 30 MB, one direction, and none of your text is part of the
   request. Afterwards translation works offline.
3. **Speaking text aloud.** The speak button hands text to your system's
   text-to-speech engine. Some engines synthesise on the device and some in the
   cloud. This app cannot tell which yours does. If it matters, check your TTS
   engine in your system settings.

Nothing else. There are no other network calls.

## Permissions

- **INTERNET** and **ACCESS_NETWORK_STATE** — loading pages and fetching a
  language model.

That is the whole list. No location, no contacts, no storage, no accessibility
service, no overlay.

## Handing a page to Chrome

The handoff button opens the current URL in Chrome. From that point the page is
Chrome's and Chrome's privacy policy applies to it. Nothing else is passed across:
no cookies, no saved words, no settings, just the address.

## The JavaScript bridge

The reader talks to the app through a JavaScript object named `LL` with four
methods: translate a batch, translate a selection, save a word, speak a word. It
is attached to the page, so any site you visit can call it. Android provides no
way to expose an interface to only your own injected script. Those four methods
are the entire surface: no file access, no storage access, no access to other
tabs. The worst a hostile site can do is add junk to your saved words or make the
phone speak.

## Children

Nothing is collected from anyone, of any age.

## Changes

This file is versioned with the code. Its history is the change log.
