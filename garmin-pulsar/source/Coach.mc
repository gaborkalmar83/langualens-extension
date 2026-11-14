import Toybox.Attention;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

// Shows messages during the workout.
// Motivating wording only appears when the user opted in ("motivation").
// Functional alerts (laps, zone guard, safety) follow their own sensor options.
class Coach {
    var msg = null;
    var msgUntil = 0;
    hidden var _lastAt = -100000;
    hidden var _low = 0;
    hidden var _high = 0;
    hidden var _cad = 0;
    hidden var _half = false;
    hidden var _final = false;
    hidden var _done = false;
    hidden var _nextClimb = 0;
    hidden var _nextTalk = 0;
    hidden var _o2At = -1000000;
    hidden var _heatAt = -1000000;
    hidden var _tired = false;

    const PUSH = ["PUSH\nHARDER", "YOU HAVE\nMORE", "PICK IT UP", "DON'T\nSETTLE", "ONE GEAR\nUP", "WAKE UP\nTHE LEGS"];
    const EASE = ["EASE OFF\nA BIT", "BREATHE\nSTAY SMOOTH", "CONTROL\nTHE PACE"];
    const KEEP = ["STRONG\nKEEP GOING", "LOCKED IN", "THIS IS\nYOUR TIME", "FUTURE YOU\nSAYS THANKS",
                  "EVERY STEP\nCOUNTS", "STAY IN\nTHE FIGHT", "SMOOTH AND\nPOWERFUL", "YOU SHOWED UP\nNOW WIN",
                  "NO ONE ELSE\nCAN DO THIS", "MAKE IT\nCOUNT"];

    function initialize() {
        Math.srand(System.getTimer());
    }

    function mot() {
        return Cfg.on("motivation");
    }

    function pick(list) {
        return list[Math.rand() % list.size()];
    }

    function visible() {
        return msg != null && System.getTimer() < msgUntil;
    }

    // level: 0 soft, 1 normal, 2 big moment
    function say(text, level) {
        var now = System.getTimer();
        msg = text;
        msgUntil = now + 6000;
        _lastAt = now;
        if (Cfg.on("vibe") && (Attention has :vibrate)) {
            var v = [new Attention.VibeProfile(60, 200)];
            if (level >= 1) { v = [new Attention.VibeProfile(80, 200), new Attention.VibeProfile(0, 120), new Attention.VibeProfile(80, 200)]; }
            if (level >= 2) { v = [new Attention.VibeProfile(100, 300), new Attention.VibeProfile(0, 120), new Attention.VibeProfile(100, 300), new Attention.VibeProfile(0, 120), new Attention.VibeProfile(100, 500)]; }
            Attention.vibrate(v);
        }
        if (Cfg.on("tones") && (Attention has :playTone)) {
            Attention.playTone(level >= 2 ? Attention.TONE_SUCCESS : (level == 1 ? Attention.TONE_LOUD_BEEP : Attention.TONE_KEY));
        }
    }

    function onStart(hub) {
        _low = 0;
        _high = 0;
        _cad = 0;
        _half = false;
        _final = false;
        _done = false;
        _tired = false;
        var step = climbStep();
        _nextClimb = step;
        _nextTalk = System.getTimer() + talkGap();
        var bb = hub.bodyBattery;
        if (Cfg.on("bodyAdapt") && bb != null) {
            _tired = bb < 30;
            if (mot()) {
                say(_tired ? "LOW BATTERY\nKEEP IT EASY" : ("BATTERY " + bb.toNumber() + "%\nGO GET IT"), 1);
                return;
            }
        }
        say(mot() ? "LET'S GO!" : "STARTED", 1);
    }

    function onPause() {
        say("PAUSED", 0);
    }

    function onResume() {
        say(mot() ? "BACK AT IT" : "RESUMED", 0);
    }

    function onLap(n) {
        say(mot() ? ("LAP " + n + " DONE\n" + pick(KEEP)) : ("LAP " + n), 1);
    }

    // Asked for by gesture.
    function boost(hub) {
        say(pick(hub.intensity() < 0.4 ? PUSH : KEEP), 1);
    }

    function climbStep() {
        var c = Cfg.num("climbStep", 0);
        return (c == 1) ? 25 : ((c == 2) ? 50 : ((c == 3) ? 100 : 0));
    }

    function talkGap() {
        var f = Cfg.num("coachFreq", 1);
        var g = (f == 0) ? 600000 : ((f == 2) ? 120000 : 300000);
        return _tired ? g * 2 : g;
    }

    // Once a second while recording.
    function tick(w, hub) {
        var now = System.getTimer();
        var m = mot();

        // safety first, never more than once per 5 minutes each
        if (Cfg.on("spo2Warn") && hub.spo2 != null && hub.spo2 < 88 && now - _o2At > 300000) {
            _o2At = now;
            say("LOW OXYGEN\nSLOW DOWN", 2);
            return;
        }
        if (Cfg.on("heatWarn") && hub.temp != null && hub.temp >= 38 && now - _heatAt > 300000) {
            _heatAt = now;
            say("HIGH HEAT\nDRINK WATER", 2);
            return;
        }

        // goal
        if (w.goalType() != 0) {
            var f = w.goalFrac();
            if (f >= 1 && !_done) {
                _done = true;
                say(m ? "GOAL\nSMASHED!" : "GOAL DONE", 2);
                return;
            }
            if (m && f >= 0.9 && !_final && !_done) {
                _final = true;
                say("FINAL PUSH\n10% LEFT", 1);
                return;
            }
            if (m && f >= 0.5 && !_half) {
                _half = true;
                say("HALFWAY\nKEEP ROLLING", 1);
                return;
            }
        }

        // heart rate zone guard
        var t = Cfg.num("hrTarget", 0);
        if (t > 0 && hub.hr != null) {
            var z = hub.zone();
            var want = t + 1;
            _low = (z < want) ? _low + 1 : ((_low < 0) ? _low + 1 : 0);
            _high = (z > want) ? _high + 1 : ((_high < 0) ? _high + 1 : 0);
            if (_low >= 30) {
                _low = -60;
                say((m && !_tired) ? pick(PUSH) : "HR LOW\nSPEED UP", 1);
                return;
            }
            if (_high >= 30) {
                _high = -60;
                say(m ? pick(EASE) : "HR HIGH\nEASE OFF", 1);
                return;
            }
        }

        // cadence coach (running only)
        var ct = Cfg.num("cadTarget", 0);
        if (ct > 0 && w.sport() == 0 && hub.cadence != null && hub.cadence > 0) {
            var cad = hub.cadence;
            if (cad < 110) { cad = cad * 2; }   // some watches report one foot only
            var target = 150 + ct * 10;
            _cad = (cad < target - 5) ? _cad + 1 : ((_cad < 0) ? _cad + 1 : 0);
            if (_cad >= 30) {
                _cad = -90;
                say("QUICK FEET\n" + target + " SPM", 0);
                return;
            }
        }

        // climb cheers
        var step = climbStep();
        if (step > 0 && w.ascent >= _nextClimb) {
            var total = _nextClimb;
            while (_nextClimb <= w.ascent) { _nextClimb += step; }
            say(m ? ("+" + total + " M UP\nCLIMB CRUSHED") : ("+" + total + " M UP"), 0);
            return;
        }

        // regular motivation, opt-in only
        if (m && now >= _nextTalk && now - _lastAt > 45000) {
            _nextTalk = now + talkGap();
            say(pick((hub.intensity() < 0.4 && !_tired) ? PUSH : KEEP), 0);
        }
    }
}
