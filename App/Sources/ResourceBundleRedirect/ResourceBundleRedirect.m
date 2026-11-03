#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "ResourceBundleRedirect.h"

// Compiled without ARC so initWithPath:'s consume-self / returns-retained
// semantics pass straight through to the original implementation.
static id (*SakuraCordOriginalInitWithPath)(id, SEL, NSString *);

static id SakuraCordInitWithPath(id self, SEL _cmd, NSString *path) {
    if ([path hasSuffix:@".bundle"]
        && ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSBundle *main = [NSBundle mainBundle];
        if ([[path stringByDeletingLastPathComponent] isEqualToString:main.bundlePath]) {
            NSString *candidate = [main.resourcePath stringByAppendingPathComponent:path.lastPathComponent];
            if ([[NSFileManager defaultManager] fileExistsAtPath:candidate]) {
                path = candidate;
            }
        }
    }
    return SakuraCordOriginalInitWithPath(self, _cmd, path);
}

void SakuraCordResourceBundleRedirectAnchor(void) {}

__attribute__((constructor)) static void SakuraCordInstallResourceBundleRedirect(void) {
    Method method = class_getInstanceMethod([NSBundle class], @selector(initWithPath:));
    SakuraCordOriginalInitWithPath = (void *)method_setImplementation(method, (IMP)SakuraCordInitWithPath);
}
