import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const html=fs.readFileSync(new URL('../pocket_progressive_reader_hardware_lab_v4.html',import.meta.url),'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];new vm.Script(script);
const calls=[], inks=[];
const stack=[], decorations=[];
const ctx={font:'22px sans-serif',globalAlpha:1,fillStyle:'#171717',save(){stack.push({font:this.font,globalAlpha:this.globalAlpha,fillStyle:this.fillStyle})},restore(){Object.assign(this,stack.pop())},measureText(text){const size=parseFloat(this.font);let width=0;for(const c of text)width+=size*(c===' '?.28:/[A-Za-z0-9]/.test(c)?.52:.98);return {width,actualBoundingBoxLeft:text.startsWith('j')?size*.06:0,actualBoundingBoxRight:width}},fillText(...a){calls.push(a);inks.push([this.globalAlpha,this.fillStyle])},strokeText(...a){decorations.push(['stroke',...a])},clearRect(){calls.length=0;decorations.length=0},fillRect(...a){decorations.push(['rect',...a])},beginPath(){},rect(...a){decorations.push(['clip',...a])},clip(){}};
const field=value=>({value,checked:false});
const ui={source:field(''),sourceFormat:field('text'),fontSize:field(22),padding:field(14),lineGap:field(6),focusStyle:field('yellow'),minimumFocusLength:field(1),presentation:field('past'),scrollMargin:field(0),bottomInset:field(4),algorithm:field('balanced'),progress:field(''),debug:field(''),screen:{}};
for(const id of ['sReveal','sSentence','sFill','sFontMm','sActive','sPpi','sPastSlots','sAspect','sourceStatus'])ui[id]={};
let panel={resolution:[480,200],active:[52.42,21.72]};
const state={viewportEnd:0,units:[],sentences:[],index:0,sentenceStarts:[],sentenceEnds:[],focusedToken:null,wheelAccum:0};
const context=vm.createContext({ctx,ui,state,hw:()=>({display:panel}),console,Intl});
const engine=script.slice(script.indexOf('// INPUT / NORMALIZATION'),script.indexOf('function chargeFloor('));
vm.runInContext(engine+'\nfunction renderAll(){render()}\nthis.api={normalizeInput,sentenceSplit,buildModel,focusY,drawPresentation,move,sentenceMove,focusMove,wheelDelta,reset,lineGeometry,ingestFile,contextMargin,pastCapacity,updateViewport,makeFocusGroups,contentLength,regroupFocus,currentFocusGroup};',context);
const {api}=context;
const md='## Attention\n\n**Attention** is limited.\n\n- Future content competes.\n- Past context can help.\n\n[OpenAI](https://openai.com)\n> *quote* with `code`.\n![diagram](https://example.com/a.png)\n<div>HTML words</div>';
const norm=api.normalizeInput(md,'markdown');assert(!/[#*`]|https:\/\//.test(norm));assert(norm.includes('Attention\n\nAttention is limited.'));assert(norm.includes('Future content competes.\nPast context can help.'));assert(norm.includes('quote with code.'));assert(norm.includes('HTML words'));
assert.equal(api.normalizeInput('[site](https://example.com/a_(b)) and ![alt](https://example.com/i_(c).png)','markdown'),'site and alt');
assert.equal(api.normalizeInput('<script>alert(1)</script><a href="https://example.com">label</a>','markdown'),'label');
// A deliberately nonlinear font fixture catches proportional-scale-only overflow.
const originalMeasure=ctx.measureText;
ctx.measureText=function(text){const size=parseFloat(this.font),metric=originalMeasure.call(this,text),factor=size<15?1.4:1;return {width:metric.width*factor,actualBoundingBoxLeft:metric.actualBoundingBoxLeft*factor,actualBoundingBoxRight:metric.actualBoundingBoxRight*factor}};
ui.source.value='🧑🏽‍🚀'.repeat(100);api.buildModel();assert.equal(state.units.length,1);assert(state.units[0].scaled);assert(state.units[0].fits);assert(state.units[0].left>=14-.011);assert(state.units[0].right<=panel.resolution[0]-14+.011);
ctx.measureText=originalMeasure;
assert.deepEqual(Array.from(api.sentenceSplit('첫 문장이다. 다음 문장이다!\n제목\n목록 항목')),['첫 문장이다.','다음 문장이다!','제목','목록 항목']);
assert.deepEqual(Array.from(api.sentenceSplit('3.14라는 숫자. 다음이다.')),['3.14라는 숫자.','다음이다.']);
assert.equal(api.normalizeInput('문장은 *기울임*이며 **굵음**이다.','markdown'),'문장은 기울임이며 굵음이다.');
const text='첫 어절은 여기, 이어지는 긴어절도 중요하다. 짧은 말. jiffy italic first words move carefully. '+ '아주긴한어절'.repeat(100);
for(const resolution of [[320,170],[400,240],[480,200],[284,76],[310,100],[320,240]])for(const algorithm of ['balanced','greedy','eojeol']){
  panel={resolution,active:[52,22]};ui.algorithm.value=algorithm;ui.source.value=text;api.buildModel();
  assert.equal(state.units.map(u=>u.text).join(' '),text);
  let documentIndex=0;
  for(const unit of state.units){
    assert(unit.left>=14-.011);assert(unit.right<=resolution[0]-14+.011);assert(unit.text.length>0);
    for(const token of unit.tokens){assert.equal(token.documentIndex,documentIndex++);assert.equal(state.document.slice(token.sourceStart,token.sourceEnd),token.text);assert.equal(unit.text.slice(token.renderStart,token.renderEnd),token.text);assert.equal(token.x,ctx.measureText(unit.text.slice(0,token.renderStart)).width)}
  }
  assert(state.units.at(-1).scaled);assert.equal(state.units.at(-1).words,1);
}
ui.source.value='처음에 여러 단어가 나온다. 다음에 다시 여러 단어가 나온다.';ui.presentation.value='current';api.buildModel();assert.equal(api.focusY(),panel.resolution[1]/2);calls.length=0;api.drawPresentation();assert.equal(calls.length,1);
ui.presentation.value='past';const y=api.focusY();ui.progress.checked=true;assert.equal(api.focusY(),y);ui.progress.checked=false;api.move(1);assert.equal(api.focusY(),y);api.move(-1);assert.equal(state.index,0);
api.move(state.units.length);ui.presentation.value='past';calls.length=0;api.drawPresentation();assert(calls.every(([text])=>state.units.slice(0,state.index+1).some(u=>u.text===text)));
ui.source.value='같은 말 같은 말 같은 말 같은 말 같은 말 같은 말.';api.buildModel();state.index=state.units.length-1;const old=state.units[state.index].documentWordStart;ui.fontSize.value=24;api.buildModel({keep:true});assert(state.units[state.index].documentWordStart<=old);
// Fine navigation activates implicitly and walks original tokens in both directions.
panel={resolution:[320,170],active:[52,22]};ui.fontSize.value=22;ui.algorithm.value='balanced';ui.presentation.value='current';ui.source.value='나는 오늘 작은 리더기를 직접 만들어 보기로 했다. 다음 문장에서도 한 어절씩 읽는다.';api.buildModel();
assert.equal(state.focusedToken,null);api.focusMove(1);assert.equal(state.index,0);assert.equal(state.focusedToken,0);
const firstLength=state.units[0].tokens.length;
for(let i=1;i<firstLength;i++){api.focusMove(1);assert.equal(state.index,0);assert.equal(state.focusedToken,i)}
api.focusMove(1);assert.equal(state.index,1);assert.equal(state.focusedToken,0);api.focusMove(-1);assert.equal(state.index,0);assert.equal(state.focusedToken,firstLength-1);
api.reset();api.focusMove(-1);assert.equal(state.index,0);assert.equal(state.focusedToken,firstLength-1);
state.focusedToken=0;api.focusMove(-1);assert.equal(state.index,0);assert.equal(state.focusedToken,0);
state.index=state.units.length-1;state.focusedToken=state.units.at(-1).tokens.length-1;api.focusMove(1);assert.equal(state.index,state.units.length-1);assert.equal(state.focusedToken,state.units.at(-1).tokens.length-1);
api.move(1);assert.equal(state.focusedToken,null);api.focusMove(1);api.sentenceMove(1);assert.equal(state.focusedToken,null);
api.focusMove(1);api.buildModel({keep:true});assert.equal(state.focusedToken,null);api.focusMove(1);api.reset();assert.equal(state.focusedToken,null);
api.wheelDelta(49);assert.equal(state.focusedToken,null);api.wheelDelta(1);assert.equal(state.focusedToken,0);api.wheelDelta(100);
const allTokens=state.units.flatMap(u=>u.tokens);assert.equal(state.units[state.index].tokens[state.focusedToken].documentIndex,2);
api.reset();let seen=[];for(let i=0;i<allTokens.length;i++){api.focusMove(1);seen.push(state.units[state.index].tokens[state.focusedToken].documentIndex)}assert.deepEqual(seen,Array.from(allTokens,t=>t.documentIndex));
// Fine reverse traversal keeps existing rows stationary until the top boundary.
ui.presentation.value='past';api.move(state.units.length);const end=state.viewportEnd;state.focusedToken=0;calls.length=0;api.drawPresentation();const before=new Map(calls.map(([text,x,y])=>[text,y]));api.focusMove(-1);assert.equal(state.viewportEnd,end);calls.length=0;api.drawPresentation();for(const [text,x,y]of calls)assert.equal(y,before.get(text));
while(state.index>=Math.max(0,end-Math.floor((api.focusY()-22*.7)/(22*1.28+6)))&&state.index>0){state.focusedToken=0;api.focusMove(-1)}
if(state.index>0)assert(state.viewportEnd<end);
api.move(0);assert.equal(state.viewportEnd,state.index);assert.equal(state.focusedToken,null);
// Accumulated context shares the normal ink and opacity.
assert(!script.includes('alpha:[.56'));assert(!html.includes('value="sentence"'));assert(html.includes('value="horizontal"'));assert(html.includes('value="full"'));
// Every focus/style uses the same full-line drawing coordinates and original font.
ui.presentation.value='current';api.reset();const normalY=api.focusY(),normalOrigin=state.units[0].origin,normalFont=state.units[0].fontSize;
for(const style of ['yellow','color','underline','dim','bold'])for(let focused=0;focused<state.units[0].tokens.length;focused++){
  ui.focusStyle.value=style;state.focusedToken=focused;calls.length=0;decorations.length=0;api.drawPresentation();
  assert(calls.length>0);for(const [text,x,y]of calls){assert.equal(text,state.units[0].text);assert.equal(x,normalOrigin);assert.equal(y,normalY)}assert.equal(state.units[0].fontSize,normalFont);
  if(style==='bold')assert(!decorations.some(c=>c[0]==='stroke'));if(style==='yellow'||style==='underline'||style==='bold')assert(decorations.some(c=>c[0]==='rect'));
}
// Context Margin uses a stable symmetric safe window, including coarse moves.
ui.source.value=Array.from({length:30},(_,i)=>`Row${i} has ordinary words.`).join(' ');ui.algorithm.value='balanced';ui.fontSize.value=22;panel={resolution:[320,170],active:[52,22]};ui.focusStyle.value='yellow';
for(const mode of ['past','current'])for(const requested of [1,2]){
  ui.presentation.value=mode;ui.scrollMargin.value=requested;api.buildModel();
  const slots=api.pastCapacity(),margin=api.contextMargin();assert.equal(margin,Math.min(requested,Math.floor(slots/2)));
  api.move(10);const initialEnd=state.viewportEnd,initialStart=Math.max(0,initialEnd-slots);
  assert.equal(initialEnd,10+margin);
  // Advance within safe bounds without moving the document rows.
  api.move(-1);assert.equal(state.viewportEnd,initialEnd);api.move(1);assert.equal(state.viewportEnd,initialEnd);
  api.move(1);assert.equal(state.viewportEnd,initialEnd+1);
  const forwardEnd=state.viewportEnd,safeStart=forwardEnd-slots+margin;
  api.move(safeStart-state.index);assert.equal(state.viewportEnd,forwardEnd);
  api.move(-1);assert.equal(state.viewportEnd,forwardEnd-1);
  calls.length=0;inks.length=0;api.drawPresentation();assert(calls.length>1);assert(calls.some(([text])=>state.units.slice(state.index+1).some(u=>u.text===text)));assert(inks.every(([alpha,color])=>alpha===1&&color==='#171717'));
  // Fine movement uses the same threshold in both directions.
  state.index=10;api.updateViewport(true);const fineEnd=state.viewportEnd;state.focusedToken=0;api.focusMove(-1);assert.equal(state.viewportEnd,fineEnd);
  while(state.index>=fineEnd-slots+margin){state.focusedToken=0;api.focusMove(-1)}assert.equal(state.viewportEnd,fineEnd-1);
  api.reset();assert.equal(state.index,0);assert.equal(state.viewportEnd,Math.min(slots,state.units.length-1));
  api.move(state.units.length);assert.equal(state.index,state.units.length-1);assert.equal(state.viewportEnd,state.units.length-1);
}
for(const height of [35,76,100]){
  panel={resolution:[320,height],active:[52,22]};ui.scrollMargin.value=2;ui.presentation.value='current';api.buildModel();assert(api.contextMargin()<=Math.floor(api.pastCapacity()/2));
  for(const target of [0,1,state.units.length-1]){api.move(target-state.index);calls.length=0;api.drawPresentation();assert(calls.length>0);assert(calls.some(([text])=>text===state.units[state.index].text));assert(calls.length<=api.pastCapacity()+1)}
}
ui.scrollMargin.value=0;panel={resolution:[320,170],active:[52,22]};ui.presentation.value='current';api.buildModel();calls.length=0;api.drawPresentation();assert.equal(calls.length,1);assert.equal(api.focusY(),85);

// An opposite partial wheel residual must not delay the next reverse detent.
api.reset();api.focusMove(1);api.focusMove(1);const beforeReverse=state.focusedToken;
api.wheelDelta(49);api.wheelDelta(-50);assert.equal(state.focusedToken,beforeReverse-1);
// Whole-document modes do not scale, truncate, or segment the source.
ui.source.value='첫 문장 전체.\n다음 문장 전체.\n\n세 번째 문단.';ui.algorithm.value='full';api.buildModel();assert.equal(state.units.length,1);assert.equal(state.units[0].text,state.document);assert(!state.units[0].scaled);assert.equal(state.units[0].tokens.length,9);api.focusMove(1);assert.equal(state.focusedToken,0);
ui.algorithm.value='balanced';ui.presentation.value='horizontal';api.buildModel();assert.equal(state.units.length,1);assert.equal(state.units[0].text,state.document);ui.presentation.value='past';
// Focus grouping counts graphemes rather than UTF-16, excluding punctuation/space.
assert.equal(api.contentLength('á!'),1);assert.equal(api.contentLength('🧑🏽‍🚀?!'),1);assert.equal(api.contentLength('한, 글!'),2);assert.equal(api.contentLength('...'),0);
const groupsFor=(words,min,breaks=[])=>Array.from(api.makeFocusGroups(words.map(text=>({text})),min,breaks),g=>[g.start,g.end]);
assert.deepEqual(groupsFor(['I','am','reading'],3),[[0,2],[2,3]]);
assert.deepEqual(groupsFor(['long','a','!'],4),[[0,3]]); // Undersized final tail merges backward, maximum three.
assert.deepEqual(groupsFor(['long','a','b','c'],4),[[0,1],[1,4]]); // Four tokens cannot be merged.
assert.deepEqual(groupsFor(['a','b','c','d'],4),[[0,3],[3,4]]);
assert.deepEqual(groupsFor(['a','b','c','d'],3,[2]),[[0,2],[2,4]]);
assert.deepEqual(groupsFor(['a','!','b'],1),[[0,1],[1,2],[2,3]]);
for(const min of [1,2,3,4]){
  ui.minimumFocusLength.value=min;ui.presentation.value='current';ui.algorithm.value='balanced';ui.source.value='I am reading a short story. A new sentence is here.';api.buildModel();
  const unitTexts=state.units.map(u=>u.text),seen=[];
  for(const unit of state.units){assert.equal(unit.focusGroups[0].start,0);assert.equal(unit.focusGroups.at(-1).end,unit.tokens.length);assert(unit.focusGroups.every(g=>g.end-g.start<=3));for(let i=1;i<unit.focusGroups.length;i++)assert.equal(unit.focusGroups[i-1].end,unit.focusGroups[i].start)}
  const total=state.focusGroups.length;
  for(let i=0;i<total;i++){api.focusMove(1);seen.push(api.currentFocusGroup().globalIndex)}assert.deepEqual(seen,Array.from({length:total},(_,i)=>i));
  for(let i=total-2;i>=0;i--){api.focusMove(-1);assert.equal(api.currentFocusGroup().globalIndex,i)}
  const chosen=state.units[state.index].tokens[state.focusedToken].documentIndex;ui.minimumFocusLength.value=min===4?2:4;api.regroupFocus();const group=api.currentFocusGroup(),unit=state.units[state.index];assert(unit.tokens[group.start].documentIndex<=chosen);assert(unit.tokens[group.end-1].documentIndex>=chosen);assert.deepEqual(state.units.map(u=>u.text),unitTexts);
  ui.focusStyle.value='bold';calls.length=0;decorations.length=0;api.drawPresentation();const rect=decorations.find(d=>d[0]==='rect');assert.equal(rect[1],unit.origin+unit.tokens[group.start].x-3);assert.equal(rect[3],unit.tokens[group.end-1].endX-unit.tokens[group.start].x+6);
}
ui.minimumFocusLength.value=3;ui.algorithm.value='full';ui.presentation.value='past';ui.source.value='I am. A go.\nNext line.';api.buildModel();const sentenceBreaks=[2,4];assert(state.units[0].focusGroups.every(g=>sentenceBreaks.every(b=>!(g.start<b&&g.end>b))));
context.RichReader={mount:options=>options.source,getHardBreaks:()=>[2]};ui.source.value='a b c d';api.buildModel();assert.deepEqual(Array.from(state.units[0].focusGroups,g=>[g.start,g.end]),[[0,2],[2,4]]);delete context.RichReader;
ui.minimumFocusLength.value=1;ui.algorithm.value='balanced';

// A file beyond the former native limit is accepted; test the real ingestion function.
const long='긴 문서의 정상 문장입니다.\n'.repeat(15000);await api.ingestFile({files:[{name:'large.txt',text:async()=>long}],value:'chosen'},'text');assert(ui.source.value.length>200000);assert.equal(state.sentences.length,15000);
assert(/textarea\{height:180px;min-height:180px;overflow-y:auto/.test(html));assert(html.includes('textarea{resize:none}'));assert(html.includes('id="loadMdBtn"'));assert(!script.includes('maxLength'));
assert(!/gaze|anchorX|anchorGeometry|anchorFraction|alignment/iu.test(html));
assert(html.includes('#richScreen .focus-paint-layer{position:absolute'));assert(html.includes('pointer-events:none;z-index:1'));assert(!html.includes('.focused{box-shadow:'));assert(!html.includes('.focused{background:#000'));
assert(/function centerAction\(\)\{\}/.test(script));
console.log('PASS: normalization, 18 panel/chunker combinations, structured original token ranges, oversized eojeol, legacy zero-margin fixed baselines/history/no future, symmetric Context Margin safe windows/coarse and fine traversal/short panels/normal context ink, transient fine focus + bounded continuous traversal + coarse reset, five stationary styles, Unicode focus groups/hard boundaries/three-token cap/reversible precomputed traversal/regroup-position preservation, large file ingestion and fixed editor. Canvas metrics are a deterministic fixture; browser pixel rendering requires separate verification.');
