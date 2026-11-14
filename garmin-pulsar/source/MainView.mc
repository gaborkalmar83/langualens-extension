import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// Four screens: 0 HUD, 1 sensors, 2 motion, 3 drive.
class MainView extends WatchUi.View {
    const PAGES = 4;
    const CV = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const LV = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    const RV = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
    var screen = 0;
    hidden var _t = null;   // current theme row
    hidden var _w = 0;
    hidden var _h = 0;

    function initialize() {
        View.initialize();
    }

    function page(step) {
        screen = (screen + step + PAGES) % PAGES;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var app = getApp();
        _t = Themes.current();
        _w = dc.getWidth();
        _h = dc.getHeight();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        dc.setColor(_t[5], _t[0]);
        dc.clear();
        decor(dc);
        if (screen == 0) {
            hud(dc, app);
        } else if (screen == 1) {
            sensors(dc, app.hub, app.workout);
        } else if (screen == 2) {
            motion(dc, app.gestures);
        } else {
            driveScreen(dc, app.workout);
        }
        dots(dc);
        if (app.coach.visible()) { banner(dc, app.coach.msg); }
    }

    hidden function txt(dc, x, y, font, s, color, just) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, just);
    }

    // Small background details that differ per design.
    hidden function decor(dc) {
        var i = Themes.index();
        var cx = _w / 2;
        dc.setColor(_t[4], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        if (i == 0) {
            for (var k = 0; k < 5; k++) {
                var y = _h * 0.70 + k * k * _h * 0.012 + k * _h * 0.02;
                dc.drawLine(0, y, _w, y);
            }
            for (var j = -3; j <= 3; j++) {
                dc.drawLine(cx + j * _w * 0.06, _h * 0.70, cx + j * _w * 0.22, _h);
            }
        } else if (i == 6) {
            var seed = 7;
            for (var s = 0; s < 18; s++) {
                seed = (seed * 73 + 41) % 997;
                var sx = seed % _w;
                seed = (seed * 73 + 41) % 997;
                var sy = seed % _h;
                dc.fillCircle(sx, sy, (s % 5 == 0) ? 2 : 1);
            }
        } else if (i == 8) {
            var a = _w * 0.24;
            var b = _w * 0.05;
            var cy = _h / 2;
            dc.drawLine(cx - a, cy - a, cx - a + b, cy - a);
            dc.drawLine(cx - a, cy - a, cx - a, cy - a + b);
            dc.drawLine(cx + a, cy - a, cx + a - b, cy - a);
            dc.drawLine(cx + a, cy - a, cx + a, cy - a + b);
            dc.drawLine(cx - a, cy + a, cx - a + b, cy + a);
            dc.drawLine(cx - a, cy + a, cx - a, cy + a - b);
            dc.drawLine(cx + a, cy + a, cx + a - b, cy + a);
            dc.drawLine(cx + a, cy + a, cx + a, cy + a - b);
        }
    }

    hidden function dots(dc) {
        var x = _w * 0.045;
        var gap = _h * 0.045;
        var y0 = _h / 2 - gap * (PAGES - 1) / 2;
        for (var i = 0; i < PAGES; i++) {
            dc.setColor(i == screen ? _t[3] : _t[4], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y0 + i * gap, i == screen ? 3 : 2);
        }
    }

    hidden function banner(dc, text) {
        var bw = _w * 0.86;
        var bh = _h * 0.34;
        var x = (_w - bw) / 2;
        var y = (_h - bh) / 2;
        dc.setColor(_t[0], _t[0]);
        dc.fillRoundedRectangle(x, y, bw, bh, 12);
        dc.setPenWidth(3);
        dc.setColor(_t[3], Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, bw, bh, 12);
        dc.setPenWidth(1);
        txt(dc, _w / 2, _h / 2, Graphics.FONT_SMALL, text, _t[5], CV);
    }

    // ---- screen 0: HUD ----
    hidden function hud(dc, app) {
        var w = app.workout;
        var hub = app.hub;
        var cx = _w / 2;
        var cy = _h / 2;
        var rw = (_w * 0.035).toNumber();
        if (rw < 6) { rw = 6; }
        var r1 = _w / 2 - rw / 2 - 3;
        var r2 = r1 - rw - 5;
        var z = hub.zone();

        // outer ring: goal progress (or the running minute when no goal is set)
        var gf = (w.goalType() != 0) ? w.goalFrac() : ((w.timerMs / 1000) % 60) / 60.0;
        Themes.ring(dc, cx, cy, r1, rw, gf, _t[1], _t[4], _t[6]);
        // inner ring: heart rate intensity in zone colour
        Themes.ring(dc, cx, cy, r2, rw, hub.intensity(), Themes.ZONE[z], _t[4], _t[6]);

        var hr = (hub.hr == null) ? "--" : hub.hr.toString();
        txt(dc, cx, _h * 0.21, Graphics.FONT_TINY, "HR " + hr + (z > 0 ? "  Z" + z : ""), Themes.ZONE[z], CV);

        var big = (w.timerMs >= 3600000) ? Graphics.FONT_NUMBER_MILD : Graphics.FONT_NUMBER_MEDIUM;
        txt(dc, cx, _h * 0.40, big, Fmt.time(w.timerMs), _t[5], CV);

        var bike = (w.sport() == 3);
        var lx = cx - _w * 0.19;
        var rx = cx + _w * 0.19;
        txt(dc, lx, _h * 0.60, Graphics.FONT_SMALL, Fmt.dist(w.dist), _t[1], CV);
        txt(dc, lx, _h * 0.70, Graphics.FONT_XTINY, Cfg.metric() ? "KM" : "MI", _t[2], CV);
        txt(dc, rx, _h * 0.60, Graphics.FONT_SMALL, bike ? Fmt.speed(hub.speed) : Fmt.pace(hub.speed), _t[1], CV);
        txt(dc, rx, _h * 0.70, Graphics.FONT_XTINY, bike ? (Cfg.metric() ? "KM/H" : "MPH") : "PACE", _t[2], CV);

        var line;
        if (w.state == Workout.REC) {
            line = "REC  " + w.live + " PTS";
        } else if (w.state == Workout.PAUSED) {
            line = "PAUSED";
        } else {
            var streak = w.stored("streak", 0);
            line = Opt.SPORTS[w.sport()].toUpper() + (streak > 0 ? "  STREAK " + streak : "  READY");
        }
        if (Cfg.on("compass") && hub.heading != null) { line = Fmt.cardinal(hub.heading) + "  " + line; }
        txt(dc, cx, _h * 0.81, Graphics.FONT_XTINY, line, w.state == Workout.PAUSED ? _t[3] : _t[5], CV);

        // GPS dot: grey off, accent searching, green locked
        if (Cfg.on("useGps")) {
            dc.setColor(hub.gpsQuality >= 3 ? 0x00FF55 : _t[3], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h * 0.895, 3);
        }
    }

    // ---- screen 1: every sensor ----
    hidden function sensors(dc, hub, w) {
        var cx = _w / 2;
        txt(dc, cx, _h * 0.11, Graphics.FONT_XTINY, "SENSORS", _t[3], CV);
        var names = ["ALT", "ASC", "TEMP", "BARO", "HDG", "O2", "CAD", "PWR", "BODY", "STRS", "RESP", "STEP"];
        var vals = [
            Fmt.n(hub.altitude, "m"), Fmt.n(w.ascent, "m"),
            Fmt.n(hub.temp, "C"), (hub.pressure == null) ? "--" : (hub.pressure / 100).toNumber().toString(),
            (hub.heading == null) ? "--" : Fmt.cardinal(hub.heading), Fmt.n(hub.spo2, "%"),
            Fmt.n(hub.cadence, ""), Fmt.n(hub.power, "W"),
            Fmt.n(hub.bodyBattery, "%"), Fmt.n(hub.stress, ""),
            Fmt.n(hub.resp, ""), Fmt.n(hub.steps, "")
        ];
        for (var i = 0; i < 12; i++) {
            var col = i % 2;
            var row = i / 2;
            var x = cx + (col == 0 ? -1 : 1) * _w * 0.21;
            var y = _h * 0.23 + row * _h * 0.115;
            txt(dc, x - 3, y, Graphics.FONT_XTINY, names[i], _t[2], RV);
            txt(dc, x + 3, y, Graphics.FONT_XTINY, vals[i], _t[5], LV);
        }
    }

    // ---- screen 2: motion and gestures ----
    hidden function motion(dc, g) {
        var cx = _w / 2;
        txt(dc, cx, _h * 0.11, Graphics.FONT_XTINY, "MOTION", _t[3], CV);
        var m = g.mags;
        var n = m.size();
        var gw = _w * 0.6;
        var base = _h * 0.46;
        var maxH = _h * 0.22;
        dc.setColor(_t[4], Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - gw / 2, base, cx + gw / 2, base);
        if (n > 0) {
            var bw = gw / n;
            for (var i = 0; i < n; i++) {
                var hgt = m[i] / 3000.0 * maxH;
                if (hgt > maxH) { hgt = maxH; }
                dc.setColor(m[i] > 1700 ? _t[2] : _t[1], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - gw / 2 + i * bw, base - hgt, (bw > 2) ? bw - 1 : 1, hgt);
            }
        } else {
            txt(dc, cx, _h * 0.36, Graphics.FONT_XTINY, g.active ? "..." : "NO MOTION SENSOR", _t[2], CV);
        }
        txt(dc, cx, _h * 0.54, Graphics.FONT_XTINY, "SPIN " + g.spin.toNumber() + "  LAST " + g.last, _t[5], CV);
        var on = Cfg.on("gestures");
        txt(dc, cx, _h * 0.64, Graphics.FONT_XTINY, on ? ("SHAKE: " + Opt.label("gShake")) : "GESTURES OFF", _t[1], CV);
        if (on) {
            txt(dc, cx, _h * 0.73, Graphics.FONT_XTINY, "TWIST: " + Opt.label("gTwist"), _t[1], CV);
            txt(dc, cx, _h * 0.82, Graphics.FONT_XTINY, "FLIP: " + Opt.label("gFlip"), _t[1], CV);
        }
    }

    // ---- screen 3: drive score, zones, streak ----
    hidden function driveScreen(dc, w) {
        var cx = _w / 2;
        var cy = _h / 2;
        var rw = (_w * 0.045).toNumber();
        var score = (w.state == Workout.IDLE) ? w.live : w.drive;
        Themes.ring(dc, cx, cy, _w / 2 - rw / 2 - 3, rw, score / 100.0, _t[2], _t[4], _t[6]);
        txt(dc, cx, _h * 0.17, Graphics.FONT_XTINY, "DRIVE", _t[3], CV);
        txt(dc, cx, _h * 0.32, Graphics.FONT_NUMBER_MEDIUM, score.toString(), _t[5], CV);

        // time in zone bars
        var total = 0;
        for (var i = 1; i <= 5; i++) { total += w.zoneSecs[i]; }
        var bw = _w * 0.09;
        var gap = _w * 0.025;
        var x0 = cx - (5 * bw + 4 * gap) / 2;
        var base = _h * 0.70;
        var maxH = _h * 0.20;
        for (var z = 1; z <= 5; z++) {
            var f = (total > 0) ? w.zoneSecs[z].toFloat() / total : 0.0;
            var x = x0 + (z - 1) * (bw + gap);
            dc.setColor(_t[4], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, base - maxH, bw, maxH);
            dc.setColor(Themes.ZONE[z], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, base - maxH * f, bw, maxH * f + 2);
        }
        txt(dc, cx, _h * 0.79, Graphics.FONT_XTINY,
            "STREAK " + w.stored("streak", 0) + "  TOTAL " + w.stored("sessions", 0), _t[5], CV);
    }
}

// Number and unit formatting.
module Fmt {
    function time(ms) {
        var s = ms / 1000;
        var h = s / 3600;
        var m = (s % 3600) / 60;
        var sec = s % 60;
        if (h > 0) { return h + ":" + m.format("%02d") + ":" + sec.format("%02d"); }
        return m.format("%02d") + ":" + sec.format("%02d");
    }

    function dist(m) {
        var d = Cfg.metric() ? m / 1000.0 : m / 1609.344;
        return d.format("%.2f");
    }

    function pace(speed) {
        if (speed == null || speed < 0.4) { return "--:--"; }
        var secs = ((Cfg.metric() ? 1000.0 : 1609.344) / speed).toNumber();
        if (secs > 5999) { return "--:--"; }
        return (secs / 60) + ":" + (secs % 60).format("%02d");
    }

    function speed(speed) {
        if (speed == null) { return "--"; }
        return (speed * (Cfg.metric() ? 3.6 : 2.23694)).format("%.1f");
    }

    function n(v, unit) {
        if (v == null) { return "--"; }
        return v.toNumber().toString() + unit;
    }

    function cardinal(rad) {
        var deg = (rad * 180 / Math.PI).toNumber();
        while (deg < 0) { deg += 360; }
        deg = deg % 360;
        var names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return names[((deg + 22) / 45) % 8] + " " + deg;
    }
}
