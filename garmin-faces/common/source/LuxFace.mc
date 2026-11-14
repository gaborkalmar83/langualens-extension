import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Shared renderer for the Maison collection.
// Each watch face supplies its look in Style.C (see <face>/source/Style.mc).
class LuxApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new LuxFace()];
    }
}

class LuxFace extends WatchUi.WatchFace {
    const CV = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden var _sleep = false;
    hidden var c = null;
    hidden var cx = 0;
    hidden var cy = 0;
    hidden var r = 0;

    function initialize() {
        WatchFace.initialize();
        c = Style.C;
    }

    function onEnterSleep() {
        _sleep = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _sleep = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        cx = dc.getWidth() / 2;
        cy = dc.getHeight() / 2;
        r = (cx < cy) ? cx : cy;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var t = System.getClockTime();
        var set = System.getDeviceSettings();

        // OLED screens: when asleep draw thin outlines only, to protect the display
        if (_sleep && (set has :requiresBurnInProtection) && set.requiresBurnInProtection) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            if (c[:digital] || c[:layout] != 0) {
                dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy, Graphics.FONT_NUMBER_MILD, timeText(t, set), CV);
            } else {
                hands(dc, t, 0x888888, true);
            }
            return;
        }

        dc.setColor(c[:txt], c[:bg]);
        dc.clear();
        pattern(dc);
        if (c[:layout] != 0) {
            if (c[:bezel]) { bezel(dc); }
            art(dc, t, set);
            return;
        }
        bezel(dc);
        indices(dc);
        var top = c[:digital] ? 0.56 : 0.38;
        text(dc, cx, cy - r * top, Graphics.FONT_XTINY, c[:mark], c[:metal]);
        sub(dc, c[:left], cx - r * 0.44, cy);
        sub(dc, c[:right], cx + r * 0.44, cy);
        sub(dc, c[:bottom], cx, cy + r * 0.44);
        var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        if (c[:digital]) {
            text(dc, cx, cy - r * 0.34, Graphics.FONT_XTINY,
                d.day_of_week.toUpper() + " " + d.day + " " + d.month.toUpper(), c[:txt]);
            text(dc, cx, cy - r * 0.04, Graphics.FONT_NUMBER_HOT, timeText(t, set), c[:metal]);
        } else {
            if (c[:date]) { dateWindow(dc, d.day); }
            hands(dc, t, c[:hand], false);
        }
    }

    hidden function timeText(t, set) {
        var h = t.hour;
        if (!set.is24Hour) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return h.format("%02d") + ":" + t.min.format("%02d");
    }

    hidden function text(dc, x, y, font, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, CV);
    }

    // Point at distance d along the angle (0 = 12 o'clock, clockwise) and o sideways.
    hidden function pt(a, d, o) {
        var s = Math.sin(a);
        var k = Math.cos(a);
        return [cx + d * s + o * k, cy - d * k + o * s];
    }

    hidden function bar(dc, a, d0, d1, hw, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([pt(a, d0, hw), pt(a, d1, hw), pt(a, d1, -hw), pt(a, d0, -hw)]);
    }

    // ---- dial texture ----
    hidden function pattern(dc) {
        var p = c[:pattern];
        dc.setColor(c[:pat], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        if (p == 1) {            // sunburst
            for (var i = 0; i < 72; i++) {
                var a = Math.PI * 2 * i / 72;
                var p0 = pt(a, r * 0.08, 0);
                var p1 = pt(a, r * 0.90, 0);
                dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
            }
        } else if (p == 2) {     // guilloche rings
            for (var q = 3; q <= 17; q++) {
                dc.drawCircle(cx, cy, r * q * 0.05);
            }
        } else if (p == 3) {     // carbon weave
            var step = r / 9;
            for (var k = -18; k <= 18; k++) {
                dc.drawLine(cx + k * step - r, cy - r, cx + k * step + r, cy + r);
                dc.drawLine(cx + k * step + r, cy - r, cx + k * step - r, cy + r);
            }
        } else if (p == 4) {     // night sky
            var seed = 11;
            for (var s = 0; s < 60; s++) {
                seed = (seed * 73 + 41) % 997;
                var sx = cx - r + (seed * 2 * r) / 997;
                seed = (seed * 73 + 41) % 997;
                var sy = cy - r + (seed * 2 * r) / 997;
                dc.setColor((s % 6 == 0) ? c[:metal] : c[:pat], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx, sy, (s % 9 == 0) ? 2 : 1);
            }
        } else if (p == 6) {     // skeleton gears
            var gears = [[-0.30, -0.28, 0.26], [0.34, -0.20, 0.20], [0.30, 0.30, 0.24], [-0.36, 0.26, 0.16], [0.0, 0.0, 0.14]];
            dc.setPenWidth(2);
            for (var g = 0; g < gears.size(); g++) {
                var gx = cx + r * gears[g][0];
                var gy = cy + r * gears[g][1];
                var gr = r * gears[g][2];
                dc.drawCircle(gx, gy, gr);
                dc.drawCircle(gx, gy, gr * 0.82);
                dc.drawCircle(gx, gy, gr * 0.28);
                for (var sp = 0; sp < 6; sp++) {
                    var ga = Math.PI * sp / 3 + g;
                    dc.drawLine(gx + gr * 0.28 * Math.sin(ga), gy - gr * 0.28 * Math.cos(ga),
                                gx + gr * 0.82 * Math.sin(ga), gy - gr * 0.82 * Math.cos(ga));
                }
            }
            dc.setPenWidth(1);
        } else if (p == 5) {     // pinstripes
            var gap = r / 8;
            for (var v = -8; v <= 8; v++) {
                dc.drawLine(cx + v * gap, cy - r, cx + v * gap, cy + r);
            }
        }
    }

    hidden function bezel(dc) {
        var bw = (r * 0.05).toNumber();
        if (bw < 3) { bw = 3; }
        dc.setPenWidth(bw);
        dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r - bw / 2);
        dc.setPenWidth(1);
        dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r - bw - 2);
        for (var i = 0; i < 60; i++) {
            if (i % 5 != 0) {
                var a = Math.PI * 2 * i / 60;
                var p0 = pt(a, r * 0.86, 0);
                var p1 = pt(a, r * 0.90, 0);
                dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
            }
        }
    }

    // ---- hour markers: 0 batons, 1 roman, 2 gems, 3 arabic ----
    hidden function indices(dc) {
        var st = c[:index];
        var roman = ["XII", "III", "VI", "IX"];
        var arab = ["12", "3", "6", "9"];
        for (var h = 0; h < 12; h++) {
            var a = Math.PI * 2 * h / 12;
            var quarter = (h % 3 == 0);
            var taken = (h == 3 && (c[:right] != 0 || c[:date])) || (h == 6 && c[:bottom] != 0) || (h == 9 && c[:left] != 0);
            if (c[:digital] && !quarter) { continue; }
            if (st == 2) {
                var g = pt(a, r * 0.78, 0);
                dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(g[0], g[1], r * (quarter ? 0.045 : 0.028));
                dc.setColor(c[:txt], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(g[0], g[1], r * (quarter ? 0.022 : 0.012));
            } else if ((st == 1 || st == 3) && quarter && !taken && !c[:digital]) {
                var n = pt(a, r * 0.72, 0);
                text(dc, n[0], n[1], (st == 1) ? Graphics.FONT_TINY : Graphics.FONT_SMALL,
                    (st == 1) ? roman[h / 3] : arab[h / 3], c[:metal]);
            } else {
                var inner = (taken && c[:date] && h == 3) ? 0.80 : (quarter ? 0.68 : 0.73);
                bar(dc, a, r * inner, r * 0.84, r * (quarter ? 0.028 : 0.014), c[:metal]);
                if (h == 0 && st == 0) {
                    bar(dc, a, r * 0.68, r * 0.84, r * 0.008, c[:bg]);
                }
            }
        }
    }

    hidden function dateWindow(dc, day) {
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var bw = fh * 1.5;
        var x = cx + r * 0.62 - bw / 2;
        var y = cy - fh / 2;
        dc.setColor(c[:sub], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, bw, fh);
        dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, bw, fh);
        text(dc, x + bw / 2, cy, Graphics.FONT_XTINY, day.toString(), c[:txt]);
    }

    // ---- sub-dials: 1 power reserve, 2 moon phase, 3 steps, 4 heart rate, 5 small seconds ----
    hidden function sub(dc, kind, x, y) {
        if (kind == 0) { return; }
        var rs = r * 0.23;
        dc.setColor(c[:sub], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, rs);
        if (kind == 2) { moon(dc, x, y, rs); }
        dc.setPenWidth(1);
        dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, rs);
        if (kind == 1 || kind == 3) {
            var f = 0.0;
            var label = "";
            if (kind == 1) {
                var b = System.getSystemStats().battery;
                f = b / 100.0;
                label = b.toNumber().toString();
            } else {
                var m = ActivityMonitor.getInfo();
                var steps = (m.steps == null) ? 0 : m.steps;
                var goal = (m.stepGoal == null || m.stepGoal == 0) ? 10000 : m.stepGoal;
                f = steps.toFloat() / goal;
                label = (steps >= 1000) ? (steps / 1000.0).format("%.1f") + "K" : steps.toString();
            }
            if (f > 1) { f = 1.0; }
            var pw = (rs * 0.16).toNumber();
            if (pw < 2) { pw = 2; }
            dc.setPenWidth(pw);
            dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, rs * 0.78, Graphics.ARC_CLOCKWISE, 225, 315);
            if (f > 0.02) {
                dc.setColor(c[:accent], Graphics.COLOR_TRANSPARENT);
                var end = (225 - 270 * f).toNumber();
                if (end < 0) { end += 360; }
                dc.drawArc(x, y, rs * 0.78, Graphics.ARC_CLOCKWISE, 225, end);
            }
            dc.setPenWidth(1);
            text(dc, x, y, Graphics.FONT_XTINY, label, c[:txt]);
        } else if (kind == 4) {
            var info = Activity.getActivityInfo();
            var hr = (info == null || info.currentHeartRate == null) ? "--" : info.currentHeartRate.toString();
            text(dc, x, y, Graphics.FONT_XTINY, hr, c[:txt]);
            dc.setColor(c[:accent], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y + rs * 0.68, rs * 0.09);
        } else if (kind == 5) {
            dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 12; i++) {
                var a = Math.PI * 2 * i / 12;
                dc.drawLine(x + rs * 0.78 * Math.sin(a), y - rs * 0.78 * Math.cos(a),
                            x + rs * 0.95 * Math.sin(a), y - rs * 0.95 * Math.cos(a));
            }
            if (!_sleep) {
                var sa = Math.PI * 2 * System.getClockTime().sec / 60;
                dc.setPenWidth(2);
                dc.setColor(c[:accent], Graphics.COLOR_TRANSPARENT);
                dc.drawLine(x - rs * 0.2 * Math.sin(sa), y + rs * 0.2 * Math.cos(sa),
                            x + rs * 0.8 * Math.sin(sa), y - rs * 0.8 * Math.cos(sa));
                dc.setPenWidth(1);
            }
            dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 2);
        }
    }

    hidden function moon(dc, x, y, rs) {
        // days since the new moon of 6 January 2000, 18:14 UTC
        var days = (Time.now().value() - 947182440) / 86400.0;
        var p = days / 29.530588;
        p = p - Math.floor(p);
        var mr = rs * 0.55;
        dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, mr);
        // lit part: outer limb on one side, curved shadow edge on the other
        var side = (p < 0.5) ? 1 : -1;
        var k = Math.cos(Math.PI * 2 * p);
        var pts = [];
        for (var i = 0; i <= 12; i++) {
            var t = -Math.PI / 2 + Math.PI * i / 12;
            pts.add([x + side * mr * Math.cos(t), y + mr * Math.sin(t)]);
        }
        for (var j = 12; j >= 0; j--) {
            var u = -Math.PI / 2 + Math.PI * j / 12;
            pts.add([x + side * k * mr * Math.cos(u), y + mr * Math.sin(u)]);
        }
        dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    // ---- hands: 0 dauphine, 1 baton, 2 sword ----
    hidden function shape(a, len, hw, tail) {
        var st = c[:hands];
        if (st == 1) {
            return [pt(a, -tail, hw * 0.7), pt(a, len, hw * 0.7), pt(a, len, -hw * 0.7), pt(a, -tail, -hw * 0.7)];
        }
        if (st == 2) {
            return [pt(a, -tail, hw * 0.5), pt(a, len * 0.82, hw), pt(a, len, 0), pt(a, len * 0.82, -hw), pt(a, -tail, -hw * 0.5)];
        }
        return [pt(a, -tail, 0), pt(a, len * 0.28, hw), pt(a, len, 0), pt(a, len * 0.28, -hw)];
    }

    hidden function hand(dc, a, len, hw, color, outline) {
        var pts = shape(a, len, hw, r * 0.10);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (outline) {
            dc.setPenWidth(1);
            for (var i = 0; i < pts.size(); i++) {
                var n = pts[(i + 1) % pts.size()];
                dc.drawLine(pts[i][0], pts[i][1], n[0], n[1]);
            }
            return;
        }
        dc.fillPolygon(pts);
        if (c[:lume] != null) {
            bar(dc, a, len * 0.35, len * 0.78, hw * 0.35, c[:lume]);
        }
    }

    hidden function hands(dc, t, color, outline) {
        var ha = Math.PI * 2 * ((t.hour % 12) + t.min / 60.0) / 12;
        var ma = Math.PI * 2 * t.min / 60;
        hand(dc, ha, r * 0.50, r * 0.055, color, outline);
        hand(dc, ma, r * 0.80, r * 0.042, color, outline);
        if (outline) { return; }
        if (!_sleep && c[:sweep]) {
            var sa = Math.PI * 2 * t.sec / 60;
            var p0 = pt(sa, -r * 0.18, 0);
            var p1 = pt(sa, r * 0.84, 0);
            dc.setPenWidth(2);
            dc.setColor(c[:accent], Graphics.COLOR_TRANSPARENT);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
            dc.fillCircle(p0[0], p0[1], r * 0.03);
            dc.setPenWidth(1);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 0.05);
        dc.setColor(c[:bg], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 0.02);
    }

    // ================= art layouts (c[:layout] 1..10) =================
    hidden function ring(dc, x, y, rad, f0, f1, pw, color) {
        var a0 = (90 - 360 * f0).toNumber();
        var a1 = (90 - 360 * f1).toNumber();
        if (a0 == a1) { return; }
        while (a0 < 0) { a0 += 360; }
        while (a1 < 0) { a1 += 360; }
        dc.setPenWidth(pw);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, rad, Graphics.ARC_CLOCKWISE, a0 % 360, a1 % 360);
        dc.setPenWidth(1);
    }

    hidden function disc(dc, p, rad, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], rad);
    }

    hidden function art(dc, t, set) {
        var L = c[:layout];
        var v = c[:v];
        var m = t.min;
        var hh = t.hour;
        if (!set.is24Hour) {
            hh = hh % 12;
            if (hh == 0) { hh = 12; }
        }
        var H = hh.format("%02d");
        var M = m.format("%02d");
        var hf = ((t.hour % 12) + m / 60.0) / 12;
        var mf = m / 60.0;
        var TAU = Math.PI * 2;
        var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var date = d.day_of_week.toUpper() + " " + d.day;
        var pw = (r * 0.09).toNumber();

        if (L == 1) {           // orbit: planets instead of hands
            dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r * 0.82);
            dc.drawCircle(cx, cy, r * 0.54);
            if (v == 1) {
                ring(dc, cx, cy, r * 0.82, 0, mf, 3, c[:accent]);
                ring(dc, cx, cy, r * 0.54, 0, hf, 3, c[:metal]);
            }
            for (var i = 0; i < 12; i++) { disc(dc, pt(TAU * i / 12, r * 0.82, 0), r * 0.012, c[:metal2]); }
            disc(dc, pt(TAU * hf, r * 0.54, 0), r * 0.11, c[:metal]);
            if (v == 2) { disc(dc, pt(TAU * hf, r * 0.54, 0), r * 0.05, c[:bg]); }
            disc(dc, pt(TAU * mf, r * 0.82, 0), r * 0.07, c[:accent]);
            disc(dc, [cx, cy], r * 0.22, c[:sub]);
            dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r * 0.22);
            text(dc, cx, cy, Graphics.FONT_SMALL, d.day.toString(), c[:txt]);
        } else if (L == 2) {    // grand numerals: stacked giant digits
            text(dc, cx, cy - r * 0.40, Graphics.FONT_NUMBER_THAI_HOT, H, c[:metal]);
            text(dc, cx, cy + r * 0.40, Graphics.FONT_NUMBER_THAI_HOT, M, c[:txt]);
            dc.setColor(c[:accent], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r * 0.7, cy - 1, r * 0.4, 3);
            dc.fillRectangle(cx + r * 0.3, cy - 1, r * 0.4, 3);
            text(dc, cx, cy, Graphics.FONT_XTINY, (v == 0) ? date : c[:mark], c[:accent]);
        } else if (L == 3) {    // regulator: minutes centre, hours in their own dial
            var hx = cx;
            var hy = cy - r * 0.42;
            var rs = r * 0.30;
            disc(dc, [hx, hy], rs, c[:sub]);
            dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(hx, hy, rs);
            for (var k = 0; k < 12; k++) {
                var a = TAU * k / 12;
                dc.drawLine(hx + rs * 0.80 * Math.sin(a), hy - rs * 0.80 * Math.cos(a), hx + rs * 0.95 * Math.sin(a), hy - rs * 0.95 * Math.cos(a));
            }
            var ha = TAU * hf;
            dc.setPenWidth(3);
            dc.drawLine(hx, hy, hx + rs * 0.62 * Math.sin(ha), hy - rs * 0.62 * Math.cos(ha));
            dc.setPenWidth(1);
            sub(dc, (v == 1) ? 2 : ((v == 2) ? 1 : 5), cx, cy + r * 0.46);
            bar(dc, TAU * mf, -r * 0.12, r * 0.84, r * 0.018, c[:hand]);
            disc(dc, [cx, cy], r * 0.045, c[:hand]);
            text(dc, cx + r * 0.50, cy, Graphics.FONT_XTINY, date, c[:txt]);
        } else if (L == 4) {    // sectors: time as two glowing arcs
            ring(dc, cx, cy, r * 0.88, 0, 0.999, pw, c[:metal2]);
            ring(dc, cx, cy, r * 0.88, 0, mf, pw, c[:accent]);
            ring(dc, cx, cy, r * 0.70, 0, 0.999, pw, c[:sub]);
            ring(dc, cx, cy, r * 0.70, 0, hf, pw, c[:metal]);
            text(dc, cx, cy - r * 0.05, Graphics.FONT_NUMBER_MEDIUM, H + ":" + M, c[:txt]);
            text(dc, cx, cy + r * 0.30, Graphics.FONT_XTINY, date, c[:metal]);
        } else if (L == 5) {    // jump hour: hour in a window, minutes on a scale
            var ww = r * 0.74;
            var wh = r * 0.50;
            dc.setColor(c[:sub], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - ww / 2, cy - r * 0.62, ww, wh, r * 0.06);
            dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(cx - ww / 2, cy - r * 0.62, ww, wh, r * 0.06);
            dc.setPenWidth(1);
            text(dc, cx, cy - r * 0.37, Graphics.FONT_NUMBER_HOT, H, c[:txt]);
            ring(dc, cx, cy, r * 0.80, 0.33, 0.67, 2, c[:metal2]);
            for (var q = 0; q <= 12; q++) {
                var fa = TAU * (0.67 - 0.34 * q / 12);
                var p0 = pt(fa, r * 0.76, 0);
                var p1 = pt(fa, r * 0.84, 0);
                dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
                dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
            }
            disc(dc, pt(TAU * (0.67 - 0.34 * mf), r * 0.80, 0), r * 0.06, c[:accent]);
            text(dc, cx, cy + r * 0.22, Graphics.FONT_MEDIUM, M, c[:metal]);
            text(dc, cx, cy + r * 0.50, Graphics.FONT_XTINY, (v == 0) ? "MINUTES" : date, c[:metal2]);
        } else if (L == 6) {    // words
            var hw = ["TWELVE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN"];
            var ones = ["", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE",
                        "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN", "SEVENTEEN", "EIGHTEEN", "NINETEEN"];
            var tens = ["", "", "TWENTY", "THIRTY", "FORTY", "FIFTY"];
            var mw = "O'CLOCK";
            if (m > 0 && m < 10) { mw = "OH " + ones[m]; }
            if (m >= 10 && m < 20) { mw = ones[m]; }
            if (m >= 20) { mw = tens[m / 10] + ((m % 10 > 0) ? " " + ones[m % 10] : ""); }
            dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - r * 0.6, cy - r * 0.42, cx + r * 0.6, cy - r * 0.42);
            dc.drawLine(cx - r * 0.6, cy + r * 0.36, cx + r * 0.6, cy + r * 0.36);
            text(dc, cx, cy - r * 0.56, Graphics.FONT_XTINY, (v == 2) ? c[:mark] : "IT IS", c[:metal2]);
            text(dc, cx, cy - r * 0.18, Graphics.FONT_LARGE, hw[t.hour % 12], c[:metal]);
            text(dc, cx, cy + r * 0.14, Graphics.FONT_SMALL, mw, c[:txt]);
            text(dc, cx, cy + r * 0.52, Graphics.FONT_XTINY, date, c[:accent]);
        } else if (L == 7) {    // pave: gems light up with the hours, dots with the minutes
            for (var j = 0; j < 60; j++) {
                disc(dc, pt(TAU * j / 60, r * 0.90, 0), (j <= m) ? r * 0.024 : r * 0.012, (j <= m) ? c[:accent] : c[:metal2]);
            }
            var lit = t.hour % 12;
            if (lit == 0) { lit = 12; }
            for (var g = 1; g <= 12; g++) {
                var gp = pt(TAU * g / 12, r * 0.66, 0);
                if (g <= lit) {
                    disc(dc, gp, r * 0.075, c[:metal]);
                    disc(dc, gp, r * 0.03, c[:txt]);
                } else {
                    dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(gp[0], gp[1], r * 0.06);
                }
            }
            text(dc, cx, cy - r * 0.05, Graphics.FONT_NUMBER_MILD, H + ":" + M, c[:txt]);
            text(dc, cx, cy + r * 0.24, Graphics.FONT_XTINY, date, c[:metal]);
        } else if (L == 8) {    // tape: two scales slide under a fixed pointer
            var bh = r * 0.34;
            dc.setColor(c[:sub], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, cy - r * 0.44, r * 2 + 2, bh);
            dc.fillRectangle(0, cy + r * 0.10, r * 2 + 2, bh);
            var hpos = (t.hour % 12) + m / 60.0;
            for (var n = -3; n <= 15; n++) {
                var x = cx + (n - hpos) * r * 0.55;
                if (x > cx - r * 1.1 && x < cx + r * 1.1) {
                    var lab = n % 12;
                    if (lab <= 0) { lab += 12; }
                    text(dc, x, cy - r * 0.27, Graphics.FONT_MEDIUM, lab.toString(), c[:metal]);
                }
            }
            for (var w = m - 12; w <= m + 12; w++) {
                var mx = cx + (w - m) * r * 0.09;
                var big = (w % 5 == 0);
                dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
                dc.drawLine(mx, cy + r * 0.10, mx, cy + r * (big ? 0.19 : 0.15));
                if (big && w != m) { text(dc, mx, cy + r * 0.31, Graphics.FONT_XTINY, ((w + 60) % 60).format("%02d"), c[:txt]); }
            }
            dc.setColor(c[:accent], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, cy - r * 0.50, 3, r * 1.0);
            dc.fillPolygon([[cx - r * 0.06, cy - r * 0.56], [cx + r * 0.06, cy - r * 0.56], [cx, cy - r * 0.46]]);
            text(dc, cx, cy - r * 0.70, Graphics.FONT_XTINY, c[:mark], c[:metal2]);
            text(dc, cx, cy + r * 0.64, Graphics.FONT_XTINY, date, c[:metal]);
        } else if (L == 9) {    // retrograde: minute hand sweeps a fan and snaps back
            var py = cy + r * 0.30;
            dc.setPenWidth(2);
            dc.setColor(c[:metal2], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, py, r * 1.05, Graphics.ARC_CLOCKWISE, 150, 30);
            dc.setPenWidth(1);
            for (var e = 0; e <= 12; e++) {
                var ea = (-60 + 10 * e) * Math.PI / 180;
                var len = (e % 3 == 0) ? 0.10 : 0.05;
                dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cx + r * (1.05 - len) * Math.sin(ea), py - r * (1.05 - len) * Math.cos(ea), cx + r * 1.05 * Math.sin(ea), py - r * 1.05 * Math.cos(ea));
            }
            var ra = (-60 + 120 * mf) * Math.PI / 180;
            dc.setPenWidth(3);
            dc.setColor(c[:accent], Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx, py, cx + r * 0.98 * Math.sin(ra), py - r * 0.98 * Math.cos(ra));
            dc.setPenWidth(1);
            disc(dc, [cx, py], r * 0.07, c[:metal]);
            text(dc, cx, cy + r * 0.62, Graphics.FONT_NUMBER_MILD, H, c[:txt]);
            text(dc, cx - r * 0.52, cy + r * 0.45, Graphics.FONT_XTINY, "0", c[:metal2]);
            text(dc, cx + r * 0.52, cy + r * 0.45, Graphics.FONT_XTINY, "60", c[:metal2]);
        } else {                // split: two-tone dial, hour left, minute right
            dc.setColor(c[:sub], Graphics.COLOR_TRANSPARENT);
            if (v == 1) {
                dc.fillRectangle(0, 0, r * 2 + 2, cy);
                text(dc, cx, cy - r * 0.42, Graphics.FONT_NUMBER_HOT, H, c[:txt]);
                text(dc, cx, cy + r * 0.42, Graphics.FONT_NUMBER_HOT, M, c[:metal]);
                dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(0, cy - 1, r * 2 + 2, 3);
            } else {
                dc.fillRectangle(0, 0, cx, r * 2 + 2);
                text(dc, cx - r * 0.44, cy, Graphics.FONT_NUMBER_HOT, H, c[:txt]);
                text(dc, cx + r * 0.44, cy, Graphics.FONT_NUMBER_HOT, M, c[:metal]);
                dc.setColor(c[:metal], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - 1, 0, 3, r * 2 + 2);
                text(dc, cx + r * 0.44, cy + r * 0.52, Graphics.FONT_XTINY, date, c[:accent]);
            }
        }
    }
}
