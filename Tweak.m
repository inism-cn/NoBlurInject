#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>

#pragma mark - Blocked Paths (initialized early, not lazily)

static NSArray *gBlockedPaths = nil;
static NSArray *gBlockedExecutables = nil;

__attribute__((constructor(101)))
static void NoBlurInjectEarlyInit(void) {
    // 预初始化所有静态数据,避开 Foundation 初始化竞争
    gBlockedPaths = @[
        @"/var/jb",
        @"/Applications/TrollStore.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Library/MobileSubstrate",
        @"DynamicLibraries",
        @".theos",
        @"cydia",
        @"substrate",
        @"ellekit"
    ];
    gBlockedExecutables = @[@"SpringBoard", @"backboardd", @"launchservicesd"];
}

#pragma mark - Helpers

// 用一个空 UIVisualEffect 替换 UIBlurEffect —— 与 nil 不同,
// 这是个合法的 UIVisualEffect 子类,不会触发 UIInternalInconsistencyException
static inline UIVisualEffect *SanitizedEffect(UIVisualEffect *effect) {
    if ([effect isKindOfClass:[UIBlurEffect class]]) {
        // 拿到原 effect 的 frame/alpha 信息不可行;返回父类空 effect 即可
        return [[UIVisualEffect alloc] init];
    }
    return effect;
}

#pragma mark - UIView addSubview / insertSubview hooks
//
// 关键:不要吞掉 addSubview 调用。只把 UIVisualEffectView 内的 effect 替换掉。
// UIVisualEffectView 本身必须照常加入层级,否则 UIKit 内部状态机
// (autolayout, KVO, hierarchy notifications)会全部错乱,直接 SIGABRT。

static void (*orig_addSubview)(UIView *, SEL, UIView *);
static void hook_addSubview(UIView *self, SEL _cmd, UIView *view) {
    if (view && [view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            // 安全替换:通过 KVC 不行,直接用 ivar 改或重新 init 都太重。
            // 改用 hook 后的 setEffect: 把模糊 effect 抹掉。
            // 注意:这里调用的 setEffect: 已经是我们的 hook,
            // hook_setEffect 看到非 UIBlurEffect 会直接转发,不会死循环。
            objc_msgSend(vev, @selector(setEffect:), (UIVisualEffect *)nil);
        }
    }
    orig_addSubview(self, _cmd, view);
}

static void (*orig_insertAtIndex)(UIView *, SEL, UIView *, NSInteger);
static void hook_insertAtIndex(UIView *self, SEL _cmd, UIView *view, NSInteger idx) {
    if (view && [view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            objc_msgSend(vev, @selector(setEffect:), (UIVisualEffect *)nil);
        }
    }
    orig_insertAtIndex(self, _cmd, view, idx);
}

static void (*orig_insertAbove)(UIView *, SEL, UIView *, UIView *);
static void hook_insertAbove(UIView *self, SEL _cmd, UIView *view, UIView *sib) {
    if (view && [view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            objc_msgSend(vev, @selector(setEffect:), (UIVisualEffect *)nil);
        }
    }
    orig_insertAbove(self, _cmd, view, sib);
}

static void (*orig_insertBelow)(UIView *, SEL, UIView *, UIView *);
static void hook_insertBelow(UIView *self, SEL _cmd, UIView *view, UIView *sib) {
    if (view && [view isKindOfClass:[UIVisualEffectView class]]) {
        UIVisualEffectView *vev = (UIVisualEffectView *)view;
        if ([vev.effect isKindOfClass:[UIBlurEffect class]]) {
            objc_msgSend(vev, @selector(setEffect:), (UIVisualEffect *)nil);
        }
    }
    orig_insertBelow(self, _cmd, view, sib);
}

#pragma mark - UIVisualEffectView hooks

static id (*orig_initWithEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static id hook_initWithEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    // 不要传 nil 给 initWithEffect:,它会抛 UIInternalInconsistencyException。
    // 用一个空 UIVisualEffect 替换 UIBlurEffect —— 视觉效果=无模糊,行为合法。
    UIVisualEffect *safe = SanitizedEffect(effect);
    return orig_initWithEffect(self, _cmd, safe);
}

static void (*orig_setEffect)(UIVisualEffectView *, SEL, UIVisualEffect *);
static void hook_setEffect(UIVisualEffectView *self, SEL _cmd, UIVisualEffect *effect) {
    // setEffect: 接受 nil 是合法的(Apple 公开 API 保证)。
    UIVisualEffect *safe = SanitizedEffect(effect);
    orig_setEffect(self, _cmd, safe);
}

#pragma mark - NSFileManager hook

static BOOL (*orig_fileExists)(NSFileManager *, SEL, NSString *);
static BOOL hook_fileExists(NSFileManager *self, SEL _cmd, NSString *path) {
    // NSFileManager 在启动早期就会被调用,只做指针判空,不调用任何
    // 可能未初始化的 Objective-C runtime 方法。
    if (path == nil) {
        return orig_fileExists(self, _cmd, path);
    }
    // 快速路径:长字符串才需要扫描
    if (path.length >= 4 && gBlockedPaths != nil) {
        for (NSString *b in gBlockedPaths) {
            if ([path rangeOfString:b].location != NSNotFound) {
                return NO;
            }
        }
    }
    return orig_fileExists(self, _cmd, path);
}

#pragma mark - Init

__attribute__((constructor(102)))
static void init(void) {
    if (gBlockedExecutables == nil) {
        // 早 init 还没跑(理论上不应该发生,做防御)
        return;
    }
    NSString *proc = [[NSProcessInfo processInfo] processName];
    if ([gBlockedExecutables containsObject:proc]) return;

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

    // 故意不 hook NSProcessInfo environment:
    // 1. 调用时机太早,有崩溃风险
    // 2. 多数应用的反注入检测会读这个 env,清掉后反而触发主动 crash
    // 3. 对去模糊目标毫无价值

    NSLog(@"[NoBlurInject] loaded into %@", proc);
}
