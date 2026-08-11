#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

#pragma mark - UIView Hooks

static void (*orig_addSubview)(UIView *, SEL, UIView *);
static void hook_addSubview(UIView *self, SEL _cmd, UIView *view) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            return;
        }
    }
    orig_addSubview(self, _cmd, view);
}

static void (*orig_insertSubviewAtIndex)(UIView *, SEL, UIView *, NSInteger);
static void hook_insertSubviewAtIndex(UIView *self, SEL _cmd, UIView *view, NSInteger idx) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            return;
        }
    }
    orig_insertSubviewAtIndex(self, _cmd, view, idx);
}

static void (*orig_insertSubviewAbove)(UIView *, SEL, UIView *, UIView *);
static void hook_insertSubviewAbove(UIView *self, SEL _cmd, UIView *view, UIView *sibling) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            return;
        }
    }
    orig_insertSubviewAbove(self, _cmd, view, sibling);
}

static void (*orig_insertSubviewBelow)(UIView *, SEL, UIView *, UIView *);
static void hook_insertSubviewBelow(UIView *self, SEL _cmd, UIView *view, UIView *sibling) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            return;
        }
    }
    orig_insertSubviewBelow(self, _cmd, view, sibling);
}

#pragma mark - UIVisualEffectView Hooks

static id (*orig_initWithEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static id hook_initWithEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    if ([effect isKindOfClass:[UIBlurEffect class]]) {
        effect = nil;
    }
    return orig_initWithEffect(self, _cmd, effect);
}

static void (*orig_setEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static void hook_setEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    if ([effect isKindOfClass:[UIBlurEffect class]]) {
        return;
    }
    orig_setEffect(self, _cmd, effect);
}

#pragma mark - Anti-detection Hooks

static BOOL (*orig_fileExistsAtPath)(NSFileManager *, SEL, NSString *);
static BOOL hook_fileExistsAtPath(NSFileManager *self, SEL _cmd, NSString *path) {
    static NSString *blocked[] = {
        @"/var/jb",
        @"/Applications/TrollStore.app",
        @"DynamicLibraries",
        @".theos",
        @"cydia",
        @"substrate",
        nil
    };
    for (int i = 0; blocked[i] != nil; i++) {
        if ([path containsString:blocked[i]]) {
            return NO;
        }
    }
    return orig_fileExistsAtPath(self, _cmd, path);
}

/*
 * ARC 修复说明：
 * 上一版用 [env mutableCopy] autorelease 触发 ARC 编译错误。
 * 正确写法：CFBridgingRelease 把 CFDictionaryRef 的所有权转移给 ARC，
 * 等价于 MRC 下的 [[... mutableCopy] autorelease]，但 ARC 合法。
 */
static NSDictionary<NSString *, NSString *> *(*orig_environment)(NSProcessInfo *, SEL);
static NSDictionary<NSString *, NSString *> *hook_environment(NSProcessInfo *self, SEL _cmd) {
    CFDictionaryRef env_cf = (CFDictionaryRef)orig_environment(self, _cmd);
    NSMutableDictionary *env = (NSMutableDictionary *)CFBridgingRelease(env_cf);
    if (![env isKindOfClass:[NSMutableDictionary class]]) {
        env = [env mutableCopy];
    }
    [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [env removeObjectForKey:@"DYLD_LIBRARIES"];
    return env;
}

#pragma mark - Constructor

__attribute__((constructor))
static void NoBlurInject_init() {
    @autoreleasepool {
        NSString *procName = [[NSProcessInfo processInfo] processName];
        if ([procName isEqualToString:@"SpringBoard"] ||
            [procName isEqualToString:@"backboardd"] ||
            [procName isEqualToString:@"launchservicesd"]) {
            return;
        }

        Class clsUIView = [UIView class];
        Class clsVEV   = [UIVisualEffectView class];
        Class clsFM    = [NSFileManager class];
        Class clsPI    = [NSProcessInfo class];
        Method m;

        m = class_getInstanceMethod(clsUIView, @selector(addSubview:));
        orig_addSubview = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_addSubview);

        m = class_getInstanceMethod(clsUIView, @selector(insertSubview:atIndex:));
        orig_insertSubviewAtIndex = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_insertSubviewAtIndex);

        m = class_getInstanceMethod(clsUIView, @selector(insertSubview:aboveSubview:));
        orig_insertSubviewAbove = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_insertSubviewAbove);

        m = class_getInstanceMethod(clsUIView, @selector(insertSubview:belowSubview:));
        orig_insertSubviewBelow = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_insertSubviewBelow);

        m = class_getInstanceMethod(clsVEV, @selector(initWithEffect:));
        orig_initWithEffect = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_initWithEffect);

        m = class_getInstanceMethod(clsVEV, @selector(setEffect:));
        orig_setEffect = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_setEffect);

        m = class_getInstanceMethod(clsFM, @selector(fileExistsAtPath:));
        orig_fileExistsAtPath = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_fileExistsAtPath);

        m = class_getInstanceMethod(clsPI, @selector(environment));
        orig_environment = (void *)method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_environment);

        NSLog(@"[NoBlurInject] Loaded successfully");
    }
}
