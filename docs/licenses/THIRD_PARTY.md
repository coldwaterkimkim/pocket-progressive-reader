# Bundled reader dependencies

The app and the HTML hardware lab share the local assets in `PocketReader/RichReader`. Runtime rendering does not fetch scripts from a CDN.

- **Marked 15.0.12** — https://github.com/markedjs/marked/tree/v15.0.12 — MIT, complete license in `marked-LICENSE.md`. Bundled npm UMD distribution (`marked@15.0.12/lib/marked.umd.js`). GFM parsing, including tables and fenced code.
- **DOMPurify 3.2.6** — https://github.com/cure53/DOMPurify/tree/3.2.6 — dual Apache-2.0 / MPL-2.0, complete license in `DOMPurify-LICENSE.txt`. Bundled npm minified distribution (`dompurify@3.2.6/dist/purify.min.js`). Sanitizes Markdown-generated HTML before inserting it into a document.

Distribution files were retrieved during development from jsDelivr's pinned npm package URLs. Licenses were retrieved from the official GitHub release tags. No remote JavaScript is loaded by the app.

External image URLs are rendered as their alt text and an explicit `이미지 불러오기` control. They are fetched only after tapping that control, without a Referer header. Data PNG/JPEG/GIF/WebP images can display immediately. Unsupported or non-HTTPS image URLs remain placeholders. Links open only on a user's tap. Raw HTML is sanitized; scripts, styles, embedded frames, forms, audio, and video are excluded.

SHA-256 of bundled distributions:

- marked.js: `d7931d1cd7bf727dd756c871637edcc9e0f8538003b927368400ec1ee47a9dd9`
- purify.js: `89e1fa7647cb495370d3a997ace4387f5d15d9f4c5af12352c53daa400956287`
