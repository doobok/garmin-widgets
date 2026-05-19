using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class WatchTrackerDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() {
        WatchUi.switchToView(new DetailsView(), new DetailsDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() {
        WatchUi.switchToView(new AnimView(), new AnimDelegate(), WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() {
        WatchSchedule.loadConfig();
        WatchUi.requestUpdate();
        return true;
    }
}

class WatchGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        try {
            WatchSchedule.loadConfig();
            var pct10 = WatchSchedule.totalProgressX10();
            var pct = pct10 / 10;

            // State label — upper half
            var shiftNum = WatchSchedule.shiftNumber();
            var shiftStr = " #" + shiftNum.toString();
            var stateLabel;
            if (WatchSchedule.isPending()) {
                stateLabel = "PENDING" + shiftStr;
            } else if (WatchSchedule.isOnDuty()) {
                stateLabel = "ON DUTY" + shiftStr;
            } else {
                stateLabel = "REST" + shiftStr;
            }
            dc.drawText(cx, cy - 24, Graphics.FONT_MEDIUM, stateLabel, Graphics.TEXT_JUSTIFY_CENTER);

            // Voyage progress bar — centred
            var barW = w - 20;
            var barX = 10;
            var barY = cy + 2;
            var barH = 7;
            dc.drawRectangle(barX, barY, barW, barH);
            if (pct10 > 0) {
                var fillW = (barW - 2) * pct10 / 1000;
                if (fillW < 1) { fillW = 1; }
                dc.fillRectangle(barX + 1, barY + 1, fillW, barH - 2);
            }

            var pctStr = pct.toString() + "." + (pct10 % 10).toString() + "%";
            dc.drawText(cx, barY + barH + 2, Graphics.FONT_XTINY,
                "voyage " + pctStr,
                Graphics.TEXT_JUSTIFY_CENTER);

        } catch (ex instanceof Lang.Exception) {
            dc.drawText(cx, cy - 8, Graphics.FONT_SMALL, "Watch Tracker", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
