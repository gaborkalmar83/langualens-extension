import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// Settings live in Application.Properties so the watch menu and the
// Garmin Connect phone settings stay in sync.
module Cfg {
    function get(key, def) {
        var v = null;
        try {
            v = Application.Properties.getValue(key);
        } catch (e) {
            v = null;
        }
        return (v == null) ? def : v;
    }

    function num(key, def) {
        var v = get(key, def);
        if (v instanceof Lang.Number) { return v; }
        if (v instanceof Lang.Boolean) { return v ? 1 : 0; }
        if (v instanceof Lang.Float || v instanceof Lang.String || v instanceof Lang.Long || v instanceof Lang.Double) {
            var n = v.toNumber();
            return (n == null) ? def : n;
        }
        return def;
    }

    function on(key) {
        var v = get(key, false);
        if (v instanceof Lang.Boolean) { return v; }
        return num(key, 0) != 0;
    }

    function set(key, v) {
        try {
            Application.Properties.setValue(key, v);
        } catch (e) {
        }
    }

    function metric() {
        return System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
    }
}

// Option labels for the on-watch menus.
module Opt {
    const ACTIONS = ["Nothing", "Next screen", "Lap", "Pause / resume", "Motivate me", "Backlight", "Next design"];
    const SPORTS = ["Run", "Walk", "Hike", "Bike", "Cardio", "Strength"];
    const GOALS = ["None", "10 min", "20 min", "30 min", "45 min", "60 min", "90 min",
                   "1 km", "3 km", "5 km", "10 km", "21.1 km",
                   "200 kcal", "400 kcal", "600 kcal", "800 kcal"];
    // goal type per entry: 0 none, 1 minutes, 2 km, 3 kcal
    const GOAL_TYPE = [0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3];
    const GOAL_VAL = [0, 10, 20, 30, 45, 60, 90, 1, 3, 5, 10, 21.1, 200, 400, 600, 800];

    function labels(key) {
        if (key.equals("sport")) { return SPORTS; }
        if (key.equals("theme")) { return Themes.NAMES; }
        if (key.equals("goal")) { return GOALS; }
        if (key.equals("coachFreq")) { return ["Calm", "Normal", "Intense"]; }
        if (key.equals("gShake") || key.equals("gTwist") || key.equals("gFlip")) { return ACTIONS; }
        if (key.equals("gSens")) { return ["Low", "Medium", "High"]; }
        if (key.equals("hrTarget")) { return ["Off", "Zone 2", "Zone 3", "Zone 4"]; }
        if (key.equals("cadTarget")) { return ["Off", "160 spm", "170 spm", "180 spm"]; }
        if (key.equals("climbStep")) { return ["Off", "Every 25 m", "Every 50 m", "Every 100 m"]; }
        return ["Off", "On"];
    }

    function label(key) {
        var l = labels(key);
        var i = Cfg.num(key, 0);
        if (i < 0 || i >= l.size()) { i = 0; }
        return l[i];
    }
}
