/* Shared bundled Markdown renderer. No runtime CDN or remote request until an image button is tapped. */
(function (global) {
  'use strict';
  let root, tokens = [], active = null, previousSource = null, scrollMarginLines = 0;
  const blocks = new Set(['P','DIV','H1','H2','H3','H4','H5','H6','LI','BLOCKQUOTE','PRE','TR','TH','TD','HR','BR']);
  function prepareImages() {
    root.querySelectorAll('img').forEach(img => {
      const src = img.dataset.pendingSrc || img.getAttribute('src') || '', alt = img.getAttribute('alt') || '이미지';
      if (/^data:image\/(png|jpeg|gif|webp);base64,/i.test(src)) { img.src = src; return; }
      const box = document.createElement('span'); box.className = 'image-placeholder';
      const label = document.createElement('span'); label.textContent = '[' + alt + ']'; box.append(label);
      if (/^https:\/\//i.test(src)) {
        const button = document.createElement('button'); button.textContent = '이미지 불러오기'; button.dataset.readerControl = 'true';
        button.addEventListener('click', () => {
          const loaded = document.createElement('img'); loaded.alt = alt; loaded.referrerPolicy = 'no-referrer';
          loaded.src = src; loaded.onerror = () => { button.textContent = '불러오기 실패 · 다시 시도'; button.disabled = false; };
          loaded.onload = () => { box.append(loaded); button.remove(); }; button.disabled = true;
        }); box.append(button);
      }
      img.replaceWith(box);
    });
  }
  function indexText() {
    let text = '', pieces = [];
    function walk(node) {
      if (node.nodeType === 3) { const start = text.length; text += node.nodeValue; pieces.push({node,start,end:text.length}); return; }
      if (node.nodeType !== 1 || node.dataset.readerControl || node.tagName === 'IMG') return;
      const boundary = blocks.has(node.tagName);
      if (boundary && text && !/\s$/.test(text)) text += '\n';
      [...node.childNodes].forEach(walk);
      if (boundary && text && !/\s$/.test(text)) text += '\n';
    }
    walk(root);
    tokens = [...text.matchAll(/\S+/gu)].map(m => ({text:m[0],start:m.index,end:m.index+m[0].length,elements:[]}));
    let cursor = 0;
    pieces.forEach(piece => {
      const fragment = document.createDocumentFragment(); let local = 0;
      while (cursor < tokens.length && tokens[cursor].end <= piece.start) cursor++;
      let j = cursor;
      while (j < tokens.length && tokens[j].start < piece.end) {
        const token = tokens[j], a = Math.max(piece.start,token.start)-piece.start, b = Math.min(piece.end,token.end)-piece.start;
        if (a > local) fragment.append(document.createTextNode(piece.node.nodeValue.slice(local,a)));
        const span = document.createElement('span'); span.dataset.token = j; span.textContent = piece.node.nodeValue.slice(a,b);
        fragment.append(span); token.elements.push(span); local = b; j++;
      }
      if (local < piece.node.nodeValue.length) fragment.append(document.createTextNode(piece.node.nodeValue.slice(local)));
      piece.node.replaceWith(fragment);
    });
    return tokens.map(t => t.text).join(' ');
  }
  function focus(index, style) {
    if (!root) return;
    root.dataset.focusStyle = style || 'yellow'; root.classList.toggle('has-focus', Number.isInteger(index));
    if (active !== null && tokens[active]) tokens[active].elements.forEach(el => el.classList.remove('focused'));
    active = Number.isInteger(index) && tokens[index] ? index : null;
    if (active === null) return;
    tokens[active].elements.forEach(el => el.classList.add('focused'));
    ensureTokenVisible(active);
  }
  function ensureTokenVisible(index) {
    if (!root || !tokens[index]) return;
    const elements = tokens[index].elements;
    const first = elements[0], last = elements[elements.length-1]; if (!first) return;
    const bounds = root.getBoundingClientRect(), a = first.getBoundingClientRect(), b = last.getBoundingClientRect();
    if (root.classList.contains('horizontal')) {
      // Convert visual coordinates to scroll coordinates, including scaled hardware previews.
      const scale = root.clientWidth / bounds.width;
      root.scrollLeft += ((a.left + b.right) / 2 - (bounds.left + bounds.right) / 2) * scale;
      return;
    }
    if (scrollMarginLines > 0) {
      // Find actual neighboring visual rows, including Markdown headings/block spacing.
      // Walk only the nearby tokens; never reshape or enumerate the whole document per detent.
      function adjacent(direction) {
        const rows = []; let edge = direction < 0 ? a.top : b.bottom;
        for (let j = index + direction; j >= 0 && j < tokens.length && rows.length < scrollMarginLines; j += direction) {
          const parts = tokens[j].elements; if (!parts.length) continue;
          const firstBox = parts[0].getBoundingClientRect(), lastBox = parts[parts.length - 1].getBoundingClientRect();
          const box = {top:firstBox.top, bottom:lastBox.bottom};
          if (direction < 0 ? box.bottom <= edge + .5 : box.top >= edge - .5) {
            rows.push(box); edge = direction < 0 ? box.top : box.bottom;
          }
        }
        return rows;
      }
      const before = adjacent(-1), after = adjacent(1);
      let margin = scrollMarginLines, top = a.top, bottom = b.bottom;
      do {
        top = margin && before.length ? before[Math.min(margin, before.length) - 1].top : a.top;
        bottom = margin && after.length ? after[Math.min(margin, after.length) - 1].bottom : b.bottom;
        if (bottom - top <= bounds.height + .5 || margin === 0) break;
        margin--;
      } while (true);
      const scale = root.clientHeight / bounds.height;
      if (top < bounds.top) root.scrollTop -= (bounds.top - top) * scale;
      else if (bottom > bounds.bottom) root.scrollTop += (bottom - bounds.bottom) * scale;
      return;
    }
    if (a.top < bounds.top || b.bottom > bounds.bottom || a.left < bounds.left || b.right > bounds.right) {
      first.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});
    }
  }
  function setHorizontal(value) {
    if (!root) return;
    root.classList.toggle('horizontal', !!value);
    const existing = root.querySelector(':scope > .rail-strip');
    if (value && !existing) {
      const strip = document.createElement('div'); strip.className = 'rail-strip';
      strip.append(...root.childNodes); root.append(strip);
    } else if (!value && existing) {
      existing.replaceWith(...existing.childNodes);
    }
  }
  function mount(payload) {
    root = document.getElementById('reader-document'); if (!root) throw new Error('Missing reader-document'); active = null;
    scrollMarginLines = Math.min(2, Math.max(0, Number(payload.scrollMarginLines || 0)));
    const source = String(payload.source || '');
    if (source !== previousSource) { root.scrollTop = 0; root.scrollLeft = 0; previousSource = source; }
    if (payload.format === 'markdown') {
      // Images have their source removed before insertion: no eager network request can leak the imported document.
      const clean = DOMPurify.sanitize(marked.parse(source,{gfm:true,breaks:false}), {FORBID_TAGS:['style','iframe','video','audio','form'], FORBID_ATTR:['style','srcset','ping','background'], USE_PROFILES:{html:true}});
      const template = document.createElement('template'); template.innerHTML = clean;
      template.content.querySelectorAll('input').forEach(input => {
        if (input.type === 'checkbox') { const marker = document.createElement('span'); marker.textContent = input.checked ? '☑ ' : '☐ '; input.replaceWith(marker); }
        else input.remove();
      });
      template.content.querySelectorAll('img').forEach(img => { img.dataset.pendingSrc = img.getAttribute('src') || ''; img.removeAttribute('src'); });
      root.replaceChildren(template.content);
      prepareImages();
    } else { root.textContent = source; root.classList.add('plain'); }
    root.classList.toggle('plain', payload.format !== 'markdown');
    root.style.setProperty('--font-size', Number(payload.fontSize || 26)+'px');
    root.style.setProperty('--padding', Number(payload.padding || 14)+'px');
    root.style.setProperty('--line-gap', Number(payload.lineGap || 6)+'px');
    setHorizontal(payload.horizontal);
    const normalized = indexText();
    if (global.webkit && global.webkit.messageHandlers.reader) global.webkit.messageHandlers.reader.postMessage({text:normalized});
    if (typeof global.readerDocumentReady === 'function') global.readerDocumentReady(normalized);
    focus(payload.focusIndex,payload.style);
    return normalized;
  }
  global.RichReader = {mount,focus,setHorizontal,ensureTokenVisible,getTokenCount:()=>tokens.length};
})(window);
