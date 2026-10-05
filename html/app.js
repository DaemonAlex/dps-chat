// dps-chat NUI: a fixed command box. Suggestions narrow as you type; history with up/down.
(() => {
  const box = document.getElementById('box'), input = document.getElementById('in'), sug = document.getElementById('sug');
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'dps-chat';
  let commands = [], shown = [], sel = -1, history = [], hpos = -1;
  try { history = JSON.parse(localStorage.getItem('dpsChatHistory') || '[]'); } catch (e) { history = []; }
  const post = (n, d) => fetch(`https://${RES}/${n}`, { method: 'POST', body: JSON.stringify(d || {}) }).catch(() => {});
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  function render() {
    const v = input.value.trim().replace(/^\//, '').toLowerCase();
    const word = v.split(/\s+/)[0] || '';
    shown = word === '' ? [] : commands.filter((c) => c.name.startsWith(word)).slice(0, 8);
    if (sel >= shown.length) sel = shown.length - 1;
    sug.innerHTML = shown.map((c, i) => {
      const params = (c.params || []).map((p) => `[${esc(p.name || '')}]`).join(' ');
      return `<li class="${i === sel ? 'on' : ''}" role="option"><span class="n">/${esc(c.name)}</span><span class="p">${params}</span><span class="h">${esc(c.help || '')}</span></li>`;
    }).join('');
  }
  let editing = false, drag = null;
  // a saved spot is { x, y } in percent of the screen (top-left corner of the box)
  function place(pos) {
    if (!pos || typeof pos.x !== 'number' || typeof pos.y !== 'number') { box.style.left = box.style.top = box.style.right = box.style.bottom = ''; return; }
    box.style.right = 'auto'; box.style.bottom = 'auto'; box.style.left = pos.x + '%'; box.style.top = pos.y + '%';
  }
  function openBox(list, pos) { place(pos); commands = list || []; input.value = '/'; sel = -1; hpos = -1; box.hidden = false; render(); grabFocus(); }
  // the page only gets keyboard focus a moment after the game hands it over: keep asking briefly
  function grabFocus() { let n = 0; const t = setInterval(() => { window.focus(); input.focus(); const end = input.value.length; input.setSelectionRange(end, end); if (document.activeElement === input && ++n > 2) clearInterval(t); if (n > 20) clearInterval(t); n++; }, 50); }
  function startEdit(pos) {
    place(pos); editing = true; box.classList.add('edit'); box.hidden = false; sug.innerHTML = '';
    input.value = 'Drag me. Enter saves, Esc cancels, R resets';
  }
  function endEdit(save) {
    editing = false; box.classList.remove('edit');
    const r = box.getBoundingClientRect();
    const pos = save ? { x: +(r.left / innerWidth * 100).toFixed(2), y: +(r.top / innerHeight * 100).toFixed(2) } : null;
    post('editDone', { save: !!save, pos: pos }); closeBox();
  }
  box.addEventListener('mousedown', (e) => { if (!editing) { input.focus(); return; } const r = box.getBoundingClientRect(); drag = { dx: e.clientX - r.left, dy: e.clientY - r.top }; e.preventDefault(); });
  window.addEventListener('mousemove', (e) => {
    if (!drag) return;
    const w = box.offsetWidth, h = box.offsetHeight;
    const x = Math.min(Math.max(0, e.clientX - drag.dx), innerWidth - w), y = Math.min(Math.max(0, e.clientY - drag.dy), innerHeight - h);
    place({ x: x / innerWidth * 100, y: y / innerHeight * 100 });
  });
  window.addEventListener('mouseup', () => { drag = null; });
  window.addEventListener('keydown', (e) => {
    if (!editing) return;
    if (e.key === 'Enter') endEdit(true);
    else if (e.key === 'Escape') endEdit(false);
    else if (e.key === 'r' || e.key === 'R') { post('editDone', { save: false, reset: true }); editing = false; box.classList.remove('edit'); place(null); closeBox(); }
  });
  function closeBox() { box.hidden = true; input.value = ''; sug.innerHTML = ''; }

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') openBox(d.commands, d.pos);
    else if (d.action === 'edit') startEdit(d.pos);
    else if (d.action === 'commands') { commands = d.commands || commands; render(); }
    else if (d.action === 'close') closeBox();
    else if (d.action === 'bubbles') drawBubbles(d.list || []);
    else if (d.action === 'ring') { ringOn = !!d.on; if (!ringEditing) ring.hidden = !ringOn; }
    else if (d.action === 'ringpos') placeRing(d.pos);
    else if (d.action === 'ringedit') startRingEdit();
  });
  input.addEventListener('input', () => { sel = -1; render(); });
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { e.preventDefault(); post('close'); closeBox(); return; }
    if (e.key === 'Enter') {
      e.preventDefault();
      let text = input.value.trim();
      if (sel >= 0 && shown[sel]) text = '/' + shown[sel].name;
      if (text && text !== '/') { history = [text].concat(history.filter((h) => h !== text)).slice(0, 30); try { localStorage.setItem('dpsChatHistory', JSON.stringify(history)); } catch (er) {} }
      post('run', { text }); closeBox(); return;
    }
    if (e.key === 'Tab') { e.preventDefault(); const c = shown[sel >= 0 ? sel : 0]; if (c) { input.value = '/' + c.name + ' '; sel = -1; render(); } return; }
    if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
      e.preventDefault();
      const up = e.key === 'ArrowUp';
      if (shown.length && (sel >= 0 || input.value.trim().length > 1)) { sel = up ? Math.max(0, sel - 1) : Math.min(shown.length - 1, sel + 1); render(); return; }
      if (!history.length) return;
      hpos = up ? Math.min(history.length - 1, hpos + 1) : Math.max(-1, hpos - 1);
      input.value = hpos >= 0 ? history[hpos] : '/'; render();
    }
  });
  // bubbles: the client sends every visible line with its screen spot each frame; elements are reused by id
  const layer = document.getElementById('bubbles'), live = new Map();
  const TAG = { me: 'ME', do: 'DO', try: 'TRY', npc: 'NPC', info: 'INFO' };
  function drawBubbles(list) {
    const seen = new Set();
    for (const b of list) {
      seen.add(b.id);
      let el = live.get(b.id);
      if (!el) {
        el = document.createElement('div');
        const kind = TAG[b.kind] ? b.kind : 'me';
        el.className = 'bub ' + kind + (kind === 'try' ? (b.ok ? ' ok' : ' no') : '');
        el.innerHTML = '<span class="tag">' + esc(b.tag || TAG[kind]) + '</span><span class="txt">' + esc(b.text) + '</span>' + (kind === 'try' ? '<span class="res">' + (b.ok ? 'SUCCESS' : 'FAIL') + '</span>' : '');
        layer.appendChild(el); live.set(b.id, el);
      }
      el.style.left = (b.x * 100) + '%'; el.style.top = (b.y * 100) + '%'; el.style.opacity = b.a;
    }
    for (const [id, el] of live) if (!seen.has(id)) { el.remove(); live.delete(id); }
  }
  // the minimap ring: one spot for everyone, set by an admin with /mapring (drag, arrows nudge, Enter saves)
  const ring = document.getElementById('mapring'), ringHelp = document.getElementById('ringhelp');
  let ringOn = false, ringEditing = false, ringDrag = null, ringBefore = null;
  function placeRing(pos) {
    if (!pos || typeof pos.x !== 'number' || typeof pos.y !== 'number') { ring.style.left = ring.style.top = ring.style.right = ''; return; }
    ring.style.right = 'auto'; ring.style.left = pos.x + '%'; ring.style.top = pos.y + '%';
  }
  function ringPos() { const r = ring.getBoundingClientRect(); return { x: +(r.left / innerWidth * 100).toFixed(3), y: +(r.top / innerHeight * 100).toFixed(3) }; }
  function startRingEdit() { ringBefore = ringPos(); ringEditing = true; ring.hidden = false; ring.classList.add('edit'); ringHelp.hidden = false; placeRing(ringBefore); }
  function endRingEdit(save, reset) {
    ringEditing = false; ring.classList.remove('edit'); ringHelp.hidden = true; ring.hidden = !ringOn;
    if (reset) placeRing(null); else if (!save) placeRing(ringBefore);
    post('ringDone', { save: !!save, reset: !!reset, pos: save ? ringPos() : null });
  }
  ring.addEventListener('mousedown', (e) => { if (!ringEditing) return; const r = ring.getBoundingClientRect(); ringDrag = { dx: e.clientX - r.left, dy: e.clientY - r.top }; e.preventDefault(); });
  window.addEventListener('mousemove', (e) => { if (!ringDrag) return; placeRing({ x: (e.clientX - ringDrag.dx) / innerWidth * 100, y: (e.clientY - ringDrag.dy) / innerHeight * 100 }); });
  window.addEventListener('mouseup', () => { ringDrag = null; });
  window.addEventListener('keydown', (e) => {
    if (!ringEditing) return;
    const p = ringPos(), sx = 100 / innerWidth, sy = 100 / innerHeight;
    if (e.key === 'Enter') endRingEdit(true);
    else if (e.key === 'Escape') endRingEdit(false);
    else if (e.key === 'r' || e.key === 'R') endRingEdit(false, true);
    else if (e.key === 'ArrowLeft') placeRing({ x: p.x - sx, y: p.y });
    else if (e.key === 'ArrowRight') placeRing({ x: p.x + sx, y: p.y });
    else if (e.key === 'ArrowUp') placeRing({ x: p.x, y: p.y - sy });
    else if (e.key === 'ArrowDown') placeRing({ x: p.x, y: p.y + sy });
    else return;
    e.preventDefault();
  });
})();
