**For use with Claude Code.** Execute phases sequentially. Each phase ends with a verification step before proceeding.

-----

## Context

Building a Garmin Connect IQ `widget` for **Instinct 2 Solar** that tracks maritime watch (duty rotation) progress.

```
Device:     instinct2solar, 176×176px monochrome MIP, API Level 3.3.4
App type:   widget (NOT watch-app, NOT watch-face)
Language:   Monkey C
Config:     Garmin Connect Mobile via Properties API
Timer:      60s refresh, stopped in onHide()
```

### Architectural Rules

- `WatchSchedule.mc` — pure business logic, zero UI dependencies, all functions stateless (input → output)
- `MainView.mc` — only draws, never calculates; calls `WatchSchedule` for all data
- No global mutable state except the Timer handle and cached Properties values
- All Properties reads happen once in `onShow()` and on START button press
- Guard every `Properties.getValue()` call: if `null` → use default constant

-----

## Claude Code Session Starter

Paste at the beginning of each Claude Code session:

```
I am building a Garmin Connect IQ widget called Watch Tracker for the Instinct 2 Solar.
The widget tracks maritime watch (duty rotation) progress.

KEY CONSTRAINTS:
- Device: instinct2solar, 176x176px monochrome MIP, API Level 3.3.4
- App type: widget (NOT watch-app, NOT watch-face)
- Language: Monkey C
- No touchscreen — 5-button navigation only
- No CIQ 4.x features (no Complications, no Glance carousel)
- Config via Garmin Connect Mobile Properties API only
- Timer: 60s refresh, stopped in onHide() — no sub-second updates

ARCHITECTURE RULES:
- WatchSchedule.mc: pure business logic only, no UI imports
- MainView.mc: only renders, calls WatchSchedule for data
- Guard all Properties.getValue() calls against null with defaults
- All time is in minutes-from-midnight (0-1439), handle midnight wrap

I have a full SRS (watch-tracker-spec.md) in this directory.
Let's start with Phase [N]: [phase name].
```

-----

## Phase 0 — Project Scaffold (~15 min)

Create the project structure. No logic yet — only scaffold and verify the simulator builds.

### Tasks

- [ ] **Create project** — VS Code → `Ctrl+Shift+P` → `Monkey C: New Project` → type: `widget` → device: `instinct2solar` → name: `watch-tracker`
- [ ] **Set minApiLevel** — in `manifest.xml` set `minApiLevel="3.3.4"`, verify `instinct2solar` listed as target product
- [ ] **Create source files** — empty `.mc` files: `WatchTrackerApp.mc`, `WatchTrackerDelegate.mc`, `MainView.mc`, `DetailsView.mc`, `WatchSchedule.mc`
- [ ] **Create settings.xml** — `resources/settings/settings.xml` with all 5 property definitions (see spec §7)
- [ ] **Verify build** — F5 in VS Code → select `instinct2solar` simulator → blank screen, zero errors

### manifest.xml skeleton

```xml
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
  <iq:application entry="WatchTrackerApp" id="YOUR-UUID-HERE"
                  minApiLevel="3.3.4" name="@Strings.AppName"
                  type="widget" version="1.0.0">
    <iq:products>
      <iq:product id="instinct2solar"/>
    </iq:products>
    <iq:permissions/>
    <iq:languages>
      <iq:language>eng</iq:language>
    </iq:languages>
  </iq:application>
</iq:manifest>
```

### Expected file tree

```
watch-tracker/
├── manifest.xml
├── resources/
│   ├── settings/
│   │   └── settings.xml
│   └── strings/
│       └── strings.xml
└── source/
    ├── WatchTrackerApp.mc
    ├── WatchTrackerDelegate.mc
    ├── MainView.mc
    ├── DetailsView.mc
    └── WatchSchedule.mc
```

-----

## Phase 1 — Business Logic Module (~45 min)

Implement `WatchSchedule.mc` — the pure calculation engine. Test before touching UI.

### WatchSchedule.mc — full interface

```monkey-c
// WatchSchedule.mc
// All functions are pure — no side effects, no UI calls.

module WatchSchedule {

    // Config (populated from Properties)
    var startMin  as Number;   // 0-1439
    var endMin    as Number;   // 0-1439
    var onDutyMin as Number;   // onDutyHours * 60
    var restMin   as Number;   // restHours * 60
    var firstBlock as Number;  // 0=onDuty, 1=rest

    // Load config from Properties with null-guards and defaults
    function loadConfig() as Void { ... }

    // Total watch duration in minutes
    function totalWatchMinutes() as Number { ... }

    // Minutes elapsed since watch start.
    // Returns -1 if current time is outside the watch window (STANDBY).
    function elapsedMinutes(nowMin as Number) as Number { ... }

    // Percentage of total watch completed (0-100)
    function watchProgress(nowMin as Number) as Number { ... }

    // Current block index (0-based)
    function currentBlockIndex(elapsedMin as Number) as Number { ... }

    // True if current block is On Duty
    function isOnDuty(blockIndex as Number) as Boolean { ... }

    // Percentage of current block completed (0-100)
    function blockProgress(elapsedMin as Number) as Number { ... }

    // Minutes remaining in current block (clamped to 0)
    function blockRemaining(elapsedMin as Number) as Number { ... }

    // Minutes until next watch start — used in STANDBY state
    function minutesUntilWatchStart(nowMin as Number) as Number { ... }
}
```

### Critical edge cases

- `totalWatchMinutes()`: if `endMin < startMin` → overnight → `(1440 - startMin) + endMin`
- `elapsedMinutes()`: if time is outside watch window → return `-1` (STANDBY signal)
- `blockProgress()`: guard division by zero if block duration is 0
- `blockRemaining()`: clamp to 0, never negative
- All callers must handle `elapsedMinutes() == -1`

### Verification — add temporary test in `WatchTrackerApp.initialize()`

```monkey-c
// Scenario: start=20:00 (1200), end=08:00 (480), 4h on / 4h rest
// At 22:30 (1350) → elapsed=150min, watchProgress=20%, block=0 (onDuty), blockProgress=62%
System.println(WatchSchedule.totalWatchMinutes());      // expect 720
System.println(WatchSchedule.elapsedMinutes(1350));     // expect 150
System.println(WatchSchedule.watchProgress(1350));      // expect 20
System.println(WatchSchedule.isOnDuty(0));              // expect true
System.println(WatchSchedule.blockProgress(150));       // expect 62
```

-----

## Phase 2 — Main View, Static Layout (~30 min)

Implement `MainView.mc` with hardcoded values. Verify the visual layout before wiring dynamic data.

### MainView.mc structure

```monkey-c
class MainView extends WatchUi.View {

    var _watchPct   as Number  = 48;
    var _blockPct   as Number  = 23;
    var _isOnDuty   as Boolean = true;
    var _blockIndex as Number  = 1;
    var _blockTotal as Number  = 4;
    var _remaining  as String  = "3h 12m";
    var _isStandby  as Boolean = false;
    var _timer      as Timer.Timer?;

    function initialize() { View.initialize(); }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 60000, true);
        updateState();
    }

    function onHide() {
        // CRITICAL: stop timer to avoid battery drain
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTimer() {
        updateState();
        WatchUi.requestUpdate();
    }

    function updateState() {
        // Phase 3: wire WatchSchedule here
    }

    function onUpdate(dc as Graphics.Dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        if (_isStandby) { drawStandby(dc); } else { drawActive(dc); }
    }

    function drawActive(dc)   { ... }
    function drawStandby(dc)  { ... }
    function drawProgressBar(dc, x, y, w, h, pct) { ... }
}
```

### Layout coordinates for 176×176 px

```
MARGIN = 8        BAR_H = 10        BAR_W = 160   // 176 - 2*MARGIN

Watch label:    drawText( 88,   8, FONT_SMALL,  "WATCH 48%",   CENTER)
Watch bar:      drawProgressBar(8, 28, 160, 10, watchPct)
State label:    drawText( 88,  50, FONT_MEDIUM, "ON DUTY",     CENTER)
Block counter:  drawText( 88,  82, FONT_SMALL,  "Block 2 of 4",CENTER)
Block bar:      drawProgressBar(8, 100, 160, 10, blockPct)
Countdown:      drawText( 88, 118, FONT_SMALL,  "ends in 3h 12m", CENTER)
```

### Drawing notes — MIP monochrome

- Background: `dc.clear()` on white background
- Progress bar fill: `dc.fillRectangle(x, y, filledWidth, h)`
- Progress bar border: `dc.drawRectangle(x, y, totalWidth, h)`
- Colors: **only** `Graphics.COLOR_BLACK` and `Graphics.COLOR_WHITE`
- Text fonts: `Graphics.FONT_SMALL`, `FONT_MEDIUM`, `FONT_LARGE`
- Justification: `Graphics.TEXT_JUSTIFY_CENTER`

### Verification

- [ ] Simulator renders text without clipping
- [ ] Progress bars fill proportionally with hardcoded values
- [ ] No crash on `onHide()` (navigate back)

-----

## Phase 3 — Wire Dynamic Data + Input (~30 min)

Connect `MainView` to `WatchSchedule`. Load Properties. Add navigation to `DetailsView`.

### Tasks

- [ ] **Implement `updateState()`** — call `WatchSchedule` with `System.getClockTime()`, populate all view fields
- [ ] **Load Properties** — `WatchTrackerApp.onStart()` calls `WatchSchedule.loadConfig()`
- [ ] **Implement `DetailsView`** — watch times, schedule pattern, total duration — plain text layout
- [ ] **Implement `WatchTrackerDelegate`** — UP/DOWN → DetailsView, START → force refresh
- [ ] **Wire Delegate** — `getInitialView()` returns `[new MainView(), new WatchTrackerDelegate()]`

### WatchTrackerDelegate

```monkey-c
class WatchTrackerDelegate extends WatchUi.BehaviorDelegate {

    function onNextPage() {     // UP
        WatchUi.pushView(new DetailsView(), null, WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() { // DOWN
        WatchUi.pushView(new DetailsView(), null, WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() {       // START — force refresh
        WatchSchedule.loadConfig();
        WatchUi.requestUpdate();
        return true;
    }
}
```

### updateState() skeleton

```monkey-c
function updateState() {
    var clock  = System.getClockTime();
    var nowMin = clock.hour * 60 + clock.min;
    var elapsed = WatchSchedule.elapsedMinutes(nowMin);

    if (elapsed < 0) {
        _isStandby  = true;
        _remaining  = formatMinutes(WatchSchedule.minutesUntilWatchStart(nowMin));
        return;
    }

    _isStandby   = false;
    _watchPct    = WatchSchedule.watchProgress(nowMin);
    var bi       = WatchSchedule.currentBlockIndex(elapsed);
    _isOnDuty    = WatchSchedule.isOnDuty(bi);
    _blockPct    = WatchSchedule.blockProgress(elapsed);
    _remaining   = formatMinutes(WatchSchedule.blockRemaining(elapsed));
    // _blockTotal and _blockIndex: derive from totalWatchMinutes / blockDuration
}
```

### Verification

- [ ] Set Properties in simulator (Settings menu), verify UI updates
- [ ] Test overnight: `watchStartMin=1320` (22:00), `watchEndMin=480` (08:00), simulate at 01:00 → expect elapsed=180, watchProgress~25%
- [ ] Navigate UP → DetailsView → BACK → MainView

-----

## Phase 4 — Edge Cases & Hardening (~30 min)

### Tasks

- [ ] **STANDBY state** — `elapsedMinutes == -1` → show STANDBY + countdown to watch start
- [ ] **Zero-duration guard** — `watchStartMin == watchEndMin` → show “Invalid Schedule”
- [ ] **Properties null-guard** — every `getValue()` falls back to a default constant
- [ ] **Block overflow** — elapsed > totalWatchMinutes → STANDBY, not negative countdown
- [ ] **Remaining formatter** — `formatMinutes(min)`: `"3h 12m"`, `"45m"` (if hours=0), `"2h"` (if min=0)

### Test matrix

|Scenario           |Input                       |Expected                       |
|-------------------|----------------------------|-------------------------------|
|Normal mid-watch   |start=0, end=720, now=180   |25% watch, block 1, ON DUTY 75%|
|Overnight watch    |start=1320, end=480, now=60 |10% watch, block 1, ON DUTY 25%|
|Before watch starts|start=600, end=1200, now=300|STANDBY, starts in 5h          |
|Watch just ended   |start=0, end=720, now=721   |STANDBY                        |
|Properties all null|—                           |All defaults, no crash         |
|start == end       |start=600, end=600          |“Invalid Schedule” error view  |

-----

## Phase 5 — Device Deploy & Smoke Test (~20 min)

### Tasks

- [ ] **Build .prg** — VS Code → Build for Device → `instinct2solar`
- [ ] **Deploy** — USB → mount as drive → copy `.prg` to `GARMIN/APPS/` → safely eject
- [ ] **Configure** — Garmin Connect Mobile → My Device → Connect IQ → Watch Tracker → Settings
- [ ] **Smoke test on device** — navigate to widget, verify all states
- [ ] **Battery check** — leave running 1 hour, no abnormal drain

> **Debug tip:** If widget crashes → connect USB → check `GARMIN/APPS/LOGS/CIQ_LOG.yml`

-----

## Quick Reference

### Monkey C APIs

|API                                   |Usage                                           |
|--------------------------------------|------------------------------------------------|
|`System.getClockTime()`               |Returns `ClockTime` with `.hour`, `.min`, `.sec`|
|`Application.Properties.getValue(key)`|Read setting; returns `null` if not set         |
|`Timer.Timer()`                       |Create timer; `.start(callback, ms, repeat)`    |
|`WatchUi.requestUpdate()`             |Trigger `onUpdate()` on next frame              |
|`WatchUi.pushView(view, del, anim)`   |Navigate to new view                            |
|`dc.drawText(x, y, font, text, just)` |Render text on canvas                           |
|`dc.fillRectangle(x, y, w, h)`        |Filled rect — progress bar fill                 |
|`dc.drawRectangle(x, y, w, h)`        |Outline rect — progress bar border              |
|`Graphics.FONT_SMALL/MEDIUM/LARGE`    |Built-in font constants                         |
|`Graphics.COLOR_BLACK / COLOR_WHITE`  |Only colors on MIP display                      |
|`Graphics.TEXT_JUSTIFY_CENTER`        |Center-align text at x, y                       |