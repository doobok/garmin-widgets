
**Platform:** Garmin Connect IQ · **Device:** Instinct 2 Solar · **API Level:** 3.3.4  
**App Type:** `widget` · **Language:** Monkey C · **Version:** 1.0.0 · **Status:** Draft

-----

## 1. Overview

Watch Tracker is a Garmin Connect IQ widget for the Instinct 2 Solar that helps maritime or shift workers track their watch (duty rotation) progress in real time.

The widget displays:

- Overall watch progress (%)
- Current block state — **ON DUTY** or **REST**
- Block-level progress (%)
- Countdown to the next state change

Navigation is via the device’s 5-button interface. All configuration is performed through the Garmin Connect mobile application using the Properties API.

-----

## 2. Device Constraints

|Property      |Value                                          |
|--------------|-----------------------------------------------|
|Display       |176 × 176 px, monochrome MIP (black/white only)|
|Touch         |None — 5-button navigation only                |
|API Level     |3.3.4 (pre-CIQ 4.x)                            |
|Memory        |~32 KB heap for widgets                        |
|Navigation    |UP / DOWN / BACK / START / LIGHT               |
|Config channel|Garmin Connect Mobile (Properties API)         |
|CIQ Store     |Supported                                      |


> **Important:** Instinct 2 Solar runs API Level 3.3.4. It does **not** support CIQ 4.x features: Complications, Super App / Glance carousel, AMOLED partial updates. Correct app type is `widget`.

-----

## 3. Functional Requirements

### 3.1 Configuration Parameters

All parameters are configurable via Garmin Connect Mobile. Read at startup via Properties API.

|Parameter      |Type  |Default|Description                                    |
|---------------|------|-------|-----------------------------------------------|
|`watchStartMin`|Number|`0`    |Watch start time in minutes from 00:00 (0–1439)|
|`watchEndMin`  |Number|`720`  |Watch end time in minutes from 00:00 (0–1439)  |
|`onDutyHours`  |Number|`4`    |Duration of an On Duty block in hours (1–12)   |
|`restHours`    |Number|`4`    |Duration of a Rest block in hours (1–12)       |
|`firstBlock`   |Enum  |`0`    |First block type: `0` = On Duty, `1` = Rest    |

### 3.2 Core Business Logic

#### 3.2.1 Watch Duration

Supports overnight watches (`endMin < startMin`):

```
if watchEndMin >= watchStartMin:
    totalMin = watchEndMin - watchStartMin
else:  // overnight
    totalMin = (1440 - watchStartMin) + watchEndMin
```

#### 3.2.2 Block Schedule

Blocks alternate starting from `firstBlock`. Each block has a fixed duration. The schedule repeats cyclically within the watch duration. A partial block at the end is shown as-is.

```
blocks = [onDutyMin, restMin, onDutyMin, restMin, ...]
until sum(blocks) >= totalWatchMinutes
```

#### 3.2.3 State Calculation

At any moment within the watch, the widget determines:

|Value           |Description                                         |
|----------------|----------------------------------------------------|
|`elapsed`       |Minutes since watch start (midnight-safe)           |
|`watchProgress` |`elapsed / totalMin * 100` — capped at 100%         |
|`currentBlock`  |Which block index is active                         |
|`blockProgress` |`elapsedInBlock / blockDuration * 100`              |
|`blockRemaining`|Minutes left in current block                       |
|`watchState`    |ON DUTY or REST (parity of block index + firstBlock)|

If current time is outside the watch window → **STANDBY** state.

#### 3.2.4 Midnight Crossing

All time comparisons use modular arithmetic on minutes-from-midnight (0–1439). `elapsedMinutes()` wraps correctly across the 00:00 boundary.

### 3.3 Display Views

#### 3.3.1 Main View (Primary)

Full 176×176 px canvas. Entry point of the widget.

```
+---------------------------+
|  WATCH  48%               |  <- watch % (top)
|  [==========---------]    |  <- watch progress bar
|                           |
|  ▶ ON DUTY                |  <- current state (bold, center)
|  Block 2 of 4             |  <- block counter
|  [=====--------------]    |  <- block progress bar
|  ends in  3h 12m          |  <- countdown
+---------------------------+
```

STANDBY layout (outside watch window):

```
+---------------------------+
|          STANDBY          |
|  Watch starts in 4h 22m   |
+---------------------------+
```

#### 3.3.2 Details View (UP button)

- Watch start/end times formatted as `HH:MM`
- Schedule pattern (e.g., `4h ON / 4h REST`)
- Total watch duration
- Number of full cycles in current watch

### 3.4 Navigation

|Button   |Action                                   |
|---------|-----------------------------------------|
|UP / DOWN|Scroll between Main View and Details View|
|START    |Force re-read of Properties + refresh    |
|BACK     |Exit widget, return to widget loop       |
|LIGHT    |No action (device backlight)             |

### 3.5 Update Frequency

60-second Timer refresh. Timer starts in `onShow()`, stops in `onHide()`. No sub-second updates required.

-----

## 4. Non-Functional Requirements

### 4.1 Performance

- Widget loads and displays initial state within 500 ms of activation
- `onUpdate()` executes within CIQ runtime budget (target < 100 ms)
- No memory leaks — Timer stopped in `onHide()`

### 4.2 Battery

- 60-second refresh interval — no sub-second timers
- Pure arithmetic — no GPS, BLE, or sensor access
- Heap allocation minimised: calculations stateless, performed per update

### 4.3 Reliability

- Corrupted or missing Properties values fall back to defaults
- Midnight crossing handled correctly for any valid start/end combination
- Division-by-zero protection on all percentage calculations

### 4.4 Maintainability

- `WatchSchedule` fully decoupled from rendering (`MainView`)
- No magic numbers — all constants defined at top of source files
- Each public function has a descriptive comment

-----

## 5. Project Structure

```
watch-tracker/
├── manifest.xml
├── resources/
│   ├── settings/
│   │   └── settings.xml        # Properties schema for Garmin Connect
│   └── strings/
│       └── strings.xml
└── source/
    ├── WatchTrackerApp.mc      # Application entry point
    ├── WatchTrackerDelegate.mc # Input handler
    ├── MainView.mc             # Primary display view
    ├── DetailsView.mc          # Secondary info view
    └── WatchSchedule.mc        # Pure business logic module
```

-----

## 6. Data Persistence

Configuration stored via `Toybox.Application.Properties`. Persists across widget restarts. No `ObjectStore` required for v1.0.

```monkey-c
var startMin = Application.Properties.getValue("watchStartMin");
if (startMin == null) { startMin = 0; }
```

-----

## 7. Settings Schema

```xml
<settings>
  <setting propertyKey="watchStartMin" title="Watch Start (min)">
    <settingConfig type="numeric" min="0" max="1439" />
  </setting>
  <setting propertyKey="watchEndMin" title="Watch End (min)">
    <settingConfig type="numeric" min="0" max="1439" />
  </setting>
  <setting propertyKey="onDutyHours" title="On Duty Block (hours)">
    <settingConfig type="numeric" min="1" max="12" />
  </setting>
  <setting propertyKey="restHours" title="Rest Block (hours)">
    <settingConfig type="numeric" min="1" max="12" />
  </setting>
  <setting propertyKey="firstBlock" title="First Block">
    <settingConfig type="list">
      <listEntry value="0">On Duty</listEntry>
      <listEntry value="1">Rest</listEntry>
    </settingConfig>
  </setting>
</settings>
```

-----

## 8. Out of Scope (v1.0)

- Complications / Watch Face integration (requires CIQ 4.x)
- Notifications or alerts at block transitions
- Multiple watch schedules or profiles
- Multi-device support beyond Instinct 2 series
- Companion mobile app

-----

## 9. Glossary

| Term           | Definition                                                               |
| -------------- | ------------------------------------------------------------------------ |
| Watch          | A scheduled duty period divided into alternating On Duty and Rest blocks |
| Block          | A single continuous period of On Duty or Rest within the watch           |
| Watch progress | Percentage of total watch elapsed time completed                         |
| Block progress | Percentage of current block elapsed time completed                       |
| MIP            | Memory-In-Pixel — Instinct 2’s always-on monochrome display technology   |
| CIQ            | Connect IQ — Garmin’s application platform and runtime                   |
| Properties     | Garmin API for persistent key-value configuration tied to the app        |