# SETUP — getting your Mac ready (≈1–2 hours, mostly downloads)

Do these steps yourself, once. After that, the coding assistant does the building, one milestone at a time.

> **Building happens on your Mac.** iPhone and Apple Watch apps can only be built with Xcode, and Xcode only runs on macOS. You can read and edit these docs on any computer.

---

## 1. What you need

- Your Mac with **40 GB+ free space** (Apple menu → About This Mac → Storage)
- Your iPhone and its cable, and your Apple Watch (paired to that iPhone)
- Your Apple ID (a free account is enough)
- A coding assistant that can work in a folder on your Mac (Codex or Claude Code). Install it using its official instructions.

---

## 2. Install Xcode

1. Mac App Store → search **Xcode** → Get. It's large, so leave it to download.
2. Open Xcode once. Accept the licence and let it install components.
3. **Xcode → Settings → Components:** make sure the **iOS** and **watchOS** platforms (simulators) are installed.
4. **Xcode → Settings → Accounts → +** → Apple ID → sign in. It will show **"Your Name (Personal Team)"**.

---

## 3. Create the project

1. **File → New → Project → iOS → App** → Next
   - Product Name: `Steady`
   - Team: *Your Name (Personal Team)*
   - Organization Identifier: `com.yourname` (lowercase, no spaces). **Keep this forever.**
   - Interface: **SwiftUI** · Language: **Swift** · Storage: **None** · Testing System: **Swift Testing**
   - Save it in a folder like `~/Developer/` and tick **Create Git repository on my Mac**
2. Add the watch app: **File → New → Target → watchOS → App** → Next
   - Product Name: `SteadyWatch`
   - Choose **Watch App for Existing iOS App** → companion app: **Steady**
   - Finish. If asked to activate the scheme, click **Activate**.
3. Your folder now looks like this:
   ```
   ~/Developer/Steady/
   ├── Steady.xcodeproj
   ├── Steady/
   └── SteadyWatch Watch App/
   ```
4. **Copy this starter kit into that folder** so `AGENTS.md`, `CLAUDE.md`, `SETUP.md`, `.gitignore` and `docs/` sit next to `Steady.xcodeproj`.

---

## 4. Permissions (both targets)

For **Steady** and then again for **SteadyWatch Watch App**:

1. Click the blue project icon → select the target → **Signing & Capabilities**
   - Team: your Personal Team. Leave **Automatically manage signing** ticked.
   - **+ Capability → HealthKit**
2. **Info** tab → hover any row → **+** → add these keys (type the name; Xcode autocompletes):

| Key | Value |
|---|---|
| Privacy - Health Share Usage Description | Steady reads your sleep, heart and activity data to suggest realistic plans. |
| Privacy - Health Update Usage Description | Steady saves the meals and drinks you log to Apple Health. |
| Privacy - Calendars Full Access Usage Description *(iPhone only)* | Steady finds free time in your schedule and adds plans to its own calendar when you confirm. |
| Privacy - Location When In Use Usage Description *(iPhone only)* | Steady uses your approximate location to find food nearby when you ask. |

---

## 5. Prepare your iPhone and Watch

1. Plug the iPhone into the Mac → unlock → **Trust This Computer**.
2. iPhone: **Settings → Privacy & Security → Developer Mode → On** → restart → confirm. (This option appears after Xcode has seen the phone.)
3. Watch (on its charger, near the phone): **Settings → Privacy & Security → Developer Mode → On** → restart.
4. Xcode → **Window → Devices and Simulators** → both devices should appear. The first time, this can take a few minutes while Xcode prepares them.

---

## 6. First run (checks everything works)

1. At the top of Xcode, choose scheme **Steady** and your **iPhone** → press **▶**.
2. On the iPhone the first time: **Settings → General → VPN & Device Management** → your Apple ID → **Trust**. Press ▶ again.
3. You should see the default "Hello, world!" app. Setup is done.
4. Choose scheme **SteadyWatch Watch App** and your **Watch** → ▶. The first watch install can be slow or fail once on a free account. Just run it again.

---

## 7. Start building with your coding assistant

1. Open your coding assistant **in the `~/Developer/Steady` folder**.
2. Paste the **Kickoff prompt** from `docs/PROMPTS.md`. It builds **M0** only.
3. After each milestone:
   - Follow the **"Test it on your iPhone/Watch"** steps it gives you.
   - Save your progress: Xcode → **Integrate → Commit…** (or ask the assistant to commit).
   - Then paste the **Next milestone prompt** from `docs/PROMPTS.md`.
4. If a session goes badly: Xcode → **Integrate → Discard All Changes…** takes you back to your last commit.

---

## 8. Your weekly routine (free account)

Apps installed with a free account **stop opening after 7 days**. Every Sunday: plug in the iPhone → open Xcode → ▶ Run (then the watch scheme → ▶). It takes about 2 minutes. **Your data stays** as long as you don't delete the app.

---

## 9. Free stuff to set up on your phone now (no code)

- **Health app → Sleep → Set up Sleep Schedule** and turn on **Track Sleep with Apple Watch**. Steady needs a few nights of data.
- **Healthy 365** (Singpass) → pair Apple Health → join the **National Steps Challenge** to earn Healthpoints you can redeem.
- **ActiveSG** app → check your credits → **make at least one booking before 31 Dec 2026** so your credits roll into 2027.
- Wear the watch to bed. Charge it during your morning shower and breakfast.
