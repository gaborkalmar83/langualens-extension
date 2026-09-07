# This folder is staged, not final

`browser/` holds the complete **LanguaLens Browser** Android project. It lives here
only because the session that wrote it could not create a new GitHub repository;
it belongs in one of its own, at the root, not as a subfolder of the extension.

To move it, once an empty `langualens-browser` repository exists:

```bash
cd browser
git init -b main
git add .
git commit -m "LanguaLens Browser: a translating Android browser"
git remote add origin git@github.com:gaborkalmar83/langualens-browser.git
git push -u origin main
```

Then drop it from this repository:

```bash
cd ..
git rm -r browser
git commit -m "Move the browser to its own repository"
```

The CI workflow under `browser/.github/workflows/` only runs once the folder is at
a repository root, which is another reason not to leave it here.
