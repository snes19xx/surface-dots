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

function reconcileOrder(order, names) {
    var out = []
    for (var i = 0; i < order.length; i++)
        if (names.indexOf(order[i]) !== -1) out.push(order[i])
    for (var j = 0; j < names.length; j++)
        if (out.indexOf(names[j]) === -1) out.push(names[j])
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
