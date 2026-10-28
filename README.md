# KianCraft

A kid-friendly multiplayer block-building adventure game, made by a dad and his son with [Godot](https://godotengine.org/). It plays a lot like Minecraft: explore, mine, build, craft, beat bosses and play together on the same home network. All the art and sounds are made in code.

## ⬇️ Download and play (Windows)

1. Go to **[Releases](../../releases/latest)** and download **`KianCraft.exe`**.
2. Double-click it. There's nothing to install.
3. **Windows may warn you** ("Windows protected your PC") because the game isn't signed by a big company. Click **More info**, then **Run anyway**.

The game starts with no worlds and no characters. You make your own on first launch.

## What's in it

- An endless world with lots of biomes: meadows, tall forest, snowy mountains, desert, candy land, fall forest, spooky forest, floating islands, a chessboard kingdom and fast food land.
- **11 bosses** in their own lairs, each with a legendary drop and a trophy power.
- Villager camps in every biome, with a different folk for each biome and shops that change every day.
- Crafting tiers from wood to titanium, recipes you unlock with toots, gem jewelry, cute gear and capes.
- Water and lava that flow like Minecraft.
- **The Deep**, far underground below a titanium-only crust: gems, albino monsters, lava caverns and the Fire Giant.
- Fairies that follow you and give you powers, maps, chests, beds, doors, furniture and lots of building blocks.
- Multiplayer for up to 8 players with chat, trading and parties.

## Playing together

**On the same Wi-Fi or home network:**
1. One person picks a world and clicks **Host for Friends**.
2. They press **Esc**. The pause menu shows their address (something like `192.168.1.23`).
3. Everyone else types that address under **Join a friend**.
4. If it doesn't connect, allow KianCraft through the host's Windows firewall when it asks.

**Over the internet:** use a free virtual-LAN app like [Tailscale](https://tailscale.com/) or [ZeroTier](https://www.zerotier.com/) and join using the host's Tailscale or ZeroTier address. Or the host can forward **UDP port 7777** on their router.

## Controls

| Key | Action |
|---|---|
| W A S D, Space, Ctrl, Shift | Move, jump, sprint, sneak |
| Left click (hold) | Mine, or attack |
| Right click | Use, open, eat or place |
| 1–9 / mouse wheel | Hotbar |
| E or Tab | Inventory and crafting |
| T or Enter, / | Chat, commands (`/help`) |
| Esc | Pause menu |
| F1 / F3 / F11 | Controls card / FPS and coordinates / fullscreen |

## Where your worlds are saved

Worlds, characters and settings live only on your own PC:
- **Windows:** `%APPDATA%\Godot\app_userdata\Blockcraft\`

## Playing from the source (any computer)

1. Download [Godot 4.7](https://godotengine.org/download) (the normal version, not .NET).
2. Click **Code → Download ZIP** on this page and unzip it.
3. In Godot, click **Import**, pick `project.godot`, then press **F5** to play.

To build your own exe in Godot, use **Project → Export → Windows**.

---
© 2026 UserForFunzies. **All rights reserved.** You're welcome to download and play the game and to read the source, but please don't copy, share, modify or reuse it. See [LICENSE](LICENSE).
