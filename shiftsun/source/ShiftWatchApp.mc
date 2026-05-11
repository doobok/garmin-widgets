using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Lang;

class WatchTrackerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new MainView(), new WatchTrackerDelegate()];
    }

    function getGlanceView() {
        return [new WatchGlanceView()];
    }

    function onStart(state) {}
    function onStop(state)  {}
}
