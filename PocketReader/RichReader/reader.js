/* Shared bundled Markdown renderer. No runtime CDN or remote request until an image button is tapped. */
(function (global) {
  'use strict';
  let root, tokens = [], active = null, previousSource = null, scrollMarginLines = 0, hardBreaks = [], paintLayer;
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
          loaded.onload = () => { box.append(loaded); button.remove(); if (active) ensureTokenRangeVisible(active.start,active.end); paintFocus(); }; button.disabled = true;
        }); box.append(button);
      }
      img.replaceWith(box);
    });
  }
  function indexText() {
    let text = '', pieces = [], boundaries = new Set();
    function walk(node) {
      if (node.nodeType === 3) { const start = text.length; text += node.nodeValue; pieces.push({node,start,end:text.length}); return; }
      if (node.nodeType !== 1) return;
      if (node.dataset.readerControl || node.tagName === 'IMG') { boundaries.add(text.length); return; }
      const boundary = blocks.has(node.tagName) || node.classList.contains('image-placeholder');
      if (boundary) { if (text && !/\s$/.test(text)) text += '\n'; boundaries.add(text.length); }
      [...node.childNodes].forEach(walk);
      if (boundary) { if (text && !/\s$/.test(text)) text += '\n'; boundaries.add(text.length); }
    }
    walk(root);
    tokens = [...text.matchAll(/\S+/gu)].map(m => ({text:m[0],start:m.index,end:m.index+m[0].length,elements:[]}));
    // Keep structural boundaries from the original DOM, before the rail flattens its display.
    for (const match of text.matchAll(/\n+/g)) boundaries.add(match.index + match[0].length);
    if (typeof Intl.Segmenter === 'function') {
      for (const sentence of new Intl.Segmenter(undefined, {granularity:'sentence'}).segment(text)) boundaries.add(sentence.index);
    }
    function tokenAtOrAfter(offset) {
      let lo=0,hi=tokens.length;
      while (lo<hi) { const mid=(lo+hi)>>1; if (tokens[mid].start<offset) lo=mid+1; else hi=mid; }
      return lo;
    }
    hardBreaks = [...new Set([...boundaries].map(tokenAtOrAfter).filter(index => index > 0 && index < tokens.length))].sort((a,b) => a-b);
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
  function validRange(start, end) {
    if (!Number.isInteger(start) || !tokens[start]) return null;
    return {start, end:Math.max(start + 1, Math.min(tokens.length, Number.isInteger(end) ? end : start + 1))};
  }
  function rangeRects(range) {
    const first = tokens[range.start].elements[0], parts = tokens[range.end-1].elements, last = parts[parts.length-1];
    if (!first || !last) return [];
    const selection = document.createRange();
    selection.setStart(first.firstChild,0); selection.setEnd(last.lastChild,last.lastChild.textContent.length);
    return [...selection.getClientRects()].filter(rect => rect.width > 0 && rect.height > 0);
  }
  function paintFocus() {
    if (!paintLayer || !root) return;
    paintLayer.replaceChildren();
    if (!active || !['yellow','highContrast','underline'].includes(root.dataset.focusStyle)) return;
    const bounds = root.getBoundingClientRect(), sx = root.offsetWidth / bounds.width, sy = root.offsetHeight / bounds.height;
    const rows = [];
    for (const rect of rangeRects(active)) {
      const row = rows.find(row => Math.min(row.bottom,rect.bottom) - Math.max(row.top,rect.top) > Math.min(row.bottom-row.top,rect.height)*.6);
      if (row) { row.left=Math.min(row.left,rect.left); row.right=Math.max(row.right,rect.right); row.top=Math.min(row.top,rect.top); row.bottom=Math.max(row.bottom,rect.bottom); }
      else rows.push({left:rect.left,right:rect.right,top:rect.top,bottom:rect.bottom});
    }
    for (const row of rows) {
      const mark = document.createElement('i');
      mark.style.left=((row.left-bounds.left)*sx+root.scrollLeft-3)+'px';
      const underline=root.dataset.focusStyle==='underline';
      mark.style.top=(( (underline ? row.bottom : row.top)-bounds.top)*sy+root.scrollTop+(underline ? 2 : 0))+'px';
      mark.style.width=((row.right-row.left)*sx+6)+'px'; mark.style.height=(underline ? 2 : (row.bottom-row.top)*sy)+'px';
      paintLayer.append(mark);
    }
  }
  function focusRange(start, endExclusive, style) {
    if (!root) return;
    if (active) for (let i=active.start;i<active.end;i++) tokens[i].elements.forEach(el => el.classList.remove('focused'));
    active = validRange(start,endExclusive);
    root.dataset.focusStyle = style || 'yellow'; root.classList.toggle('has-focus', !!active);
    if (active) {
      for (let i=active.start;i<active.end;i++) tokens[i].elements.forEach(el => el.classList.add('focused'));
      ensureTokenRangeVisible(active.start,active.end);
    }
    paintFocus();
  }
  function focus(index, style) { focusRange(index,Number.isInteger(index) ? index+1 : null,style); }
  function ensureTokenRangeVisible(start, endExclusive) {
    const range = validRange(start,endExclusive); if (!root || !range) return;
    const rects = rangeRects(range); if (!rects.length) return;
    const bounds=root.getBoundingClientRect();
    const a={left:Math.min(...rects.map(r=>r.left)),top:Math.min(...rects.map(r=>r.top))};
    const b={right:Math.max(...rects.map(r=>r.right)),bottom:Math.max(...rects.map(r=>r.bottom))};
    if (root.classList.contains('horizontal')) {
      root.scrollLeft += ((a.left+b.right)/2-(bounds.left+bounds.right)/2)*root.clientWidth/bounds.width;
      return;
    }
    function adjacent(direction) {
      const rows=[]; let edge=direction<0 ? a.top : b.bottom;
      for (let j=direction<0 ? range.start-1 : range.end;j>=0 && j<tokens.length && rows.length<scrollMarginLines;j+=direction) {
        const parts=tokens[j].elements; if (!parts.length) continue;
        const boxes=parts.flatMap(el=>[...el.getClientRects()]);
        const box={top:Math.min(...boxes.map(r=>r.top)),bottom:Math.max(...boxes.map(r=>r.bottom))};
        if (direction<0 ? box.bottom<=edge+.5 : box.top>=edge-.5) { rows.push(box); edge=direction<0 ? box.top : box.bottom; }
      }
      return rows;
    }
    const before=adjacent(-1),after=adjacent(1); let margin=scrollMarginLines,top=a.top,bottom=b.bottom;
    do {
      top=margin && before.length ? before[Math.min(margin,before.length)-1].top : a.top;
      bottom=margin && after.length ? after[Math.min(margin,after.length)-1].bottom : b.bottom;
      if (bottom-top<=bounds.height+.5 || margin===0) break;
      margin--;
    } while (true);
    const scale=root.clientHeight/bounds.height;
    // Oversized groups anchor their first row; do not alternate between opposing edges.
    if (top<bounds.top || bottom-top>bounds.height) root.scrollTop+=(top-bounds.top)*scale;
    else if (bottom>bounds.bottom) root.scrollTop+=(bottom-bounds.bottom)*scale;
  }
  function ensureTokenVisible(index) { ensureTokenRangeVisible(index,index+1); }
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
    paintLayer=document.createElement('div'); paintLayer.className='focus-paint-layer'; paintLayer.dataset.readerControl='true'; paintLayer.setAttribute('aria-hidden','true'); root.append(paintLayer);
    root.onscroll=paintFocus;
    root.querySelectorAll('img').forEach(img=>img.addEventListener('load',paintFocus));
    if (global.webkit && global.webkit.messageHandlers.reader) global.webkit.messageHandlers.reader.postMessage({text:normalized,hardBreaks});
    if (typeof global.readerDocumentReady === 'function') global.readerDocumentReady(normalized);
    focus(payload.focusIndex,payload.style);
    return normalized;
  }
  global.RichReader = {mount,focus,focusRange,setHorizontal,ensureTokenVisible,ensureTokenRangeVisible,getTokenCount:()=>tokens.length,getHardBreaks:()=>hardBreaks.slice()};
  global.addEventListener('resize',()=>{ if (active) { ensureTokenRangeVisible(active.start,active.end); paintFocus(); } });
})(window);
