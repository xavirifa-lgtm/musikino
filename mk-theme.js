/* mk-theme.js — aspecto visual común de Musikino: imágenes, confeti, celebraciones y sonidos. */
(function (root) {
  'use strict';
  const IMG = 'img_mk/';
  const PRIZE_IMG = { linea: 'mk_premio_linea', esquinas: 'mk_premio_esquinas', cuadrado: 'mk_premio_cuadrado', racha: 'mk_premio_racha', experto: 'mk_premio_experto', final: 'mk_premio_final' };
  const MASCOT = { escucha: 'mk_mascota_escucha', celebra: 'mk_mascota_celebra', fallo: 'mk_mascota_fallo' };
  const prize = p => IMG + (PRIZE_IMG[p] || 'mk_premio_final') + '.png';
  const mascot = m => IMG + (MASCOT[m] || MASCOT.escucha) + '.png';

  const CSS = `
  @keyframes mkBob { 0%,100% { transform: translateY(0) rotate(-2deg) } 50% { transform: translateY(-8px) rotate(2deg) } }
  @keyframes mkSpin { to { transform: rotate(360deg) } }
  @keyframes mkPop { 0% { transform: scale(.2) rotate(-12deg); opacity: 0 } 60% { transform: scale(1.12) rotate(4deg); opacity: 1 } 100% { transform: scale(1) rotate(0) } }
  @keyframes mkBurst { 0% { transform: scale(.3) rotate(0); opacity: 0 } 30% { opacity: 1 } 100% { transform: scale(1.25) rotate(25deg); opacity: 0 } }
  @keyframes mkFall { to { transform: translate(var(--dx), 110vh) rotate(var(--rot)); } }
  @keyframes mkEq { 0%,100% { height: 18% } 50% { height: 100% } }
  @keyframes mkFadeIn { from { opacity: 0 } to { opacity: 1 } }
  .mk-bob { animation: mkBob 2.4s ease-in-out infinite; }
  .mk-pop { animation: mkPop .55s cubic-bezier(.2,1.4,.4,1) both; }
  .mk-eq { display: inline-flex; align-items: flex-end; gap: 5px; height: 46px; }
  .mk-eq i { width: 9px; border-radius: 4px; background: linear-gradient(#ffcf3f, #b48cff); animation: mkEq .9s ease-in-out infinite; }
  .mk-eq i:nth-child(2) { animation-delay: .15s } .mk-eq i:nth-child(3) { animation-delay: .3s } .mk-eq i:nth-child(4) { animation-delay: .45s }
  .mk-eq i:nth-child(5) { animation-delay: .6s } .mk-eq i:nth-child(6) { animation-delay: .75s } .mk-eq i:nth-child(7) { animation-delay: .2s }
  .mk-confetti { position: fixed; inset: 0; pointer-events: none; overflow: hidden; z-index: 60; }
  .mk-confetti i { position: absolute; top: -20px; width: 10px; height: 14px; border-radius: 2px; animation: mkFall var(--t) cubic-bezier(.3,.6,.5,1) forwards; }
  .mk-cele { position: fixed; inset: 0; z-index: 50; display: flex; flex-direction: column; align-items: center; justify-content: center; background: radial-gradient(circle, #2a1f4ecc, #0d0a18ee); animation: mkFadeIn .2s; cursor: pointer; text-align: center; padding: 20px; }
  .mk-cele .burst { position: absolute; width: min(90vw, 760px); animation: mkBurst 2.6s ease-out forwards; }
  .mk-cele .icon { width: min(46vw, 230px); position: relative; animation: mkPop .6s cubic-bezier(.2,1.4,.4,1) both; filter: drop-shadow(0 10px 30px #ffcf3f55); }
  .mk-cele .t { position: relative; font-size: clamp(34px, 8vw, 68px); font-weight: 700; color: #ffcf3f; margin-top: 10px; text-shadow: 0 4px 0 #6b3fd1; animation: mkPop .6s .15s both; }
  .mk-cele .s { position: relative; font-size: clamp(18px, 4vw, 28px); color: #f1eefb; margin-top: 4px; animation: mkFadeIn .4s .3s both; }
  `;
  function injectStyles() {
    if (document.getElementById('mk-theme-css')) return;
    const st = document.createElement('style'); st.id = 'mk-theme-css'; st.textContent = CSS; document.head.appendChild(st);
  }

  function confetti(n = 90) {
    injectStyles();
    const box = document.createElement('div'); box.className = 'mk-confetti';
    const colors = ['#ffcf3f', '#b48cff', '#ff5fa2', '#7c4dff', '#ffffff', '#3fd18b'];
    for (let i = 0; i < n; i++) {
      const c = document.createElement('i');
      c.style.left = Math.random() * 100 + 'vw';
      c.style.background = colors[i % colors.length];
      c.style.setProperty('--dx', (Math.random() * 200 - 100) + 'px');
      c.style.setProperty('--rot', (Math.random() * 900 - 450) + 'deg');
      c.style.setProperty('--t', (1.8 + Math.random() * 1.6) + 's');
      c.style.animationDelay = (Math.random() * 0.4) + 's';
      if (Math.random() < 0.3) { c.style.borderRadius = '50%'; c.style.width = c.style.height = '9px'; }
      box.appendChild(c);
    }
    document.body.appendChild(box);
    setTimeout(() => box.remove(), 4000);
  }

  let actx = null;
  function ctx() { try { actx = actx || new (window.AudioContext || window.webkitAudioContext)(); if (actx.state === 'suspended') actx.resume(); } catch {} return actx; }
  function tone(f, start, dur, type = 'triangle', vol = 0.18) {
    const a = ctx(); if (!a) return;
    const o = a.createOscillator(), g = a.createGain();
    o.type = type; o.frequency.value = f; o.connect(g); g.connect(a.destination);
    const t = a.currentTime + start;
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.start(t); o.stop(t + dur + 0.05);
  }
  function fanfare() { [523, 659, 784, 1047].forEach((f, i) => tone(f, i * 0.11, 0.3)); tone(1047, 0.48, 0.6, 'triangle', 0.2); tone(1319, 0.48, 0.6, 'sine', 0.12); }
  function ding() { tone(880, 0, 0.25, 'sine', 0.15); tone(1320, 0.08, 0.3, 'sine', 0.1); }
  function boing() { tone(220, 0, 0.18, 'square', 0.08); tone(160, 0.12, 0.25, 'square', 0.07); }

  /** Celebración a pantalla completa. items: [{pot, title, subtitle}] se muestran en cola. */
  const queue = [];
  let showing = false;
  function celebrate(items, { sound = true, ms = 2600 } = {}) {
    injectStyles();
    queue.push(...(Array.isArray(items) ? items : [items]));
    if (!showing) next(sound, ms);
  }
  function next(sound, ms) {
    const it = queue.shift();
    if (!it) { showing = false; return; }
    showing = true;
    const el = document.createElement('div'); el.className = 'mk-cele';
    el.innerHTML = `<img class="burst" src="${IMG}mk_celebra.png" alt=""><img class="icon" src="${prize(it.pot)}" alt="">
      <div class="t">${it.title || ''}</div>${it.subtitle ? `<div class="s">${it.subtitle}</div>` : ''}`;
    document.body.appendChild(el);
    confetti(); if (sound) fanfare();
    if (navigator.vibrate) navigator.vibrate([80, 60, 80, 60, 200]);
    let done = false;
    const close = () => { if (done) return; done = true; el.remove(); next(sound, ms); };
    el.onclick = close; setTimeout(close, ms);
  }

  function preload() {
    [...Object.values(PRIZE_IMG), ...Object.values(MASCOT), 'mk_celebra', 'mk_logo'].forEach(n => { const i = new Image(); i.src = IMG + n + '.png'; });
  }

  root.MK = { IMG, prize, mascot, confetti, celebrate, fanfare, ding, boing, injectStyles, preload,
    eq: (n = 7) => `<span class="mk-eq">${'<i></i>'.repeat(n)}</span>` };
})(typeof self !== 'undefined' ? self : this);
