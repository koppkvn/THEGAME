// rules.js - Server-side game rules (synced with Rules.gd)
// Anti-Gravity Character Spell System

const BOARD = { cols: 9, rows: 9, ringOut: false };

const OBSTACLES = [
  { x: 4, y: 4 },
  { x: 5, y: 4 },
  { x: 4, y: 5 },
  { x: 7, y: 2 },
  { x: 2, y: 7 },
];

// Game constants - Anti-Gravity spec
const MAX_HP = 10000;
const MAX_AP = 10;
const MAX_MP = 4;

// Anti-Gravity Spells
const SPELLS = {
  KNOCKBACK_ARROW: {
    id: "KNOCKBACK_ARROW",
    label: "Knockback Arrow",
    type: "ATTACK",
    range: 5,
    min_range: 1,
    damage_min: 200,
    damage_max: 400,
    ap_cost: 3,
    casts_per_turn: 1,
    cooldown: 0,
    requires_los: true,
    push: 3,
    collision_damage_per_tile: 100,
  },
  PIERCING_ARROW: {
    id: "PIERCING_ARROW",
    label: "Piercing Arrow",
    type: "ATTACK",
    range: 8,
    min_range: 1,
    damage_min: 100,
    damage_max: 300,
    ap_cost: 2,
    casts_per_turn: 2,
    cooldown: 0,
    requires_los: false,
  },
  EXPONENTIAL_ARROW: {
    id: "EXPONENTIAL_ARROW",
    label: "Exponential Arrow",
    type: "ATTACK",
    range: 8,
    min_range: 3,
    ap_cost: 5,
    casts_per_turn: 1,
    cooldown: 2,
    requires_los: true,
    stage_damage: {
      1: { min: 200, max: 600 },
      2: { min: 600, max: 1200 },
      3: { min: 3000, max: 4000 },
    },
  },
  IMMOBILIZING_ARROW: {
    id: "IMMOBILIZING_ARROW",
    label: "Immobilizing Arrow",
    type: "ATTACK",
    range: 8,
    min_range: 1,
    damage_min: 1,
    damage_max: 200,
    ap_cost: 2,
    casts_per_turn: 2,
    cooldown: 0,
    requires_los: true,
    mp_removal_min: 0,
    mp_removal_max: 2,
  },
  DISPLACEMENT_ARROW: {
    id: "DISPLACEMENT_ARROW",
    label: "Displacement Arrow",
    type: "DISPLACEMENT",
    range: 8,
    min_range: 1,
    ap_cost: 4,
    casts_per_turn: 1,
    cooldown: 1,
    requires_los: true,
    requires_empty_tile: true,
    cross_range: 3,
    push_distance: 2,
  },
  THIEF_ARROW: {
    id: "THIEF_ARROW",
    label: "Thief Arrow",
    type: "ATTACK",
    range: 8,
    min_range: 1,
    damage_min: 0,
    damage_max: 100,
    ap_cost: 1,
    casts_per_turn: 2,
    cooldown: 0,
    requires_los: true,
    random_effects: true,
  },
};

function getSpell(spellId) {
  return SPELLS[spellId] || null;
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

  const dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];

  while (queue.length > 0) {
    const current = queue.shift();
    for (const [dx, dy] of dirs) {
      const nx = current.x + dx;
      const ny = current.y + dy;
      const key = `${nx},${ny}`;
      const newDist = current.dist + 1;

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
// RANDOM HELPERS
// =============================================================================

function rollDamage(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// =============================================================================
// AOE HELPERS
// =============================================================================

function getCrossTiles(cx, cy, radius = 1) {
  const tiles = [{ x: cx, y: cy }];
  for (let i = 1; i <= radius; i++) {
    tiles.push({ x: cx + i, y: cy });
    tiles.push({ x: cx - i, y: cy });
    tiles.push({ x: cx, y: cy + i });
    tiles.push({ x: cx, y: cy - i });
  }
  return tiles;
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

function isRooted(unit) { return hasStatus(unit, "root"); }
function isStunned(unit) { return hasStatus(unit, "stun"); }

function getDamageBoost(unit) {
  if (hasStatus(unit, "damage_boost")) return unit.status.damage_boost.percent;
  return 0.0;
}

function getMpReduction(unit) {
  if (hasStatus(unit, "mp_reduction")) return unit.status.mp_reduction.amount;
  return 0;
}

function tickStatusEffects(state, pid) {
  const unit = state.units[pid];
  const effects = ["slow", "root", "revealed", "stun", "knocked_down", "damage_reduction", "movement_loss", "mp_reduction", "damage_boost"];
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
// DAMAGE SYSTEM
// =============================================================================

function dealDamageAt(state, x, y, amount, source = "", caster = null) {
  const target = getUnitAt(state, x, y);
  if (target) {
    let dmg = amount;
    if (caster && hasStatus(caster, "damage_boost")) {
      const boost = getDamageBoost(caster);
      dmg = Math.floor(dmg * (1.0 + boost));
    }
    if (hasStatus(target, "damage_boost")) {
      const boost = getDamageBoost(target);
      dmg = Math.floor(dmg * (1.0 + boost));
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

// =============================================================================
// PUSH SYSTEM
// =============================================================================

function pushUnitFromWithCollision(state, target, fromX, fromY, distance, collisionDamagePerTile) {
  const dx = target.x - fromX;
  const dy = target.y - fromY;
  let pushDirX = 0, pushDirY = 0;

  if (Math.abs(dx) > Math.abs(dy)) {
    pushDirX = Math.sign(dx);
  } else if (Math.abs(dy) > Math.abs(dx)) {
    pushDirY = Math.sign(dy);
  } else {
    if (dy !== 0) pushDirY = Math.sign(dy);
    else pushDirX = dx !== 0 ? Math.sign(dx) : 1;
  }

  let pushed = 0;
  let blockedTiles = 0;

  for (let i = 0; i < distance; i++) {
    const nx = target.x + pushDirX;
    const ny = target.y + pushDirY;

    if (!inBounds(nx, ny)) {
      if (BOARD.ringOut) {
        target.hp = 0;
        pushLog(state, "Ring Out!");
        checkWin(state);
      } else {
        blockedTiles = distance - i;
      }
      break;
    }

    if (isObstacle(nx, ny)) {
      blockedTiles = distance - i;
      break;
    }

    const blockingUnit = getUnitAt(state, nx, ny);
    if (blockingUnit) {
      blockedTiles = distance - i;
      break;
    }

    target.x = nx;
    target.y = ny;
    pushed++;
  }

  if (pushed > 0) {
    pushLog(state, `${target.id} pushed ${pushed} tiles`);
  }

  if (blockedTiles > 0 && collisionDamagePerTile > 0) {
    const collisionDmg = blockedTiles * collisionDamagePerTile;
    target.hp = Math.max(0, target.hp - collisionDmg);
    pushLog(state, `Collision! +${collisionDmg} damage (${blockedTiles} tiles blocked)`);
    checkWin(state);
  }
}

function pushUnitFromCenter(state, target, centerX, centerY, distance) {
  const dx = target.x - centerX;
  const dy = target.y - centerY;
  let pushDirX = 0, pushDirY = 0;

  if (dx !== 0 && dy === 0) {
    pushDirX = Math.sign(dx);
  } else if (dy !== 0 && dx === 0) {
    pushDirY = Math.sign(dy);
  } else if (dx === 0 && dy === 0) {
    const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    const dir = dirs[Math.floor(Math.random() * 4)];
    pushDirX = dir[0];
    pushDirY = dir[1];
  } else {
    if (Math.abs(dx) >= Math.abs(dy)) {
      pushDirX = Math.sign(dx);
    } else {
      pushDirY = Math.sign(dy);
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
      }
      return;
    }

    if (isObstacle(nx, ny)) break;

    const blockingUnit = getUnitAt(state, nx, ny);
    if (blockingUnit) break;

    target.x = nx;
    target.y = ny;
    pushed++;
  }

  if (pushed > 0) {
    pushLog(state, `${target.id} displaced ${pushed} tiles`);
  }
}

// =============================================================================
// TURN HANDLING
// =============================================================================

function handleTurnEnd(state) {
  if (state.winner) return;

  const current = state.turn.currentPlayerId;
  const nextPlayer = current === "P1" ? "P2" : "P1";
  const currentUnit = state.units[current];

  // Check Exponential Arrow reset
  const expCooldown = currentUnit.cooldowns.EXPONENTIAL_ARROW || 0;
  const expCasts = currentUnit.casts_this_turn.EXPONENTIAL_ARROW || 0;

  if (expCooldown === 0 && expCasts === 0) {
    if (currentUnit.exponential_stage > 1) {
      pushLog(state, `${current}: Exponential Arrow reset to Stage 1 (not cast when available)`);
      currentUnit.exponential_stage = 1;
    }
  }

  tickStatusEffects(state, current);

  state.turn.currentPlayerId = nextPlayer;
  if (nextPlayer === "P1") state.turn.number += 1;
  state.turn.apRemaining = MAX_AP;
  state.turn.movesRemaining = MAX_MP;

  const pUnit = state.units[nextPlayer];
  pUnit.casts_this_turn = {};

  // Apply MP reduction
  if (hasStatus(pUnit, "mp_reduction")) {
    const reduction = getMpReduction(pUnit);
    state.turn.movesRemaining = Math.max(0, state.turn.movesRemaining - reduction);
    pushLog(state, `${nextPlayer} has ${reduction} less MP this turn!`);
  }

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
  mp_reduction: null,
  damage_boost: null,
};

const defaultCooldowns = {
  KNOCKBACK_ARROW: 0,
  PIERCING_ARROW: 0,
  EXPONENTIAL_ARROW: 0,
  IMMOBILIZING_ARROW: 0,
  DISPLACEMENT_ARROW: 0,
  THIEF_ARROW: 0,
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
        casts_this_turn: {},
        exponential_stage: 1,
        exponential_available_last_turn: false,
      },
      P2: {
        id: "P2",
        x: 7,
        y: 4,
        hp: MAX_HP,
        status: { ...defaultStatus },
        cooldowns: { ...defaultCooldowns },
        casts_this_turn: {},
        exponential_stage: 1,
        exponential_available_last_turn: false,
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
  if (next.turn.currentPlayerId !== pid && action.type !== "END_TURN") return state;

  const me = next.units[pid];
  const otherId = pid === "P1" ? "P2" : "P1";
  const enemy = next.units[otherId];

  if (action.type === "MOVE") {
    const tx = action.to.x;
    const ty = action.to.y;
    if (!inBounds(tx, ty)) return state;
    if (getUnitAt(next, tx, ty)) return state;
    if (next.turn.movesRemaining <= 0) return state;

    if (isStunned(me) || isRooted(me)) {
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

    // Check cooldown
    if ((me.cooldowns[spellId] || 0) > 0) return state;

    // Check casts per turn
    const castsThisTurn = me.casts_this_turn[spellId] || 0;
    const maxCasts = spell.casts_per_turn || 1;
    if (castsThisTurn >= maxCasts) return state;

    // Check AP
    const apCost = spell.ap_cost || 0;
    if (next.turn.apRemaining < apCost) return state;

    // Check range
    const d = Math.abs(me.x - target.x) + Math.abs(me.y - target.y);
    const minRange = spell.min_range || 1;
    const maxRange = spell.range || 1;
    if (d < minRange || d > maxRange || d === 0) return state;

    // Check LOS
    if (spell.requires_los && !hasLineOfSightToCell(me.x, me.y, target.x, target.y)) return state;

    // Deduct AP and increment casts
    next.turn.apRemaining -= apCost;
    me.casts_this_turn[spellId] = castsThisTurn + 1;

    // Set cooldown after max casts
    if (me.casts_this_turn[spellId] >= maxCasts) {
      me.cooldowns[spellId] = spell.cooldown || 0;
    }

    pushLog(next, `${pid} casts ${spell.label} (-${apCost} AP, ${next.turn.apRemaining} remaining)`);

    // Spell resolution
    switch (spellId) {
      case "KNOCKBACK_ARROW": {
        const hitUnit = getUnitAt(next, target.x, target.y);
        if (hitUnit) {
          const dmg = rollDamage(spell.damage_min, spell.damage_max);
          dealDamageAt(next, target.x, target.y, dmg, "Knockback Arrow", me);
          if (hitUnit.hp > 0) {
            pushUnitFromWithCollision(next, hitUnit, me.x, me.y, spell.push, spell.collision_damage_per_tile);
          }
        } else {
          pushLog(next, "No target at location");
        }
        return next;
      }

      case "PIERCING_ARROW": {
        const hitUnit = getUnitAt(next, target.x, target.y);
        if (hitUnit) {
          const dmg = rollDamage(spell.damage_min, spell.damage_max);
          dealDamageAt(next, target.x, target.y, dmg, "Piercing Arrow", me);
        } else {
          pushLog(next, "No target at location");
        }
        return next;
      }

      case "EXPONENTIAL_ARROW": {
        const hitUnit = getUnitAt(next, target.x, target.y);
        if (hitUnit) {
          const stage = me.exponential_stage;
          const stageDmg = spell.stage_damage[stage];
          const dmg = rollDamage(stageDmg.min, stageDmg.max);
          dealDamageAt(next, target.x, target.y, dmg, `Exponential Arrow (Stage ${stage})`, me);

          if (me.exponential_stage < 3) {
            me.exponential_stage += 1;
            pushLog(next, `Exponential Arrow advanced to Stage ${me.exponential_stage}!`);
          }
        } else {
          pushLog(next, "No target at location");
        }
        return next;
      }

      case "IMMOBILIZING_ARROW": {
        const hitUnit = getUnitAt(next, target.x, target.y);
        if (hitUnit) {
          const dmg = rollDamage(spell.damage_min, spell.damage_max);
          dealDamageAt(next, target.x, target.y, dmg, "Immobilizing Arrow", me);
          if (hitUnit.hp > 0) {
            const mpRemove = Math.floor(Math.random() * (spell.mp_removal_max - spell.mp_removal_min + 1)) + spell.mp_removal_min;
            if (mpRemove > 0) {
              applyStatus(hitUnit, "mp_reduction", { turns: 1, amount: mpRemove });
              pushLog(next, `${hitUnit.id} loses ${mpRemove} MP for 1 turn!`);
            }
          }
        } else {
          pushLog(next, "No target at location");
        }
        return next;
      }

      case "DISPLACEMENT_ARROW": {
        if (getUnitAt(next, target.x, target.y)) {
          pushLog(next, "Must target empty tile!");
          next.turn.apRemaining += apCost;
          me.casts_this_turn[spellId] = castsThisTurn;
          return state;
        }

        const crossTiles = getCrossTiles(target.x, target.y, spell.cross_range);
        const unitsToPush = [];

        for (const tile of crossTiles) {
          if (inBounds(tile.x, tile.y)) {
            const unitOnTile = getUnitAt(next, tile.x, tile.y);
            if (unitOnTile) {
              unitsToPush.push(unitOnTile);
            }
          }
        }

        for (const unit of unitsToPush) {
          pushUnitFromCenter(next, unit, target.x, target.y, spell.push_distance);
        }

        if (unitsToPush.length === 0) {
          pushLog(next, "No units in displacement area");
        }
        return next;
      }

      case "THIEF_ARROW": {
        const hitUnit = getUnitAt(next, target.x, target.y);
        if (!hitUnit) {
          pushLog(next, "No target at location");
          return next;
        }

        // Step 1: Deal damage
        const dmg = rollDamage(spell.damage_min, spell.damage_max);
        dealDamageAt(next, target.x, target.y, dmg, "Thief Arrow", me);

        if (hitUnit.hp <= 0) return next;

        // Step 2: Roll random effects
        const stealAp = Math.random() < (1.0 / 3.0);
        const giveAp = Math.random() < (1.0 / 3.0);
        const boostCaster = Math.random() < (1.0 / 5.0);
        const boostTarget = Math.random() < (1.0 / 5.0);
        const swapHp = Math.random() < (1.0 / 20.0);

        // Step 3: Apply AP changes
        if (stealAp) {
          pushLog(next, `Stole 1 AP from ${hitUnit.id}!`);
          next.turn.apRemaining += 1;
        }

        if (giveAp) {
          pushLog(next, `Gave 1 AP to ${hitUnit.id}!`);
          next.turn.apRemaining = Math.max(0, next.turn.apRemaining - 1);
        }

        // Step 4: Apply damage modifiers
        if (boostCaster) {
          applyStatus(me, "damage_boost", { turns: 1, percent: 0.20 });
          pushLog(next, `${pid} gains +20% damage next turn!`);
        }

        if (boostTarget) {
          applyStatus(hitUnit, "damage_boost", { turns: 1, percent: 0.20 });
          pushLog(next, `${hitUnit.id} gains +20% damage next turn!`);
        }

        // Step 5: HP swap
        if (swapHp) {
          const myHp = me.hp;
          const theirHp = hitUnit.hp;
          me.hp = theirHp;
          hitUnit.hp = myHp;
          pushLog(next, `HP SWAPPED! ${pid}: ${myHp} -> ${theirHp}, ${hitUnit.id}: ${theirHp} -> ${myHp}`);
          checkWin(next);
        }

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
