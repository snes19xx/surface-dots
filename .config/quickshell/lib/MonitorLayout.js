.pragma library

// odd transforms are rotated 90
function logicalSize(m) {
    var s = m.scale > 0 ? m.scale : 1
    var w = Math.ceil(m.width / s)
    var h = Math.ceil(m.height / s)
    return (m.transform & 1) === 1 ? { w: h, h: w } : { w: w, h: h }
}

function place(list, startX) {
    var x = startX || 0
    var out = []
    for (var i = 0; i < list.length; i++) {
        out.push({ name: list[i].name, x: x, y: 0 })
        x += logicalSize(list[i]).w
    }
    return out
}

// connector names swap between boots
function reconcileOrder(order, names, rank) {
    rank = rank || function () { return Infinity }
    var out = []
    for (var i = 0; i < order.length; i++)
        if (names.indexOf(order[i]) !== -1) out.push(order[i])
    var fresh = names.filter(function (n) { return out.indexOf(n) === -1 })
        .map(function (n, k) { return { n: n, r: rank(n), k: k } })
        .sort(function (a, b) { return a.r === b.r ? a.k - b.k : (a.r < b.r ? -1 : 1) })
    for (var j = 0; j < fresh.length; j++) {
        var at = out.length
        for (var p = 0; p < out.length; p++)
            if (rank(out[p]) > fresh[j].r) { at = p; break }
        out.splice(at, 0, fresh[j].n)
    }
    return out
}

function move(order, name, dir) {
    var out = order.slice()
    var i = out.indexOf(name)
    var j = i + dir
    if (i === -1 || j < 0 || j >= out.length) return out
    var t = out[i]
    out[i] = out[j]
    out[j] = t
    return out
}

// others keep their order
function moveTo(order, name, index) {
    var out = order.slice()
    var i = out.indexOf(name)
    if (i === -1) return out
    out.splice(i, 1)
    out.splice(Math.max(0, Math.min(index, out.length)), 0, name)
    return out
}

function pairKey(descs) {
    return descs.slice().sort().join(" + ")
}

// null for "preferred" and such
function parseMode(mode) {
    var p = /^(\d+)x(\d+)@(\d+(?:\.\d+)?)$/.exec(String(mode || ""))
    return p ? { width: Number(p[1]), height: Number(p[2]), hz: Number(p[3]) } : null
}

// saved values over live ones
function target(m, saved, transform) {
    var t = {
        name: m.name, width: m.width, height: m.height,
        mode: m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2),
        scale: m.scale, transform: m.transform
    }
    var p = saved ? parseMode(saved.mode) : null
    if (p) { t.width = p.width; t.height = p.height; t.mode = saved.mode }
    if (saved && saved.scale > 0) t.scale = saved.scale
    if (transform !== undefined) t.transform = transform
    return t
}
