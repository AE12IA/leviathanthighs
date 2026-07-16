# HubFFlag — publish (free)

Your live URL will look like:

```
https://YOUR_USERNAME.github.io/hubfflag/
```

## What you do (step by step)

### 1. Preview locally
Open `index.html` in your browser (double-click it).  
You should see a dark page like Potassium: big **HubFFlag**, tagline, three buttons.

### 2. Create the GitHub repo
1. Log in at https://github.com
2. Open https://github.com/new
3. **Repository name:** `hubfflag`
4. Set to **Public**
5. Do **not** check “Add a README”
6. Click **Create repository**

### 3. Upload the site
On the new empty repo page:
1. Click **uploading an existing file** (or **Add file → Upload files**)
2. Open the `website` folder on your PC
3. Drag **all** of these into GitHub:
   - `index.html`
   - `downloads.html`
   - `styles.css`
   - `app.js` (optional)
   - `meta.json` (optional)
   - `README.md`
   - `.gitignore`
   - the whole `downloads` folder
4. Scroll down → **Commit changes**

### 4. Turn on GitHub Pages
1. Repo → **Settings**
2. Left sidebar → **Pages**
3. **Source:** Deploy from a branch
4. **Branch:** `main` (or `master`), folder **/(root)**
5. **Save**

Wait 1–2 minutes, then open:

`https://YOUR_USERNAME.github.io/hubfflag/`

### 5. Fix the button links
Edit `index.html` on GitHub (pencil icon) and replace:
- `YOUR_USERNAME` → your real GitHub username
- `YOUR_INVITE` → your Discord invite code (or remove the Discord button)

---

## After it’s live
- Update files anytime → re-upload / commit → site updates
- Swap placeholder dumps in `downloads/` for real ones
