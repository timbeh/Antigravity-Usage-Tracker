# 🚀 Antigravity Usage Tracker for macOS

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-black.svg?logo=apple)](https://apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](#contributing)

A beautifully native, lightning-fast macOS Menu Bar app that tracks your Google Antigravity (Codeium/Windsurf) LLM quotas in real-time. 

Built entirely in **SwiftUI**, it connects directly to your local IDE language server to instantly display your remaining usage quotas in Antigravity, without requiring Node.js, external CLI tools, or cloud authentication.


## ✨ Why this exists
Keeping track of premium AI usage limits inside the IDE can be frustrating. While [other excellent tools exist](https://github.com/skainguyen1412/antigravity-usage), they require Node.js, `npm` global installs, and shell wrappers running constantly in the background. 

This project was built to be the **ultimate native macOS experience**. It runs purely in Swift, consumes virtually zero system resources, and gives you a beautiful, native popover right in your Mac's top bar.

## 🌟 Key Features

- **⚡️ Zero Dependencies:** Pure native Swift. No Node.js, no Python, no CLI wrappers.
- **🎯 Smart Port Discovery:** Automatically scans your Mac's process tree to find the dynamic local gRPC port and CSRF tokens used by the Antigravity Language Server.
- **🎨 Native SwiftUI Interface:** A sleek, responsive Menu Bar extra with dynamic progress bars that change color (Green/Orange/Red) as your quota depletes.
- **⏰ Live Reset Timers:** Accurately decodes ISO-8601 timestamps to tell you exactly when your quotas reset (e.g., *"Resets tomorrow at 4:00 PM"*).
- **🪣 Custom Quota Buckets:** Group shared quotas together! (e.g., Combine `gemini-3.1-pro-high` and `gemini-3.1-pro-low` into a single "Gemini Pro" progress bar).
- **🕵️‍♂️ Built-in Debugger:** If the IDE is closed or the connection fails, the app safely displays the exact server response logs inside the UI for easy debugging.

---

## 🛠 Installation

### Option 1: Download the App
1. Go to the [Releases](#) tab.
2. Download `AntigravityTracker.app.zip`.
3. Unzip and drag the app into your `Applications` folder.
4. Launch it! It will automatically pin itself to your Menu Bar.

### Option 2: Build from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/timbeh/Antigravity-Usage-Tracker.git
   ```
2. Open `Antigravity-Usage-Tracker.xcodeproj` in Xcode 14+.
3. Ensure **App Sandbox** is disabled in your `Signing & Capabilities` tab (this is required so the app can scan the local `ps` process tree to find the IDE's dynamic port).
4. Hit `Cmd + R` to build and run.

---

## ⚙️ Configuration & Custom Buckets

Antigravity frequently shares quota limits across multiple models (e.g., *Claude 4.6 Sonnet Thinking* and *Claude 4.6 Opus Thinking* draw from the exact same token bucket). 

Instead of showing you three identical progress bars, this app includes a powerful **Settings Interface** allowing you to group them:

1. Click on the Menu Bar icon and select **"Settings..."**
2. Enable **Quota Grouping**.
3. Create a new Bucket (e.g., "Claude Models").
4. Look at the blue **Live IDs** cheat sheet at the top of the settings window, and paste the exact model slugs you want to group into the text box (comma-separated).
5. Your menu bar will instantly collapse them into one clean progress bar!

---

## 🧠 How it works under the hood

When Google Antigravity boots up it's IDE, it launches a local background Language Server. This server generates a dynamic, randomized port and a secure CSRF token to prevent unauthorized access.

This Swift app bypasses the need for cloud authentication by using a **Dual-Discovery** system to handshake directly with that local server:

1. **Process Scanning:** It silently executes `ps -xww` to locate the `language_server_macos` PID and parses its launch arguments to extract the `--csrf_token`.
2. **Port Probing:** It uses `lsof -nP -a -p PID -iTCP -sTCP:LISTEN` to find every local TCP port opened by the Language Server.
3. **gRPC Handshake:** It loops through the discovered ports, sending a POST request to `/exa.language_server_pb.LanguageServerService/GetUserStatus` with the required `X-Codeium-Csrf-Token` header, parsing the resulting JSON payload natively in Swift.

Because it connects locally, **it only updates when your IDE is open**.

---

## 🙏 Acknowledgements

Massive credit to the open-source community that helped reverse-engineer the Antigravity/Windsurf local APIs.
* Inspiration and local API endpoint structure adapted from [skainguyen1412/antigravity-usage](https://github.com/skainguyen1412/antigravity-usage) and [hamed-elfayome/Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker).

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*If you find this tool helpful, please consider leaving a ⭐️ on the repository!*
