# Slingshot Something

A short space game I made in 3 days in Godot, without using a single asset. Every planet, ship, star and effect is drawn with Godot's built-in draw commands and shaders, and even the sound effects are generated in code. I wanted to see if I could make a game with no art files at all.

You fly a small ship around an open solar system, using planet gravity to slingshot yourself around, because your fuel won't last long. Pick research missions at space stations, survey planets and land probe drones on them, then cash in your research for credits and upgrade your ship.

*(Super Wakatime shows up in the repo because it's a plugin I use to track how long I spend working on it. It isn't part of the game.)*

<img width="767" height="422" alt="Screenshot 2026-09-29 223626" src="https://github.com/user-attachments/assets/761ac20c-db87-419e-b5d4-722b0cd35411" />

## Framework

- **Engine:** Godot 4.6 (Forward+ renderer)
- **Language:** GDScript
- **Assets:** none. Everything is drawn with `_draw()`, shaders and particles, and all sounds are generated in code.

## Demo

**Download it on itch.io:** https://hesitant.itch.io/slingshot-smthng

What's in the demo:
- An open solar system with a sun, 7 planets, moons, an asteroid belt and a black hole, all moving on real orbits
- Gravity-based flying, where you slingshot around planets to save fuel
- Survey and drone research missions that you choose at space stations
- Research levels for each planet, up to 3
- Upgrades for fuel, engine, efficiency, drones, hull and scanner
- An autopilot that flies you to the nearest station and a docking beam that pulls you in
- A minimap and a mission tracker

**Controls:** mouse to aim · left click to boost · S or Shift to brake · right click or E to fire a drone · F for autopilot · T to switch target · TAB for missions · M for the map · Esc to pause

## Installation or running locally

**Play the build (Windows):**
1. Download the latest version from the itch.io page above, or download this repo as a ZIP.
2. Extract it and run the `.exe`.

**Open the project in Godot:**
1. Install [Godot 4.6](https://godotengine.org/download).
2. Clone the repo:
```
   git clone https://github.com/unityguy45/Slingshot-something.git
```
3. Open Godot, click **Import**, and select the `project.godot` file.
4. Press **F5** to run.

It's a lightweight project, so it should run on most computers.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
