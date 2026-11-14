import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.System;

// Motion gestures from the accelerometer and gyroscope (25 Hz).
//   shake     : fast back and forth movement
//   twist     : quick wrist rotation out and back (turn the face away and back)
//   face down : hold the face pointing to the ground for 2 seconds
class GestureEngine {
    var last = "--";
    var lastAt = 0;
    var active = false;
    var gyroOk = false;
    var mags = [];      // last second of acceleration strength, for the motion screen
    var spin = 0;       // strongest wrist rotation of the last second, deg/s
    hidden var _upSign = -1;
    hidden var _zAvg = 0;
    hidden var _down = 0;

    function initialize() {
    }

    function start() {
        if (active || !(Sensor has :registerSensorDataListener)) { return; }
        var acc = {:enabled => true, :sampleRate => 25};
        try {
            Sensor.registerSensorDataListener(method(:onData),
                {:period => 1, :accelerometer => acc, :gyroscope => {:enabled => true, :sampleRate => 25}});
            gyroOk = true;
            active = true;
        } catch (e) {
            try {
                Sensor.registerSensorDataListener(method(:onData), {:period => 1, :accelerometer => acc});
                active = true;
            } catch (e2) {
            }
        }
    }

    function stop() {
        if (active) {
            Sensor.unregisterSensorDataListener();
            active = false;
        }
    }

    // The user looks at the watch when pressing a button: learn which way is "face up".
    function learnUp() {
        if (_zAvg > 400) { _upSign = 1; }
        if (_zAvg < -400) { _upSign = -1; }
    }

    function onData(d) {
        var a = d.accelerometerData;
        if (a == null || a.x == null) { return; }
        var xs = a.x;
        var ys = a.y;
        var zs = a.z;
        var n = xs.size();
        if (n == 0) { return; }
        var sens = Cfg.num("gSens", 1);
        var thr = (sens == 0) ? 2200 : ((sens == 2) ? 1300 : 1700);
        var rev = 0;
        var sign = 0;
        var zsum = 0;
        var m = new [n];
        for (var i = 0; i < n; i++) {
            var x = xs[i];
            var y = ys[i];
            var z = zs[i];
            zsum += z;
            m[i] = Math.sqrt(x.toFloat() * x + y.toFloat() * y + z.toFloat() * z);
            var v = (x.abs() > y.abs()) ? x : y;
            if (v > thr && sign != 1) {
                if (sign == -1) { rev++; }
                sign = 1;
            } else if (v < -thr && sign != -1) {
                if (sign == 1) { rev++; }
                sign = -1;
            }
        }
        mags = m;
        _zAvg = zsum / n;

        var twist = false;
        spin = 0;
        if ((d has :gyroscopeData) && d.gyroscopeData != null && d.gyroscopeData.x != null) {
            var gx = d.gyroscopeData.x;
            var gthr = (sens == 0) ? 450 : ((sens == 2) ? 220 : 320);
            var hi = 0;
            var lo = 0;
            for (var k = 0; k < gx.size(); k++) {
                if (gx[k] > hi) { hi = gx[k]; }
                if (gx[k] < lo) { lo = gx[k]; }
            }
            spin = (hi > -lo) ? hi : -lo;
            twist = (hi > gthr && lo < -gthr);
        }

        if (!Cfg.on("gestures")) { return; }
        if (_zAvg * _upSign < -700) {
            _down++;
            if (_down == 2) { fire("FACE DOWN", "gFlip"); }
            return;
        }
        _down = 0;
        if (rev >= 3) {
            fire("SHAKE", "gShake");
        } else if (twist) {
            fire("TWIST", "gTwist");
        }
    }

    hidden function fire(name, key) {
        var now = System.getTimer();
        if (now - lastAt < 3000) { return; }
        lastAt = now;
        last = name;
        getApp().doAction(Cfg.num(key, 0));
    }
}
