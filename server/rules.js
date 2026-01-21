// rules.js - Server-side game rules (synced with Rules.gd)
// Updated: Full Ranger spell system with AP, status effects, and delayed effects

const BOARD = { cols: 10, rows: 10, ringOut: true };

const OBSTACLES = [
  { x: 4, y: 4 },
  { x: 5, y: 4 },
  { x: 4, y: 5 },
  { x: 7, y: 2 },
  { x: 2, y: 7 },
];

// Game constants
const MAX_HP = 100;
const MAX_AP = 50;
const MAX_MP = 3;

// Ranger Spells
const RANGER_SPELLS = {
  CROSSFIRE_VOLLEY: {
    id: "CROSSFIRE_VOLLEY",
    label: "Crossfire Volley",
    type: "ATTACK",
    range: 6,
    damage: 25,
    ap_cost: 18,
    cooldown: 3,
    requires_los: true,
    aoe: "CROSS",
  },
  PIERCING_WINDSHOT: {
    id: "PIERCING_WINDSHOT",
    label: "Piercing Windshot",
    type: "ATTACK",
    range: 8,
    damage: 22,
    ap_cost: 16,
    cooldown: 2,
    requires_los: true,
    aoe: "LINE",
    cardinal_only: true,
  },
  BLAZING_SCATTER: {
    id: "BLAZING_SCATTER",
    label: "Blazing Scatter",
    type: "ATTACK",
    range: 5,
    damage: 28,
    ap_cost: 24,
    cooldown: 4,
    requires_los: true,
    aoe: "3X3",
    damage_type: "FIRE",
  },
  HAWKS_INDIRECT_STRIKE: {
    id: "HAWKS_INDIRECT_STRIKE",
    label: "Hawk's Indirect Strike",
    type: "ATTACK",
    range: 7,
    damage: 35,
    ap_cost: 30,
    cooldown: 5,
    requires_los: false,
    aoe: "CROSS",
    delayed: true,
  },
  REPELLING_SHOT: {
    id: "REPELLING_SHOT",
    label: "Repelling Shot",
    type: "ATTACK",
    range: 6,
    damage: 40,
    ap_cost: 20,
    cooldown: 3,
    requires_los: true,
    push: 2,
    collision_damage: 20,
  },
  SHADOW_RAIN: {
    id: "SHADOW_RAIN",
    label: "Shadow Rain",
    type: "ATTACK",
    range: 7,
    damage: 15,
    ap_cost: 32,
    cooldown: 5,
    requires_los: false,
    aoe: "5X5_RANDOM",
    arrow_count: 10,
  },
  PINNING_CROSS: {
    id: "PINNING_CROSS",
    label: "Pinning Cross",
    type: "ATTACK",
    range: 5,
    damage: 20,
    ap_cost: 18,
    cooldown: 3,
    requires_los: true,
    aoe: "CROSS",
  },
  PHANTOM_SHOT: {
    id: "PHANTOM_SHOT",
    label: "Phantom Shot",
    type: "ATTACK",
    range: 8,
    damage: 30,
    ap_cost: 14,
    cooldown: 2,
    requires_los: false,
    pierces_walls: true,
  },
  CONE_OF_THORNS: {
    id: "CONE_OF_THORNS",
    label: "Cone of Thorns",
    type: "ATTACK",
    range: 4,
    damage: 24,
    ap_cost: 18,
    cooldown: 3,
    requires_los: true,
    aoe: "CONE",
  },
  MARKED_DETONATION: {
    id: "MARKED_DETONATION",
    label: "Marked Detonation",
    type: "ATTACK",
    range: 6,
    damage: 45,
    ap_cost: 34,
    cooldown: 6,
    requires_los: true,
    aoe: "CROSS",
    delayed: true,
    status_bonus: 20,
  },
};

function getSpell(spellId) {
  return RANGER_SPELLS[spellId] || null;
}

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
  let x0 = fromX,
    y0 = fromY;
  const x1 = toX,
    y1 = toY;
  const dx = Math.abs(x1 - x0);
  const dy = -Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1;
  const sy = y0 < y1 ? 1 : -1;
  let err = dx + dy;

  while (true) {
    if (isObstacle(x0, y0)) return false;
    if (x0 === x1 && y0 === y1) break;
    const e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y0 += sy;
    }
  }
  return true;
}

function getPathDistance(state, fromX, fromY, toX, toY) {
  if (fromX === toX && fromY === toY) return 0;

  const visited = new Map();
  const queue = [{ x: fromX, y: fromY, dist: 0 }];
  visited.set(`${fromX},${fromY}`, true);

  const dirs = [
    [0, 1],
    [0, -1],
    [1, 0],
    [-1, 0],
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1],
  ];

  while (queue.length > 0) {
    const current = queue.shift();
    for (const [dx, dy] of dirs) {
      const nx = current.x + dx;
      const ny = current.y + dy;
      const key = `${nx},${ny}`;
      const moveCost = dx !== 0 && dy !== 0 ? 2 : 1;
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

// =============================================================================
// AOE PATTERN HELPERS
// =============================================================================

function getCrossTiles(cx, cy) {
  return [
    { x: cx, y: cy },
    { x: cx + 1, y: cy },
    { x: cx - 1, y: cy },
    { x: cx, y: cy + 1 },
    { x: cx, y: cy - 1 },
  ];
}

function get3x3Tiles(cx, cy) {
  const tiles = [];
  for (let dx = -1; dx <= 1; dx++) {
    for (let dy = -1; dy <= 1; dy++) {
      tiles.push({ x: cx + dx, y: cy + dy });
    }
  }
  return tiles;
}

function get5x5Tiles(cx, cy) {
  const tiles = [];
  for (let dx = -2; dx <= 2; dx++) {
    for (let dy = -2; dy <= 2; dy++) {
      tiles.push({ x: cx + dx, y: cy + dy });
    }
  }
  return tiles;
}

function getLineTiles(sx, sy, dirX, dirY, maxRange) {
  const tiles = [];
  for (let i = 1; i <= maxRange; i++) {
    const nx = sx + dirX * i;
    const ny = sy + dirY * i;
    if (!inBounds(nx, ny)) break;
    if (isObstacle(nx, ny)) break;
    tiles.push({ x: nx, y: ny });
  }
  return tiles;
}

function getConeTiles(sx, sy, dirX, dirY, rangeVal) {
  const tiles = [];
  for (let i = 1; i <= rangeVal; i++) {
    const width = i;
    const cx = sx + dirX * i;
    const cy = sy + dirY * i;
    const perpX = -dirY;
    const perpY = dirX;
    for (let w = -width + 1; w < width; w++) {
      const tx = cx + perpX * w;
      const ty = cy + perpY * w;
      if (inBounds(tx, ty)) {
        tiles.push({ x: tx, y: ty });
      }
    }
  }
  return tiles;
}

function getCardinalDirection(fromX, fromY, toX, toY) {
  const dx = toX - fromX;
  const dy = toY - fromY;
  if (Math.abs(dx) >= Math.abs(dy)) {
    return dx !== 0 ? { x: Math.sign(dx), y: 0 } : { x: 0, y: Math.sign(dy) };
  } else {
    return dy !== 0 ? { x: 0, y: Math.sign(dy) } : { x: Math.sign(dx), y: 0 };
  }
}

// =============================================================================
// STATUS EFFECT SYSTEM
// =============================================================================

function hasStatus(unit, effect) {
  return unit.status[effect] != null;
}

function applyStatus(unit, effect, data) {
  if (!unit.status[effect]) {
    unit.status[effect] = data;
  } else {
    unit.status[effect].turns = Math.max(unit.status[effect].turns, data.turns);
  }
}

function isRooted(unit) {
  return hasStatus(unit, "root");
}

function isStunned(unit) {
  return hasStatus(unit, "stun");
}

function isKnockedDown(unit) {
  return hasStatus(unit, "knocked_down");
}

function hasMovementLoss(unit) {
  return hasStatus(unit, "movement_loss");
}

function getSlowAmount(unit) {
  if (hasStatus(unit, "slow")) {
    return unit.status.slow.amount;
  }
  return 0.0;
}

function processBleed(state, pid) {
  const unit = state.units[pid];
  if (hasStatus(unit, "bleed")) {
    const bleedDmg = 10;
    unit.hp = Math.max(0, unit.hp - bleedDmg);
    pushLog(state, `${pid} bleeds for ${bleedDmg} damage`);
    unit.status.bleed.turns -= 1;
    if (unit.status.bleed.turns <= 0) {
      unit.status.bleed = null;
      pushLog(state, `${pid}: bleed wore off`);
    }
    checkWin(state);
  }
}

function processBurn(state, pid) {
  const unit = state.units[pid];
  if (hasStatus(unit, "burn")) {
    const burnDmg = unit.status.burn.damage;
    unit.hp = Math.max(0, unit.hp - burnDmg);
    pushLog(state, `${pid} burns for ${burnDmg} damage (ignores armor)`);
    unit.status.burn.turns -= 1;
    if (unit.status.burn.turns <= 0) {
      unit.status.burn = null;
    }
    checkWin(state);
  }
}

function tickStatusEffects(state, pid) {
  const unit = state.units[pid];
  const effects = [
    "slow",
    "root",
    "revealed",
    "stun",
    "knocked_down",
    "damage_reduction",
    "movement_loss",
  ];
  for (const effect of effects) {
    if (hasStatus(unit, effect)) {
      unit.status[effect].turns -= 1;
      if (unit.status[effect].turns <= 0) {
        unit.status[effect] = null;
        pushLog(state, `${pid}: ${effect} wore off`);
      }
    }
  }
}

// =============================================================================
// DELAYED EFFECT SYSTEM
// =============================================================================

function addPendingEffect(state, effect) {
  if (!state.pending_effects) {
    state.pending_effects = [];
  }
  state.pending_effects.push(effect);
  pushLog(state, `Delayed effect queued for turn ${effect.trigger_turn}`);
}

function processPendingEffects(state) {
  if (!state.pending_effects) return;

  const currentTurn = state.turn.number;
  const toRemove = [];

  for (let i = 0; i < state.pending_effects.length; i++) {
    const effect = state.pending_effects[i];
    if (effect.trigger_turn <= currentTurn) {
      resolveDelayedEffect(state, effect);
      toRemove.push(i);
    }
  }

  for (let i = toRemove.length - 1; i >= 0; i--) {
    state.pending_effects.splice(toRemove[i], 1);
  }
}

function resolveDelayedEffect(state, effect) {
  pushLog(state, "Delayed effect triggers!");

  if (effect.spell_id === "HAWKS_INDIRECT_STRIKE") {
    const tiles = getCrossTiles(effect.target_x, effect.target_y);
    for (const tile of tiles) {
      const targetUnit = getUnitAt(state, tile.x, tile.y);
      if (targetUnit) {
        const dmg =
          tile.x === effect.target_x && tile.y === effect.target_y ? 35 : 20;
        targetUnit.hp = Math.max(0, targetUnit.hp - dmg);
        pushLog(state, `${targetUnit.id} hit for ${dmg} (Hawk's Strike)`);
      }
    }
    checkWin(state);
  } else if (effect.spell_id === "MARKED_DETONATION") {
    const tiles = getCrossTiles(effect.target_x, effect.target_y);
    for (const tile of tiles) {
      const targetUnit = getUnitAt(state, tile.x, tile.y);
      if (targetUnit) {
        let dmg = 45;
        if (hasStatus(targetUnit, "burn") || hasStatus(targetUnit, "bleed")) {
          dmg += 20;
          pushLog(state, "Bonus damage from status!");
        }
        targetUnit.hp = Math.max(0, targetUnit.hp - dmg);
        pushLog(state, `${targetUnit.id} hit for ${dmg} (Detonation)`);
      }
    }
    checkWin(state);
  }
}

// =============================================================================
// DAMAGE AND PUSH SYSTEM
// =============================================================================

function dealDamageAt(state, x, y, amount, source = "") {
  const target = getUnitAt(state, x, y);
  if (target) {
    let dmg = amount;
    if (target.status.guard != null) {
      dmg = Math.max(0, dmg - target.status.guard.value);
      target.status.guard = null;
      pushLog(state, "Guard absorbed damage");
    }
    target.hp = Math.max(0, target.hp - dmg);
    if (source) {
      pushLog(state, `${target.id} hit for ${dmg} (${source})`);
    } else {
      pushLog(state, `${target.id} hit for ${dmg} damage`);
    }
    checkWin(state);
    return true;
  }
  return false;
}

function pushUnitFrom(state, target, fromX, fromY, distance, collisionDamage) {
  const dx = target.x - fromX;
  const dy = target.y - fromY;
  let pushDirX = 0;
  let pushDirY = 0;

  if (Math.abs(dx) > Math.abs(dy)) {
    pushDirX = Math.sign(dx);
  } else if (Math.abs(dy) > Math.abs(dx)) {
    pushDirY = Math.sign(dy);
  } else {
    if (dy !== 0) {
      pushDirY = Math.sign(dy);
    } else {
      pushDirX = dx !== 0 ? Math.sign(dx) : 1;
    }
  }

  let pushed = 0;
  for (let i = 0; i < distance; i++) {
    const nx = target.x + pushDirX;
    const ny = target.y + pushDirY;

    if (!inBounds(nx, ny)) {
      if (BOARD.ringOut) {
        target.hp = 0;
        pushLog(state, "Ring Out!");
        checkWin(state);
      } else if (collisionDamage > 0) {
        target.hp = Math.max(0, target.hp - collisionDamage);
        pushLog(state, `Wall collision! +${collisionDamage} damage`);
        checkWin(state);
      }
      return;
    }

    if (isObstacle(nx, ny)) {
      if (collisionDamage > 0) {
        target.hp = Math.max(0, target.hp - collisionDamage);
        pushLog(state, `Wall collision! +${collisionDamage} damage`);
        checkWin(state);
      }
      return;
    }

    const blockingUnit = getUnitAt(state, nx, ny);
    if (blockingUnit) {
      if (collisionDamage > 0) {
        target.hp = Math.max(0, target.hp - collisionDamage);
        blockingUnit.hp = Math.max(0, blockingUnit.hp - collisionDamage);
        pushLog(state, `Unit collision! Both take ${collisionDamage} damage`);
        checkWin(state);
      }
      return;
    }

    target.x = nx;
    target.y = ny;
    pushed++;
  }

  if (pushed > 0) {
    pushLog(state, `${target.id} pushed ${pushed} tiles`);
  }
}

// =============================================================================
// TURN HANDLING
// =============================================================================

function handleTurnEnd(state) {
  if (state.winner) return;

  const current = state.turn.currentPlayerId;
  const nextPlayer = current === "P1" ? "P2" : "P1";

  // Process bleed at end of current player's turn
  processBleed(state, current);
  if (state.winner) return;

  // Process pending delayed effects
  processPendingEffects(state);
  if (state.winner) return;

  state.turn.currentPlayerId = nextPlayer;
  if (nextPlayer === "P1") state.turn.number += 1;
  state.turn.apRemaining = MAX_AP;
  state.turn.movesRemaining = MAX_MP;

  const pUnit = state.units[nextPlayer];
  pUnit.status.guard = null;

  // Apply slow
  if (hasStatus(pUnit, "slow")) {
    const reduction = getSlowAmount(pUnit);
    state.turn.movesRemaining = Math.floor(MAX_MP * (1.0 - reduction));
    pushLog(
      state,
      `${nextPlayer} is slowed! (${state.turn.movesRemaining} movement)`
    );
  }

  // Process burn at start of new player's turn
  processBurn(state, nextPlayer);
  if (state.winner) return;

  // Tick status effects
  tickStatusEffects(state, nextPlayer);

  // Decrement cooldowns
  for (const key in pUnit.cooldowns) {
    pUnit.cooldowns[key] = Math.max(0, pUnit.cooldowns[key] - 1);
  }
}

// =============================================================================
// INITIAL STATE
// =============================================================================

const defaultStatus = {
  guard: null,
  burn: null,
  bleed: null,
  slow: null,
  root: null,
  revealed: null,
  stun: null,
  knocked_down: null,
  damage_reduction: null,
  movement_loss: null,
};

const defaultCooldowns = {
  CROSSFIRE_VOLLEY: 0,
  PIERCING_WINDSHOT: 0,
  BLAZING_SCATTER: 0,
  HAWKS_INDIRECT_STRIKE: 0,
  REPELLING_SHOT: 0,
  SHADOW_RAIN: 0,
  PINNING_CROSS: 0,
  PHANTOM_SHOT: 0,
  CONE_OF_THORNS: 0,
  MARKED_DETONATION: 0,
};

export function createInitialState() {
  return {
    turn: {
      currentPlayerId: "P1",
      number: 1,
      apRemaining: MAX_AP,
      movesRemaining: MAX_MP,
    },
    units: {
      P1: {
        id: "P1",
        x: 2,
        y: 5,
        hp: MAX_HP,
        status: { ...defaultStatus },
        cooldowns: { ...defaultCooldowns },
      },
      P2: {
        id: "P2",
        x: 7,
        y: 4,
        hp: MAX_HP,
        status: { ...defaultStatus },
        cooldowns: { ...defaultCooldowns },
      },
    },
    pending_effects: [],
    winner: null,
    log: [],
  };
}

// =============================================================================
// ACTION HANDLING
// =============================================================================

export function applyAction(state, action) {
  const next = JSON.parse(JSON.stringify(state));
  const pid = action.playerId;

  if (next.winner) return state;
  if (next.turn.currentPlayerId !== pid && action.type !== "END_TURN")
    return state;

  const me = next.units[pid];
  const otherId = pid === "P1" ? "P2" : "P1";
  const enemy = next.units[otherId];

  if (action.type === "MOVE") {
    const tx = action.to.x;
    const ty = action.to.y;
    if (!inBounds(tx, ty)) return state;
    if (getUnitAt(next, tx, ty)) return state;
    if (next.turn.movesRemaining <= 0) return state;

    if (isStunned(me) || isRooted(me) || isKnockedDown(me) || hasMovementLoss(me)) {
      pushLog(next, `${pid} cannot move!`);
      return state;
    }

    const pathDist = getPathDistance(next, me.x, me.y, tx, ty);
    if (pathDist < 0 || pathDist > next.turn.movesRemaining) return state;

    me.x = tx;
    me.y = ty;
    next.turn.movesRemaining -= pathDist;
    pushLog(next, `${pid} moved to (${tx},${ty})`);
    return next;
  } else if (action.type === "CAST") {
    if (isStunned(me)) {
      pushLog(next, `${pid} is stunned and cannot act!`);
      return state;
    }

    const spellId = action.spellId;
    const target = action.target;
    const spell = getSpell(spellId);
    if (!spell) return state;

    if ((me.cooldowns[spellId] || 0) > 0) return state;

    const apCost = spell.ap_cost || 0;
    if (next.turn.apRemaining < apCost) return state;

    next.turn.apRemaining -= apCost;
    me.cooldowns[spellId] = spell.cooldown || 0;
    pushLog(
      next,
      `${pid} casts ${spell.label} (-${apCost} AP, ${next.turn.apRemaining} remaining)`
    );

    // Spell resolution
    switch (spellId) {
      case "CROSSFIRE_VOLLEY": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;
        if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

        const tiles = getCrossTiles(target.x, target.y);
        const pushedUnits = [];
        for (const tile of tiles) {
          if (!inBounds(tile.x, tile.y)) continue;
          const dmg =
            tile.x === target.x && tile.y === target.y ? 25 : 15;
          const hitUnit = getUnitAt(next, tile.x, tile.y);
          if (hitUnit) {
            dealDamageAt(next, tile.x, tile.y, dmg, "Crossfire Volley");
            if (!(tile.x === target.x && tile.y === target.y) && hitUnit.hp > 0) {
              pushedUnits.push(hitUnit);
            }
          }
        }
        for (const unit of pushedUnits) {
          pushUnitFrom(next, unit, target.x, target.y, 1, 0);
        }
        return next;
      }

      case "PIERCING_WINDSHOT": {
        const dir = getCardinalDirection(me.x, me.y, target.x, target.y);
        if (dir.x === 0 && dir.y === 0) return state;
        if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

        const lineTiles = getLineTiles(me.x, me.y, dir.x, dir.y, 8);
        for (const tile of lineTiles) {
          const hitUnit = getUnitAt(next, tile.x, tile.y);
          if (hitUnit) {
            dealDamageAt(next, tile.x, tile.y, 22, "Piercing Windshot");
            if (hitUnit.hp > 0) {
              applyStatus(hitUnit, "slow", { turns: 1, amount: 0.3 });
              pushLog(next, `${hitUnit.id} slowed!`);
            }
          }
        }
        return next;
      }

      case "BLAZING_SCATTER": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;
        if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

        const tiles = get3x3Tiles(target.x, target.y);
        for (const tile of tiles) {
          if (!inBounds(tile.x, tile.y)) continue;
          const hitUnit = getUnitAt(next, tile.x, tile.y);
          if (hitUnit) {
            dealDamageAt(next, tile.x, tile.y, 28, "Blazing Scatter");
            if (hitUnit.hp > 0) {
              applyStatus(hitUnit, "burn", { turns: 2, damage: 8 });
              pushLog(next, `${hitUnit.id} is burning!`);
            }
          }
        }
        return next;
      }

      case "HAWKS_INDIRECT_STRIKE": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;

        addPendingEffect(next, {
          spell_id: "HAWKS_INDIRECT_STRIKE",
          trigger_turn: next.turn.number + 1,
          target_x: target.x,
          target_y: target.y,
          caster_id: pid,
        });
        pushLog(next, `Hawk's Strike incoming at (${target.x},${target.y})!`);
        return next;
      }

      case "REPELLING_SHOT": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;
        if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

        const hitUnit = getUnitAt(next, target.x, target.y);
        if (hitUnit) {
          dealDamageAt(next, target.x, target.y, 40, "Repelling Shot");
          if (hitUnit.hp > 0) {
            pushUnitFrom(next, hitUnit, me.x, me.y, 2, 20);
          }
        } else {
          pushLog(next, "No target at location");
        }
        return next;
      }

      case "SHADOW_RAIN": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;

        const tiles = get5x5Tiles(target.x, target.y);
        const validTiles = tiles.filter((t) => inBounds(t.x, t.y));
        const numArrows = 10;
        for (let i = 0; i < numArrows; i++) {
          if (validTiles.length === 0) break;
          const randIdx = Math.floor(Math.random() * validTiles.length);
          const tile = validTiles[randIdx];
          const hitUnit = getUnitAt(next, tile.x, tile.y);
          if (hitUnit) {
            hitUnit.hp = Math.max(0, hitUnit.hp - 15);
            pushLog(next, `Arrow hits ${hitUnit.id} for 15!`);
          }
        }
        checkWin(next);
        return next;
      }

      case "PINNING_CROSS": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;
        if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

        const tiles = getCrossTiles(target.x, target.y);
        for (const tile of tiles) {
          if (!inBounds(tile.x, tile.y)) continue;
          const hitUnit = getUnitAt(next, tile.x, tile.y);
          if (hitUnit) {
            dealDamageAt(next, tile.x, tile.y, 20, "Pinning Cross");
            if (hitUnit.hp > 0) {
              applyStatus(hitUnit, "root", { turns: 1 });
              pushLog(next, `${hitUnit.id} is rooted!`);
            }
          }
        }
        return next;
      }

      case "PHANTOM_SHOT": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;

        const hitUnit = getUnitAt(next, target.x, target.y);
        if (hitUnit) {
          dealDamageAt(next, target.x, target.y, 30, "Phantom Shot");
          if (hitUnit.hp > 0) {
            applyStatus(hitUnit, "revealed", { turns: 2 });
            pushLog(next, `${hitUnit.id} revealed!`);
          }
        } else {
          pushLog(next, "No target at location");
        }
        return next;
      }

      case "CONE_OF_THORNS": {
        const dir = getCardinalDirection(me.x, me.y, target.x, target.y);
        if (dir.x === 0 && dir.y === 0) return state;
        if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

        const coneTiles = getConeTiles(me.x, me.y, dir.x, dir.y, 4);
        for (const tile of coneTiles) {
          if (!inBounds(tile.x, tile.y)) continue;
          const hitUnit = getUnitAt(next, tile.x, tile.y);
          if (hitUnit) {
            dealDamageAt(next, tile.x, tile.y, 24, "Cone of Thorns");
            if (hitUnit.hp > 0) {
              applyStatus(hitUnit, "bleed", { turns: 2 });
              pushLog(next, `${hitUnit.id} is bleeding!`);
            }
          }
        }
        return next;
      }

      case "MARKED_DETONATION": {
        const d = distManhattan(me, target);
        if (d > spell.range || d === 0) return state;
        if (!hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

        addPendingEffect(next, {
          spell_id: "MARKED_DETONATION",
          trigger_turn: next.turn.number + 1,
          target_x: target.x,
          target_y: target.y,
          caster_id: pid,
        });
        pushLog(
          next,
          `Mark placed at (${target.x},${target.y}) - detonates next turn!`
        );
        return next;
      }
    }

    return next;
  } else if (action.type === "END_TURN") {
    pushLog(next, `${pid} ends turn`);
    handleTurnEnd(next);
    return next;
  }

  return state;
}
