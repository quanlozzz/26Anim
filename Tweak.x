#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// ---------- TUNABLES ----------
static const double kOpenResponse     = 0.90;
static const double kOpenDamping      = 0.60;
static const double kCloseResponse    = 0.90;
static const double kCloseDamping     = 0.60;
static const double kOpenDuration     = 0.30;  // Đã sửa từ 1.50 -> 0.30s cho mượt
static const double kCloseDuration    = 0.30;
static const double kGlassBlurAlpha   = 0.95;
static const double kGlassFadeIn      = 0.12;
static const double kGlassFadeOut     = 0.22;
// ------------------------------

@interface BSAnimationSettings : NSObject
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) double delay;
@property (nonatomic, assign) double speed;
@end

@interface SBFluidBehaviorSettings : NSObject
@property (nonatomic, assign) double response;
@property (nonatomic, assign) double dampingRatio;
@property (nonatomic, assign) double mass;
@end

static BOOL gIsOpening = YES;
static UIVisualEffectView *gGlassOverlay = nil;

static void presentGlassOverlay(void) {
    UIWindow *kw = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in scene.windows) {
                if (w.isKeyWindow) { kw = w; break; }
            }
        }
        if (kw) break;
    }
    if (!kw) return;

    if (gGlassOverlay) { [gGlassOverlay removeFromSuperview]; gGlassOverlay = nil; }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    gGlassOverlay = [[UIVisualEffectView alloc] initWithEffect:blur];
    gGlassOverlay.frame = kw.bounds;
    gGlassOverlay.alpha = 0.0;
    gGlassOverlay.userInteractionEnabled = NO;
    [kw addSubview:gGlassOverlay];

    [UIView animateWithDuration:kGlassFadeIn animations:^{
        gGlassOverlay.alpha = kGlassBlurAlpha;
    } completion:^(BOOL fin){
        [UIView animateWithDuration:kGlassFadeOut delay:0.05 options:UIViewAnimationOptionCurveEaseOut animations:^{
            gGlassOverlay.alpha = 0.0;
        } completion:^(BOOL f){
            [gGlassOverlay removeFromSuperview];
            gGlassOverlay = nil;
        }];
    }];
}

// ============ HOOKS ============

%hook SBMainWorkspaceTransitionRequest
- (void)setEventLabel:(NSString *)label {
    if ([label containsString:@"ActivateApplication"] || [label containsString:@"LaunchApplication"]) {
        gIsOpening = YES;
    } else if ([label containsString:@"DeactivateApplication"] || [label containsString:@"Home"]) {
        gIsOpening = NO;
    }
    %orig;
}
%end

%hook SBFluidBehaviorSettings
- (double)response {
    return gIsOpening ? kOpenResponse : kCloseResponse;
}
- (double)dampingRatio {
    return gIsOpening ? kOpenDamping : kCloseDamping;
}
%end

%hook SBHIconZoomAnimator
- (void)_animateZoomWithDuration:(double)duration animations:(id)animations completion:(id)completion {
    double newDur = gIsOpening ? kOpenDuration : kCloseDuration;
    %orig(newDur, animations, completion);
}

- (double)_animationDuration {
    return gIsOpening ? kOpenDuration : kCloseDuration;
}
%end

%hook SBAppToAppWorkspaceTransaction
- (double)_animationDuration {
    double orig = %orig;
    if (orig > 0.1) return gIsOpening ? kOpenDuration : kCloseDuration;
    return orig;
}
%end

%hook SBMainWorkspace
- (void)executeTransitionRequest:(id)request {
    presentGlassOverlay();
    %orig;
}
%end

%ctor {
    NSLog(@"[iOS26Anim] loaded successfully!");
}
