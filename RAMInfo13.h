@interface _UIStatusBarForegroundView: UIView
@property(nonatomic, retain) UILabel *ramLabel;
@end

@interface SBCoverSheetPresentationManager: NSObject
+ (id)sharedInstance;
- (BOOL)isPresented;
@end
