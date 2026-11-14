import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Application;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Records the activity and keeps score.
class Workout {
    enum { IDLE, REC, PAUSED }
    var state = IDLE;
    var session = null;
    var timerMs = 0;
    var dist = 0.0;       // metres
    var calories = 0;
    var avgHr = null;
    var ascent = 0;
    var laps = 0;
    var live = 0;         // drive score right now, 0..100
    var drive = 0;        // average drive score of this workout
    var zoneSecs = [0, 0, 0, 0, 0, 0];
    var summary = null;
    hidden var _field = null;
    hidden var _sum = 0;
    hidden var _n = 0;
    hidden var _nextLap = 0;

    function initialize() {
    }

    function sport() {
        var s = Cfg.num("sport", 0);
        return (s < 0 || s > 5) ? 0 : s;
    }

    function start() {
        if (state != IDLE) { return; }
        var sp = Activity.SPORT_RUNNING;
        var sub = Activity.SUB_SPORT_GENERIC;
        var s = sport();
        if (s == 1) { sp = Activity.SPORT_WALKING; }
        if (s == 2) { sp = Activity.SPORT_HIKING; }
        if (s == 3) { sp = Activity.SPORT_CYCLING; }
        if (s == 4) { sp = Activity.SPORT_TRAINING; sub = Activity.SUB_SPORT_CARDIO_TRAINING; }
        if (s == 5) { sp = Activity.SPORT_TRAINING; sub = Activity.SUB_SPORT_STRENGTH_TRAINING; }
        session = ActivityRecording.createSession({:name => "Pulsar " + Opt.SPORTS[s], :sport => sp, :subSport => sub});
        try {
            _field = session.createField("drive_score", 0, FitContributor.DATA_TYPE_UINT8,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "pts"});
        } catch (e) {
            _field = null;
        }
        timerMs = 0;
        dist = 0.0;
        calories = 0;
        avgHr = null;
        ascent = 0;
        laps = 0;
        live = 0;
        drive = 0;
        _sum = 0;
        _n = 0;
        zoneSecs = [0, 0, 0, 0, 0, 0];
        _nextLap = lapLength();
        session.start();
        state = REC;
    }

    function pause() {
        if (state == REC) {
            session.stop();
            state = PAUSED;
        }
    }

    function resume() {
        if (state == PAUSED) {
            session.start();
            state = REC;
        }
    }

    function lap() {
        if (state == REC) {
            session.addLap();
            laps++;
        }
    }

    function discard() {
        if (session != null) {
            if (session.isRecording()) { session.stop(); }
            session.discard();
            session = null;
        }
        state = IDLE;
    }

    function save() {
        if (session == null) { return; }
        if (session.isRecording()) { session.stop(); }
        session.save();
        session = null;
        state = IDLE;

        // streak: days in a row with a saved workout
        var day = (Time.now().value() + System.getClockTime().timeZoneOffset) / 86400;
        var lastDay = stored("lastDay", 0);
        var streak = stored("streak", 0);
        if (day == lastDay + 1) {
            streak++;
        } else if (day != lastDay) {
            streak = 1;
        }
        var count = stored("sessions", 0) + 1;
        var best = stored("bestDist", 0);
        var record = dist > best && dist > 100;
        Application.Storage.setValue("lastDay", day);
        Application.Storage.setValue("streak", streak);
        Application.Storage.setValue("sessions", count);
        Application.Storage.setValue("lastDist", dist);
        if (record) { Application.Storage.setValue("bestDist", dist); }
        summary = {:time => timerMs, :dist => dist, :cal => calories, :hr => avgHr,
                   :drive => drive, :streak => streak, :count => count, :record => record && count > 1};
    }

    function stored(key, def) {
        var v = Application.Storage.getValue(key);
        return (v == null) ? def : v;
    }

    function lapLength() {
        return Cfg.metric() ? 1000.0 : 1609.344;
    }

    // 0 none, 1 minutes, 2 km, 3 kcal
    function goalType() {
        var g = Cfg.num("goal", 0);
        if (g < 0 || g >= Opt.GOAL_TYPE.size()) { g = 0; }
        return Opt.GOAL_TYPE[g];
    }

    function goalFrac() {
        var g = Cfg.num("goal", 0);
        if (g <= 0 || g >= Opt.GOAL_TYPE.size()) { return 0.0; }
        var t = Opt.GOAL_TYPE[g];
        var v = Opt.GOAL_VAL[g];
        var f = 0.0;
        if (t == 1) { f = timerMs / (v * 60000.0); }
        if (t == 2) { f = dist / (v * 1000.0); }
        if (t == 3) { f = calories / v.toFloat(); }
        return (f > 1) ? 1.0 : f;
    }

    // Once a second. Returns true when an auto lap was just taken.
    function tick(hub) {
        if (state == IDLE) {
            live = (hub.intensity() * 100).toNumber();
            return false;
        }
        var a = Activity.getActivityInfo();
        if (a != null) {
            if (a.timerTime != null) { timerMs = a.timerTime; }
            if (a.elapsedDistance != null) { dist = a.elapsedDistance; }
            if (a.calories != null) { calories = a.calories; }
            if (a.averageHeartRate != null) { avgHr = a.averageHeartRate; }
            if (a.totalAscent != null) { ascent = a.totalAscent; }
        }
        if (state != REC) { return false; }
        var s = 80 * hub.intensity() + 20 * goalFrac();
        live = (s > 100) ? 100 : s.toNumber();
        _sum += live;
        _n++;
        drive = _sum / _n;
        zoneSecs[hub.zone()]++;
        if (_field != null) { _field.setData(live); }
        if (Cfg.on("autoLap") && dist >= _nextLap) {
            _nextLap += lapLength();
            lap();
            return true;
        }
        return false;
    }
}
