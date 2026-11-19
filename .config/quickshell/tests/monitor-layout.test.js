const test = require("node:test")
const assert = require("node:assert")
const fs = require("node:fs")
const path = require("node:path")

const src = fs.readFileSync(path.join(__dirname, "../lib/MonitorLayout.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "")
const L = new Function(src + "; return { logicalSize, place, reconcileOrder, move, moveTo, pairKey, parseMode, target }")()

const mon = (name, width, height, scale, transform) => ({ name, width, height, scale, transform })

test("logicalSize divides by scale and rounds up", () => {
    assert.deepStrictEqual(L.logicalSize(mon("a", 3840, 2160, 1.33, 0)), { w: 2888, h: 1625 })
})

test("logicalSize swaps for 90 and 270, not 180", () => {
    assert.deepStrictEqual(L.logicalSize(mon("a", 1920, 1080, 1, 1)), { w: 1080, h: 1920 })
    assert.deepStrictEqual(L.logicalSize(mon("a", 1920, 1080, 1, 3)), { w: 1080, h: 1920 })
    assert.deepStrictEqual(L.logicalSize(mon("a", 1920, 1080, 1, 2)), { w: 1920, h: 1080 })
    assert.deepStrictEqual(L.logicalSize(mon("a", 1920, 1080, 1, 5)), { w: 1080, h: 1920 })
})

test("logicalSize treats a missing scale as 1", () => {
    assert.deepStrictEqual(L.logicalSize(mon("a", 100, 50, 0, 0)), { w: 100, h: 50 })
})

test("place lays screens out left to right with the rotated width", () => {
    const spots = L.place([mon("tv", 1920, 1080, 1, 0), mon("side", 1920, 1080, 1, 1), mon("x", 1000, 500, 1, 0)], 0)
    assert.deepStrictEqual(spots, [
        { name: "tv", x: 0, y: 0 },
        { name: "side", x: 1920, y: 0 },
        { name: "x", x: 3000, y: 0 },
    ])
})

test("place honours a start offset and empty input", () => {
    assert.deepStrictEqual(L.place([], 0), [])
    assert.deepStrictEqual(L.place([mon("a", 10, 10, 1, 0)], 5), [{ name: "a", x: 5, y: 0 }])
})

test("reconcileOrder drops gone names and appends new ones", () => {
    assert.deepStrictEqual(L.reconcileOrder(["a", "b"], ["b", "c"]), ["b", "c"])
    assert.deepStrictEqual(L.reconcileOrder([], ["x", "y"]), ["x", "y"])
    assert.deepStrictEqual(L.reconcileOrder(["a"], []), [])
})

test("reconcileOrder places new names by rank, whatever the connector order", () => {
    const rank = n => ({ left: 0, right: 1 })[n] ?? Infinity
    assert.deepStrictEqual(L.reconcileOrder([], ["right", "left"], rank), ["left", "right"])
    // replugged left goes back first
    assert.deepStrictEqual(L.reconcileOrder(["right"], ["right", "left"], rank), ["left", "right"])
    // unranked last, picked slots kept
    assert.deepStrictEqual(L.reconcileOrder([], ["tv", "right", "left"], rank), ["left", "right", "tv"])
    assert.deepStrictEqual(L.reconcileOrder(["right", "left"], ["right", "left"], rank), ["right", "left"])
})

test("move swaps with the neighbour and stops at the ends", () => {
    assert.deepStrictEqual(L.move(["a", "b", "c"], "b", -1), ["b", "a", "c"])
    assert.deepStrictEqual(L.move(["a", "b", "c"], "b", 1), ["a", "c", "b"])
    assert.deepStrictEqual(L.move(["a", "b"], "a", -1), ["a", "b"])
    assert.deepStrictEqual(L.move(["a", "b"], "b", 1), ["a", "b"])
    assert.deepStrictEqual(L.move(["a", "b"], "zzz", 1), ["a", "b"])
})

test("move does not mutate its input", () => {
    const o = ["a", "b"]
    L.move(o, "a", 1)
    assert.deepStrictEqual(o, ["a", "b"])
})

test("moveTo puts a screen in the left, center or right slot", () => {
    assert.deepStrictEqual(L.moveTo(["a", "b", "c"], "c", 0), ["c", "a", "b"])
    assert.deepStrictEqual(L.moveTo(["a", "b", "c"], "a", 1), ["b", "a", "c"])
    assert.deepStrictEqual(L.moveTo(["a", "b", "c"], "a", 2), ["b", "c", "a"])
    assert.deepStrictEqual(L.moveTo(["a", "b"], "a", 1), ["b", "a"])
})

test("moveTo clamps the slot, ignores unknown names and does not mutate", () => {
    const o = ["a", "b", "c"]
    assert.deepStrictEqual(L.moveTo(o, "a", 9), ["b", "c", "a"])
    assert.deepStrictEqual(L.moveTo(o, "a", -4), ["a", "b", "c"])
    assert.deepStrictEqual(L.moveTo(o, "zzz", 0), ["a", "b", "c"])
    assert.deepStrictEqual(o, ["a", "b", "c"])
})

test("pairKey is order independent", () => {
    assert.strictEqual(L.pairKey(["Z", "A"]), "A + Z")
    assert.strictEqual(L.pairKey(["A", "Z"]), "A + Z")
})

test("parseMode reads size and rate, and rejects anything else", () => {
    assert.deepStrictEqual(L.parseMode("1920x1200@120"), { width: 1920, height: 1200, hz: 120 })
    assert.deepStrictEqual(L.parseMode("1920x1080@143.85"), { width: 1920, height: 1080, hz: 143.85 })
    assert.strictEqual(L.parseMode("preferred"), null)
    assert.strictEqual(L.parseMode(undefined), null)
})

const live = { name: "eDP-1", width: 1920, height: 1200, refreshRate: 60.001, scale: 1, transform: 0 }

test("target keeps the live mode when nothing is saved", () => {
    assert.deepStrictEqual(L.target(live, undefined, undefined), {
        name: "eDP-1", width: 1920, height: 1200, mode: "1920x1200@60.00", scale: 1, transform: 0,
    })
})

test("target lays the saved mode, scale and rotation over the live screen", () => {
    assert.deepStrictEqual(L.target(live, { mode: "2560x1600@120", scale: 1.5 }, 3), {
        name: "eDP-1", width: 2560, height: 1600, mode: "2560x1600@120", scale: 1.5, transform: 3,
    })
})

test("target ignores a broken saved mode and a missing scale", () => {
    const t = L.target(live, { mode: "garbage" }, undefined)
    assert.strictEqual(t.mode, "1920x1200@60.00")
    assert.strictEqual(t.scale, 1)
})

test("place uses the target size, so a saved rotation moves the next screen", () => {
    const a = L.target({ name: "a", width: 1920, height: 1080, refreshRate: 60, scale: 1, transform: 0 }, undefined, 1)
    const b = L.target({ name: "b", width: 1920, height: 1080, refreshRate: 60, scale: 1, transform: 0 }, undefined, undefined)
    assert.deepStrictEqual(L.place([a, b], 0), [{ name: "a", x: 0, y: 0 }, { name: "b", x: 1080, y: 0 }])
})
