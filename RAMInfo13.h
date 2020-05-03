@interface SBCoverSheetPresentationManager: NSObject
+ (id)sharedInstance;
- (BOOL)_isEffectivelyLocked;
@end

@interface UILabelWithInsets : UILabel
@end

@interface RamInfo: NSObject
{
    UIWindow *ramInfoWindow;
    UILabelWithInsets *ramInfoLabel;
}
- (id)init;
- (void)updateOrientation;
- (void)updateFrame;
- (void)updateRAMInfoSize;
- (void)updateText;
- (void)updateTextColor: (UIColor*)color;
- (void)openDoubleTapApp;
- (void)openHoldApp;
@end

@interface UIWindow ()
- (void)_setSecure: (BOOL)arg1;
@end

@interface SBApplication: NSObject
-(NSString*)bundleIdentifier;
@end

@interface SpringBoard: UIApplication
- (id)_accessibilityFrontMostApplication;
@end

@interface UIApplication ()
- (UIDeviceOrientation)_frontMostAppOrientation;
- (BOOL)launchApplicationWithIdentifier:(id)arg1 suspended:(BOOL)arg2;
@end

@interface _UIStatusBarStyleAttributes: NSObject
@property(nonatomic, copy) UIColor *imageTintColor;
@end

@interface _UIStatusBar: UIView
@property(nonatomic, retain) _UIStatusBarStyleAttributes *styleAttributes;
@end

@interface CALayer ()
- (void)setContinuousCorners:(BOOL)arg1;
@end
