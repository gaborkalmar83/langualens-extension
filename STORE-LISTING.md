# Chrome Web Store submission

Everything the dashboard asks for, written out so it can be pasted in. Fields marked
**YOU** need a decision or an action that cannot be prepared in advance.

---

## Before you can submit

1. **Register as a Chrome Web Store developer** at
   <https://chrome.google.com/webstore/devconsole>. There is a **one-time 5 USD
   registration fee**, payable by card. **YOU** — this cannot be done on your behalf.
2. **Verify a contact email** in the developer console. Publishing is blocked until
   an email is verified. It becomes publicly visible on the listing.
3. Put that same address into `PRIVACY.md` where it says `CONTACT_EMAIL_HERE`, and
   host the policy at a public URL (the GitHub file URL is acceptable).

---

## Listing fields

**Name** (45 char limit)

```
LanguaLens
```

**Short description** (132 char limit — this is 123)

```
Read any page in the language you are learning, with the translation underneath. Runs on your device. Saves words for Anki.
```

**Category**: `Education`
**Language**: English

**Detailed description**

```
LanguaLens turns any web page into a bilingual reader. Each paragraph keeps its
original text and gets its translation underneath, so you read in the language you
are learning and only glance down when you need to.

READING
- A translation under every paragraph, or under every sentence.
- Hide-until-clicked mode, so you try first and check yourself after.
- Select any text to see its translation in a large popup, without pressing
  anything.
- Pages already written in your target language are flipped automatically: if you
  are learning Dutch and reading with Dutch to English, an English page is turned
  into Dutch instead of being left alone.

VOCABULARY
- Save any word or sentence with one click. It keeps the sentence it came from and
  the page it came from.
- Export everything as a tab separated file that Anki imports directly.

PRIVACY
Translation runs on your own machine using Chrome's built-in translator. The pages
you read and the text you select are never sent to a translation server. There is no
account, no analytics and no advertising. Saved words stay in your browser until you
export or clear them.

Chrome downloads a translation model once per language pair. That transfers the
model to you and does not contain your text.

REQUIREMENTS
Chrome 138 or newer, which is the first version with the built-in on-device
translator. The extension will tell you if your Chrome is too old.

59 languages, any pair among them.
```

**Privacy policy URL**

```
https://github.com/gaborkalmar83/langualens-extension/blob/main/PRIVACY.md
```

---

## Privacy practices tab

**Single purpose** (required, one sentence)

```
LanguaLens displays translations of the text on the page you are reading, and lets
you save that text as vocabulary for study.
```

**Permission justifications** — paste one per permission:

`storage`
```
Stores the user's chosen language pair, their reading options, and the vocabulary
they explicitly save. All of it stays in local extension storage on the user's own
machine.
```

`contextMenus`
```
Adds two right-click entries: "Translate with LanguaLens" for a selection, and
"Translate this page with LanguaLens" for the whole page.
```

**Host permission** (`http://*/*`, `https://*/*`)
```
The extension's only function is to insert translations into the page the user is
reading, which requires reading that page's text and adding elements to it. The user
chooses which pages to translate, and the extension cannot know in advance which
sites those will be, since people read in a foreign language on any site. No page
content is transmitted anywhere: translation happens locally through Chrome's
built-in Translator API.
```

**Remote code**: select **No, I am not using remote code.**
All code is in the package. There are no external scripts, no eval of fetched code
and no CDN references.

**Data usage** — tick these and nothing else:
- Does your extension collect or transmit any of the listed data types? **No** to all.
- Then certify all three statements:
  - I do not sell or transfer user data to third parties, apart from the approved use cases
  - I do not use or transfer user data for purposes unrelated to my item's single purpose
  - I do not use or transfer user data to determine creditworthiness or for lending purposes

---

## Graphics assets

**YOU** — these have to be made from the extension actually running, and fabricated
mockups risk rejection.

| Asset | Size | Required |
|---|---|---|
| Store icon | 128x128 PNG | Yes — `icons/icon128.png` is ready to upload |
| Screenshot | 1280x800 or 640x400 PNG | Yes, at least one, up to five |
| Small promo tile | 440x280 PNG | Only if you want to be featured |

**Taking the screenshots.** Load the extension unpacked, then:

1. Open a foreign-language article and press Alt+L. Screenshot the page with the
   blue translations under each paragraph. This is the one screenshot that matters —
   make it the first.
2. Select a phrase so the three buttons and the large popup are both visible.
3. Open the extension popup showing the language pair and the saved list.

Set the browser window so the capture is exactly 1280x800. In Chrome DevTools, use
device toolbar with a custom 1280x800 size, then "Capture screenshot" from the
DevTools command menu.

---

## Packaging and uploading

Build the zip:

```
powershell -ExecutionPolicy Bypass -File package.ps1
```

That produces `dist/langualens-chrome-<version>.zip` with `manifest.json` at the
root, which is what the dashboard expects. Documentation and the packaging script
itself are excluded.

Then in the developer console: **Add new item**, upload the zip, fill in the fields
above, and **Submit for review**.

---

## What to expect from review

- Review usually takes a few days. Broad host permissions attract more scrutiny, so
  the justification above matters.
- If it is rejected, the mail names the policy clause. The most likely one here is
  the host permission breadth. The fallback, if they insist, is to switch to
  `activeTab` plus `chrome.scripting.executeScript` on click, which narrows access to
  tabs the user explicitly acts on. That is a code change, not a listing change, so
  come back to it if it happens rather than pre-emptively.
- Each update needs the `version` in `manifest.json` bumped before you upload again.
