#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'json'
require 'base64'

output = File.expand_path(ARGV.fetch(0))
runs = Dir.glob(File.join(output, '*', 'results.json')).sort.map do |path|
  result = JSON.parse(File.read(path))
  result.fetch('cases').each do |item|
    abort "Incomplete evidence: #{path}: #{item['image']}" unless item.fetch('coverage').fetch('complete') && item.fetch('imageWritten')
    item['imageData'] = 'data:image/png;base64,' + Base64.strict_encode64(File.binread(File.join(File.dirname(path), item.fetch('image'))))
  end
  result
end
abort 'No native results found' if runs.empty?
data = JSON.generate(runs).gsub('<', '\u003c')
html = <<~HTML
  <!doctype html>
  <!-- SPDX-FileCopyrightText: 2026 the Folio Project; SPDX-License-Identifier: MIT -->
  <html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
  <title>Folio · Paragraph composition</title>
  <style>
  body{margin:0;background:#f5f3ed;color:#252720;font:16px system-ui}main{max-width:1100px;margin:auto;padding:32px}
  h1{font:36px Georgia;margin:0 0 12px}p{line-height:1.55;max-width:850px}.controls{display:flex;gap:16px;flex-wrap:wrap;margin:24px 0}
  label{display:grid;gap:6px;font-size:13px}select{font:15px system-ui;padding:8px;border:1px solid #a6aa9e;border-radius:6px;background:white}
  .pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}article{background:white;padding:20px;border:1px solid #ddd;border-radius:8px;overflow:auto}
  img{display:block;max-width:100%;height:auto;margin:auto}h2{font-size:18px;margin:0 0 10px}.note{font-size:13px;color:#4c5548;line-height:1.5}
  pre{white-space:pre-wrap;font-size:12px;line-height:1.4}details{margin-top:16px}summary{cursor:pointer}.badge{color:#45643c}footer{margin-top:30px;font-size:13px}
  @media(max-width:760px){.pair{grid-template-columns:1fr}main{padding:20px}}
  </style>
  <main><h1>Paragraph composition</h1><p>Four passages from <i>Summa Theologiae</i>, I, question 1. Compare native line breaks and typographic color at matched font sizes and measures. This is a development experiment for Folio #22.</p>
  <p class="note">Core Text uses its default framesetter behavior in both hyphenation views. The on/off control applies to TextKit 2. Space advances are diagnostic measurements, not a quality score. Font fallback can be inspected directly only in the Core Text records.</p>
  <div class="controls"><label>Font<select id="font"></select></label><label>Passage<select id="passage"></select></label><label>Measure<select id="measure"><option>240</option><option>300</option><option>360</option></select></label><label>TextKit 2 hyphenation<select id="hyphen"><option value="false">Off</option><option value="true">On</option></select></label></div>
  <p id="context" class="note"></p><div class="pair" id="pair"></div><footer id="environment"></footer>
  <details><summary>Experiment limits</summary><p>These pages cannot establish a particular private algorithm, global optimum, editable custom-fragment integration, coordinated Streams or whole-page behavior. Review loose/tight lines, rivers, consecutive hyphens and short final lines. Each specimen preserves a complete source answer paragraph; whitespace is normalized. See the fixture provenance.</p></details></main>
  <script>
  const runs=#{data};
  const byId=id=>document.getElementById(id);
  runs.forEach((run,i)=>byId('font').add(new Option(run.font.actualPostScriptName,i)));
  [...new Set(runs[0].cases.map(c=>c.specimenId))].forEach(id=>byId('passage').add(new Option(id,id)));
  function render(){
    const run=runs[Number(byId('font').value)], specimen=byId('passage').value;
    const cases=run.cases.filter(c=>c.specimenId===specimen && c.measurePoints===Number(byId('measure').value) && c.requestedHyphenation===(byId('hyphen').value==='true'));
    byId('pair').replaceChildren();
    cases.forEach(c=>{
      const article=document.createElement('article'), title=document.createElement('h2'), note=document.createElement('p'), img=document.createElement('img');
      title.textContent=c.engine==='textkit2'?'TextKit 2':'Core Text';
      note.className='note badge';note.textContent=c.lines.length+' lines · complete coverage · '+(c.engine==='textkit2'?'hyphenation '+(c.requestedHyphenation?'on':'off'):'default framesetter');
      img.src=c.imageData;img.alt=title.textContent+' rendering of '+specimen;img.style.width=c.imageSizePoints[0]+'px';
      const detail=document.createElement('details'), summary=document.createElement('summary'), pre=document.createElement('pre');
      summary.textContent='Line breaks, space advances and controls';
      pre.textContent=JSON.stringify({controls:c.effectiveControls,limitations:c.unsupportedMeasurements,lines:c.lines},null,2);
      detail.append(summary,pre);article.append(title,note,img,detail);byId('pair').append(article);
    });
    byId('context').textContent=cases[0].locator+' · '+cases[0].language+' · 12 pt · '+run.font.metadata.version;
    byId('environment').textContent=run.environment.osVersion+' · '+run.environment.machine+' · SDK '+run.environment.sdkVersion+' · rendered at 2×';
  }
  ['font','passage','measure','hyphen'].forEach(id=>byId(id).addEventListener('change',render));render();
  </script></html>
HTML
File.write(File.join(output, 'comparison.html'), html)
puts "Comparison: #{File.join(output, 'comparison.html')}"
