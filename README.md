# Flyover ✈️

**Flyover** is a lightweight, privacy-focused macOS menu-bar utility designed to gently remind you to take breaks. When it's break time, a beautifully animated, procedurally generated 3D vehicle flies across your screen towing a customizable banner text to nudge you to stand up, stretch, or rest your eyes.

---

## Key Features

- **Privacy-First Activity Tracking:** Uses system-wide keyboard and mouse idle times via `CGEventSource`. It requires **zero** accessibility permissions, does **not** log any keystrokes, and is entirely run on-device.
- **Multiple Procedural 3D Vehicles:**
  - **Propeller Plane:** The classic red & white airplane with a spinning nose propeller and white exhaust smoke.
  - **Paper Airplane:** A clean, matte white folded paper glider that drifts floatily on wind currents, trailing a warm gold stardust path.
  - **Retro Rocket:** A sleek red tin rocket that launches along a high-speed parabolic path, trailing a roaring column of fire and sparks.
  - **UFO:** A metallic flying saucer that zips in sharp, non-ballistic step-and-hover intervals, spins constantly on its Y-axis, and trails neon plasma.
  - **Hot Air Balloon:** A slow-moving, peaceful option that sways gently, fires its burner periodically (flame particle effect), and floats calmly.
  - **Witch on a Broomstick:** A spooky option riding a wooden straw broom, trailing purple sparks and flying with erratic swooping motions.
  - **Santa's Sleigh:** A festive option carrying gift box packages, led by a reindeer with gold reins/antlers, and trailing magical white snow dust.
- **Dynamic, Vehicle-Specific Banners:**
  - **Propeller Plane, Rocket, & Balloon:** Tow the standard high-contrast red fabric banner with traditional ropes.
  - **Paper Airplane:** Tows a clean white paper-like banner with a thin dark outline.
  - **UFO:** Projects a futuristic, semi-transparent green HUD billboard towed by a bright glowing green laser beam.
  - **Witch:** Tows a spooky dark purple banner with a bright orange border and text.
  - **Santa:** Tows a festive forest-green banner with a gold border and gold text.
- **GPU-Accelerated Banner Waving:** All banners now ripple smoothly in the wind using a custom Metal geometry shader modifier. The wave amplitude is zero at the rope connection point and increases toward the back, mimicking realistic aerodynamic drag.
- **Combinable Reminder Modes:**
  - **Active Streak:** Triggers after a continuous stretch of active work. Idle time resets the streak automatically.
  - **Fixed Interval:** Triggers at a fixed wall-clock interval since your last break, regardless of activity levels.
- **Daily Rollover:** Automatically tracks your active hours and breaks taken, resetting counters daily when the calendar date changes.
- **Test Fly Option:** Preview the 3D animation instantly with a click.

---

## Screen Preview

*When a reminder is triggered, a transparent, click-through overlay window is created, showing the 3D vehicle crossing the screen. You can continue clicking on underlying windows without interruption.*

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
