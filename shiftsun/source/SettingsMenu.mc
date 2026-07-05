using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

// On-device settings editor.
// Works with manual .prg sideload where Garmin Connect Mobile settings are unreachable.
// Reads/writes the same Property keys WatchSchedule.loadConfig() consumes.
module SettingsUi {

    // [key, title, min, max, default] — defaults mirror WatchSchedule DEF_* and properties.xml
    function fields() {
        return [
            ["startYear",   "Start Year",  2020, 2099, 2026],
            ["startMonth",  "Start Month", 1,    12,   4],
            ["startDay",    "Start Day",   1,    31,   15],
            ["startHour",   "Start Hour",  0,    23,   14],
            ["onDutyHours", "On Duty (h)", 1,    24,   6],
            ["restHours",   "Rest (h)",    1,    24,   12],
            ["endYear",     "End Year",    2020, 2099, 2026],
            ["endMonth",    "End Month",   1,    12,   7],
            ["endDay",      "End Day",     1,    31,   15]
        ];
    }

    function getVal(key, def) {
        var v = Application.getApp().getProperty(key);
        return (v != null) ? v : def;
    }

    function setVal(key, val) {
        Application.getApp().setProperty(key, val);
    }

    function descriptorFor(key) {
        var fs = fields();
        for (var i = 0; i < fs.size(); i++) {
            if (fs[i][0].equals(key)) { return fs[i]; }
        }
        return null;
    }

    function buildMenu() {
        var menu = new WatchUi.Menu2({:title => "Settings"});
        var fs = fields();
        for (var i = 0; i < fs.size(); i++) {
            var f = fs[i];
            var cur = getVal(f[0], f[4]);
            menu.addItem(new WatchUi.MenuItem(f[1], cur.toString(), f[0], null));
        }
        return menu;
    }
}

// Contiguous integer range [min..max], step 1. SDK has no built-in factory.
class NumberFactory extends WatchUi.PickerFactory {

    private var _min;
    private var _max;

    function initialize(minV, maxV) {
        PickerFactory.initialize();
        _min = minV;
        _max = maxV;
    }

    function getSize() {
        return _max - _min + 1;
    }

    function getValue(index) {
        return _min + index;
    }

    function getDrawable(index, selected) {
        return new WatchUi.Text({
            :text  => (_min + index).toString(),
            :color => Graphics.COLOR_WHITE,
            :font  => Graphics.FONT_NUMBER_MEDIUM,
            :locX  => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY  => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var key = item.getId();
        var f = SettingsUi.descriptorFor(key);
        if (f == null) { return; }

        var minV = f[2];
        var maxV = f[3];
        var cur  = SettingsUi.getVal(key, f[4]);
        if (cur < minV) { cur = minV; }
        if (cur > maxV) { cur = maxV; }

        var factory = new NumberFactory(minV, maxV);
        var title = new WatchUi.Text({
            :text   => f[1],
            :color  => Graphics.COLOR_WHITE,
            :font   => Graphics.FONT_TINY,
            :locX   => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY   => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
        var picker = new WatchUi.Picker({
            :title    => title,
            :pattern  => [factory],
            :defaults => [cur - minV]
        });

        WatchUi.pushView(picker, new FieldPickerDelegate(key, item), WatchUi.SLIDE_LEFT);
    }
}

class FieldPickerDelegate extends WatchUi.PickerDelegate {

    private var _key;
    private var _item;

    function initialize(key, item) {
        PickerDelegate.initialize();
        _key  = key;
        _item = item;
    }

    function onAccept(values) {
        var val = values[0];
        SettingsUi.setVal(_key, val);
        WatchSchedule.loadConfig();
        _item.setSubLabel(val.toString());
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
