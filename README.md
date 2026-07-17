# Flyover ✈️

**Flyover** is a lightweight, privacy-focused macOS menu-bar utility designed to gently remind you to take breaks. When it's break time, a beautifully animated, procedurally generated 3D propeller plane flies across your screen towing a customizable banner text to nudge you to stand up, stretch, or rest your eyes.

---

## Key Features

- **Privacy-First Activity Tracking:** Uses system-wide keyboard and mouse idle times via `CGEventSource`. It requires **zero** accessibility permissions, does **not** log any keystrokes, and is entirely run on-device.
- **Procedural 3D Animations:** The animated propeller plane, exhaust smoke trails, and towed banner are built entirely with procedural geometry using macOS **SceneKit**. No heavy external assets or meshes are required.
- **Combinable Reminder Modes:**
  - **Active Streak:** Triggers after a continuous stretch of active work. Idle time resets the streak automatically.
  - **Fixed Interval:** Triggers at a fixed wall-clock interval since your last break, regardless of activity levels.
- **Daily Rollover:** Automatically tracks your active hours and breaks taken, resetting counters daily when the calendar date changes.
- **Test Fly Option:** Preview the 3D plane animation instantly with a click.

---

## Screen Preview

*When a reminder is triggered, a transparent, click-through overlay window is created, showing the 3D plane crossing the screen. You can continue clicking on underlying windows without interruption.*



https://github.com/user-attachments/assets/739d8366-3efa-42ba-922e-0aed8f51fa15



---

## Requirements

- **macOS:** 14.0+ (Sonoma or newer)
- **Swift version:** 6.0+ (Swift Package Manager supported)

---

## Build and Installation

You can build the application locally from source.

### 1. Build Using the Included Script
The repository includes a helper script `build-app.sh` that compiles a release binary, structures the `.app` bundle, injects the `Info.plist`, and signs it ad-hoc.

```bash
chmod +x build-app.sh
./build-app.sh
```

This generates `Flyover.app` in the root of the project.

### 2. Run the App
Launch the app directly from your terminal:
```bash
open Flyover.app
```
Alternatively, you can drag `Flyover.app` into your `/Applications` folder.

### 3. Dev Build
To build only the executable package for debugging:
```bash
swift build
```

---

## Development & Test Flight
To see the plane fly immediately upon launching:
```bash
FLYOVER_TESTFLY=1 open Flyover.app
```
Or simply click the **"Fly now"** button from the Flyover menu bar icon.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
