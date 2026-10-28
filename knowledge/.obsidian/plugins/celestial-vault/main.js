/* Celestial Vault: starfield welcome tab, painted daily banners, moon calendar, streak planet.
   No build step: plain CommonJS against Obsidian's API. The builders (welcome, banner, calendar,
   orb) are pure DOM and exported on the class so _scripts/celestial_preview.html can render them. */
'use strict';

const { Plugin, ItemView, PluginSettingTab, Setting, Platform, TFile, moment, normalizePath } = require('obsidian');

const SIDEBAR = 'celestial-sidebar';
const DEFAULTS = { nickname: 'Traveler', dailyFolder: 'Journal/Daily', monthlyFolder: 'Journal/Monthly', sidebarOpened: false, sky: true, planet: 30 };

// One palette per weekday (moment().day(): 0 = Sunday). sky = top, middle, horizon.
const DAYS = [
	{ sky: ['#1d1233', '#9c4f78', '#f3b07a'], sun: '#ffe2a8', accent: '#f4b183', far: '#35203f', near: '#170d1e', night: false },
	{ sky: ['#0b1433', '#34539e', '#a3c4ea'], sun: '#eef4ff', accent: '#93b6ff', far: '#1b2850', near: '#0b1126', night: false },
	{ sky: ['#08191e', '#2c767d', '#a9e0d2'], sun: '#effff6', accent: '#72d5c6', far: '#123a40', near: '#071619', night: false },
	{ sky: ['#2b1d0e', '#c08537', '#f6d68c'], sun: '#fff2c4', accent: '#e9c47a', far: '#4a3420', near: '#1e140b', night: false },
	{ sky: ['#0f2016', '#4c8657', '#dbe8aa'], sun: '#fbffe2', accent: '#a9d98f', far: '#1f3a26', near: '#0b170f', night: false },
	{ sky: ['#240c18', '#a3324b', '#f2896a'], sun: '#ffd4b2', accent: '#f27f7f', far: '#3a1424', near: '#16080f', night: false },
	{ sky: ['#06051a', '#2f2470', '#8a5fd0'], sun: '#f4eaff', accent: '#b89cff', far: '#1a1440', near: '#0a0820', night: true },
];

/* ------------------------------------------------------------------ helpers */
function h(tag, cls, kids, attrs) {
	const el = document.createElement(tag);
	if (cls) el.className = cls;
	if (attrs) for (const k in attrs) {
		if (k === 'on') for (const e in attrs.on) el.addEventListener(e, attrs.on[e]);
		else if (k === 'style') el.style.cssText = attrs[k];
		else el.setAttribute(k, attrs[k]);
	}
	for (const c of [].concat(kids == null ? [] : kids)) {
		if (c == null || c === false) continue;
		el.appendChild(typeof c === 'object' ? c : document.createTextNode(String(c)));
	}
	return el;
}

function rng(seed) { // mulberry32
	return function () {
		seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
		let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

function click(fn) { return { click: (e) => { e.preventDefault(); e.stopPropagation(); fn(e); } }; }

/* ------------------------------------------------------------------ welcome tab */
const LOGO = `<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
<defs>
 <radialGradient id="cvHalo"><stop offset="0" stop-color="#b06bff" stop-opacity=".55"/><stop offset=".55" stop-color="#5b3bd0" stop-opacity=".18"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
 <radialGradient id="cvBody" cx=".38" cy=".34" r=".75"><stop offset="0" stop-color="#6f8dff"/><stop offset=".45" stop-color="#4b33c9"/><stop offset="1" stop-color="#1a0f45"/></radialGradient>
 <linearGradient id="cvRing" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#ff5fb4"/><stop offset=".5" stop-color="#b15cff"/><stop offset="1" stop-color="#ffc9f0"/></linearGradient>
 <linearGradient id="cvGold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe1a0"/><stop offset="1" stop-color="#d79a4e"/></linearGradient>
 <filter id="cvGlow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>
<circle cx="100" cy="100" r="98" fill="url(#cvHalo)"/>
<g transform="rotate(-38 100 100)" filter="url(#cvGlow)">
 <path d="M18 100 A82 24 0 0 1 182 100" fill="none" stroke="url(#cvRing)" stroke-width="7" stroke-linecap="round" opacity=".85"/>
</g>
<circle cx="100" cy="100" r="44" fill="url(#cvBody)" filter="url(#cvGlow)"/>
<circle cx="100" cy="100" r="25" fill="none" stroke="url(#cvGold)" stroke-width="5"/>
<circle cx="100" cy="100" r="17" fill="#0d0820" opacity=".8"/>
<g transform="rotate(-38 100 100)" filter="url(#cvGlow)">
 <path d="M182 100 A82 24 0 0 1 18 100" fill="none" stroke="url(#cvRing)" stroke-width="8" stroke-linecap="round"/>
</g>
<circle cx="170" cy="44" r="2.2" fill="#fff"/><circle cx="34" cy="150" r="1.6" fill="#ffd9f3"/>
</svg>`;

// Living sky: three parallax star layers drifting slowly (wrapping), twinkle, constellations,
// slow nebula clouds, shooting stars, and a gentle mouse parallax. ~30 fps, idles when hidden.
function startStars(canvas) {
	const ctx = canvas.getContext('2d');
	const r = rng(Date.now() & 0xffff);
	let w = 0, hgt = 0, layers = [], cons = [], clouds = [], shooters = [], last = 0, ro;
	let mx = 0, my = 0, tx = 0, ty = 0;
	const LAYERS = [{ n: 1 / 9000, s: [0.3, 0.7], v: 0.004, par: 4 }, { n: 1 / 16000, s: [0.6, 1.1], v: 0.009, par: 10 }, { n: 1 / 42000, s: [1.1, 1.8], v: 0.018, par: 22 }];
	const TINT = ['#e9e2ff', '#cfe0ff', '#ffd9f3', '#fff4d6'];
	function seed() {
		layers = LAYERS.map((L) => Array.from({ length: Math.round(w * hgt * L.n) + 25 }, () => ({
			x: r() * w, y: r() * hgt, s: L.s[0] + r() * (L.s[1] - L.s[0]), p: r() * 6.28, tw: 0.0006 + r() * 0.002, c: TINT[Math.floor(r() * TINT.length)],
		})));
		cons = Array.from({ length: 4 }, () => {
			const pts = []; let x = r() * w, y = r() * hgt;
			for (let i = 0, n = 3 + Math.floor(r() * 3); i < n; i++) { pts.push([x, y]); x += (r() - 0.3) * 90; y += (r() - 0.5) * 70; }
			return { pts, p: r() * 6.28 };
		});
		clouds = Array.from({ length: 5 }, (_, i) => ({
			x: r() * w, y: r() * hgt, rad: 160 + r() * 260, vx: (r() - 0.5) * 0.012, vy: (r() - 0.5) * 0.008,
			c: ['176,107,255', '255,95,180', '90,140,255', '130,90,255', '255,150,220'][i], a: 0.035 + r() * 0.035, p: r() * 6.28,
		}));
	}
	function resize() {
		const b = canvas.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
		if (!b.width || !b.height) return;
		w = b.width; hgt = b.height;
		canvas.width = w * dpr; canvas.height = hgt * dpr;
		ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		seed();
	}
	function onMove(e) { const b = canvas.getBoundingClientRect(); if (!b.width) return; tx = (e.clientX - b.left) / b.width - 0.5; ty = (e.clientY - b.top) / b.height - 0.5; }
	window.addEventListener('mousemove', onMove, { passive: true });
	function wrap(v, m) { return ((v % m) + m) % m; }
	function frame(t) {
		if (!canvas.isConnected) { if (ro) ro.disconnect(); window.removeEventListener('mousemove', onMove); return; }
		requestAnimationFrame(frame);
		if (t - last < 33 || !canvas.offsetParent || !w) return;
		const dt = Math.min(80, t - last); last = t;
		mx += (tx - mx) * 0.04; my += (ty - my) * 0.04;
		ctx.clearRect(0, 0, w, hgt);
		// nebula clouds drift and breathe
		for (const c of clouds) {
			c.x = wrap(c.x + c.vx * dt, w + c.rad * 2); c.y = wrap(c.y + c.vy * dt, hgt + c.rad * 2);
			const x = c.x - c.rad - mx * 14, y = c.y - c.rad - my * 14, a = c.a * (0.75 + 0.25 * Math.sin(t * 0.0003 + c.p));
			const g = ctx.createRadialGradient(x, y, 0, x, y, c.rad);
			g.addColorStop(0, `rgba(${c.c},${a})`); g.addColorStop(1, `rgba(${c.c},0)`);
			ctx.fillStyle = g; ctx.fillRect(x - c.rad, y - c.rad, c.rad * 2, c.rad * 2);
		}
		// three star layers: slow diagonal drift, deeper layers move less, mouse parallax
		layers.forEach((stars, li) => {
			const L = LAYERS[li];
			for (const st of stars) {
				st.x = wrap(st.x - L.v * dt * 0.6, w); st.y = wrap(st.y + L.v * dt * 0.15, hgt);
				const x = wrap(st.x - mx * L.par, w), y = wrap(st.y - my * L.par, hgt);
				const tw = 0.5 + 0.5 * Math.sin(t * st.tw + st.p);
				ctx.globalAlpha = 0.15 + 0.7 * tw; ctx.fillStyle = st.c;
				ctx.beginPath(); ctx.arc(x, y, st.s, 0, 6.28); ctx.fill();
				if (st.s > 1.4 && tw > 0.85) { // occasional cross glint on the big ones
					ctx.globalAlpha = (tw - 0.85) * 4; ctx.strokeStyle = st.c; ctx.lineWidth = 0.6;
					ctx.beginPath(); ctx.moveTo(x - 5, y); ctx.lineTo(x + 5, y); ctx.moveTo(x, y - 5); ctx.lineTo(x, y + 5); ctx.stroke();
				}
			}
		});
		// constellations float with the middle layer
		for (const c of cons) {
			const a = 0.16 + 0.1 * Math.sin(t * 0.0005 + c.p), dx = Math.sin(t * 0.00008 + c.p) * 6 - mx * 10, dy = -my * 10;
			ctx.globalAlpha = a; ctx.strokeStyle = '#c9bcff'; ctx.lineWidth = 0.8;
			ctx.beginPath(); c.pts.forEach(([x, y], i) => (i ? ctx.lineTo(x + dx, y + dy) : ctx.moveTo(x + dx, y + dy))); ctx.stroke();
			ctx.globalAlpha = a + 0.4; ctx.fillStyle = '#fff';
			for (const [x, y] of c.pts) { ctx.beginPath(); ctx.arc(x + dx, y + dy, 1.5, 0, 6.28); ctx.fill(); }
		}
		// shooting stars
		if (r() < 0.006 * (dt / 33) && shooters.length < 2) {
			const ang = 0.35 + r() * 0.35;
			shooters.push({ x: r() * w * 0.8 + w * 0.2, y: r() * hgt * 0.4, vx: -Math.cos(ang) * 0.9, vy: Math.sin(ang) * 0.9, life: 0, max: 600 + r() * 500 });
		}
		shooters = shooters.filter((s) => s.life < s.max);
		for (const s of shooters) {
			s.life += dt; s.x += s.vx * dt; s.y += s.vy * dt;
			const fade = Math.sin(Math.PI * s.life / s.max), len = 90;
			const g = ctx.createLinearGradient(s.x, s.y, s.x - s.vx * len, s.y - s.vy * len);
			g.addColorStop(0, `rgba(255,255,255,${0.9 * fade})`); g.addColorStop(1, 'rgba(180,140,255,0)');
			ctx.globalAlpha = 1; ctx.strokeStyle = g; ctx.lineWidth = 1.6;
			ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(s.x - s.vx * len, s.y - s.vy * len); ctx.stroke();
		}
		ctx.globalAlpha = 1;
	}
	if (typeof ResizeObserver !== 'undefined') { ro = new ResizeObserver(resize); ro.observe(canvas); }
	resize();
	requestAnimationFrame(frame);
}
function buildWelcome(name, actions) {
	const mod = Platform && Platform.isMacOS ? '⌘' : 'Ctrl';
	const typed = h('span', 'cv-typed');
	const root = h('div', 'cv-welcome', [
		h('canvas', 'cv-stars'),
		h('div', 'cv-welcome-center', [
			h('div', 'cv-logo'),
			h('div', 'cv-hello', [h('span', 'cv-br', '[['), typed, h('span', 'cv-caret'), h('span', 'cv-br', ']]')]),
			h('div', 'cv-sub', '✦  Celestial Vault  ✦'),
			h('div', 'cv-keys', actions.map((a) => h('button', 'cv-key', [h('kbd', null, a.keys.replace('Mod', mod)), a.label], { on: click(a.run) }))),
		]),
	]);
	root.querySelector('.cv-logo').innerHTML = LOGO;
	const text = `Welcome. ${name}.`;
	let i = 0;
	const tick = () => { if (!root.isConnected && i) return; typed.textContent = text.slice(0, ++i); if (i < text.length) setTimeout(tick, 55 + Math.random() * 60); else root.classList.add('cv-done'); };
	setTimeout(tick, 350);
	startStars(root.querySelector('canvas'));
	return root;
}

// The sky behind every page: one starfield canvas and the planet, laid under the main editor area.
function buildSky() {
	const sky = h('div', 'cv-sky', [h('canvas', 'cv-stars'), h('div', 'cv-sky-planet')]);
	sky.querySelector('.cv-sky-planet').innerHTML = LOGO;
	startStars(sky.querySelector('canvas'));
	return sky;
}

/* ------------------------------------------------------------------ daily banner */
function bannerSVG(m) {
	const d = DAYS[m.day()], r = rng(+m.format('YYYYMMDD')), id = 'cv' + Math.floor(r() * 1e9);
	const W = 1200, HZ = 205, sunX = 420 + r() * 520, sunY = d.night ? 70 + r() * 30 : 150 + r() * 25;
	const out = [];
	out.push(`<defs>
<linearGradient id="${id}s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${d.sky[0]}"/><stop offset=".6" stop-color="${d.sky[1]}"/><stop offset="1" stop-color="${d.sky[2]}"/></linearGradient>
<radialGradient id="${id}g"><stop offset="0" stop-color="${d.sun}" stop-opacity=".9"/><stop offset=".25" stop-color="${d.sun}" stop-opacity=".35"/><stop offset="1" stop-color="${d.sun}" stop-opacity="0"/></radialGradient>
<linearGradient id="${id}w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${d.sky[1]}" stop-opacity=".55"/><stop offset=".5" stop-color="${d.far}"/><stop offset="1" stop-color="${d.near}"/></linearGradient>
<linearGradient id="${id}f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(--background-primary)" stop-opacity="0"/><stop offset="1" stop-color="var(--background-primary)" stop-opacity="1"/></linearGradient>
</defs>`);
	out.push(`<rect width="${W}" height="${HZ}" fill="url(#${id}s)"/>`);
	if (d.night) for (let i = 0; i < 90; i++) out.push(`<circle cx="${(r() * W).toFixed(1)}" cy="${(r() * HZ * 0.8).toFixed(1)}" r="${(0.4 + r() * 1.1).toFixed(2)}" fill="#fff" opacity="${(0.3 + r() * 0.7).toFixed(2)}"/>`);
	for (let i = 0; i < 5; i++) { // soft cloud bands
		const y = 40 + r() * 120, x = r() * W;
		out.push(`<ellipse cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" rx="${(120 + r() * 220).toFixed(0)}" ry="${(6 + r() * 10).toFixed(0)}" fill="${d.sky[2]}" opacity="${(0.12 + r() * 0.15).toFixed(2)}"/>`);
	}
	out.push(`<circle cx="${sunX}" cy="${sunY}" r="170" fill="url(#${id}g)"/><circle cx="${sunX}" cy="${sunY}" r="${d.night ? 20 : 30}" fill="${d.sun}"/>`);
	// far skyline: towers with lit windows
	for (let x = -10; x < W;) {
		const bw = 26 + r() * 50, bh = 30 + r() * (r() < 0.15 ? 120 : 70);
		out.push(`<rect x="${x.toFixed(0)}" y="${(HZ - bh).toFixed(0)}" width="${bw.toFixed(0)}" height="${bh.toFixed(0)}" fill="${d.far}" opacity=".92"/>`);
		for (let k = 0; k < bh / 14; k++) if (r() < 0.22) out.push(`<rect x="${(x + 4 + r() * (bw - 10)).toFixed(0)}" y="${(HZ - bh + 6 + k * 13).toFixed(0)}" width="3" height="4" fill="${d.sun}" opacity=".55"/>`);
		x += bw + r() * 6;
	}
	// near rooftops with lanterns
	let path = `M0 ${HZ + 8}`;
	const lanterns = [];
	for (let x = 0; x < W;) {
		const bw = 50 + r() * 90, top = HZ - 18 - r() * 40;
		path += ` L${x.toFixed(0)} ${(top + 10).toFixed(0)} L${(x + bw / 2).toFixed(0)} ${top.toFixed(0)} L${(x + bw).toFixed(0)} ${(top + 10).toFixed(0)}`;
		if (r() < 0.45) lanterns.push([x + bw * (0.2 + r() * 0.6), top + 22 + r() * 12]);
		x += bw;
	}
	path += ` L${W} ${HZ + 8} Z`;
	out.push(`<path d="${path}" fill="${d.near}"/>`);
	for (const [lx, ly] of lanterns) out.push(`<circle cx="${lx.toFixed(0)}" cy="${ly.toFixed(0)}" r="9" fill="${d.accent}" opacity=".18"/><circle cx="${lx.toFixed(0)}" cy="${ly.toFixed(0)}" r="3" fill="${d.sun}"/>`);
	// a blossom tree on the left
	for (let i = 0; i < 26; i++) out.push(`<circle cx="${(20 + r() * 230).toFixed(0)}" cy="${(25 + r() * 90).toFixed(0)}" r="${(16 + r() * 26).toFixed(0)}" fill="${d.accent}" opacity="${(0.25 + r() * 0.35).toFixed(2)}"/>`);
	out.push(`<path d="M120 ${HZ + 8} C128 160 110 120 140 70 M132 140 C160 120 190 110 215 95" stroke="${d.near}" stroke-width="9" fill="none"/>`);
	// water and the sun's reflection
	out.push(`<rect y="${HZ + 8}" width="${W}" height="${300 - HZ}" fill="url(#${id}w)"/>`);
	for (let i = 0; i < 9; i++) {
		const y = HZ + 14 + i * 9, len = 120 - i * 10 + r() * 30;
		out.push(`<rect x="${(sunX - len / 2 + (r() - 0.5) * 20).toFixed(0)}" y="${y}" width="${len.toFixed(0)}" height="2" rx="1" fill="${d.sun}" opacity="${(0.55 - i * 0.05).toFixed(2)}"/>`);
	}
	out.push(`<rect y="120" width="${W}" height="180" fill="url(#${id}f)"/>`);
	return `<svg viewBox="0 0 ${W} 300" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg">${out.join('')}</svg>`;
}

function buildDay(m, nav) {
	const d = DAYS[m.day()];
	const art = h('div', 'cv-banner-art');
	art.innerHTML = bannerSVG(m);
	return h('div', 'cv-day', [
		art,
		h('div', 'cv-day-head', [
			h('div', 'cv-day-title', ['✧ ', m.format('dddd, MMMM D, YYYY')]),
			h('div', 'cv-nav', [
				h('button', null, '← Yesterday', { on: click(() => nav.day(m.clone().subtract(1, 'day'))) }),
				h('button', null, 'This Month', { on: click(() => nav.month(m)) }),
				h('button', null, 'Tomorrow →', { on: click(() => nav.day(m.clone().add(1, 'day'))) }),
			]),
		]),
	], { style: `--cv-day:${d.accent};--cv-sun:${d.sun}` });
}

/* ------------------------------------------------------------------ calendar + orb */
function buildCalendar(view, ctx) {
	// ctx: { has(key), active (key|null), today (moment), onDay(m), onMove(delta), big }
	const start = view.clone().startOf('month').startOf('isoWeek');
	const cells = [];
	for (let i = 0; i < 42; i++) {
		const m = start.clone().add(i, 'day'), key = m.format('YYYY-MM-DD');
		const cls = ['cv-cal-day',
			m.month() !== view.month() && 'is-other',
			m.isSame(ctx.today, 'day') && 'is-today',
			ctx.active === key && 'is-active',
			ctx.has(key) && 'has-note'].filter(Boolean).join(' ');
		cells.push(h('div', cls, [h('span', null, m.date())], { on: click(() => ctx.onDay(m)), title: m.format('dddd, MMM D') }));
	}
	return h('div', 'cv-cal' + (ctx.big ? ' is-big' : ''), [
		h('div', 'cv-cal-head', [
			h('span', 'cv-cal-btn', '‹', { on: click(() => ctx.onMove(-1)) }),
			h('span', 'cv-cal-title', [view.format('MMMM'), h('em', null, ' Q' + view.quarter() + ' '), view.format('YYYY')]),
			h('span', 'cv-cal-btn', '›', { on: click(() => ctx.onMove(1)) }),
		]),
		h('div', 'cv-cal-grid', ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((w) => h('div', 'cv-cal-wd', w)).concat(cells)),
	]);
}

function buildOrb(streak, total) {
	return h('div', 'cv-orb-wrap' + (streak ? ' is-lit' : ''), [
		h('div', 'cv-orb-spark s1'), h('div', 'cv-orb-spark s2'), h('div', 'cv-orb-spark s3'),
		h('div', 'cv-orb', [h('div', 'cv-orb-count', ['★ ', String(streak)])]),
		h('div', 'cv-orb-water'),
		h('div', 'cv-orb-label', streak ? `${streak}-day streak · ${total} entries` : `${total} entries · write today to light it`),
	]);
}

/* ------------------------------------------------------------------ sidebar view */
class CelestialView extends ItemView {
	constructor(leaf, plugin) { super(leaf); this.plugin = plugin; this.month = moment(); }
	getViewType() { return SIDEBAR; }
	getDisplayText() { return 'Celestial'; }
	getIcon() { return 'orbit'; }
	async onOpen() { this.render(); }
	render() {
		const p = this.plugin, el = this.contentEl, af = p.app.workspace.getActiveFile();
		el.empty(); el.addClass('cv-side');
		const active = af && p.dayKeyOf(af);
		el.appendChild(buildCalendar(this.month, {
			has: (k) => p.days.has(k), active, today: moment(),
			onDay: (m) => p.openDay(m), onMove: (dl) => { this.month.add(dl, 'month'); this.render(); },
		}));
		el.appendChild(buildOrb(p.streak(), p.days.size));
	}
}

/* ------------------------------------------------------------------ plugin */
class CelestialVault extends Plugin {
	async onload() {
		this.settings = Object.assign({}, DEFAULTS, await this.loadData());
		this.days = new Map();
		this.registerView(SIDEBAR, (leaf) => new CelestialView(leaf, this));
		this.addSettingTab(new CelestialSettings(this.app, this));

		this.addRibbonIcon('sparkles', "Today's journal", () => this.openDay(moment()));
		this.addCommand({ id: 'open-today', name: "Open today's journal", hotkeys: [{ modifiers: ['Alt'], key: 'd' }], callback: () => this.openDay(moment()) });
		this.addCommand({ id: 'open-yesterday', name: "Open yesterday's journal", callback: () => this.openDay(moment().subtract(1, 'day')) });
		this.addCommand({ id: 'open-month', name: "Open this month's page", callback: () => this.openMonth(moment()) });
		this.addCommand({ id: 'open-sidebar', name: 'Show the Celestial sidebar', callback: () => this.showSidebar() });

		this.registerMarkdownCodeBlockProcessor('celestial-day', (src, el, ctx) => {
			const m = this.dateOf(ctx.sourcePath) || moment();
			const block = buildDay(m, { day: (d) => this.openDay(d), month: (d) => this.openMonth(d) });
			el.appendChild(block);
			setTimeout(() => { const v = el.closest('.markdown-preview-view, .markdown-source-view'); if (v) v.style.setProperty('--cv-day', DAYS[m.day()].accent); }, 0);
		});
		this.registerMarkdownCodeBlockProcessor('celestial-month', (src, el, ctx) => {
			const base = ctx.sourcePath.split('/').pop().slice(0, 7);
			let view = moment(base, 'YYYY-MM', true);
			if (!view.isValid()) view = moment();
			const draw = () => { el.empty(); el.appendChild(buildCalendar(view, {
				has: (k) => this.days.has(k), active: null, today: moment(), big: true,
				onDay: (m) => this.openDay(m), onMove: (dl) => { view.add(dl, 'month'); draw(); },
			})); };
			draw();
		});
		this.registerMarkdownCodeBlockProcessor('celestial-today', (src, el, ctx) => {
			const m = this.dateOf(ctx.sourcePath) || moment();
			const files = this.app.vault.getMarkdownFiles()
				.filter((f) => f.path !== ctx.sourcePath && !this.dayKeyOf(f) && moment(f.stat.ctime).isSame(m, 'day'))
				.sort((a, b) => a.stat.ctime - b.stat.ctime);
			el.appendChild(h('div', 'cv-today', [
				h('div', 'cv-today-head', [h('span', null, '✦ Notes born today'), h('span', 'cv-pill', String(files.length))]),
				files.length ? h('div', 'cv-today-list', files.map((f) => h('a', 'cv-today-row', [h('span', null, f.basename), h('em', null, f.parent && f.parent.path !== '/' ? f.parent.path : 'vault')], {
					on: click(() => this.app.workspace.getLeaf(false).openFile(f)),
				}))) : h('div', 'cv-today-empty', 'Nothing new yet. Every note you create today lands here.'),
			]));
		});

		const refresh = () => { this.indexDays(); this.refreshViews(); };
		this.app.workspace.onLayoutReady(() => {
			refresh();
			this.decorateEmpty();
			this.applySky();
			if (!this.settings.sidebarOpened) { this.settings.sidebarOpened = true; this.saveData(this.settings); this.showSidebar(); }
		});
		this.registerEvent(this.app.workspace.on('layout-change', () => { this.decorateEmpty(); this.applySky(); }));
		this.registerEvent(this.app.workspace.on('file-open', () => this.refreshViews()));
		for (const ev of ['create', 'delete', 'rename']) this.registerEvent(this.app.vault.on(ev, () => refresh()));

		this.status = this.addStatusBarItem();
		this.status.addClass('cv-status');
		this.status.setText('✦ Celestial Vault   ·   Alt+D today');
	}

	onunload() {
		document.querySelectorAll('.cv-welcome').forEach((e) => e.remove());
		document.querySelectorAll('.cv-empty').forEach((e) => e.classList.remove('cv-empty'));
		document.querySelectorAll('.cv-sky').forEach((e) => e.remove());
		document.body.classList.remove('cv-sky-on');
	}

	/* ---- sky behind every page */
	applySky() {
		const root = this.app.workspace.rootSplit && this.app.workspace.rootSplit.containerEl;
		document.body.classList.toggle('cv-sky-on', !!this.settings.sky);
		document.body.style.setProperty('--cv-planet-opacity', String((this.settings.planet ?? 30) / 100));
		const have = root && root.querySelector(':scope > .cv-sky');
		if (!this.settings.sky) { if (have) have.remove(); return; }
		if (root && !have) root.prepend(buildSky());
	}

	/* ---- daily index */
	dayKeyOf(file) {
		const folder = normalizePath(this.settings.dailyFolder) + '/';
		if (!(file instanceof TFile) || !file.path.startsWith(folder)) return null;
		const m = moment(file.basename.slice(0, 10), 'YYYY-MM-DD', true);
		return m.isValid() ? m.format('YYYY-MM-DD') : null;
	}
	dateOf(path) {
		const m = moment(path.split('/').pop().slice(0, 10), 'YYYY-MM-DD', true);
		return m.isValid() ? m : null;
	}
	indexDays() {
		this.days.clear();
		for (const f of this.app.vault.getMarkdownFiles()) { const k = this.dayKeyOf(f); if (k) this.days.set(k, f); }
	}
	streak() {
		const d = moment();
		if (!this.days.has(d.format('YYYY-MM-DD'))) d.subtract(1, 'day'); // today not written yet still keeps yesterday's run
		let n = 0;
		while (this.days.has(d.format('YYYY-MM-DD'))) { n++; d.subtract(1, 'day'); }
		return n;
	}
	refreshViews() { for (const leaf of this.app.workspace.getLeavesOfType(SIDEBAR)) if (leaf.view instanceof CelestialView) leaf.view.render(); }

	/* ---- notes */
	async ensureFolder(path) {
		let cur = '';
		for (const part of normalizePath(path).split('/')) {
			cur = cur ? `${cur}/${part}` : part;
			if (!this.app.vault.getAbstractFileByPath(cur)) await this.app.vault.createFolder(cur);
		}
	}
	async openDay(m) {
		const key = m.format('YYYY-MM-DD');
		let f = this.days.get(key);
		if (!f) {
			await this.ensureFolder(this.settings.dailyFolder);
			const path = normalizePath(`${this.settings.dailyFolder}/${m.format('YYYY-MM-DD-dddd')}.md`);
			f = this.app.vault.getAbstractFileByPath(path) || await this.app.vault.create(path,
				`---\ncssclasses:\n  - cv-daily\ncreated: ${key}\n---\n\`\`\`celestial-day\n\`\`\`\n\n**Today in 20 words:** \n\n- \n\n---\n\n\`\`\`celestial-today\n\`\`\`\n`);
			this.indexDays();
		}
		await this.app.workspace.getLeaf(false).openFile(f);
	}
	async openMonth(m) {
		await this.ensureFolder(this.settings.monthlyFolder);
		const path = normalizePath(`${this.settings.monthlyFolder}/${m.format('YYYY-MM-MMMM')}.md`);
		const f = this.app.vault.getAbstractFileByPath(path) || await this.app.vault.create(path,
			`---\ncssclasses:\n  - cv-month\n---\n# ✧ ${m.format('MMMM YYYY')}\n\n\`\`\`celestial-month\n\`\`\`\n\n## Highlights\n\n- \n`);
		await this.app.workspace.getLeaf(false).openFile(f);
	}
	async showSidebar() {
		let leaf = this.app.workspace.getLeavesOfType(SIDEBAR)[0];
		if (!leaf) { leaf = this.app.workspace.getLeftLeaf(true); await leaf.setViewState({ type: SIDEBAR, active: true }); }
		this.app.workspace.revealLeaf(leaf);
	}

	/* ---- welcome tab */
	decorateEmpty() {
		for (const leaf of this.app.workspace.getLeavesOfType('empty')) {
			const el = leaf.view && (leaf.view.contentEl || leaf.view.containerEl);
			if (!el || el.querySelector('.cv-welcome')) continue;
			el.classList.add('cv-empty');
			el.prepend(buildWelcome(this.settings.nickname || 'Traveler', [
				{ keys: 'Mod P', label: 'command panel', run: () => this.app.commands.executeCommandById('command-palette:open') },
				{ keys: 'Mod O', label: 'go to file', run: () => this.app.commands.executeCommandById('switcher:open') },
				{ keys: 'Alt D', label: 'today', run: () => this.openDay(moment()) },
			]));
		}
	}
}

class CelestialSettings extends PluginSettingTab {
	constructor(app, plugin) { super(app, plugin); this.plugin = plugin; }
	display() {
		const { containerEl: el } = this, p = this.plugin;
		el.empty();
		el.createEl('h2', { text: '✦ Celestial Vault' });
		const save = async () => { await p.saveData(p.settings); };
		new Setting(el).setName('Nickname').setDesc('What the welcome tab calls you.')
			.addText((t) => t.setValue(p.settings.nickname).onChange(async (v) => { p.settings.nickname = v.trim() || 'Traveler'; await save(); }));
		new Setting(el).setName('Starry sky behind every page').setDesc('The welcome-tab stars and planet, under all your notes.')
			.addToggle((t) => t.setValue(p.settings.sky).onChange(async (v) => { p.settings.sky = v; await save(); p.applySky(); }));
		new Setting(el).setName('Planet brightness').setDesc('How strongly the planet shows behind note text.')
			.addSlider((s) => s.setLimits(0, 100, 5).setValue(p.settings.planet).setDynamicTooltip().onChange(async (v) => { p.settings.planet = v; await save(); p.applySky(); }));
		new Setting(el).setName('Daily journal folder').setDesc('Daily notes are named YYYY-MM-DD-Weekday.')
			.addText((t) => t.setValue(p.settings.dailyFolder).onChange(async (v) => { p.settings.dailyFolder = v.trim() || DEFAULTS.dailyFolder; await save(); p.indexDays(); p.refreshViews(); }));
		new Setting(el).setName('Monthly pages folder')
			.addText((t) => t.setValue(p.settings.monthlyFolder).onChange(async (v) => { p.settings.monthlyFolder = v.trim() || DEFAULTS.monthlyFolder; await save(); }));
	}
}

CelestialVault.builders = { buildWelcome, buildSky, buildDay, buildCalendar, buildOrb, bannerSVG, DAYS };
module.exports = CelestialVault;
