import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const html=fs.readFileSync(new URL('../pocket_progressive_reader_hardware_lab_v4.html',import.meta.url),'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];new vm.Script(script);
const calls=[];
const ctx={font:'22px sans-serif',save(){this.previous=this.font},restore(){this.font=this.previous},measureText(text){const size=parseFloat(this.font);let width=0;for(const c of text)width+=size*(c===' '?.28:/[A-Za-z0-9]/.test(c)?.52:.98);return {width,actualBoundingBoxLeft:text.startsWith('j')?size*.06:0,actualBoundingBoxRight:width}},fillText(...a){calls.push(a)},clearRect(){calls.length=0},fillRect(){}};
const field=value=>({value,checked:false});
const ui={source:field(''),sourceFormat:field('text'),fontSize:field(22),padding:field(14),lineGap:field(6),alignment:field('left'),anchorX:field(33),presentation:field('past'),bottomInset:field(4),algorithm:field('balanced'),progress:field(''),debug:field(''),screen:{}};
for(const id of ['sReveal','sSentence','sFill','sFontMm','sActive','sPpi','sPastSlots','sAspect','sourceStatus'])ui[id]={};
let panel={resolution:[480,200],active:[52.42,21.72]};
const state={units:[],sentences:[],index:0,sentenceStarts:[],sentenceEnds:[]};
const context=vm.createContext({ctx,ui,state,hw:()=>({display:panel}),console});
const engine=script.slice(script.indexOf('// INPUT / NORMALIZATION'),script.indexOf('function chargeFloor('));
vm.runInContext(engine+'\nfunction renderAll(){render()}\nthis.api={normalizeInput,sentenceSplit,buildModel,focusY,drawPresentation,move,anchorGeometry,ingestFile};',context);
const {api}=context;
const md='## Attention\n\n**Attention** is limited.\n\n- Future content competes.\n- Past context can help.\n\n[OpenAI](https://openai.com)\n> *quote* with `code`.\n![diagram](https://example.com/a.png)\n<div>HTML words</div>';
const norm=api.normalizeInput(md,'markdown');assert(!/[#*`]|https:\/\//.test(norm));assert(norm.includes('Attention\n\nAttention is limited.'));assert(norm.includes('Future content competes.\nPast context can help.'));assert(norm.includes('quote with code.'));assert(norm.includes('HTML words'));
assert.equal(api.normalizeInput('[site](https://example.com/a_(b)) and ![alt](https://example.com/i_(c).png)','markdown'),'site and alt');
assert.equal(api.normalizeInput('<script>alert(1)</script><a href="https://example.com">label</a>','markdown'),'label');
// A deliberately nonlinear font fixture catches proportional-scale-only overflow.
const originalMeasure=ctx.measureText;
ctx.measureText=function(text){const size=parseFloat(this.font),metric=originalMeasure.call(this,text),factor=size<15?1.4:1;return {width:metric.width*factor,actualBoundingBoxLeft:metric.actualBoundingBoxLeft*factor,actualBoundingBoxRight:metric.actualBoundingBoxRight*factor}};
ui.alignment.value='anchor';ui.anchorX.value=20;ui.source.value='🧑🏽‍🚀'.repeat(100);api.buildModel();assert.equal(state.units.length,1);assert(state.units[0].scaled);assert(state.units[0].fits);assert(state.units[0].left>=14-.011);assert(state.units[0].right<=panel.resolution[0]-14+.011);
ctx.measureText=originalMeasure;
assert.deepEqual(Array.from(api.sentenceSplit('첫 문장이다. 다음 문장이다!\n제목\n목록 항목')),['첫 문장이다.','다음 문장이다!','제목','목록 항목']);
assert.deepEqual(Array.from(api.sentenceSplit('3.14라는 숫자. 다음이다.')),['3.14라는 숫자.','다음이다.']);
assert.equal(api.normalizeInput('문장은 *기울임*이며 **굵음**이다.','markdown'),'문장은 기울임이며 굵음이다.');
const text='첫 어절은 여기, 이어지는 긴어절도 중요하다. 짧은 말. jiffy italic first words move carefully. '+ '아주긴한어절'.repeat(100);
for(const resolution of [[320,170],[400,240],[480,200],[284,76],[310,100],[320,240]])for(const alignment of ['left','anchor'])for(const anchor of [20,33,50])for(const algorithm of ['balanced','greedy','eojeol']){
  panel={resolution,active:[52,22]};ui.alignment.value=alignment;ui.anchorX.value=anchor;ui.algorithm.value=algorithm;ui.source.value=text;api.buildModel();
  assert.equal(state.units.map(u=>u.text).join(' '),text);
  for(const unit of state.units){assert(unit.left>=14-.011);assert(unit.right<=resolution[0]-14+.011);if(alignment==='anchor')assert(Math.abs(unit.firstCenter-unit.anchor)<1e-7);assert(unit.text.length>0)}
  assert(state.units.at(-1).scaled);assert.equal(state.units.at(-1).words,1);
}
ui.source.value='처음에 여러 단어가 나온다. 다음에 다시 여러 단어가 나온다.';ui.presentation.value='current';api.buildModel();assert.equal(api.focusY(),panel.resolution[1]/2);calls.length=0;api.drawPresentation();assert.equal(calls.length,1);
ui.presentation.value='past';const y=api.focusY();ui.progress.checked=true;assert.equal(api.focusY(),y);ui.progress.checked=false;api.move(1);assert.equal(api.focusY(),y);api.move(-1);assert.equal(state.index,0);
api.move(state.units.length);const sentenceStart=state.sentenceStarts[state.units[state.index].sentenceIndex];state.index=sentenceStart;ui.presentation.value='sentence';calls.length=0;api.drawPresentation();assert.equal(calls.length,1);assert.equal(calls[0][0],state.units[state.index].text);
ui.presentation.value='past';calls.length=0;api.drawPresentation();assert(calls.every(([text])=>state.units.slice(0,state.index+1).some(u=>u.text===text)));
ui.source.value='같은 말 같은 말 같은 말 같은 말 같은 말 같은 말.';api.buildModel();state.index=state.units.length-1;const old=state.units[state.index].documentWordStart;ui.anchorX.value=20;api.buildModel({keep:true});assert(state.units[state.index].documentWordStart<=old);
// A file beyond the former native limit is accepted; test the real ingestion function.
const long='긴 문서의 정상 문장입니다.\n'.repeat(15000);await api.ingestFile({files:[{name:'large.txt',text:async()=>long}],value:'chosen'},'text');assert(ui.source.value.length>200000);assert.equal(state.sentences.length,15000);
assert(/textarea\{height:180px;min-height:180px;overflow-y:auto/.test(html));assert(html.includes('textarea{resize:none}'));assert(html.includes('id="loadMdBtn"'));assert(!script.includes('maxLength'));
console.log('PASS: normalization, sentence boundaries, 108 preset/alignment/chunk combinations, indivisible long eojeol, fixed baseline, past/no-future/regression, source anchor preservation, large file ingestion, editor CSS. Canvas metrics are a deterministic test fixture; browser pixel rendering requires separate verification.');
