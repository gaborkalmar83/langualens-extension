import Toybox.Graphics;
import Toybox.Lang;

// 10 designs. Each row: background, primary, secondary, accent, dim, text, ring style.
// Ring styles: 0 solid, 1 segments, 2 dots, 3 twin lines, 4 blocks.
module Themes {
    const NAMES = ["Neon Grid", "Plasma", "Reactor", "Solar Flare", "Ice Core",
                   "Crimson Ops", "Deep Space", "Hologram", "Stealth", "Aurora"];
    const DATA = [
        [0x000000, 0x00E5FF, 0xFF00AA, 0xFFFF00, 0x003844, 0xFFFFFF, 1],
        [0x0A0014, 0xC000FF, 0xFF3399, 0x00FFFF, 0x2A0044, 0xFFFFFF, 0],
        [0x000800, 0x00FF55, 0xAAFF00, 0xFFFFFF, 0x003311, 0xCCFFCC, 2],
        [0x0A0400, 0xFF6600, 0xFFCC00, 0xFFFFFF, 0x442200, 0xFFEECC, 0],
        [0x000A14, 0xAAEEFF, 0x55AAFF, 0xFFFFFF, 0x113355, 0xFFFFFF, 3],
        [0x000000, 0xFF0033, 0xAAAAAA, 0xFFFFFF, 0x440011, 0xFFFFFF, 1],
        [0x02001E, 0x5566FF, 0x00FFCC, 0xFFAAFF, 0x151555, 0xDDDDFF, 2],
        [0x000A0A, 0x00FFDD, 0xAA77FF, 0xFFFFFF, 0x004444, 0xCCFFFF, 3],
        [0x000000, 0xAAAAAA, 0x555555, 0xFFAA00, 0x222222, 0xFFFFFF, 4],
        [0x000510, 0x00FF99, 0x3388FF, 0xCC66FF, 0x003333, 0xFFFFFF, 4]
    ];
    const ZONE = [0x777777, 0x999999, 0x00AAFF, 0x00FF55, 0xFFAA00, 0xFF0055];

    function index() {
        var i = Cfg.num("theme", 0);
        if (i < 0 || i >= DATA.size()) { i = 0; }
        return i;
    }

    function current() {
        return DATA[index()];
    }

    function next() {
        Cfg.set("theme", (index() + 1) % DATA.size());
    }

    // Progress ring that starts at 12 o'clock and runs clockwise.
    function ring(dc, cx, cy, r, w, frac, color, dim, style) {
        if (frac < 0) { frac = 0.0; }
        if (frac > 1) { frac = 1.0; }
        if (style == 2) {
            var n = 48;
            var lit = (frac * n + 0.5).toNumber();
            var dr = (w / 2 > 2) ? w / 2 : 2;
            for (var i = 0; i < n; i++) {
                var a = Math.PI * 2 * i / n - Math.PI / 2;
                dc.setColor(i < lit ? color : dim, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx + r * Math.cos(a), cy + r * Math.sin(a), i < lit ? dr : dr - 1);
            }
            return;
        }
        if (style == 1 || style == 4) {
            var segs = (style == 1) ? 40 : 12;
            var gap = (style == 1) ? 3 : 6;
            var step = 360.0 / segs;
            var on = (frac * segs + 0.5).toNumber();
            dc.setPenWidth(w);
            for (var j = 0; j < segs; j++) {
                var s = 90 - j * step - gap / 2.0;
                var e = 90 - (j + 1) * step + gap / 2.0;
                dc.setColor(j < on ? color : dim, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, norm(s), norm(e));
            }
            dc.setPenWidth(1);
            return;
        }
        var sweep = (frac * 360).toNumber();
        if (style == 3) {
            var t = (w / 4 > 1) ? w / 4 : 1;
            dc.setPenWidth(t);
            dc.setColor(dim, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r + w / 2 - 1);
            dc.drawCircle(cx, cy, r - w / 2 + 1);
            if (sweep > 0) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                arc(dc, cx, cy, r + w / 2 - 1, sweep);
                arc(dc, cx, cy, r - w / 2 + 1, sweep);
            }
            dc.setPenWidth(1);
            return;
        }
        dc.setPenWidth(w);
        dc.setColor(dim, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        if (sweep > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            arc(dc, cx, cy, r, sweep);
        }
        dc.setPenWidth(1);
    }

    function arc(dc, cx, cy, r, sweep) {
        if (sweep >= 360) {
            dc.drawCircle(cx, cy, r);
        } else {
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, norm(90 - sweep));
        }
    }

    function norm(a) {
        var n = a.toNumber();
        while (n < 0) { n += 360; }
        return n % 360;
    }
}
