#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Hooks

// 拦截 addSubview: 丢弃 UIVisualEffectView (blur)
static void (*orig_addSubview)(UIView *, SEL, UIView *);
static void hook_addSubview(UIView *self, SEL _cmd, UIView *view) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            return; // 丢弃模糊层
        }
    }
    orig_addSubview(self, _cmd, view);
}

// 拦截 insertSubview:atIndex:
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

// 拦截 insertSubview:aboveSubview:
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

// 拦截 insertSubview:belowSubview:
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

// 拦截 UIVisualEffectView initWithEffect: 返回 nil effect
static id (*orig_initWithEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static id hook_initWithEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    if ([effect isKindOfClass:[UIBlurEffect class]]) {
        effect = nil; // 不设置模糊
    }
    return orig_initWithEffect(self, _cmd, effect);
}

// 拦截 setEffect: 阻止设置模糊
static void (*orig_setEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static void hook_setEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    if ([effect isKindOfClass:[UIBlurEffect class]]) {
        return; // 忽略
    }
    orig_setEffect(self, _cmd, effect);
}

#pragma mark - Anti-detection hooks

static BOOL (*orig_fileExistsAtPath)(NSFileManager *, SEL, NSString *);
static BOOL hook_fileExistsAtPath(NSFileManager *self, SEL _cmd, NSString *path) {
    static NSArray<NSString *> *blockedPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockedPaths = @[
            @"/var/jb",
            @"/Applications/TrollStore.app",
            @"DynamicLibraries",
            @".theos",
            @"cydia",
            @"substrate"
        ];
    });
    for (NSString *blocked in blockedPaths) {
        if ([path containsString:blocked]) return NO;
    }
    return orig_fileExistsAtPath(self, _cmd, path);
}

static NSDictionary<NSString *, NSString *> *(*orig_environment)(NSProcessInfo *, SEL);
static NSDictionary<NSString *, NSString *> *hook_environment(NSProcessInfo *self, SEL _cmd) {
    NSMutableDictionary *env = [[orig_environment(self, _cmd) mutableCopy] autorelease];
    [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    [env removeObjectForKey:@"DYLD_LIBRARIES"];
    return env;
}

#pragma mark - Constructor

__attribute__((constructor))
static void init() {
    // 只 hook 非系统进程（避免影响 SpringBoard 等）
    NSString *procName = [[NSProcessInfo processInfo] processName];
    if ([procName isEqualToString:@"SpringBoard"] ||
        [procName isEqualToString:@"backboardd"] ||
        [procName isEqualToString:@"launchservicesd"]) {
        return;
    }

    Class clsUIView = [UIView class];
    Class clsVEV = [UIVisualEffectView class];
    Class clsFM = [NSFileManager class];
    Class clsPI = [NSProcessInfo class];

    // UIView addSubview:
    Method m1 = class_getInstanceMethod(clsUIView, @selector(addSubview:));
    orig_addSubview = (void *)method_getImplementation(m1);
    method_setImplementation(m1, (IMP)hook_addSubview);

    // UIView insertSubview:atIndex:
    Method m2 = class_getInstanceMethod(clsUIView, @selector(insertSubview:atIndex:));
    orig_insertSubviewAtIndex = (void *)method_getImplementation(m2);
    method_setImplementation(m2, (IMP)hook_insertSubviewAtIndex);

    // UIView insertSubview:aboveSubview:
    Method m3 = class_getInstanceMethod(clsUIView, @selector(insertSubview:aboveSubview:));
    orig_insertSubviewAbove = (void *)method_getImplementation(m3);
    method_setImplementation(m3, (IMP)hook_insertSubviewAbove);

    // UIView insertSubview:belowSubview:
    Method m4 = class_getInstanceMethod(clsUIView, @selector(insertSubview:belowSubview:));
    orig_insertSubviewBelow = (void *)method_getImplementation(m4);
    method_setImplementation(m4, (IMP)hook_insertSubviewBelow);

    // UIVisualEffectView initWithEffect:
    Method m5 = class_getInstanceMethod(clsVEV, @selector(initWithEffect:));
    orig_initWithEffect = (void *)method_getImplementation(m5);
    method_setImplementation(m5, (IMP)hook_initWithEffect);

    // UIVisualEffectView setEffect:
    Method m6 = class_getInstanceMethod(clsVEV, @selector(setEffect:));
    orig_setEffect = (void *)method_getImplementation(m6);
    method_setImplementation(m6, (IMP)hook_setEffect);

    // NSFileManager fileExistsAtPath:
    Method m7 = class_getInstanceMethod(clsFM, @selector(fileExistsAtPath:));
    orig_fileExistsAtPath = (void *)method_getImplementation(m7);
    method_setImplementation(m7, (IMP)hook_fileExistsAtPath);

    // NSProcessInfo environment
    Method m8 = class_getInstanceMethod(clsPI, @selector(environment));
    orig_environment = (void *)method_getImplementation(m8);
    method_setImplementation(m8, (IMP)hook_environment);

    NSLog(@"[NoBlurInject] Loaded successfully");
}