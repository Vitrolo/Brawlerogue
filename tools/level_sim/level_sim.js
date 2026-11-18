// Testa o gerador de niveis 2D fora do GameMaker.
//
// Uso (na raiz do projeto):
//   node tools/level_sim/level_sim.js [seeds=1000] [mapas=3] [primeira_seed=1] [--linear]
//
// --linear zera max_attempts e testa so o nivel linear (o plano B do gerador).
//
// Carrega o MESMO arquivo scripts/scr_level_gen/scr_level_gen.gml, converte as
// poucas diferencas de sintaxe para JavaScript e imita as funcoes do GameMaker
// que ele usa. A configuracao vem do bloco `level: { ... }` de scr_config.gml.
// O gerador aleatorio daqui nao e o do GameMaker: a mesma seed gera mapas
// diferentes no jogo e no teste. O teste confere as regras, nao o mapa de cada
// seed.
//
// Alem de level_validate (do proprio GML), confere tudo de novo com codigo
// independente, para um erro no validador nao passar despercebido.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..', '..');
const GEN_FILE = path.join(ROOT, 'scripts', 'scr_level_gen', 'scr_level_gen.gml');
const CFG_FILE = path.join(ROOT, 'scripts', 'scr_config', 'scr_config.gml');

// ------------------------------------------------------------ aleatorio

let rngState = 1;
function rnd() {
    rngState = (rngState + 0x6D2B79F5) | 0;
    let t = Math.imul(rngState ^ (rngState >>> 15), 1 | rngState);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

// ------------------------------------------------------------ GML -> JS

const debugLog = [];
const shim = {
    array_length: (a) => a.length,
    array_push: (a, ...v) => { a.push(...v); },
    array_create: (n, v = 0) => new Array(n).fill(v),
    array_contains: (a, v) => a.includes(v),
    irandom: (n) => Math.floor(rnd() * (Math.floor(n) + 1)),
    irandom_range: (a, b) => {
        a = Math.floor(a);
        b = Math.floor(b);
        if (a > b) [a, b] = [b, a];
        return a + Math.floor(rnd() * (b - a + 1));
    },
    random: (n) => rnd() * n,
    floor: Math.floor,
    abs: Math.abs,
    min: Math.min,
    max: Math.max,
    sign: Math.sign,
    round: Math.round,
    clamp: (v, a, b) => Math.max(a, Math.min(b, v)),
    string: (v) => String(v),
    is_undefined: (v) => v === undefined,
    variable_struct_exists: (s, k) => Object.prototype.hasOwnProperty.call(s, k),
    show_debug_message: (m) => { debugLog.push(String(m)); },
    show_error: (m) => { throw new Error('show_error: ' + m); },
};

function gmlToJs(src) {
    if (/\b(with|repeat|div|enum)\b\s*[({]?/.test(src.replace(/\/\/[^\n]*/g, '').replace(/"[^"\n]*"/g, '""'))) {
        // so um aviso: o arquivo do gerador nao deveria usar essas construcoes
        console.warn('aviso: o GML do gerador usa with/repeat/div/enum; a conversao pode falhar');
    }
    return src
        .replace(/\[\$\s*/g, '[')
        .replace(/\[@\s*/g, '[')
        .replace(/\bmod\b/g, '%');
}

function loadCfg() {
    const src = fs.readFileSync(CFG_FILE, 'utf8');
    const m = /\n\s*level:\s*\{/.exec(src);
    if (!m) throw new Error('bloco "level: {" nao encontrado em scr_config.gml');
    let i = src.indexOf('{', m.index);
    let depth = 0;
    let k = i;
    for (; k < src.length; k++) {
        if (src[k] === '{') depth++;
        else if (src[k] === '}') {
            depth--;
            if (depth === 0) break;
        }
    }
    return vm.runInNewContext('(' + src.slice(i, k + 1) + ')');
}

function loadGenerator() {
    const ctx = vm.createContext(Object.assign({ global: {} }, shim));
    vm.runInContext(gmlToJs(fs.readFileSync(GEN_FILE, 'utf8')), ctx, { filename: 'scr_level_gen.gml' });
    ctx.chunk_types_init();
    return ctx;
}

// ------------------------------------------------------------ conferencia independente

function independentCheck(lv, cfg, types) {
    const errs = [];
    const n = lv.chunks.length;
    const onGrid = lv.chunks.filter((c) => c.on_grid);
    const at = new Map();
    for (const c of onGrid) {
        const key = c.row + ',' + c.col;
        if (at.has(key)) errs.push('sobreposicao em ' + key);
        at.set(key, c.index);
        if (Math.abs(c.row) > cfg.max_depth) errs.push('linha fora do limite');
        if (c.col < 0 || c.col >= lv.cols) errs.push('coluna fora do limite');
    }
    // grade x chunks
    for (let r = 0; r < lv.rows; r++) {
        for (let c = 0; c < lv.cols; c++) {
            const g = lv.grid[r][c];
            const key = (r + lv.row_min) + ',' + c;
            if (g === -1 && at.has(key)) errs.push('grade vazia onde ha chunk ' + key);
            if (g !== -1 && at.get(key) !== g) errs.push('grade diverge em ' + key);
        }
    }
    // ligacoes
    const adj = Array.from({ length: n }, () => []);
    const stairsPer = new Array(n).fill(0);
    for (const l of lv.links) {
        const A = lv.chunks[l.a];
        const B = lv.chunks[l.b];
        adj[l.a].push(l.b);
        adj[l.b].push(l.a);
        if (l.kind === 'walk' && !(A.row === B.row && B.col === A.col + 1)) errs.push('walk com geometria errada');
        if (l.kind === 'stairs') {
            if (!(A.col === B.col && B.row === A.row - 1)) errs.push('escada com geometria errada');
            if (A.type !== 'junction' || B.type !== 'junction') errs.push('escada fora de junction');
            stairsPer[l.a]++;
            stairsPer[l.b]++;
        }
        if (l.kind !== 'walk' && l.kind !== 'stairs') errs.push('ligacao de tipo desconhecido: ' + l.kind);
        for (const [ix, dir] of [[l.a, dirOf(l, l.a)], [l.b, dirOf(l, l.b)]]) {
            if (!types[lv.chunks[ix].type].sockets.includes(dir)) errs.push('abertura ' + dir + ' proibida em ' + lv.chunks[ix].type);
        }
    }
    for (const c of lv.chunks) {
        if (c.type === 'junction' && stairsPer[c.index] !== 1) errs.push('junction com ' + stairsPer[c.index] + ' escadas');
        if (c.type !== 'junction' && stairsPer[c.index] !== 0) errs.push('escada em ' + c.type);
    }
    // vizinhos na mesma linha precisam estar ligados; corredores diferentes com folga
    for (const c of onGrid) {
        const right = at.get(c.row + ',' + (c.col + 1));
        if (right !== undefined && !lv.links.some((l) => l.kind === 'walk' && l.a === c.index && l.b === right)) {
            errs.push('celulas encostadas sem passagem');
        }
    }
    // alcance
    const seen = new Array(n).fill(false);
    const queue = [lv.start];
    seen[lv.start] = true;
    while (queue.length) {
        const v = queue.shift();
        for (const w of adj[v]) if (!seen[w]) { seen[w] = true; queue.push(w); }
    }
    if (seen.includes(false)) errs.push('chunk inalcancavel');
    // caminho do principal do inicio ao chefe sem sair da linha 0
    for (let c = 0; c + 1 < lv.cols; c++) {
        const a = at.get('0,' + c);
        const b = at.get('0,' + (c + 1));
        if (a === undefined || b === undefined || !lv.links.some((l) => l.kind === 'walk' && l.a === a && l.b === b)) {
            errs.push('principal interrompido');
            break;
        }
    }
    if (lv.chunks[lv.boss].type !== 'boss' || lv.chunks[lv.boss].row !== 0) errs.push('chefe fora do principal');
    // salas obrigatorias
    const rooms = lv.chunks.filter((c) => ROOM[c.type]).map((c) => c.type);
    for (const c of lv.chunks) if (!c.on_grid) errs.push('chunk fora da grade');
    for (const k of cfg.interiors_main) if (lv.chunks.some((c) => c.type === k && c.row !== 0)) errs.push('sala ' + k + ' fora do principal');
    if (rooms.filter((r) => r === 'rest').length > 1) errs.push('descanso repetido');
    for (const k of cfg.interiors_main.concat(cfg.interiors_branch)) {
        if (rooms.filter((r) => r === k).length !== 1) errs.push('sala ' + k + ' faltando ou repetida');
    }
    return errs;
}

function dirOf(l, ix) {
    if (l.kind === 'walk') return ix === l.a ? 'right' : 'left';
    if (l.kind === 'stairs') return ix === l.a ? 'up' : 'down';
    return '';
}

// ------------------------------------------------------------ desenho ASCII

const LETTER = {
    start: 'INI', boss: 'CHF', exit_combat: 'SAI', combat: 'cmb', junction: 'esc',
    corridor: '...', dead_end: 'BEC', horde: 'HOR',
    shop: 'LOJ', reward: 'TES', challenge: 'DES', rest: 'DSC',
};
const ROOM = { shop: '$', reward: 'T', challenge: '!', rest: 'z' };

function ascii(lv) {
    const lines = [];
    const stairsCols = new Map(); // "linha_de_baixo" -> colunas com escada para cima
    for (const l of lv.links) {
        if (l.kind !== 'stairs') continue;
        const low = lv.chunks[l.a];
        const k = low.row;
        if (!stairsCols.has(k)) stairsCols.set(k, new Set());
        stairsCols.get(k).add(low.col);
    }
    let header = '      ';
    for (let c = 0; c < lv.cols; c++) header += String(c).padStart(3, ' ').padEnd(6, ' ');
    lines.push(header);
    for (let r = lv.row_min; r < lv.row_min + lv.rows; r++) {
        // escadas entre a linha r-1 e r
        if (r > lv.row_min) {
            let s = '      ';
            for (let c = 0; c < lv.cols; c++) s += (stairsCols.has(r) && stairsCols.get(r).has(c)) ? '  ||  ' : '      ';
            if (s.trim()) lines.push(s);
        }
        let row = String(r).padStart(3, ' ') + '   ';
        let any = false;
        for (let c = 0; c < lv.cols; c++) {
            const g = lv.grid[r - lv.row_min][c];
            if (g < 0) { row += '      '; continue; }
            any = true;
            const ch = lv.chunks[g];
            // celulas vizinhas da mesma linha sempre estao ligadas (a validacao exige)
            row += '[' + LETTER[ch.type] + ' ]';
        }
        if (any) lines.push(row);
    }
    return lines.join('\n');
}

// ------------------------------------------------------------ principal

function main() {
    const args = process.argv.slice(2).filter((a) => !a.startsWith('--'));
    const seeds = parseInt(args[0] || '1000', 10);
    const show = parseInt(args[1] || '3', 10);
    const first = parseInt(args[2] || '1', 10);
    const cfg = loadCfg();
    if (process.argv.includes('--linear')) cfg.max_attempts = 0;
    const gen = loadGenerator();
    const types = gen.global.chunk_types;

    const stats = {
        ok: 0, failed: 0, linear: 0, retries: 0, cells: [], branches: [], depth2: 0, loops: 0,
        dead_end: 0, horde: 0, branch_combat: 0, rooms_on_branch: 0, rooms_total: 0, rest: 0,
        cols: [], reasons: new Map(),
    };

    for (let s = first; s < first + seeds; s++) {
        rngState = s * 2654435761;
        debugLog.length = 0;
        let lv;
        try {
            lv = gen.level_build(cfg);
        } catch (e) {
            stats.failed++;
            console.log('seed ' + s + ': ' + e.message);
            continue;
        }
        stats.retries += debugLog.length;
        for (const m of debugLog) {
            const r = m.replace(/\d+/g, '#');
            stats.reasons.set(r, (stats.reasons.get(r) || 0) + 1);
        }
        const err = gen.level_validate(lv, cfg);
        const errs = independentCheck(lv, cfg, types);
        if (err !== '' || errs.length) {
            stats.failed++;
            console.log('seed ' + s + ' INVALIDO: ' + (err || '') + ' ' + errs.join('; '));
            console.log(ascii(lv));
            continue;
        }
        stats.ok++;
        if (lv.linear) stats.linear++;
        const onGrid = lv.chunks.filter((c) => c.on_grid);
        stats.cells.push(onGrid.length);
        stats.cols.push(lv.cols);
        const roots = new Set();
        for (const l of lv.links) {
            if (l.kind !== 'stairs') continue;
            const A = lv.chunks[l.a];
            const B = lv.chunks[l.b];
            if (A.row === 0) roots.add(B.corridor);
            if (B.row === 0) roots.add(A.corridor);
        }
        stats.branches.push(roots.size);
        if (onGrid.some((c) => Math.abs(c.row) === 2)) stats.depth2++;
        const walkStairs = lv.links.length;
        if (walkStairs - onGrid.length + 1 === 1) stats.loops++;
        for (const c of lv.chunks) {
            if (c.type === 'dead_end') stats.dead_end++;
            if (c.type === 'horde') stats.horde++;
            if (c.type === 'combat' && c.on_grid && c.row !== 0) stats.branch_combat++;
            if (ROOM[c.type]) {
                stats.rooms_total++;
                if (c.row !== 0) stats.rooms_on_branch++;
                if (c.type === 'rest') stats.rest++;
            }
        }
        if (s < first + show) {
            console.log('\n--- seed ' + s + (lv.linear ? ' (linear)' : '') + ' ---');
            console.log(ascii(lv));
        }
    }

    const avg = (a) => (a.length ? (a.reduce((x, y) => x + y, 0) / a.length).toFixed(2) : '-');
    const hist = (a) => {
        const m = new Map();
        for (const v of a) m.set(v, (m.get(v) || 0) + 1);
        return [...m.entries()].sort((x, y) => x[0] - y[0]).map(([k, v]) => k + ':' + v).join(' ');
    };
    console.log('\n=== ' + seeds + ' seeds ===');
    console.log('validos: ' + stats.ok + '   invalidos: ' + stats.failed + '   lineares (fallback): ' + stats.linear);
    console.log('tentativas descartadas: ' + stats.retries + ' (media ' + (stats.retries / seeds).toFixed(2) + ' por nivel)');
    for (const [r, k] of [...stats.reasons.entries()].sort((a, b) => b[1] - a[1])) console.log('   ' + k + 'x ' + r);
    console.log('colunas do principal: ' + hist(stats.cols));
    console.log('celulas ocupadas: media ' + avg(stats.cells) + '  [' + hist(stats.cells) + ']');
    console.log('ramos do principal: ' + hist(stats.branches));
    console.log('niveis com linha +-2: ' + stats.depth2 + '   com atalho (ciclo): ' + stats.loops);
    console.log('becos: ' + stats.dead_end + '   hordas: ' + stats.horde + '   combates em ramos: ' + stats.branch_combat);
    console.log('salas: ' + stats.rooms_total + ' (' + stats.rooms_on_branch + ' em ramos)   descansos: ' + stats.rest);

    const fillSeeds = Math.min(seeds, 300);
    const fillFailed = fillPhase(fillSeeds, first);
    process.exitCode = (stats.failed || fillFailed) ? 1 : 0;
}

// ------------------------------------------------------------ preenchimento
//
// Roda o preenchimento real (run_level_fill em scr_route) e as consultas de jogo
// (scr_level) sobre os mesmos arquivos GML do projeto, com os modulos de
// scr_rooms e a configuracao de scr_config. Confere coordenadas, escadas,
// portas, armas, objetos e se o mapa vira JSON (o save usa json_stringify).

const FILL_FILES = ['scr_config', 'scr_level_gen', 'scr_level', 'scr_rooms', 'scr_route', 'scr_props', 'scr_backdrop'];

function gmlToJsFull(src) {
    return src
        .replace(/^#macro\s+(\w+)\s+(.+)$/gm, (m, name, expr) =>
            'Object.defineProperty(globalThis, "' + name + '", { get: () => (' + expr.replace(/\/\/.*$/, '').trim() + '), configurable: true });')
        // with (alvo) { ... } -> laco sobre as instancias (continue e break funcionam)
        .replace(/\bwith\s*\(([^()]*)\)/g, 'for (var __w of __with($1)) with (__w)')
        // so aparece em codigo de desenho, que o teste nao executa
        .replace(/\bdiv\b/g, '/')
        .replace(/\[\$\s*/g, '[')
        .replace(/\[@\s*/g, '[')
        .replace(/\bmod\b/g, '%');
}

function loadFull() {
    const sources = FILL_FILES.map((n) => [n, gmlToJsFull(fs.readFileSync(path.join(ROOT, 'scripts', n, n + '.gml'), 'utf8'))]);
    // sprites, objetos, rooms e constantes do GameMaker viram numeros distintos (>= 0)
    const idents = new Set();
    for (const [, js] of sources) {
        for (const m of js.matchAll(/\b(?:spr|obj|rm|c|vk|gp|fa|bm|snd|fnt)_\w+\b/g)) idents.add(m[0]);
    }
    const consts = {};
    let k = 0;
    for (const id of idents) consts[id] = k++;
    const gm = {
        global: {},
        noone: -4,
        infinity: Infinity,
        __with: () => [],
        make_colour_rgb: (r, g, b) => r + g * 256 + b * 65536,
        make_color_rgb: (r, g, b) => r + g * 256 + b * 65536,
        merge_colour: (a) => a,
        is_struct: (v) => v !== null && typeof v === 'object' && !Array.isArray(v),
        is_array: (v) => Array.isArray(v),
        is_string: (v) => typeof v === 'string',
        is_real: (v) => typeof v === 'number',
        variable_struct_get_names: (s) => Object.keys(s),
        variable_struct_get: (s, k2) => s[k2],
        variable_struct_set: (s, k2, v) => { s[k2] = v; },
        array_copy: (dst, di, src, si, n) => { for (let i = 0; i < n; i++) dst[di + i] = src[si + i]; },
        array_shuffle: (a) => a.slice(),
        array_shuffle_ext: () => {},
        string_upper: (s) => String(s).toUpperCase(),
        string_lower: (s) => String(s).toLowerCase(),
        real: Number,
        lerp: (a, b, t) => a + (b - a) * t,
        point_distance: (x1, y1, x2, y2) => Math.hypot(x2 - x1, y2 - y1),
        ceil: Math.ceil,
        sqrt: Math.sqrt,
        power: Math.pow,
        sin: Math.sin,
        cos: Math.cos,
        frac: (v) => v - Math.trunc(v),
    };
    const ctx = vm.createContext(Object.assign(gm, shim, consts));
    for (const [n, js] of sources) vm.runInContext(js, ctx, { filename: n + '.gml' });
    vm.runInContext(
        'function stage_define(_d) { global.stages[_d.sid] = _d; }\n' +
        'function stage_get(_s) { return global.stages[_s]; }', ctx);
    ctx.config_init();
    ctx.chunk_types_init();
    ctx.global.stages = {};
    ctx.rooms_init();
    return ctx;
}

function verifyMap(ctx, map) {
    const errs = [];
    const W = map.cell_w;
    const H = map.band_h;
    const L = ctx.global.cfg.level;
    const num = (v) => typeof v === 'number' && Number.isFinite(v);
    // x que o jogador alcanca no corredor (limites de stage_x1/x2 com as paredes),
    // com a folga _slack de quem interage (portas: 20 px)
    const reach = (ci, x, slack) => {
        const c = map.corridors[ci];
        const body = ctx.global.cfg.player.body_w + ctx.global.cfg.stage.edge_margin;
        const lo = c.x1 + (c.cap_left ? L.cap_margin : 0) + body;
        const hi = c.x2 - (c.cap_right ? L.cap_margin : 0) - body;
        return x >= lo - slack && x <= hi + slack;
    };
    // chunks na grade e no mundo
    for (const ch of map.chunks) {
        if (!ch.on_grid) {
            errs.push('chunk fora da grade');
            continue;
        }
        if (ROOM[ch.type]) {
            const st = ctx.stage_get(ch.sid);
            if (!st) errs.push('sala sem modulo: ' + ch.type);
            else if (st.kind !== (ch.type === 'challenge' ? 'event' : ch.type)) errs.push('sala com modulo de outro tipo');
            if (!ctx.global.run.special_rooms[ch.sid]) errs.push('sala sem estado salvo');
            if (!reach(ch.corridor, ch.room_x, 25)) errs.push('objeto da sala atras de uma parede no chunk ' + ch.index);
            if (!(ch.room_x > ch.x1 && ch.room_x < ch.x2)) errs.push('objeto da sala fora da celula');
        }
        if ('door' in ch || 'door_x' in ch) errs.push('chunk ainda tem porta');
        if (ch.x1 !== ch.col * W || ch.x2 !== ch.x1 + W || ch.oy !== ch.band * H) errs.push('chunk ' + ch.index + ' fora do lugar');
        if (ch.floor_top !== ch.oy + 178 || ch.floor_bottom !== ch.oy + 258) errs.push('chao errado no chunk ' + ch.index);
        if (map.grid[ch.band][ch.col] !== ch.index) errs.push('grade do mundo errada no chunk ' + ch.index);
        if (ctx.level_chunk_at(map, (ch.x1 + ch.x2) / 2, ch.floor_top + 40) !== ch.index) errs.push('level_chunk_at errado no chunk ' + ch.index);
        const cor = map.corridors[ch.corridor];
        if (!cor || ch.x1 < cor.x1 || ch.x2 > cor.x2 || cor.oy !== ch.oy) errs.push('chunk ' + ch.index + ' fora do corredor');
        if (['combat', 'exit_combat', 'horde', 'boss'].includes(ch.type)) {
            if (ch.state !== 'pending' || !ch.waves.length || !ch.waves.every((w) => w.length > 0)) errs.push('combate sem ondas no chunk ' + ch.index);
            if (!(ch.trigger_x1 >= ch.x1 && ch.trigger_x2 <= ch.x2 && ch.trigger_x1 < ch.trigger_x2)) errs.push('gatilho fora do chunk ' + ch.index);
            for (const w of ch.waves) for (const e of w) {
                if (typeof e.type !== 'string' || !ctx.global.cfg.enemies[e.type]) errs.push('inimigo desconhecido: ' + e.type);
                if (!num(e.x) || !num(e.y)) errs.push('inimigo sem posicao');
            }
        } else if (ch.state !== 'cleared') errs.push('chunk sem combate fora de cleared');
        if (ch.type === 'horde' && !ctx.global.run.special_rooms[ch.reward_key]) errs.push('horda sem bau');
    }
    // corredores
    for (const c of map.corridors) {
        if (c.x1 !== c.c1 * W || c.x2 !== (c.c2 + 1) * W || c.oy !== c.band * H) errs.push('corredor ' + c.index + ' fora do lugar');
        for (const id of c.chunks) if (map.chunks[id].corridor !== c.index) errs.push('corredor e chunk discordam');
        if (c.has_boss !== c.chunks.includes(map.boss)) errs.push('corredor do chefe errado');
        // ponto no vazio da mesma faixa cai no corredor mais perto
        if (ctx.level_corridor_at(map, c.x1 + 10, c.floor_top + 10) !== c.index) errs.push('level_corridor_at errado');
    }
    // escadas
    for (const li of map.stairs) {
        const k2 = map.links[li];
        const low = map.chunks[k2.a];
        const up = map.chunks[k2.b];
        if (![k2.x_foot, k2.y_foot, k2.x_top, k2.y_top].every(num)) errs.push('escada sem geometria');
        if (k2.x_foot < low.x1 + 100 || k2.x_foot > low.x2 - 100 || k2.x_top < up.x1 + 100 || k2.x_top > up.x2 - 100) errs.push('escada perto da borda');
        if (k2.y_foot !== low.floor_top || k2.y_top !== up.floor_bottom) errs.push('escada fora do chao');
        if (Math.abs(k2.x_top - k2.x_foot) !== ctx.stage_stairs_run(map.biome)) errs.push('escada com deslocamento errado');
        if (!reach(low.corridor, k2.x_foot, 0) || !reach(up.corridor, k2.x_top, 0)) errs.push('ponta de escada atras de uma parede');
        const foot = ctx.level_stairs_near(map, low.corridor, k2.x_foot, k2.y_foot);
        const top = ctx.level_stairs_near(map, up.corridor, k2.x_top, k2.y_top);
        if (!foot || foot.link !== li || foot.top) errs.push('pe da escada nao encontrado');
        if (!top || top.link !== li || !top.top) errs.push('topo da escada nao encontrado');
        // no meio do chao, longe da parede e da beirada, nao ha escada
        if (ctx.level_stairs_near(map, low.corridor, k2.x_foot, low.floor_top + 40)) errs.push('escada ativa longe da parede');
        // o jogador sai da escada dentro do chao da outra faixa
        if (ctx.level_corridor_at(map, k2.x_top, up.floor_bottom - 2) !== up.corridor) errs.push('topo fora do corredor de cima');
        if (ctx.level_corridor_at(map, k2.x_foot, low.floor_top + 2) !== low.corridor) errs.push('pe fora do corredor de baixo');
    }
    // armas e objetos dentro de uma celula, no chao da faixa
    const inside = (x, y) => {
        const id = ctx.level_chunk_at(map, x, y);
        if (id < 0) return false;
        const ch = map.chunks[id];
        return y >= ch.floor_top && y <= ch.floor_bottom;
    };
    for (const p of map.pickups) {
        if (!inside(p.x, p.y)) errs.push('arma fora do chao: ' + p.key);
        else if (!reach(map.chunks[ctx.level_chunk_at(map, p.x, p.y)].corridor, p.x, 25)) errs.push('arma atras de uma parede: ' + p.key);
    }
    // corredor do chefe: saida aberta a direita; os outros fecham as duas pontas
    // (salvo porta rente a ponta)
    for (const c of map.corridors) if (c.has_boss && c.cap_right) errs.push('saida do chefe fechada');
    for (const p of map.props) if (!inside(p.x, p.y)) errs.push('objeto fora do chao: ' + p.kind);
    // nascimento
    const st = map.chunks[map.start];
    if (ctx.level_corridor_at(map, st.x1 + 60, st.oy + 222) !== st.corridor) errs.push('nascimento fora do corredor');
    if (!st.discovered) errs.push('inicio nao descoberto');
    // save
    try {
        const back = JSON.parse(JSON.stringify(map));
        if (back.chunks.length !== map.chunks.length) errs.push('JSON perdeu chunks');
    } catch (e) {
        errs.push('mapa nao vira JSON: ' + e.message);
    }
    return errs;
}

function fillPhase(seeds, first) {
    let ctx;
    try {
        ctx = loadFull();
    } catch (e) {
        console.log('\nPREENCHIMENTO: falhou ao carregar o GML: ' + e.stack);
        return true;
    }
    let ok = 0;
    let bad = 0;
    const totals = { maps: 0, stairs: 0, rooms: 0, pickups: 0, props: 0, hordes: 0, bands: 0 };
    for (let s = first; s < first + seeds; s++) {
        rngState = s * 2654435761 + 7;
        ctx.global.run = { special_rooms: {}, maps: [], return_context: undefined };
        const used = {};
        let errs = [];
        try {
            for (let b = 0; b < ctx.global.biomes.length; b++) {
                const lv = ctx.level_build(ctx.global.cfg.level);
                const map = ctx.run_level_fill(lv, ctx.global.biomes[b], b, used);
                errs = errs.concat(verifyMap(ctx, map).map((e) => ctx.global.biomes[b].bid + ': ' + e));
                totals.maps++;
                totals.stairs += map.stairs.length;
                totals.rooms += map.chunks.filter((c) => ROOM[c.type]).length;
                totals.pickups += map.pickups.length;
                totals.props += map.props.length;
                totals.hordes += map.chunks.filter((c) => c.type === 'horde').length;
                totals.bands += map.bands;
            }
        } catch (e) {
            errs.push('erro de execucao: ' + e.stack.split('\n').slice(0, 3).join(' | '));
        }
        if (errs.length) {
            bad++;
            if (bad <= 5) console.log('seed ' + s + ' (preenchimento): ' + [...new Set(errs)].slice(0, 6).join('; '));
        } else ok++;
    }
    const per = (v) => (v / Math.max(1, totals.maps)).toFixed(2);
    console.log('\n=== preenchimento: ' + seeds + ' seeds x ' + ctx.global.biomes.length + ' biomas ===');
    console.log('ok: ' + ok + '   com problema: ' + bad);
    console.log('por mapa: faixas ' + per(totals.bands) + '  escadas ' + per(totals.stairs) + '  salas ' + per(totals.rooms)
        + '  armas ' + per(totals.pickups) + '  objetos ' + per(totals.props) + '  hordas ' + per(totals.hordes));
    return bad > 0;
}

main();
