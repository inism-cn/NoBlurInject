/*
 * NoBlurInject - Universal Blur Blocker
 * Works on any App via TrollFools / TrollStore dylib injection.
 * Filters UIBlurEffect additions and replaces them with nil effect.
 * No bundle filter → inject into any App, iOS 14+.
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─── Config ───────────────────────────────────────────────
// Set to YES to log every blocked blur (useful for first-run debugging)
static BOOL kLogBlockedBlurs = YES;

// Bundle identifiers to SKIP (system UI / SpringBoard / safe apps)
static NSSet *gSkipBundles = nil;

__attribute__((constructor))
static void NoBlurInjectInit(void) {
    gSkipBundles = [NSSet setWithObjects:
        @"com.apple.SpringBoard",
        @"com.apple.backboardd",
        @"com.apple.coreservices.launchservicesd",
        nil];
    NSLog(@"[NoBlurInject] Loaded ✅ arm64(e) universal");
}

// ─── Helpers ──────────────────────────────────────────────
static inline BOOL IsBlurEffect(id effect) {
    return [effect isKindOfClass:[UIBlurEffect class]];
}

static inline BOOL IsVisualEffectView(id obj) {
    return [obj isKindOfClass:[UIVisualEffectView class]];
}

static inline BOOL ShouldSkipCurrentApp(void) {
    NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
    return [gSkipBundles containsObject:bundle];
}

static inline UIBlurEffect *ReplacementEffect(void) {
    // Return nil so the view becomes a plain see-through layer
    return nil;
}

// ─── UIView hooks ────────────────────────────────────────
%hook UIView

- (void)addSubview:(UIView *)view {
    if (ShouldSkipCurrentApp()) { %orig(view); return; }
    if (IsVisualEffectView(view) && IsBlurEffect(((UIVisualEffectView *)view).effect)) {
        if (kLogBlockedBlurs) NSLog(@"[NoBlurInject] 🚫 addSubview: blur blocked");
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        vev.effect = nil; // strip blur before adding
    }
    %orig(view);
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index {
    if (ShouldSkipCurrentApp()) { %orig(view, index); return; }
    if (IsVisualEffectView(view) && IsBlurEffect(((UIVisualEffectView *)view).effect)) {
        if (kLogBlockedBlurs) NSLog(@"[NoBlurInject] 🚫 insertSubview:atIndex: blur blocked");
        ((UIVisualEffectView *)view).effect = nil;
    }
    %orig(view, index);
}

- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)siblingSubview {
    if (ShouldSkipCurrentApp()) { %orig(view, siblingSubview); return; }
    if (IsVisualEffectView(view) && IsBlurEffect(((UIVisualEffectView *)view).effect)) {
        ((UIVisualEffectView *)view).effect = nil;
    }
    %orig(view, siblingSubview);
}

- (void)insertSubview:(UIView *)view belowSubview:(UIView *)siblingSubview {
    if (ShouldSkipCurrentApp()) { %orig(view, siblingSubview); return; }
    if (IsVisualEffectView(view) && IsBlurEffect(((UIVisualEffectView *)view).effect)) {
        ((UIVisualEffectView *)view).effect = nil;
    }
    %orig(view, siblingSubview);
}

%end

// ─── UIVisualEffectView direct hooks ────────────────────
%hook UIVisualEffectView

- (instancetype)initWithEffect:(UIVisualEffect *)effect {
    if (ShouldSkipCurrentApp()) return %orig(effect);
    if (IsBlurEffect(effect)) {
        if (kLogBlockedBlurs) NSLog(@"[NoBlurInject] 🚫 initWithEffect: blur → nil");
        return %orig(nil);
    }
    return %orig(effect);
}

- (void)setEffect:(UIVisualEffect *)effect {
    if (ShouldSkipCurrentApp()) { %orig(effect); return; }
    if (IsBlurEffect(effect)) {
        if (kLogBlockedBlurs) NSLog(@"[NoBlurInject] 🚫 setEffect: blur stripped");
        %orig(nil);
        return;
    }
    %orig(effect);
}

%end

// ─── Anti-detection (lightweight, generic) ───────────────
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    // Hide common jailbreak / trollstore traces from the injected app
    if ([path containsString:@"/var/jb"] ||
        [path containsString:@"/var/root"] ||
        [path containsString:@"TrollStore.app"] ||
        [path containsString:@"DynamicLibraries"] ||
        [path containsString:@".theos"] ||
        [path containsString:@"CydiaSubstrate"]) {
        return NO;
    }
    return %orig(path);
}

%end

%hook NSProcessInfo

- (NSDictionary<NSString *, NSString *> *)environment {
    NSMutableDictionary *env = [%orig() mutableCopy] ?: [NSMutableDictionary dictionary];
    [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [env removeObjectForKey:@"DYLD_LIBRARIES"];
    [env removeObjectForKey:@"DYLD_FRAMEWORK_PATH"];
    [env removeObjectForKey:@"DYLD_FALLBACK_FRAMEWORK_PATH"];
    return env;
}

%end

// ─── App background-snapshot hardening (optional) ────────
/*
 * Some apps replace the root view with a blank/blur snapshot on
 * applicationDidEnterBackground. We try to keep the real content
 * visible by preventing the window's rootViewController from
 * being swapped to a placeholder.
 *
 * This is best-effort: apps that render a custom secure snapshot
 * view may still blank out. For those, use FLEX to find the class
 * and add a targeted hook in Tweak.x, then rebuild via GitHub Actions.
 */

%hook UIWindow

- (void)setRootViewController:(UIViewController *)vc {
    // Only interfere if the new VC looks like a "secure/blank snapshot" placeholder
    // Heuristic: class name contains common snapshot/secure keywords
    NSString *cls = NSStringFromClass([vc class]);
    if ([cls containsString:@"Snapshot"] ||
        [cls containsString:@"Secure"] ||
        [cls containsString:@"Blur"] ||
        [cls containsString:@"Privacy"] ||
        [cls containsString:@"Cover"]) {
        if (kLogBlockedBlurs) NSLog(@"[NoBlurInject] 🚫 snapshot VC blocked: %@", cls);
        // Don't replace — keep previous root VC alive
        UIViewController *current = %orig;
        if (current) return; // already has a real root, keep it
    }
    %orig(vc);
}

%end
