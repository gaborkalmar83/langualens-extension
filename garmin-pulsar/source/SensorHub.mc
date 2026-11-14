import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;
import Toybox.UserProfile;

// Reads every sensor the watch offers and keeps the latest values.
// Anything a device does not have simply stays null.
class SensorHub {
    var hr = null;
    var cadence = null;
    var speed = null;
    var power = null;
    var temp = null;
    var altitude = null;
    var pressure = null;
    var heading = null;
    var spo2 = null;
    var bodyBattery = null;
    var stress = null;
    var resp = null;
    var steps = null;
    var gpsQuality = 0;
    var zones = [100, 120, 140, 160, 175, 190];
    hidden var _slow = 0;
    hidden var _gpsOn = false;

    function initialize() {
    }

    function start() {
        var list = [Sensor.SENSOR_HEARTRATE, Sensor.SENSOR_TEMPERATURE, Sensor.SENSOR_FOOTPOD,
                    Sensor.SENSOR_BIKECADENCE, Sensor.SENSOR_BIKESPEED, Sensor.SENSOR_BIKEPOWER];
        if (Sensor has :SENSOR_PULSE_OXIMETRY) {
            list.add(Sensor.SENSOR_PULSE_OXIMETRY);
        }
        try {
            Sensor.setEnabledSensors(list);
        } catch (e) {
            try {
                Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            } catch (e2) {
            }
        }
        Sensor.enableSensorEvents(method(:onSensor));
        try {
            var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            if (z != null && z.size() >= 6) { zones = z; }
        } catch (e3) {
        }
        gps(Cfg.on("useGps"));
        update();
    }

    function stop() {
        Sensor.enableSensorEvents(null);
        gps(false);
    }

    function gps(enable) {
        if (enable == _gpsOn) { return; }
        _gpsOn = enable;
        try {
            if (enable) {
                Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            } else {
                Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
                gpsQuality = 0;
            }
        } catch (e) {
        }
    }

    function onPosition(info) {
        if (info != null && info.accuracy != null) { gpsQuality = info.accuracy; }
    }

    function onSensor(info) {
        if (info == null) { return; }
        if (info.heartRate != null) { hr = info.heartRate; }
        if (info.cadence != null) { cadence = info.cadence; }
        if (info.speed != null) { speed = info.speed; }
        if (info.power != null) { power = info.power; }
        if (info.temperature != null) { temp = info.temperature; }
        if (info.altitude != null) { altitude = info.altitude; }
        if (info.pressure != null) { pressure = info.pressure; }
        if (info.heading != null) { heading = info.heading; }
        if ((info has :oxygenSaturation) && info.oxygenSaturation != null) { spo2 = info.oxygenSaturation; }
    }

    // Called once a second.
    function update() {
        var a = Activity.getActivityInfo();
        if (a != null) {
            if (a.currentHeartRate != null) { hr = a.currentHeartRate; }
            if (a.currentCadence != null) { cadence = a.currentCadence; }
            if (a.currentSpeed != null) { speed = a.currentSpeed; }
            if ((a has :currentPower) && a.currentPower != null) { power = a.currentPower; }
            if (a.altitude != null) { altitude = a.altitude; }
            if ((a has :ambientPressure) && a.ambientPressure != null) { pressure = a.ambientPressure; }
            if (a.currentHeading != null) { heading = a.currentHeading; }
            if ((a has :currentOxygenSaturation) && a.currentOxygenSaturation != null) { spo2 = a.currentOxygenSaturation; }
        }
        if (_slow <= 0) {
            _slow = 30;
            slow();
        }
        _slow--;
    }

    hidden function slow() {
        var m = ActivityMonitor.getInfo();
        if (m != null) {
            if (m.steps != null) { steps = m.steps; }
            if ((m has :respirationRate) && m.respirationRate != null) { resp = m.respirationRate; }
            if ((m has :stressScore) && m.stressScore != null) { stress = m.stressScore; }
        }
        if (Toybox has :SensorHistory) {
            var sh = Toybox.SensorHistory;
            if (sh has :getBodyBatteryHistory) { bodyBattery = last(sh.getBodyBatteryHistory({:period => 1}), bodyBattery); }
            if (sh has :getStressHistory) { stress = last(sh.getStressHistory({:period => 1}), stress); }
            if (spo2 == null && (sh has :getOxygenSaturationHistory)) { spo2 = last(sh.getOxygenSaturationHistory({:period => 1}), spo2); }
            if (temp == null && (sh has :getTemperatureHistory)) { temp = last(sh.getTemperatureHistory({:period => 1}), temp); }
        }
    }

    hidden function last(iter, def) {
        if (iter == null) { return def; }
        var s = iter.next();
        if (s == null || s.data == null) { return def; }
        return s.data;
    }

    // 0 = below zone 1, 1..5 = heart rate zone.
    function zone() {
        if (hr == null) { return 0; }
        var z = 0;
        for (var i = 0; i < 5; i++) {
            if (hr >= zones[i]) { z = i + 1; }
        }
        return z;
    }

    // 0..1 how hard the heart works between zone 1 start and zone 5 end.
    function intensity() {
        if (hr == null) { return 0.0; }
        var lo = zones[0];
        var hi = zones[5];
        if (hi <= lo) { return 0.0; }
        var f = (hr - lo).toFloat() / (hi - lo);
        if (f < 0) { f = 0.0; }
        if (f > 1) { f = 1.0; }
        return f;
    }
}
