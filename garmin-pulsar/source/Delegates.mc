import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class MainDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    // START/STOP button or tap
    function onSelect() {
        getApp().startStop();
        return true;
    }

    // BACK: lap while recording, finish menu while paused, exit when idle
    function onBack() {
        var app = getApp();
        if (app.workout.state == Workout.REC) {
            app.lap();
            return true;
        }
        if (app.workout.state == Workout.PAUSED) {
            var m = new WatchUi.Menu2({:title => "Paused"});
            m.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
            m.addItem(new WatchUi.MenuItem("Save", null, :save, null));
            m.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
            WatchUi.pushView(m, new PauseDelegate(), WatchUi.SLIDE_UP);
            return true;
        }
        return false;
    }

    function onNextPage() {
        getApp().view.page(1);
        return true;
    }

    function onPreviousPage() {
        getApp().view.page(-1);
        return true;
    }

    function onMenu() {
        Menus.open();
        return true;
    }
}

class PauseDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var app = getApp();
        var id = item.getId();
        if (id == :save) {
            app.workout.save();
            WatchUi.switchToView(new SummaryView(), new SummaryDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        if (id == :discard) {
            app.workout.discard();
        } else {
            app.startStop();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// ---- settings menus ----
module Menus {
    function toggle(m, label, key) {
        m.addItem(new WatchUi.ToggleMenuItem(label, null, key, Cfg.on(key), null));
    }

    function list(m, label, key) {
        m.addItem(new WatchUi.MenuItem(label, Opt.label(key), key, null));
    }

    function open() {
        var m = new WatchUi.Menu2({:title => "Pulsar"});
        toggle(m, "Motivation", "motivation");
        list(m, "Coach intensity", "coachFreq");
        list(m, "Design", "theme");
        list(m, "Sport", "sport");
        list(m, "Goal", "goal");
        m.addItem(new WatchUi.MenuItem("Gestures", "Shake, twist, flip", "menu:gestures", null));
        m.addItem(new WatchUi.MenuItem("Sensors", "What each one does", "menu:sensors", null));
        toggle(m, "Vibration", "vibe");
        toggle(m, "Tones", "tones");
        WatchUi.pushView(m, new SettingsDelegate(), WatchUi.SLIDE_UP);
    }

    function gestures() {
        var m = new WatchUi.Menu2({:title => "Gestures"});
        toggle(m, "Gestures on", "gestures");
        list(m, "Shake", "gShake");
        list(m, "Wrist twist", "gTwist");
        list(m, "Face down", "gFlip");
        list(m, "Sensitivity", "gSens");
        WatchUi.pushView(m, new SettingsDelegate(), WatchUi.SLIDE_LEFT);
    }

    function sensors() {
        var m = new WatchUi.Menu2({:title => "Sensors"});
        list(m, "HR zone guard", "hrTarget");
        list(m, "Cadence coach", "cadTarget");
        list(m, "Climb cheers", "climbStep");
        toggle(m, "GPS route", "useGps");
        toggle(m, "GPS auto lap", "autoLap");
        toggle(m, "Low oxygen alert", "spo2Warn");
        toggle(m, "Heat alert", "heatWarn");
        toggle(m, "Compass on HUD", "compass");
        toggle(m, "Body Battery coach", "bodyAdapt");
        WatchUi.pushView(m, new SettingsDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var key = item.getId();
        if (key.equals("menu:gestures")) {
            Menus.gestures();
        } else if (key.equals("menu:sensors")) {
            Menus.sensors();
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            Cfg.set(key, item.isEnabled());
            if (key.equals("useGps")) { getApp().hub.gps(item.isEnabled()); }
        } else if (key.equals("sport") && getApp().workout.state != Workout.IDLE) {
            item.setSubLabel("Locked while recording");
            WatchUi.requestUpdate();
        } else {
            // open a picker with every option
            var labels = Opt.labels(key);
            var cur = Cfg.num(key, 0);
            var m = new WatchUi.Menu2({:title => item.getLabel()});
            for (var i = 0; i < labels.size(); i++) {
                m.addItem(new WatchUi.MenuItem(labels[i], null, i, null));
            }
            if (cur >= 0 && cur < labels.size()) { m.setFocus(cur); }
            WatchUi.pushView(m, new PickDelegate(key, item), WatchUi.SLIDE_LEFT);
        }
    }
}

class PickDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _key;
    hidden var _parent;

    function initialize(key, parent) {
        Menu2InputDelegate.initialize();
        _key = key;
        _parent = parent;
    }

    function onSelect(item) {
        Cfg.set(_key, item.getId());
        _parent.setSubLabel(Opt.label(_key));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

// ---- summary after saving ----
class SummaryView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        var t = Themes.current();
        var s = getApp().workout.summary;
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(t[5], t[0]);
        dc.clear();
        if (s == null) { return; }
        var rw = (w * 0.04).toNumber();
        Themes.ring(dc, cx, h / 2, w / 2 - rw / 2 - 3, rw, s[:drive] / 100.0, t[1], t[4], t[6]);
        var mot = Cfg.on("motivation");
        var head = "SAVED";
        if (mot) { head = s[:record] ? "NEW RECORD!" : (s[:streak] > 1 ? "STREAK " + s[:streak] + " DAYS" : "WELL DONE"); }
        dc.setColor(t[3], Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.18, Graphics.FONT_TINY, head, j);
        dc.setColor(t[5], Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.36, Graphics.FONT_NUMBER_MILD, Fmt.time(s[:time]), j);
        dc.setColor(t[1], Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.53, Graphics.FONT_SMALL, Fmt.dist(s[:dist]) + (Cfg.metric() ? " km" : " mi"), j);
        dc.setColor(t[5], Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.65, Graphics.FONT_XTINY, "HR " + Fmt.n(s[:hr], "") + "   " + s[:cal] + " KCAL", j);
        dc.setColor(t[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.76, Graphics.FONT_XTINY, "DRIVE " + s[:drive] + "   WORKOUT " + s[:count], j);
        if (mot) {
            dc.setColor(t[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY, "SEE YOU TOMORROW", j);
        }
    }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
