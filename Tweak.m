#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>

static void (*orig_addSubview)(UIView *, SEL, UIView *);
static void hook_addSubview(UIView *self, SEL _cmd, UIView *view) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) return;
    }
    orig_addSubview(self, _cmd, view);
}

static void (*orig_insertAtIndex)(UIView *, SEL, UIView *, NSInteger);
static void hook_insertAtIndex(UIView *self, SEL _cmd, UIView *view, NSInteger idx) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) return;
    }
    orig_insertAtIndex(self, _cmd, view, idx);
}

static void (*orig_insertAbove)(UIView *, SEL, UIView *, UIView *);
static void hook_insertAbove(UIView *self, SEL _cmd, UIView *view, UIView *sib) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) return;
    }
    orig_insertAbove(self, _cmd, view, sib);
}

static void (*orig_insertBelow)(UIView *, SEL, UIView *, UIView *);
static void hook_insertBelow(UIView *self, SEL _cmd, UIView *view, UIView *sib) {
    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) return;
    }
    orig_insertBelow(self, _cmd, view, sib);
}

static id (*orig_initWithEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static id hook_initWithEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    if ([effect isKindOfClass:[UIBlurEffect class]]) effect = nil;
    return orig_initWithEffect(self, _cmd, effect);
}

static void (*orig_setEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static void hook_setEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    if ([effect isKindOfClass:[UIBlurEffect class]]) return;
    orig_setEffect(self, _cmd, effect);
}

static BOOL (*orig_fileExists)(NSFileManager *, SEL, NSString *);
static BOOL hook_fileExists(NSFileManager *self, SEL _cmd, NSString *path) {
    static NSArray *blocked;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        blocked = @[@"/var/jb", @"/Applications/TrollStore.app", @"DynamicLibraries", @".theos", @"cydia", @"substrate"];
    });
    for (NSString *b in blocked) {
        if ([path containsString:b]) return NO;
    }
    return orig_fileExists(self, _cmd, path);
}

static NSDictionary<NSString *, NSString *> *(*orig_environment)(NSProcessInfo *, SEL);
static NSDictionary<NSString *, NSString *> *hook_environment(NSProcessInfo *self, SEL _cmd) {
    NSDictionary *orig = orig_environment(self, _cmd);
    CFMutableDictionaryRef mut = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, (__bridge CFDictionaryRef)orig);
    CFDictionaryRemoveValue(mut, CFSTR("DYLD_INSERT_LIBRARIES"));
    CFDictionaryRemoveValue(mut, CFSTR("DYLD_LIBRARIES"));
    return CFBridgingRelease(mut);
}

__attribute__((constructor))
static void init() {
    NSString *proc = [[NSProcessInfo processInfo] processName];
    if ([proc isEqualToString:@"SpringBoard"] || [proc isEqualToString:@"backboardd"]) return;

    Method m;
    m = class_getInstanceMethod([UIView class], @selector(addSubview:));
    orig_addSubview = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_addSubview);

    m = class_getInstanceMethod([UIView class], @selector(insertSubview:atIndex:));
    orig_insertAtIndex = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_insertAtIndex);

    m = class_getInstanceMethod([UIView class], @selector(insertSubview:aboveSubview:));
    orig_insertAbove = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_insertAbove);

    m = class_getInstanceMethod([UIView class], @selector(insertSubview:belowSubview:));
    orig_insertBelow = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_insertBelow);

    m = class_getInstanceMethod([UIVisualEffectView class], @selector(initWithEffect:));
    orig_initWithEffect = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_initWithEffect);

    m = class_getInstanceMethod([UIVisualEffectView class], @selector(setEffect:));
    orig_setEffect = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_setEffect);

    m = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    orig_fileExists = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_fileExists);

    m = class_getInstanceMethod([NSProcessInfo class], @selector(environment));
    orig_environment = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_environment);

    NSLog(@"[NoBlurInject] loaded");
}