const test = require("node:test")
const assert = require("node:assert")
const fs = require("node:fs")
const path = require("node:path")

const src = fs.readFileSync(path.join(__dirname, "../lib/MonitorLayout.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "")
const L = new Function(src + "; return { logicalSize, place, reconcileOrder, move, pairKey }")()

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

test("pairKey is order independent", () => {
    assert.strictEqual(L.pairKey(["Z", "A"]), "A + Z")
    assert.strictEqual(L.pairKey(["A", "Z"]), "A + Z")
})
