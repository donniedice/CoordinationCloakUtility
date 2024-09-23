# Coordination Cloak Utility

## Overview

**Coordination Cloak Utility** simplifies the use of teleportation cloaks in World of Warcraft by automating gear swaps. It equips your teleportation cloak before use and re-equips your original cloak afterward, enhancing gameplay efficiency.

---

## Features

- **Automatic Cloak Detection**
  - Detects all teleportation cloaks in your inventory, including:
    - [Cloak of Coordination](https://www.wowhead.com/item=65360)
    - [Wrap of Unity](https://www.wowhead.com/item=63206)
    - [Shroud of Cooperation](https://www.wowhead.com/item=63352)
    - And more.

- **Seamless Cloak Swapping**
  - **Auto-Equip**: Saves your original cloak and equips the teleportation cloak when using `/ccu` or equipping manually.
  - **Auto Re-Equip**: Re-equips your original cloak after teleportation.

- **On-Screen Teleportation Button**
  - Appears when a teleportation cloak is equipped.
  - **Single Click Teleport**: Click to cast teleportation; the addon handles cloak swaps automatically.
  - **Cooldown Alerts**: Notifies you if the cloak is on cooldown, displaying remaining time.

- **User-Friendly Commands**
  - `/ccu`: Initiates cloak swap and displays teleportation button.
  - `/ccu help`: Shows help information.
  - `/ccu welcome`: Toggles the welcome message.

- **Combat Compliance**
  - Avoids gear swaps or UI changes during combat, notifying you if action is restricted.

---

## Installation

1. **Download** the addon from:
   - [CurseForge](https://legacy.curseforge.com/wow/addons/ccu-coordination-cloak-utility)
   - [GitHub](https://github.com/donniedice/CoordinationCloakUtility)
   - [Wago.io](#)

2. **Extract** to your WoW `Interface/AddOns` directory:
   - For **Retail**: `World of Warcraft/_retail_/Interface/AddOns`

3. **Restart WoW** and enable the addon in the AddOns menu.

---

## Usage

- **Initiate Cloak Utility**: Type `/ccu` in chat.
- **Access Help**: Type `/ccu help`.
- **Toggle Welcome Message**: Type `/ccu welcome`.

---

## Error Handling

- **No Usable Cloaks Found**: Informs you if no teleportation cloaks are available or all are on cooldown.
- **Item Info Unavailable**: Waits for item data to load before proceeding.
- **Combat Restrictions**: Notifies you if actions are attempted during combat.
- **Cooldown Notifications**: Alerts you to remaining cooldown times.
- **Manual Cloak Swapping**: Handles cloak swaps even when done manually.
- **Interrupted Teleportation**: Detects interruptions and adjusts accordingly.
- **Post-Teleport Combat**: Waits until combat ends to re-equip original cloak if needed.

---

## Support the Project

If you find this addon helpful:

- **Buy Me a Coffee**: [☕️ Donate](https://www.buymeacoffee.com/donniedice)
- **Donate via CashApp**: [💸 Donate](https://bit.ly/3fyxxSU)
- **Star on GitHub**: [⭐️ CoordinationCloakUtility](https://github.com/donniedice/CoordinationCloakUtility)
- **Share** with friends and guildmates!

---

## Feedback and Contributions

Your feedback is valuable! If you encounter any issues or have suggestions:

- **Report Issues**: [GitHub Issues](https://github.com/donniedice/CoordinationCloakUtility/issues)
- **Contribute**: Submit a pull request on GitHub.
- **Contact**: Reach out via GitHub.

---

## License

This project is licensed under the [MIT License](https://github.com/donniedice/CoordinationCloakUtility/blob/main/LICENSE).

---

## Disclaimer

This addon is provided "as is" without warranty. Use at your own risk. The author is not responsible for any issues arising from its use.
