# Moonlight XR for visionOS 27

A fork of [RikuKunMS2/moonlight-ios-vision](https://github.com/RikuKunMS2/moonlight-ios-vision) (Moonlight XrOS) for Apple Vision Pro on visionOS 27, streaming from a [Sunshine](https://github.com/LizardByte/Sunshine) or [Apollo](https://github.com/ClassicOldSong/Apollo) host.

## Why this fork exists

I use Moonlight XrOS on Apple Vision Pro with a Bluetooth mouse to play PC games streamed from Sunshine. With the upstream TestFlight build (v11.0.22), three things blocked that:

1. **FPS Locked Mouse did not work.** Only Absolute Mouse mode responded, and absolute mode does not work in games that need relative mouse input (first-person camera control).
2. **The app could not be built with a free Apple ID.** The project declared the Group Activities, Low-Latency Streaming and Spatial Audio Profile capabilities. Xcode refuses to create a provisioning profile for those with a free Personal Team, so I could not build and test my own fixes.
3. **Pressing Home in a stream window crashed the app.** This happened in both the flat (UIKit) and the Volume (RealityKit) window.

## What this fork changes

| Area | Change |
|---|---|
| FPS Locked Mouse | Uses native `GCMouse` deltas for relative mouse movement and drops the synthetic hover-based movement. |
| Home button crash | Stream windows no longer reset their scene value while visionOS is closing them. Before this fix, SwiftUI stopped the app with `EXC_BREAKPOINT` in `ViewGraph.instantiateOutputs`. Verified on Apple Vision Pro (visionOS 27.0.1). |
| Stream stalls | Hardened VideoToolbox IDR recovery: session invalidation, parameter-set validation, and no audio reconfiguration on every IDR frame. |
| Audio | Avoids a main-thread deadlock in `OutputAU` audio session setup. |
| Free Apple ID builds | Removed SharePlay / Group Activities and the restricted entitlements. The visionOS target no longer needs SDL. Rebuilt the opus and FFmpeg libraries for visionOS. |

**Trade-off:** SharePlay and Spatial Personas co-watching are removed in this fork.

## Build it yourself (free Apple ID)

1. `git clone --recursive https://github.com/imaginaerumai/moonlight-XR-visionOS-27.git`
2. Open `Moonlight.xcodeproj` and select the **Moonlight XrOS** scheme.
3. In **Signing & Capabilities**, select your own Team and change the Bundle Identifier to a unique value.
4. Pair your Vision Pro in **Window > Devices and Simulators**. On the Vision Pro, turn on **Settings > Privacy & Security > Developer Mode** (this option appears only after you start pairing).
5. Select your Vision Pro as the run destination and press **Run**.

## License

This fork is licensed under the [GNU GPL v3](LICENSE.txt), the same license as Moonlight and Moonlight XrOS. All upstream credits below remain in effect.

---

**Additional note:** if you use AVP with Logitech or other multi-channel keyboards or mice, see my [easyswitch-reconnect-macos](https://github.com/imaginaerumai/easyswitch-reconnect-macos) repo. It fixes the "stale" Bluetooth connection that can happen when you switch a device from another computer to the AVP and back. Without it, you sometimes have to reset Bluetooth to reconnect the device to the original computer.

## Upstream README (Moonlight XrOS)


[Moonlight for VisionOs/iOS/tvOS](https://moonlight-stream.org) is an open source client for [Sunshine](https://github.com/LizardByte/Sunshine) and NVIDIA GameStream. Moonlight for iOS/tvOS allows you to stream your full collection of games and apps from your powerful desktop computer to your iOS device or Apple TV.

It also supports a Sunshine fork called [Apollo](https://github.com/ClassicOldSong/Apollo) which on Windows supports a Built-in Virtual Display with HDR support that matches the resolution/framerate config of your client automatically.

Moonlight also has a [PC client](https://github.com/moonlight-stream/moonlight-qt) and [Android client](https://github.com/moonlight-stream/moonlight-android).

Check out [the Moonlight wiki](https://github.com/moonlight-stream/moonlight-docs/wiki) for more detailed project information, setup guide, or troubleshooting steps. Also check out the [discord](https://moonlight-stream.org/discord).

### Credits
Special thanks to the all contributors for their work on Moonlight XrOS:
**tht7, linggan-ua, shinyquagsire23, alexhaugland, sinkingsugar, JFuellem, liu547161153, dereklucas, Razorub**

And to the **Moonlight Streaming team and contributors**:
[https://moonlight-stream.org/](https://moonlight-stream.org/)
[https://github.com/moonlight-stream/moonlight-ios/graphs/contributors](https://github.com/moonlight-stream/moonlight-ios/graphs/contributors)

---

[![Moonlight for iOS and tvOS](https://moonlight-stream.org/images/App_Store_Badge_135x40.svg)](https://apps.apple.com/us/app/moonlight-game-streaming/id1000551566) 

The Vision OS Version is not available in the App Store. To download the latest stable-ish build, please install it via Testflight:

[![Moonlight XrOS](https://i.imgur.com/DHhfmmK.png)](https://testflight.apple.com/join/poWcaME5) 

## Features

* **Curved Screen Support (Reality Kit Mode)**:
    * To activate, change the Renderer in settings to Reality Kit.
    * Distortion math has been redone for better accuracy and reduced stretching.
* **Immersive View**: Now you can use the reality kit stream view in a much larger size.
    * **Lock/Unlock**: Click the lock icon to lock its position, move the screen, and lock it again. We will add tilt control to the immersive view soon.
* **Mouse & Keyboard Support**: Now available in Reality Kit mode via Bluetooth paired to the Vision Pro.
* **SBS 3D Support**: Available in Reality Kit Mode. We are looking into support for uikit sbs.
* **HDR Support**: Includes a luminance value slider to calibrate for battery levels and environment.
    * *New:* Gamma and Saturation sliders added in v11.0.16.
    * *New:* Perfect 1:1 HDR EDR mapping and Calibration Mode toggle added in v11.0.21.
* **AV1 Support**: Confirmed working (including AV1 HDR) on M5 hardware.
* **Audio Control**: Toggle between Head-Tracked and Non-Head-Tracked audio.
* **SharePlay & Spatial Personas**: Enjoy immersive co-watching experiences with friends. *(Removed in this fork.)*
* **Reactive Lighting (Ambilight)**: Dynamic ambient lighting based on stream content in Reality Kit mode.
* **Localization**: Support for Chinese added (Thanks **linggan-ua**).

![Curved Screen Support](https://preview.redd.it/moonlight-xros-1-year-anniversary-update-curved-screen-v0-xyro5aozeyge1.jpg?width=2254&format=pjpg&auto=webp&s=df631301423de93f161111df41543154e8fd5b04)

## ChangeLog (Latest: v11.0.22 - April 26, 2026)

> **⚠️ IMPORTANT UPGRADE NOTE:**
> If you are coming from an older version (pre-11.0.15), please **Uninstall and Reinstall** the app via TestFlight. There are significant code changes regarding settings and localization that may cause crashes if you simply update over the old version.

> *** I RECOMEND USING APOLLO OVER SUNSHINE**
> [RikuKunMS2/Lumanaire](https://ko-fi.com/lumanaire) tests all builds using Apollo. Apollo is a Sunshine fork called [Apollo](https://github.com/ClassicOldSong/Apollo) which on Windows supports a Built-in Virtual Display with HDR support that matches the resolution/framerate config of your client automatically. 
>* **Apollo Permissions:** *Critical Note* — If using Apollo, you **must** ensure all permissions are enabled after pairing (Click the "Edit" button in Apollo). The developer primarily tests on Apollo.


### v11.0.22 (April 26, 2026)
* **Navigation Stability:** Fixed a bug causing the app to freeze when clicking 'Return to Home' while a second paired computer is offline by prioritizing the actively streaming host.
* **UIKit Stream Recovery:** Resolved an issue in UIKit mode where the 'Return to Home' button would occasionally fail to navigate or cause the application to crash.
* **Control Panel UI:** Realigned the UIKit mode control panel ornament to reliably anchor to the top edge of the window, ensuring visual consistency with RealityKit mode.
* **Home Screen Panel UI:** Set static position of the home screen menu so that it appears in front of the user in a static area (utility panel area) ensuring visual consistency when opening the home screen panel.
* **Virtual Keyboard UI:** Fixed an interaction regression in RealityKit mode where the supplementary PC-modifier toolbar (Windows/Esc keys) failed to trigger alongside the virtual keyboard.
* **AppIntent Shortcuts:** Fixed the ability to launch directly into a host via the Shortcuts app (AppIntent).

### v11.0.21 (April 25, 2026)
* **Audio Pipeline Refactor:** Complete migration of the spatial audio pipeline (`OutputAU`) to pure Objective-C.
* **Vision Pro Spatial Audio:** Restored functional audio streaming by properly activating `AVAudioSession` and integrating native `SpatialAudioComponent` for RealityKit. Fixed Opus decoding integration and eliminated "Session lookup failed" crashes.
* **SharePlay & Spatial Personas:** Integrated SharePlay-based co-watching using Spatial Personas for shared immersive viewing experiences.
* **Reactive Lighting (Ambilight):** Added a user-configurable Reactive Lighting toggle within the immersive control panel.
* **HDR Consistency & Calibration:** Re-enabled 1:1 HDR EDR mapping for perfect RealityKit HDR and introduced a Calibration Mode toggle in the immersive control panel.
* **UIKit Stream Recovery:** Added an "Open Main Menu" recovery button to the error overlay in UIKitStreamView to escape stuck window states on failed stream resumptions.

### v11.0.17 (Expected Release: Nov 25, 2025)
* **AV1 & HDR Confirmation:** Confirmed that AV1 and AV1 HDR are working correctly on M5 devices. Special thanks to **u/webheadVR** for testing.
* **Localization:** Fixed various localization strings (Thanks **linggan-ua**).
* **Shimmering:** Fixed the shimmering issue in Reality Kit.
* **Apollo Permissions:** *Critical Note* — If using Apollo, you **must** ensure all permissions are enabled after pairing (Click the "Edit" button in Apollo). The developer primarily tests on Apollo.
* **Audio Stutter:** Observed audio stutter when using Mac Virtual Display + Moonlight in Reality Kit.
    * *Workaround:* Using a **Developer Strap** eliminates the stutter.

### v11.0.16
* **UI Updates:**
    * Changed icons to text labels for clarity.
    * Added ability to hide immersive stream controls.
* **Image Adjustments:** Added **Gamma** and **Saturation** sliders.
* **Mouse Handling:** Improved mouse handling at the edges of the screen.
* **AV1 HDR:** Includes fixes for AV1 when HDR is enabled.

### v11.0.15 Highlights
* **Mouse & Keyboard:** Added input capture layer to enable Bluetooth keyboard and mouse in Reality Kit.
* **Immersive View:** Resizable and movable screens
* **Fixes:**
    * Fixed curved screen distortion math.
    * Fixed settings saving and updated defaults.
    * Fixed volume object clipping (position is now clamped).
    * Improved Home/Resume button reliability.

## Noted Bugs & Known Issues

* **MVD Audio Stutter:** If you run Mac Virtual Display alongside Moonlight in Reality Kit, audio may stutter. This does not happen if you are connected via a Developer Strap.
* **UI/UX:** The interface is currently "Function over Form." We are working on a better UI, but for now, we are prioritizing features and stability.
* **Controller Issues:**
    * PS4 Touchpad does not work (SDL3 issue).
    * PS5 Controllers may have general issues.
    * Controller vibration is currently not working.
* **Touchscreen Mode** Moonlight XrOS does not send touch events like it does on the iOS / iPadOS version to windows.
* **General Jank:** Eye position mouse moving is an OS-level behavior; cursor pointer snapping when lifting fingers off the trackpad cannot currently be fixed.
* **Tap to Click in Reality Kit** Moonlight XrOS does not allow for tap to click and tap to drag in realitykit mode
* **The virtual keyboard button is not working in reality kit** We are looking into fixing this.
* **Dimming Button in UIKit** The dimming button does not function in UIKit mode, we are looking into this



## FAQ
* **I'm using Apollo and it won't connect/launch?**
    * **CRITICAL:** After pairing, click the **EDIT** button in Apollo and make sure **ALL PERMISSIONS** are turned ON.
* **How do I fix the audio or mouse stutter?**
    * If you are multitasking with Mac Virtual Display, this is a known issue. Connecting via a Developer Strap seems to resolve the interference.
* **How do I move the Immersive Screen?**
    * Click the **Lock** button to "Unlock" the position. You can then move/recenter the screen. Click Lock again to set it.
* **Why does the UI look basic?**
    * We are a volunteer team prioritizing functionality (AV1, HDR, 120fps) over visual polish right now. A UI overhaul is planned for the future.
* **How do I fix HDR color?**
    * We recomend looking at a [video](https://www.youtube.com/watch?v=LXb3EKWsInQ) or [image](https://depositphotos.com/vector/printer-marks-printing-cutting-and-calibration-109759386.html) to calibrate against to calibrate 
* **UIKit vs Reality Kit?**
    * Use **UIKit** if you need 100% reliable Mouse + Keyboard support (though Reality Kit support is now available and improved).
    * Use **Reality Kit** for Curved Screens, 3D SBS, and AR features.
* **How do I use Ultrawide Mode?**
    * In settings set the resolution to 5120x1440, then set up [Apollo](https://github.com/ClassicOldSong/Apollo) or a virtual display driver on Windows.
* **Why is my connection choppy?**
    * While the app has entitlements to suppress AWDL, using features like AirDrop or Handoff in the background may cause interference. Use 5GHz Ch 149 (US) / Ch 44 (EU) / Ch 6 (2.4GHz) for best results.
* **Recommended Settings:**
    * **Resolution:** 4K
    * **Aspect Ratio:** 16:9
    * **Framerate:** 60fps (120fps is tested)
    * **Bitrate:** 50mbps (Higher is supported but requires M2/M5 and strong network)
    * **Renderer:** Reality Kit

* **How do I configure 5.1 or 7.1 Surround Sound?**
    * Moonlight Vision natively requests 7.1 surround sound. For this to work, your host PC must output 5.1 or 7.1 audio so that Sunshine/Apollo can capture the discrete channels.
    * 1. On your Windows Host, open the Sound Control Panel (Press `Win+R`, type `mmsys.cpl`).
    * 2. Select your default playback device (or virtual audio cable) and click **Configure**.
    * 3. Choose **7.1 Surround** or **5.1 Surround** and complete the wizard. *(If your physical audio device doesn't support 7.1, you can install a Virtual Audio Cable like VB-Cable, set it to 7.1, and make it the default device).*
    * 4. Open the **Sunshine / Apollo Web UI** and navigate to the **Audio** tab.
    * 5. Set the **Channels** configuration to `7.1` or `5.1` (or `Stereo` if you want to bypass surround entirely).
    * 6. Restart Sunshine/Apollo.
    * 7. In Moonlight Vision, cycle the audio button to **7.1 Surround** to enable native spatial processing.

## Feature Requests / Planned Features:
* Microphone Support.
* Updates to SDL3 (to fix PS4 touchpad issues).
* Unpin immersive settings (to allow reset if window becomes too far/small).

# Donations
Some people expressed interest in donations so I set up a Ko-fi (this will help me get an m5 vision pro):
[https://ko-fi.com/lumanaire](https://ko-fi.com/lumanaire)

Thanks again for your support :)

# Building From Source

## Requirements
* Latest Xcode
* Tested on Vision OS 2.2 Beta (26.2)
  
## Build Instructions
1. Install the latest version of Xcode.
2. Run `git clone -b vision-testflight --recursive https://github.com/RikuKunMS2/moonlight-ios-vision.git`
    * If you've already cloned the repo without `--recursive`, run `git submodule update --init --recursive`
    * If you are building someone else's fork replace the part after the `-b` and the user name in the GitHub link.
3. Open `Moonlight.xcodeproj` in Xcode.
4. To run on a real device, you will need to locally modify the signing options and add your device:
    * Go to 'Window' -> Devices and Simulators.
    * Add your Vision Pro.
    * Click on "Moonlight" at the top of the left sidebar.
    * Under "Targets", select "Moonlight Vision".
    * Click on the "Signing & Capabilities" tab.
    * Select your Team (Sign into Apple account if needed).
    * Change the "Bundle Identifier" to something unique.
    * **Crucial:** Remove the "Low Latency Streaming" entitlement from signing and capabilities if you do not have a paid developer account with this entitlement enabled.
    * Select your registered Vision Pro in the target bar and click Play for logging, or profile to for not logging.
