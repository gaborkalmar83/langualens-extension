import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class PulsarApp extends Application.AppBase {
    var hub = null;
    var gestures = null;
    var coach = null;
    var workout = null;
    var view = null;
    hidden var _timer = null;
    hidden var _asked = false;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        hub = new SensorHub();
        gestures = new GestureEngine();
        coach = new Coach();
        workout = new Workout();
        hub.start();
        gestures.start();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onStop(state) {
        if (_timer != null) { _timer.stop(); }
        if (workout != null && workout.session != null) { workout.save(); }
        if (gestures != null) { gestures.stop(); }
        if (hub != null) { hub.stop(); }
    }

    function getInitialView() {
        view = new MainView();
        return [view, new MainDelegate()];
    }

    function onSettingsChanged() {
        hub.gps(Cfg.on("useGps"));
        WatchUi.requestUpdate();
    }

    function onTick() {
        if (!_asked) {
            _asked = true;
            if (Application.Storage.getValue("asked") == null) {
                Application.Storage.setValue("asked", true);
                WatchUi.pushView(new WatchUi.Confirmation("Motivation messages?"), new OptInDelegate(), WatchUi.SLIDE_UP);
            }
        }
        hub.update();
        if (workout.tick(hub)) {
            coach.onLap(workout.laps);
        } else if (workout.state == Workout.REC) {
            coach.tick(workout, hub);
        }
        WatchUi.requestUpdate();
    }

    function startStop() {
        gestures.learnUp();
        if (workout.state == Workout.IDLE) {
            hub.gps(Cfg.on("useGps"));
            workout.start();
            coach.onStart(hub);
        } else if (workout.state == Workout.REC) {
            workout.pause();
            coach.onPause();
        } else {
            workout.resume();
            coach.onResume();
        }
        WatchUi.requestUpdate();
    }

    function lap() {
        if (workout.state == Workout.REC) {
            workout.lap();
            coach.onLap(workout.laps);
        }
    }

    // Gesture actions: 0 nothing, 1 next screen, 2 lap, 3 pause/resume,
    // 4 motivate me, 5 backlight, 6 next design.
    function doAction(a) {
        if (a == 1 && view != null) { view.page(1); }
        if (a == 2) { lap(); }
        if (a == 3 && workout.state != Workout.IDLE) { startStop(); }
        if (a == 4) { coach.boost(hub); }
        if (a == 5 && (Attention has :backlight)) {
            try {
                Attention.backlight(true);
            } catch (e) {
            }
        }
        if (a == 6) { Themes.next(); }
        if (a != 0 && a != 4 && a != 3 && a != 2 && Cfg.on("vibe") && (Attention has :vibrate)) {
            Attention.vibrate([new Attention.VibeProfile(50, 100)]);
        }
        WatchUi.requestUpdate();
    }
}

function getApp() {
    return Application.getApp();
}

class OptInDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response) {
        Cfg.set("motivation", response == WatchUi.CONFIRM_YES);
        return true;
    }
}
