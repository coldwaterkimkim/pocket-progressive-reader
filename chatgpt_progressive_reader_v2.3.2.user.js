// ==UserScript==
// @name         ChatGPT Progressive Reader
// @namespace    local.chatgpt.progressive-reader
// @version      2.3.2
// @description  Reveal the native ChatGPT answer progressively and quote sentences into its composer.
// @match        https://chatgpt.com/*
// @match        https://www.chatgpt.com/*
// @match        https://chat.openai.com/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(() => {
  'use strict';

  if (window.__chatgptProgressiveReaderV2) return;
  window.__chatgptProgressiveReaderV2 = true;

  const DEBUG = false;
  const TARGET_EOJEOL = 4;
  const MIN_EOJEOL = 3;
  const MAX_EOJEOL = 5;
  const PROSE_BLOCKS = 'p,h1,h2,h3,h4,h5,h6,li,pre,td,th';
  const BLOCKS = PROSE_BLOCKS + ',code';
  const PREFIX = 'cpr2';
  const captureSessions = new Map();
  const state = {
    active: false, root: null, unit: null, scroller: null, route: '',
    blocks: [], tokens: [], chunks: [], sentences: [], lines: [],
    originalNodes: [], revealed: 0, focusedLine: 0,
    messageId: '', captureSession: null,
    side: null, controls: null, previousFocus: null, observer: null,
    turnObserver: null, routeTimer: null, resizeObserver: null,
    resizeFrame: 0, contentTimer: null, maskStyle: null, hud: null,
    markerColors: []
  };

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  }

  function toast(message) {
    document.getElementById(PREFIX + '-toast')?.remove();
    const node = el('div', PREFIX + '-toast', message);
    node.id = PREFIX + '-toast';
    document.body.appendChild(node);
    setTimeout(() => node.remove(), 3300);
  }

  function installUiStyle() {
    if (document.getElementById(PREFIX + '-style')) return;
    const style = el('style');
    style.id = PREFIX + '-style';
    style.textContent = [
      '#' + PREFIX + '-launcher{position:fixed;right:18px;bottom:18px;z-index:2147483000;border:1px solid #7778;border-radius:999px;padding:8px 12px;background:#202020;color:#fff;font:600 12px system-ui;cursor:pointer;box-shadow:0 5px 18px #0004}',
      '#' + PREFIX + '-hud{position:fixed;left:50%;bottom:18px;transform:translateX(-50%);z-index:2147483001;border:1px solid #7778;border-radius:999px;padding:8px 12px;background:#202020ed;color:#fff;font:500 12px system-ui;pointer-events:none;white-space:nowrap}',
      '#' + PREFIX + '-side{position:fixed;right:18px;top:84px;z-index:2147483001;width:min(230px,calc(100vw - 36px));font:13px/1.55 system-ui}',
      '#' + PREFIX + '-controls{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px;border:1px solid #7778;border-radius:12px;background:#202020f5;padding:8px;box-shadow:0 12px 32px #0004;color:#fff}',
      '#' + PREFIX + '-controls button{border:1px solid #7778;border-radius:7px;background:#ffffff13;color:#fff;padding:5px 9px;cursor:pointer;font:inherit}',
      '#' + PREFIX + '-controls button:hover{background:#ffffff25}',
      '#' + PREFIX + '-controls button{min-height:38px}',
      '.' + PREFIX + '-toast{position:fixed;left:50%;top:22px;transform:translateX(-50%);z-index:2147483100;padding:9px 14px;border-radius:9px;background:#272727;color:#fff;box-shadow:0 8px 24px #0005;font:13px system-ui}',
      '@media(max-width:760px){#' + PREFIX + '-side{top:auto;bottom:58px;right:10px;left:auto;width:190px}#' + PREFIX + '-hud{bottom:10px;max-width:calc(100vw - 20px);overflow:hidden;text-overflow:ellipsis}}'
    ].join('\n');
    document.head.appendChild(style);
  }

  function assistantUnits() {
    return [...document.querySelectorAll('h4[data-conversation-role="assistant"]')]
      .map(heading => heading.parentElement)
      .filter(unit => unit?.querySelector('[data-markdown-text-style="assistant-message"]'));
  }

  function findTarget() {
    const unit = assistantUnits().at(-1);
    if (!unit) return null;
    const root = unit.querySelector('[data-markdown-text-style="assistant-message"]');
    const ids = unit.getAttribute('data-chatgpt-search-message-ids') || '';
    const messageId = ids.split(/\s+/u)[0];
    const finished = !document.querySelector('button[aria-label="Stop"]') &&
      !root.hasAttribute('data-markdown-animated') &&
      !!unit.querySelector('[data-chatgpt-selection-message-id]');
    return { unit, root, messageId, finished };
  }

  function findScroller(root) {
    let scrollable = null;
    for (let node = root?.parentElement; node; node = node.parentElement) {
      if (node.classList.contains('thread-scroll-container')) return node;
      if (!scrollable && /^(auto|scroll)$/u.test(getComputedStyle(node).overflowY)) {
        scrollable = node;
      }
    }
    return scrollable || document.scrollingElement;
  }

  function scrollBounds(scroller) {
    const distance = Math.max(0, scroller.scrollHeight - scroller.clientHeight);
    const reverse = getComputedStyle(scroller).flexDirection === 'column-reverse';
    return { min: reverse ? -distance : 0, max: reverse ? 0 : distance, reverse };
  }

  function isStandaloneCode(element) {
    if (element.tagName !== 'CODE' || element.closest('pre')) return false;
    const display = getComputedStyle(element).display;
    return !element.closest(PROSE_BLOCKS) || display === 'block' || display === 'inline-block';
  }

  function textOwner(node) {
    const code = node.parentElement?.closest('code');
    if (code && isStandaloneCode(code)) return code;
    return node.parentElement?.closest(PROSE_BLOCKS);
  }

  function collectBlocks(root) {
    const blocks = [];
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      const parent = node.parentElement;
      if (!node.nodeValue || !parent || parent.closest('button,script,style,svg,[hidden],[aria-hidden="true"],[data-markdown-copy="exclude"],.sr-only')) continue;
      const element = textOwner(node);
      if (!element || !root.contains(element)) continue;
      const previous = blocks.at(-1);
      if (previous?.element === element) previous.nodes.push(node);
      else blocks.push({ element, nodes: [node] });
    }
    return blocks.filter(block => block.nodes.some(node => node.nodeValue.trim()));
  }

  function hasUncoveredContent(root, blocks = state.blocks) {
    const unsupportedMedia = [...root.querySelectorAll('img,video,canvas,iframe,svg text')]
      .some(element => {
        // Citation favicons are link decorations, not answer images.
        if (element.matches('img[alt=""]') &&
            element.closest('a[data-testid="chatgpt-citation"]')) return false;
        if (element.closest('button,[hidden],[aria-hidden="true"],[data-markdown-copy="exclude"],.sr-only')) return false;
        const css = getComputedStyle(element);
        return element.getClientRects().length > 0 &&
          css.display !== 'none' && css.visibility !== 'hidden';
      });
    if (unsupportedMedia) return true;
    const covered = new Set(blocks.flatMap(block => block.nodes));
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (!node.nodeValue?.trim() || covered.has(node)) continue;
      const parent = node.parentElement;
      if (!parent || parent.closest('button,script,style,svg,[hidden],[aria-hidden="true"],[data-markdown-copy="exclude"],.sr-only')) continue;
      const css = getComputedStyle(parent);
      if (css.display !== 'none' && css.visibility !== 'hidden') return true;
    }
    return false;
  }

  function atomicRanges(block) {
    const ranges = [];
    for (const element of block.element.querySelectorAll('a,code,kbd,samp,math,[data-math],[data-markdown-copy="inline-code"]')) {
      let offset = 0, start = Infinity, end = -Infinity;
      for (const node of block.nodes) {
        if (element.contains(node)) {
          start = Math.min(start, offset);
          end = Math.max(end, offset + node.nodeValue.length);
        }
        offset += node.nodeValue.length;
      }
      if (end > start) ranges.push({ start, end });
    }
    const patterns = [
      /(?:https?:\/\/|www\.)[^\s<>]+/giu,
      /[\(\[\{（【][^\n()\[\]{}（）【】]{1,28}[\)\]\}）】]/gu
    ];
    for (const pattern of patterns) {
      for (const match of block.text.matchAll(pattern)) {
        if (pattern === patterns[1] && match[0].trim().split(/\s+/u).length > 3) continue;
        ranges.push({ start: match.index, end: match.index + match[0].length });
      }
    }
    ranges.sort((a, b) => a.start - b.start);
    const merged = [];
    for (const range of ranges) {
      if (merged.length && range.start <= merged.at(-1).end) {
        merged.at(-1).end = Math.max(merged.at(-1).end, range.end);
      } else merged.push({ ...range });
    }
    return merged;
  }

  function sentenceSpans(block) {
    if (block.isCode) return [{ start: 0, end: block.text.length }];
    let spans = [];
    try {
      spans = [...new Intl.Segmenter('ko', { granularity: 'sentence' }).segment(block.text)]
        .map(part => ({ start: part.index, end: part.index + part.segment.length }));
    } catch (_) {
      spans = [{ start: 0, end: block.text.length }];
    }
    if (!spans.length) spans = [{ start: 0, end: block.text.length }];
    const merged = [];
    for (const span of spans) {
      const previous = merged.at(-1);
      if (previous && block.atomic.some(range => range.start < previous.end && previous.end < range.end)) {
        previous.end = span.end;
      } else merged.push({ ...span });
    }
    return merged;
  }

  function punctuationScore(text) {
    const value = text.trim().replace(/["'’”»》〉」』】\)\]\}）]+$/gu, '');
    if (/[.!?。！？‼⁉…]$/u.test(value)) return 12;
    if (/[,，:：;；]$/u.test(value)) return 6;
    return 0;
  }

  function piecesForSentence(block, sentence) {
    const pieces = [];
    const tokens = block.tokens.filter(token =>
      token.start >= sentence.start && token.start < sentence.end);
    for (let i = 0; i < tokens.length;) {
      const hit = block.atomic.find(range =>
        range.start < tokens[i].end && tokens[i].start < range.end);
      let j = i + 1;
      if (hit) while (j < tokens.length && tokens[j].start < hit.end) j++;
      pieces.push({
        startToken: tokens[i].index, endToken: tokens[j - 1].index + 1,
        eojeol: j - i,
        text: block.text.slice(tokens[i].start, tokens[j - 1].end)
      });
      i = j;
    }
    return pieces;
  }

  function makeChunks(block, sentence, pieces) {
    if (!pieces.length) return [];
    const best = new Array(pieces.length + 1);
    best[pieces.length] = { score: 0, path: [] };
    for (let i = pieces.length - 1; i >= 0; i--) {
      let count = 0;
      for (let j = i + 1; j <= pieces.length; j++) {
        count += pieces[j - 1].eojeol;
        const oversizedAtom = j === i + 1 && count > MAX_EOJEOL;
        if (count > MAX_EOJEOL && !oversizedAtom) break;
        if (!best[j]) continue;
        const from = pieces[i].startToken;
        const to = pieces[j - 1].endToken;
        const text = block.text.slice(state.tokens[from].start, state.tokens[to - 1].end);
        const chars = [...text.replace(/\s+/gu, '')].length;
        const desired = chars >= 30 && count === 4 ? 3 :
          chars <= 8 && count === 4 ? 5 : TARGET_EOJEOL;
        const tooShort = count < MIN_EOJEOL && pieces.length > 1;
        const score = best[j].score + punctuationScore(text) -
          Math.abs(count - desired) * 2 - (tooShort ? 30 : 0) -
          (oversizedAtom ? 4 : 0);
        if (!best[i] || score > best[i].score) {
          best[i] = { score, path: [{ startToken: from, endToken: to, sentenceId: sentence.id }, ...best[j].path] };
        }
        if (oversizedAtom) break;
      }
    }
    return best[0]?.path || [{
      startToken: pieces[0].startToken,
      endToken: pieces.at(-1).endToken,
      sentenceId: sentence.id
    }];
  }

  function buildModel(root) {
    const blocks = collectBlocks(root).map(({ element, nodes }) => {
      const colors = new Map(nodes.map(node => [node, getComputedStyle(node.parentElement).color]));
      return { element, nodes, colors, text: nodes.map(node => node.nodeValue).join(''),
        tokens: [], atomic: [], isCode: element.tagName === 'PRE' || element.tagName === 'CODE' };
    });
    state.blocks = blocks;
    state.tokens = [];
    state.chunks = [];
    state.sentences = [];
    for (const block of blocks) {
      block.atomic = atomicRanges(block);
      if (block.isCode) {
        state.tokens.push({
          index: state.tokens.length, block, start: 0, end: block.text.length,
          text: block.text, parts: [], isCode: true
        });
        block.tokens = [state.tokens.at(-1)];
      } else {
        for (const match of block.text.matchAll(/\S+/gu)) {
          const token = {
            index: state.tokens.length, block, start: match.index,
            end: match.index + match[0].length, text: match[0], parts: [], isCode: false
          };
          block.tokens.push(token);
          state.tokens.push(token);
        }
      }
      for (const span of sentenceSpans(block)) {
        const selected = block.tokens.filter(token => token.start >= span.start && token.start < span.end);
        if (!selected.length) continue;
        const sentence = {
          id: state.sentences.length, block, start: selected[0].start,
          end: Math.max(span.end, selected.at(-1).end),
          startToken: selected[0].index, endToken: selected.at(-1).index + 1,
          isCode: block.isCode
        };
        state.sentences.push(sentence);
        for (const token of selected) token.sentenceId = sentence.id;
        if (sentence.isCode) {
          state.chunks.push({ startToken: sentence.startToken, endToken: sentence.endToken, sentenceId: sentence.id });
        } else {
          state.chunks.push(...makeChunks(block, sentence, piecesForSentence(block, sentence)));
        }
      }
    }
    state.chunks.forEach((chunk, chunkIndex) => {
      for (let i = chunk.startToken; i < chunk.endToken; i++) {
        state.tokens[i].chunkIndex = chunkIndex;
      }
    });
    return state.tokens.length > 0 && state.chunks.length > 0;
  }

  function wrapTextNodes() {
    state.originalNodes = [];
    for (const block of state.blocks) {
      if (!block.tokens.length) continue;
      // Keep word spans for line and partial-chunk navigation. Mask the spaces
      // between words of the same chunk so each unrevealed chunk is one bar.
      // Source code is one reveal unit. Keep it as a single range instead of
      // creating thousands of word spans for a long code block.
      const intervals = block.isCode ?
        [{ token: block.tokens[0], start: 0, end: block.text.length }] :
        block.tokens.flatMap((token, index) => {
          const next = block.tokens[index + 1];
          const parts = [{ token, start: token.start, end: token.end, gap: false }];
          if (next && next.chunkIndex === token.chunkIndex && next.start > token.end) {
            parts.push({ token, start: token.end, end: next.start, gap: true });
          }
          return parts;
        });
      let nodeStart = 0;
      let intervalIndex = 0;
      for (const original of block.nodes) {
        const nodeEnd = nodeStart + original.nodeValue.length;
        const color = block.colors.get(original);
        const fragment = document.createDocumentFragment();
        const inserted = [];
        let cursor = nodeStart;
        while (intervalIndex < intervals.length && intervals[intervalIndex].end <= nodeStart) {
          intervalIndex++;
        }
        for (let i = intervalIndex; i < intervals.length && intervals[i].start < nodeEnd; i++) {
          const interval = intervals[i];
          const start = Math.max(nodeStart, interval.start);
          const end = Math.min(nodeEnd, interval.end);
          if (end <= start) continue;
          if (start > cursor) {
            const gap = document.createTextNode(original.nodeValue.slice(cursor - nodeStart, start - nodeStart));
            fragment.appendChild(gap);
            inserted.push(gap);
          }
          const span = el('span', interval.gap ? PREFIX + '-gap' : PREFIX + '-piece');
          if (!interval.gap) span.style.setProperty('--' + PREFIX + '-color', color);
          span.textContent = original.nodeValue.slice(start - nodeStart, end - nodeStart);
          interval.token.parts.push({ span, start, end });
          fragment.appendChild(span);
          inserted.push(span);
          cursor = end;
        }
        if (cursor < nodeEnd) {
          const gap = document.createTextNode(original.nodeValue.slice(cursor - nodeStart));
          fragment.appendChild(gap);
          inserted.push(gap);
        }
        if (inserted.some(node => node.nodeType === Node.ELEMENT_NODE)) {
          const parent = original.parentNode;
          parent.insertBefore(fragment, original);
          original.remove();
          state.originalNodes.push({ original, parent, inserted });
        }
        nodeStart = nodeEnd;
      }
    }
  }

  function tokenRects(token) {
    if (!token.parts.length) return [];
    const first = token.parts.find(part => part.end > token.start);
    const last = [...token.parts].reverse().find(part => part.start < token.end);
    if (!first || !last) return [];
    const range = document.createRange();
    range.setStart(first.span.firstChild, token.isCode ? 0 : token.start - first.start);
    range.setEnd(last.span.firstChild, token.isCode ? last.span.firstChild.length : token.end - last.start);
    return [...range.getClientRects()].filter(rect => rect.width > 0 && rect.height > 0);
  }

  function rebuildLines() {
    const fragments = [];
    for (const token of state.tokens) {
      const rects = tokenRects(token);
      if (!rects.length) return false;
      rects.forEach((rect, rectIndex) => fragments.push({
        token: token.index, y: (rect.top + rect.bottom) / 2,
        top: rect.top, bottom: rect.bottom, left: rect.left, rectIndex
      }));
    }
    fragments.sort((a, b) => a.y - b.y || a.left - b.left);
    const lines = [];
    for (const fragment of fragments) {
      let line = lines.at(-1);
      const overlap = line ?
        Math.min(line.bottom, fragment.bottom) - Math.max(line.top, fragment.top) : 0;
      const minHeight = line ?
        Math.min(line.bottom - line.top, fragment.bottom - fragment.top) : 0;
      const sameLine = line && (Math.abs(line.y - fragment.y) <= 5 ||
        (minHeight > 0 && overlap / minHeight >= 0.45));
      if (!sameLine) {
        line = {
          fragments: [], y: fragment.y, top: fragment.top, bottom: fragment.bottom,
          startToken: fragment.token, endToken: fragment.token + 1
        };
        lines.push(line);
      }
      line.fragments.push(fragment);
      line.top = Math.min(line.top, fragment.top);
      line.bottom = Math.max(line.bottom, fragment.bottom);
      line.y = (line.top + line.bottom) / 2;
      line.startToken = Math.min(line.startToken, fragment.token);
      line.endToken = Math.max(line.endToken, fragment.token + 1);
    }
    if (!lines.length) return false;
    state.lines = lines;
    state.tokens.forEach(token => { token.firstLine = -1; token.lastLine = -1; });
    lines.forEach((line, index) => {
      line.fragments.forEach(fragment => {
        const token = state.tokens[fragment.token];
        if (token.firstLine < 0) token.firstLine = index;
        token.lastLine = index;
      });
    });
    return true;
  }

  function centerLine(index) {
    const line = state.lines[index];
    const scroller = state.scroller;
    if (!line || !scroller?.isConnected) return;
    const bounds = scrollBounds(scroller);
    if (bounds.max - bounds.min < 2) return;
    const fragment = line.fragments[0];
    const token = state.tokens[fragment.token];
    const target = tokenRects(token)[fragment.rectIndex];
    if (!target) return;
    const viewport = scroller === document.scrollingElement ?
      { top: 0, bottom: window.innerHeight } : scroller.getBoundingClientRect();
    const lineY = (target.top + target.bottom) / 2;
    const viewportY = (viewport.top + viewport.bottom) / 2;
    const delta = lineY - viewportY;
    if (Math.abs(delta) < 2) return;
    scroller.scrollTop = Math.max(bounds.min, Math.min(bounds.max, scroller.scrollTop + delta));
  }

  function setRevealed(next, lineIndex) {
    const previous = state.revealed;
    next = Math.max(0, Math.min(state.tokens.length, next));
    if (next === previous) return;
    const show = next > previous;
    for (let i = Math.min(previous, next); i < Math.max(previous, next); i++) {
      for (const part of state.tokens[i].parts) {
        part.span.classList.toggle(PREFIX + '-show', show);
      }
    }
    state.revealed = next;
    const focusedToken = state.tokens[Math.max(0, next - 1)];
    const focus = lineIndex ??
      (focusedToken?.isCode ? focusedToken.firstLine : focusedToken?.lastLine) ?? 0;
    const movedLine = focus !== state.focusedLine;
    state.focusedLine = focus;
    updateHud();
    if (movedLine) centerLine(focus);
  }

  function nextChunk() {
    const chunk = state.chunks.find(item => item.endToken > state.revealed);
    if (chunk) setRevealed(chunk.endToken);
  }

  function previousChunk() {
    if (!state.revealed) return;
    const chunk = state.chunks.find(item => item.endToken >= state.revealed);
    if (chunk) setRevealed(chunk.startToken);
  }

  function nextLine() {
    if (!state.lines.length || state.revealed >= state.tokens.length) return;
    let target = state.revealed === 0 ? 0 : state.focusedLine;
    if (state.lines[target]?.endToken <= state.revealed) {
      target = state.lines.findIndex((line, index) =>
        index > state.focusedLine && line.endToken > state.revealed);
    }
    if (target < 0 || !state.lines[target]) return;
    setRevealed(state.lines[target].endToken, target);
  }

  function currentSentence() {
    return state.revealed ? state.sentences[state.tokens[state.revealed - 1].sentenceId] : null;
  }

  function composer() {
    return [...document.querySelectorAll('[data-composer-markdown][contenteditable="true"]')]
      .find(editor => editor.isConnected && editor.getClientRects().length &&
        getComputedStyle(editor).visibility !== 'hidden');
  }

  function sentenceText(sentence) {
    return sentence.block.text.slice(sentence.start, sentence.end).trim();
  }

  function normalizedQuoteText(text) {
    return text.replace(/\u00a0/gu, ' ').replace(/\s+/gu, ' ').trim();
  }

  function matchingQuotes(editor, text) {
    const expected = normalizedQuoteText(text);
    return [...editor.children].filter(node =>
      node.tagName === 'BLOCKQUOTE' &&
      normalizedQuoteText([...node.children].map(child => child.textContent).join(' ')) === expected);
  }

  function capturedQuote(editor, capture) {
    const matches = matchingQuotes(editor, capture.text);
    return matches.length === 1 ? matches[0] : null;
  }

  function makeQuote(text) {
    const quote = document.createElement('blockquote');
    for (const line of text.split(/\r?\n/u)) {
      quote.appendChild(el('p', '', line));
    }
    return quote;
  }

  function toggleQuote() {
    const sentence = currentSentence();
    if (!sentence) return;
    const editor = composer();
    if (!editor) {
      toast('ChatGPT 입력창을 찾지 못했어.');
      return;
    }
    const session = state.captureSession;
    const existing = session.get(sentence.id);
    if (existing) {
      const quote = capturedQuote(editor, existing);
      session.delete(sentence.id);
      if (!quote) {
        toast('인용이 수정되거나 옮겨져서 입력창 내용은 그대로 뒀어. 다시 ↑를 누르면 새로 인용해.');
        return;
      }
      if (editor.children.length === 1) quote.replaceWith(document.createElement('p'));
      else quote.remove();
      toast('입력창에서 인용을 제거했어.');
      return;
    }

    const text = sentenceText(sentence);
    if (!text) return;
    const quote = makeQuote(text);
    const entries = [...session.entries()];
    const following = entries.filter(([id]) => id > sentence.id)
      .sort((a, b) => a[0] - b[0])
      .map(([, capture]) => capturedQuote(editor, capture)).find(Boolean);
    const preceding = entries.filter(([id]) => id < sentence.id)
      .sort((a, b) => b[0] - a[0])
      .map(([, capture]) => capturedQuote(editor, capture)).find(Boolean);
    if (following) following.before(quote);
    else if (preceding) preceding.after(quote);
    else if (editor.children.length === 1 && editor.firstElementChild.tagName === 'P' &&
        !editor.textContent.trim()) editor.replaceChildren(quote);
    else editor.appendChild(quote);
    session.set(sentence.id, { text });
    toast('문장 전체를 입력창에 인용했어.');
  }

  function updateHud() {
    if (!state.hud) return;
    const chunkIndex = state.chunks.findIndex(chunk => chunk.endToken >= state.revealed);
    state.hud.textContent = 'Progressive Read · ' +
      (state.revealed ? Math.max(1, chunkIndex + 1) : 0) + '/' + state.chunks.length +
      ' · 줄 ' + (state.focusedLine + 1) + '/' + state.lines.length +
      ' · → 조각  ↓ 줄  ↑ 인용  ← 뒤로  Esc 종료';
  }

  function createUi() {
    state.hud = el('div');
    state.hud.id = PREFIX + '-hud';
    state.hud.tabIndex = -1;
    state.hud.setAttribute('aria-label', 'Progressive Reader 읽기 위치');
    state.side = el('div');
    state.side.id = PREFIX + '-side';
    state.controls = el('div');
    state.controls.id = PREFIX + '-controls';
    for (const [key, label] of [
      ['ArrowLeft', '← 뒤로'], ['ArrowRight', '→ 다음 조각'],
      ['ArrowDown', '↓ 다음 줄'], ['ArrowUp', '↑ 인용']
    ]) {
      const button = el('button', '', label);
      button.type = 'button';
      button.setAttribute('aria-label', label);
      button.addEventListener('click', () => { runReaderAction(key); focusReader(); });
      state.controls.appendChild(button);
    }
    state.side.append(state.controls);
    document.body.append(state.hud, state.side);
    updateHud();
  }

  function installMask(messageId) {
    const selector = '[data-chatgpt-search-message-ids~="' + messageId + '"] [data-markdown-text-style="assistant-message"]';
    const block = selector + ' :is(' + BLOCKS + ')';
    state.markerColors = [...state.root.querySelectorAll('li')].map(item => {
      const property = '--' + PREFIX + '-marker-color';
      const original = item.style.getPropertyValue(property);
      const priority = item.style.getPropertyPriority(property);
      const color = getComputedStyle(item, '::marker').color || getComputedStyle(item).color;
      item.style.setProperty(property, color);
      return { item, property, original, priority };
    });
    const style = el('style');
    style.textContent =
      'body.' + PREFIX + '-active ' + block + ',body.' + PREFIX + '-active ' + block + ' *{' +
      'color:transparent!important;-webkit-text-fill-color:transparent!important;text-shadow:none!important;text-decoration-color:transparent!important}' +
      'body.' + PREFIX + '-active ' + selector + ' li{-webkit-text-fill-color:currentColor!important}' +
      'body.' + PREFIX + '-active ' + selector + ' :is(.' + PREFIX + '-piece,.' + PREFIX + '-gap):not(.' + PREFIX + '-show){' +
      'background-color:rgba(127,127,127,.22)!important;' +
      '-webkit-box-decoration-break:clone;box-decoration-break:clone}' +
      'body.' + PREFIX + '-active ' + selector + ' .' + PREFIX + '-piece.' + PREFIX + '-show{' +
      'color:var(--' + PREFIX + '-color)!important;-webkit-text-fill-color:var(--' + PREFIX + '-color)!important;' +
      'text-decoration-color:var(--' + PREFIX + '-color)!important}' +
      'body.' + PREFIX + '-active ' + selector + ' li::marker{' +
      'color:var(--' + PREFIX + '-marker-color)!important;' +
      '-webkit-text-fill-color:var(--' + PREFIX + '-marker-color)!important}' +
      'body.' + PREFIX + '-active ' + selector + ' a[data-testid="chatgpt-citation"]:has(.' + PREFIX + '-piece:not(.' + PREFIX + '-show)){' +
      'visibility:hidden!important}' +
      'body.' + PREFIX + '-active ' + selector + '{user-select:none!important}';
    document.head.appendChild(style);
    state.maskStyle = style;
    document.body.classList.add(PREFIX + '-active');
  }

  function restoreWrappedText() {
    for (const item of state.originalNodes) {
      const connected = item.inserted.filter(node => node.isConnected);
      const unchanged = connected.length === item.inserted.length &&
        connected.every(node => node.parentNode === item.parent) &&
        connected.map(node => node.textContent).join('') === item.original.nodeValue;
      if (unchanged) {
        connected[0].before(item.original);
        for (const node of connected) node.remove();
      } else {
        // Preserve current app text when React replaced or edited a fragment.
        for (const node of connected) {
          if (node.nodeType === Node.ELEMENT_NODE) node.replaceWith(...node.childNodes);
        }
      }
    }
    state.originalNodes = [];
  }

  function managedTextIntact() {
    const current = collectBlocks(state.root);
    return current.length === state.blocks.length &&
      current.every((block, index) =>
        block.nodes.map(node => node.nodeValue).join('') === state.blocks[index].text) &&
      !hasUncoveredContent(state.root, current) &&
      state.originalNodes.every(item =>
      item.inserted.every(node => node.isConnected) &&
      item.inserted.map(node => node.textContent).join('') === item.original.nodeValue);
  }

  function reconcileContent() {
    state.contentTimer = null;
    if (!state.active) return;
    if (!state.root.isConnected || !state.unit.isConnected || location.href !== state.route) {
      stopReader('답변 화면이 바뀌어서 Reader를 종료했어.');
      return;
    }
    if (managedTextIntact()) return;
    const expected = state.blocks.map(block => block.text);
    const revealed = state.revealed;
    const scrollTop = state.scroller?.scrollTop;
    state.observer.disconnect();
    restoreWrappedText();
    state.maskStyle.remove();
    if (!buildModel(state.root) ||
        state.blocks.length !== expected.length ||
        state.blocks.some((block, index) => block.text !== expected[index]) ||
        hasUncoveredContent(state.root)) {
      stopReader('읽던 답변 내용이 실제로 변경되어 Reader를 종료했어.');
      return;
    }
    wrapTextNodes();
    document.head.appendChild(state.maskStyle);
    if (!rebuildLines()) {
      stopReader('줄 배치를 다시 측정할 수 없어 Reader를 종료했어.');
      return;
    }
    const token = state.tokens[Math.max(0, revealed - 1)];
    state.focusedLine = (token?.isCode ? token.firstLine : token?.lastLine) ?? 0;
    state.revealed = 0;
    setRevealed(revealed);
    if (!revealed) updateHud();
    if (state.scroller && scrollTop != null) state.scroller.scrollTop = scrollTop;
    state.observer.observe(state.root, { childList: true, characterData: true, subtree: true });
  }

  function onContentMutation() {
    if (!state.active) return;
    if (!state.root.isConnected || !state.unit.isConnected || location.href !== state.route) {
      stopReader('답변 화면이 바뀌어서 Reader를 종료했어.');
      return;
    }
    if (managedTextIntact() || state.contentTimer != null) return;
    state.contentTimer = setTimeout(reconcileContent, 60);
  }

  function onResize() {
    if (!state.active || state.resizeFrame) return;
    state.resizeFrame = requestAnimationFrame(() => {
      state.resizeFrame = 0;
      if (!state.active) return;
      if (!state.root.isConnected || !state.unit.isConnected) {
        stopReader('답변이 교체되어 Reader를 종료했어.');
        return;
      }
      if (!rebuildLines()) {
        stopReader('줄 배치를 다시 측정할 수 없어 Reader를 종료했어.');
        return;
      }
      const focusedToken = state.tokens[Math.max(0, state.revealed - 1)];
      state.focusedLine = (focusedToken?.isCode ?
        focusedToken.firstLine : focusedToken?.lastLine) ?? 0;
      centerLine(state.focusedLine);
      updateHud();
    });
  }

  function observeActive() {
    state.observer = new MutationObserver(onContentMutation);
    state.observer.observe(state.root, { childList: true, characterData: true, subtree: true });
    const turn = state.unit.closest('[data-turn-key]') || state.unit;
    state.turnObserver = new MutationObserver(() => {
      if (state.active && (!state.root.isConnected || !state.unit.isConnected)) {
        stopReader('답변이 교체되어 Reader를 종료했어.');
      }
    });
    state.turnObserver.observe(state.unit, { childList: true, subtree: true });
    if (state.unit.parentElement) {
      state.turnObserver.observe(state.unit.parentElement, { childList: true });
    }
    if (turn.parentElement && turn.parentElement !== state.unit.parentElement) {
      state.turnObserver.observe(turn.parentElement, { childList: true });
    }
    state.resizeObserver = new ResizeObserver(onResize);
    state.resizeObserver.observe(state.root);
    if (state.scroller) state.resizeObserver.observe(state.scroller);
    window.addEventListener('resize', onResize);
    state.routeTimer = setInterval(() => {
      if (state.active && (location.href !== state.route || !state.root.isConnected)) {
        stopReader('다른 대화로 이동해 Reader를 종료했어.');
      }
    }, 600);
  }

  function stopReader(message = '') {
    const restoreFocus = document.activeElement === state.hud ? state.previousFocus : null;
    state.active = false;
    state.observer?.disconnect();
    state.turnObserver?.disconnect();
    state.resizeObserver?.disconnect();
    window.removeEventListener('resize', onResize);
    clearInterval(state.routeTimer);
    clearTimeout(state.contentTimer);
    cancelAnimationFrame(state.resizeFrame);
    restoreWrappedText();
    for (const marker of state.markerColors) {
      if (marker.original) marker.item.style.setProperty(marker.property, marker.original, marker.priority);
      else marker.item.style.removeProperty(marker.property);
    }
    document.body.classList.remove(PREFIX + '-active');
    state.maskStyle?.remove();
    state.hud?.remove();
    state.side?.remove();
    Object.assign(state, {
      root: null, unit: null, scroller: null, blocks: [], tokens: [],
      chunks: [], sentences: [], lines: [], originalNodes: [], revealed: 0,
      focusedLine: 0, observer: null, turnObserver: null,
      resizeObserver: null, routeTimer: null, resizeFrame: 0, contentTimer: null,
      maskStyle: null, hud: null, side: null, controls: null,
      captureSession: null, messageId: '',
      previousFocus: null,
      markerColors: []
    });
    if (restoreFocus?.isConnected) restoreFocus.focus({ preventScroll: true });
    if (message) toast(message);
  }

  function startReader() {
    if (state.active) return;
    const target = findTarget();
    if (!target) { toast('현재 대화에서 답변 본문을 찾지 못했어.'); return; }
    if (!target.finished) { toast('최신 답변 생성이 끝난 뒤 다시 켜줘.'); return; }
    if (!/^[a-f0-9-]{16,}$/iu.test(target.messageId)) {
      toast('답변의 안정적인 식별자를 찾지 못했어.'); return;
    }
    const scroller = findScroller(target.root);
    state.root = target.root;
    state.unit = target.unit;
    state.scroller = scroller;
    state.route = location.href;
    if (!buildModel(target.root)) {
      stopReader('읽을 문장을 찾지 못했어.'); return;
    }
    if (hasUncoveredContent(target.root)) {
      stopReader('가림을 지원하지 않는 본문 요소(이미지 등)가 있어 Reader를 켜지 못했어.'); return;
    }
    state.messageId = target.messageId;
    if (!captureSessions.has(target.messageId)) captureSessions.set(target.messageId, new Map());
    state.captureSession = captureSessions.get(target.messageId);
    installMask(target.messageId);
    wrapTextNodes();
    if (!rebuildLines()) {
      stopReader('렌더링된 줄을 측정하지 못했어.'); return;
    }
    state.active = true;
    state.previousFocus = document.activeElement;
    createUi();
    observeActive();
    state.focusedLine = 0;
    centerLine(0);
    focusReader();
    if (DEBUG) console.info('[Progressive Reader]', debugState());
  }

  function isEditable(target) {
    return !!target?.closest?.('input,textarea,[contenteditable="true"],[role="textbox"]');
  }

  function focusReader() {
    if (state.active && state.hud?.isConnected) {
      state.hud.focus({ preventScroll: true });
    }
  }

  function runReaderAction(key) {
    if (!state.active) return;
    const actions = {
      ArrowRight: nextChunk, ArrowLeft: previousChunk,
      ArrowDown: nextLine, ArrowUp: toggleQuote
    };
    actions[key]?.();
  }

  function onKeyDown(event) {
    const launcher = event.metaKey && event.shiftKey && !event.ctrlKey &&
      !event.altKey && event.code === 'Digit9';
    if (launcher) {
      event.preventDefault(); event.stopPropagation();
      state.active ? stopReader() : startReader();
      return;
    }
    if (!state.active) return;
    if (event.key === 'Escape') {
      event.preventDefault(); event.stopPropagation(); stopReader(); return;
    }
    if (isEditable(event.target)) return;
    if (/^Arrow(?:Right|Left|Down|Up)$/u.test(event.key) &&
        !event.metaKey && !event.ctrlKey && !event.altKey) {
      event.preventDefault(); event.stopPropagation(); runReaderAction(event.key);
    }
  }

  function debugState() {
    const scroller = state.scroller;
    return {
      active: state.active,
      assistantTurns: assistantUnits().length,
      target: state.unit?.getAttribute('data-content-search-unit-key') || null,
      contentRoot: state.root?.getAttribute('data-markdown-text-style') || null,
      proseBlocks: state.blocks.length,
      chunks: state.chunks.length,
      scrollContainer: scroller?.className || null,
      scrollTop: scroller?.scrollTop ?? null,
      scrollHeight: scroller?.scrollHeight ?? null,
      clientHeight: scroller?.clientHeight ?? null,
      visualLine: state.focusedLine,
      revealUnit: state.revealed,
      totalUnits: state.tokens.length,
      currentLineEnd: state.lines[state.focusedLine]?.endToken ?? null,
      codeChunk: state.chunks.findIndex(chunk => state.tokens[chunk.startToken]?.isCode)
    };
  }

  window.__cprDebug = debugState;
  function ensureLauncher() {
    if (!document.body) return;
    installUiStyle();
    if (document.getElementById(PREFIX + '-launcher')) return;
    const launcher = el('button', '', 'Progressive Read · 2.3.2');
    launcher.id = PREFIX + '-launcher';
    launcher.type = 'button';
    launcher.setAttribute('aria-label', 'Progressive Read 2.3.2');
    Object.assign(launcher.style, {
      position: 'fixed', right: '18px', bottom: '18px', zIndex: '2147483000',
      border: '1px solid rgba(128,128,128,.5)', borderRadius: '999px',
      padding: '8px 12px', background: '#202020', color: '#fff',
      font: '600 12px system-ui', cursor: 'pointer'
    });
    launcher.addEventListener('click', () => state.active ? stopReader() : startReader());
    document.body.appendChild(launcher);
  }
  ensureLauncher();
  document.addEventListener('keydown', onKeyDown, true);
  setInterval(ensureLauncher, 1500);
})();
