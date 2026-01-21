// rules.js - Server-side game rules (ported from Rules.gd)

const BOARD = { cols: 10, rows: 10, ringOut: true };

const OBSTACLES = [
  { x: 4, y: 4 },
  { x: 5, y: 4 },
  { x: 4, y: 5 },
  { x: 7, y: 2 },
  { x: 2, y: 7 },
];

const SPELLS = {
  STRIKE: { id: "STRIKE", type: "ATTACK", range: 1, damage: 2, cooldown: 0 },
  DASH: { id: "DASH", type: "MOVE", range: 2, cooldown: 2 },
  GUARD: { id: "GUARD", type: "BUFF", cooldown: 3 },
  FORCE: { id: "FORCE", type: "ATTACK", range: 2, damage: 1, push: 1, cooldown: 3 },
  SHOT: { id: "SHOT", type: "ATTACK", range: 3, damage: 1, cooldown: 0 },
  SNIPE: { id: "SNIPE", type: "ATTACK", range: 8, damage: 2, cooldown: 2 },
  BACKSTEP: { id: "BACKSTEP", type: "MOVE", cooldown: 1 },
};

function isObstacle(x, y) {
  return OBSTACLES.some((o) => o.x === x && o.y === y);
}

function inBounds(x, y) {
  return x >= 0 && x < BOARD.cols && y >= 0 && y < BOARD.rows;
}

function getUnitAt(state, x, y) {
  const u1 = state.units.P1;
  const u2 = state.units.P2;
  if (u1.x === x && u1.y === y && u1.hp > 0) return u1;
  if (u2.x === x && u2.y === y && u2.hp > 0) return u2;
  return null;
}

function distManhattan(u1, u2) {
  return Math.abs(u1.x - u2.x) + Math.abs(u1.y - u2.y);
}

function hasLineOfSightToCell(fromX, fromY, toX, toY) {
  let x0 = fromX, y0 = fromY;
  const x1 = toX, y1 = toY;
  const dx = Math.abs(x1 - x0);
  const dy = -Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1;
  const sy = y0 < y1 ? 1 : -1;
  let err = dx + dy;

  while (true) {
    if (isObstacle(x0, y0)) return false;
    if (x0 === x1 && y0 === y1) break;
    const e2 = 2 * err;
    if (e2 >= dy) { err += dy; x0 += sx; }
    if (e2 <= dx) { err += dx; y0 += sy; }
  }
  return true;
}

function getPathDistance(state, fromX, fromY, toX, toY) {
  if (fromX === toX && fromY === toY) return 0;

  const visited = new Map();
  const queue = [{ x: fromX, y: fromY, dist: 0 }];
  visited.set(`${fromX},${fromY}`, true);

  const dirs = [
    [0, 1], [0, -1], [1, 0], [-1, 0],
    [1, 1], [1, -1], [-1, 1], [-1, -1],
  ];

  while (queue.length > 0) {
    const current = queue.shift();
    for (const [dx, dy] of dirs) {
      const nx = current.x + dx;
      const ny = current.y + dy;
      const key = `${nx},${ny}`;
      const moveCost = (dx !== 0 && dy !== 0) ? 2 : 1;
      const newDist = current.dist + moveCost;

      if (visited.has(key)) continue;
      if (!inBounds(nx, ny)) continue;
      if (isObstacle(nx, ny)) continue;
      if (getUnitAt(state, nx, ny)) continue;

      if (nx === toX && ny === toY) return newDist;

      visited.set(key, true);
      queue.push({ x: nx, y: ny, dist: newDist });
    }
  }
  return -1;
}

function pushLog(state, msg) {
  state.log.push(msg);
  if (state.log.length > 12) state.log.shift();
}

function checkWin(state) {
  const p1Dead = state.units.P1.hp <= 0;
  const p2Dead = state.units.P2.hp <= 0;
  if (p1Dead && p2Dead) state.winner = "DRAW";
  else if (p1Dead) state.winner = "P2";
  else if (p2Dead) state.winner = "P1";
}

function resolveDamage(state, attacker, defender, amount, type) {
  let dmg = amount;
  let countered = false;

  if (defender.status.guard) {
    dmg = Math.max(0, dmg - defender.status.guard.value);
    defender.status.guard = null;
    pushLog(state, "Guard reduced damage");
    if (type === "MELEE") countered = true;
  }

  defender.hp = Math.max(0, defender.hp - dmg);
  pushLog(state, `${defender.id} took ${dmg} damage`);
  checkWin(state);

  if (countered && defender.hp > 0 && attacker.hp > 0) {
    attacker.hp = Math.max(0, attacker.hp - 1);
    pushLog(state, `Counter-attack hit ${attacker.id}`);
    checkWin(state);
  }
}

function resolvePush(state, pusher, target) {
  const dx = target.x - pusher.x;
  const dy = target.y - pusher.y;
  let pushX = 0, pushY = 0;

  if (Math.abs(dx) > Math.abs(dy)) pushX = Math.sign(dx);
  else if (Math.abs(dy) > Math.abs(dx)) pushY = Math.sign(dy);
  else if (dy !== 0) pushY = Math.sign(dy);
  else pushX = Math.sign(dx);

  const tx = target.x + pushX;
  const ty = target.y + pushY;

  if (!inBounds(tx, ty)) {
    if (BOARD.ringOut) {
      target.hp = 0;
      pushLog(state, "Ring Out!");
      checkWin(state);
    }
    return;
  }

  if (getUnitAt(state, tx, ty)) {
    pushLog(state, "Push blocked");
    return;
  }

  target.x = tx;
  target.y = ty;
  pushLog(state, `Pushed to (${tx},${ty})`);
}

function handleTurnEnd(state) {
  if (state.winner) return;

  const current = state.turn.currentPlayerId;
  const nextPlayer = current === "P1" ? "P2" : "P1";

  state.turn.currentPlayerId = nextPlayer;
  if (nextPlayer === "P1") state.turn.number += 1;
  state.turn.actionTaken = false;
  state.turn.movesRemaining = 3;

  const pUnit = state.units[nextPlayer];
  pUnit.status.guard = null;
  for (const key in pUnit.cooldowns) {
    pUnit.cooldowns[key] = Math.max(0, pUnit.cooldowns[key] - 1);
  }
}

export function createInitialState() {
  return {
    turn: {
      currentPlayerId: "P1",
      number: 1,
      actionTaken: false,
      movesRemaining: 3,
    },
    units: {
      P1: {
        id: "P1", x: 2, y: 5, hp: 10,
        status: { guard: null },
        cooldowns: { STRIKE: 0, DASH: 0, GUARD: 0, FORCE: 0, SHOT: 0, SNIPE: 0, BACKSTEP: 0 },
      },
      P2: {
        id: "P2", x: 3, y: 1, hp: 10,
        status: { guard: null },
        cooldowns: { STRIKE: 0, DASH: 0, GUARD: 0, FORCE: 0, SHOT: 0, SNIPE: 0, BACKSTEP: 0 },
      },
    },
    winner: null,
    log: [],
  };
}

export function applyAction(state, action) {
  // Deep clone
  const next = JSON.parse(JSON.stringify(state));
  const pid = action.playerId;

  if (next.winner) return state;
  if (next.turn.currentPlayerId !== pid && action.type !== "END_TURN") return state;
  if (action.type === "CAST" && next.turn.actionTaken) return state;

  const me = next.units[pid];
  const otherId = pid === "P1" ? "P2" : "P1";
  const enemy = next.units[otherId];

  if (action.type === "MOVE") {
    const tx = action.to.x;
    const ty = action.to.y;
    if (!inBounds(tx, ty)) return state;
    if (getUnitAt(next, tx, ty)) return state;
    if (next.turn.movesRemaining <= 0) return state;

    const pathDist = getPathDistance(next, me.x, me.y, tx, ty);
    if (pathDist < 0 || pathDist > next.turn.movesRemaining) return state;

    me.x = tx;
    me.y = ty;
    next.turn.movesRemaining -= pathDist;
    pushLog(next, `${pid} moved to (${tx},${ty})`);
    return next;

  } else if (action.type === "CAST") {
    const spellId = action.spellId;
    const target = action.target;
    const spell = SPELLS[spellId];
    if (!spell) return state;
    if ((me.cooldowns[spellId] || 0) > 0) return state;

    if (spellId === "STRIKE") {
      if (distManhattan(me, target) !== 1) return state;
      if (target.x !== enemy.x || target.y !== enemy.y) return state;
      if (enemy.hp <= 0) return state;

      me.cooldowns[spellId] = spell.cooldown;
      next.turn.actionTaken = true;
      pushLog(next, `${pid} casts STRIKE`);
      resolveDamage(next, me, enemy, spell.damage, "MELEE");
      return next;

    } else if (spellId === "FORCE") {
      const d = distManhattan(me, target);
      if (d > spell.range || d === 0) return state;
      if (target.x !== enemy.x || target.y !== enemy.y) return state;

      me.cooldowns[spellId] = spell.cooldown;
      next.turn.actionTaken = true;
      pushLog(next, `${pid} casts FORCE`);
      resolveDamage(next, me, enemy, spell.damage, "RANGED");
      if (enemy.hp > 0) resolvePush(next, me, enemy);
      return next;

    } else if (spellId === "DASH") {
      me.x = target.x;
      me.y = target.y;
      me.cooldowns[spellId] = spell.cooldown;
      next.turn.actionTaken = true;
      pushLog(next, `${pid} DASHED`);
      return next;

    } else if (spellId === "GUARD") {
      me.cooldowns[spellId] = spell.cooldown;
      me.status.guard = { value: 2 };
      next.turn.actionTaken = true;
      pushLog(next, `${pid} GUARDS`);
      return next;

    } else if (spellId === "SHOT" || spellId === "SNIPE") {
      const d = Math.abs(me.x - target.x) + Math.abs(me.y - target.y);
      if (d > spell.range || d === 0) return state;
      if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

      me.cooldowns[spellId] = spell.cooldown;
      next.turn.actionTaken = true;
      pushLog(next, `${pid} casts ${spellId} at (${target.x},${target.y})`);

      if (target.x === enemy.x && target.y === enemy.y) {
        resolveDamage(next, me, enemy, spell.damage, "RANGED");
      } else {
        pushLog(next, "Shot missed (no target)");
      }
      return next;

    } else if (spellId === "BACKSTEP") {
      me.x = target.x;
      me.y = target.y;
      me.cooldowns[spellId] = spell.cooldown;
      next.turn.actionTaken = true;
      pushLog(next, `${pid} BACKSTEPS`);
      return next;
    }

  } else if (action.type === "END_TURN") {
    pushLog(next, `${pid} ends turn`);
    handleTurnEnd(next);
    return next;
  }

  return state;
}
