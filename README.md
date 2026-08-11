# NoBlurInject — Universal Blur Blocker (dylib)

> **One dylib → inject into ANY app → no more `UIBlurEffect`**
> Works on every iOS app via **TrollFools** / **TrollStore** / any dylib injector.
> No per-app recompilation. No bundle filter. Arm64 + Arm64e universal binary.

---

## What gets blocked

| Hook | Effect |
|------|--------|
| `UIView addSubview:` | Strips `UIBlurEffect` from any subview **before** it enters the hierarchy |
| `UIView insertSubview:atIndex:` | Same, for indexed insertion |
| `UIView insertSubview:aboveSubview:` / `belowSubview:` | Same, for sibling-relative insertion |
| `UIVisualEffectView initWithEffect:` | Returns a **clear** view instead of a blur view |
| `UIVisualEffectView setEffect:` | Prevents blur from ever being applied |
| `UIWindow setRootViewController:` | Blocks common "secure/blank snapshot" placeholder VCs |
| `NSFileManager fileExistsAtPath:` | Hides `/var/jb`, TrollStore, CydiaSubstrate traces |
| `NSProcessInfo environment` | Clears `DYLD_INSERT_LIBRARIES` etc. |

**System apps (SpringBoard, backboardd, launchservicesd) are auto-skipped** — won't break the OS.

---

## Architecture

- **arm64 + arm64e** → merged into a single universal dylib via `lipo`
- Minimum iOS **14.0** (tested on iOS 15.2 / iPhone 13 mini arm64e)
- Pure Objective-C runtime — **zero dependency on CydiaSubstrate / ElleKit**
- No bundle filter → the dylib's constructor runs in **every** app process
- ~30 KB final size

---

## 🚀 Build via GitHub Actions (zero local setup)

1. **Create a public GitHub repo** (e.g. `NoBlurInject`)
2. **Upload these 5 files** to the repo root:
   ```
   .github/workflows/build.yml   ← GitHub Actions auto-build
   Makefile                      ← theos config
   Tweak.x                       ← all hooks
   NoBlurInject.plist            ← filter (ignored by TrollFools anyway)
   README.md                     ← this file
   ```
3. Go to **Actions** tab → `Build NoBlurInject Universal dylib` → **Run workflow**
4. Wait **3–8 minutes** for the build to complete
5. Download the artifact: **`NoBlurInject-universal-dylib`**
6. Inside: `NoBlurInject-universal.dylib`

> 💡 **Pro tip:** Push to `main` branch = auto-build. Every push produces a fresh dylib.

---

## 📲 Inject into any app

### Method A: TrollFools (recommended ✅)

1. Open **TrollFools** (installed via TrollStore)
2. Find any app (支付宝 / 微信 / 银行App / Settings / whatever)
3. Tap **注入** (Inject) → select `NoBlurInject-universal.dylib`
4. Force-kill the app (swipe up from App Switcher)
5. Reopen → background the app → **snapshot is crystal clear** 🎉

### Method B: TrollStore + patched IPA

1. Decrypt the target app IPA (`frida-ios-dump`)
2. Use **轻松签+** / Sideloadly to inject the dylib + re-sign
3. Install the patched IPA

---

## ✅ Verify it loaded

On your Mac (with `libimobiledevice`):
```bash
idevicesyslog | grep NoBlurInject
```

Expected output:
```
[NoBlurInject] Loaded ✅ arm64(e) universal
[NoBlurInject] 🚫 addSubview: blur blocked
[NoBlurInject] 🚫 initWithEffect: blur → nil
```

The `🚫` lines confirm blurs are being stripped in real-time.

---

## 🔧 If an app STILL shows blur / blank screen

Some apps don't use `UIBlurEffect` — they use:
- **Custom CoreImage / Metal blur** → not `UIBlurEffect`, can't be caught by this dylib
- **Direct `layer` content replacement** on background → need to find the exact class
- **Custom secure-snapshot view controller** → heuristic in `UIWindow setRootViewController:` catches common cases

**Debug workflow:**
1. Inject **FLEX (巨魔版)** into the same app
2. Open FLEX → View Hierarchy → find the blur/snapshot view's **class name**
3. Add a targeted `%hook` in `Tweak.x` for that class
4. Push to GitHub → Actions rebuilds → download → re-inject

Example extra hook:
```objc
%hook MyAppSecureBlurView
- (void)setBlurred:(BOOL)b { %orig(NO); }
- (void)layoutSubviews { /* don't call %orig → draw nothing */ }
%end
```

---

## ⚠️ Notes & limits

- ✅ Strips **all `UIBlurEffect`** added by any app at runtime
- ✅ Works on iOS 14 – 17 (rootless dylib, no substrate required)
- ✅ Safe: skips SpringBoard / system processes automatically
- ⚠️ **Custom blur implementations** (CoreImage / Metal / CAFilter) are NOT `UIBlurEffect` → won't be caught
- ⚠️ Apps with **strong anti-tamper** may still detect and crash → pair with **Shadow (rootless)**
- ⚠️ The `Filter` plist is **ignored by TrollFools** (it `dlopen`s directly) — the dylib constructor controls everything
- ⚠️ After app update → re-inject (TrollFools makes this 2 taps)

---

## 📁 File map

```
NoBlurInject/
├── .github/workflows/build.yml   ← GitHub Actions: install theos → build arm64+arm64e → lipo → upload
├── Makefile                      ← theos makefile (auto-detects THEOS, merges archs)
├── Tweak.x                       ← 8 hooks, pure ObjC runtime, no substrate
├── NoBlurInject.plist            ← filter (cosmetic for TrollFools)
└── README.md                     ← this file
```

---

## License

MIT — do whatever you want. If it breaks your app, that's on you.
