#import "RAMInfo13.h"

#import "SparkColourPickerUtils.h"
#import "SparkAppList.h"
#import <Cephei/HBPreferences.h>
#import <mach/mach_init.h>
#import <mach/mach_host.h>

#define DegreesToRadians(degrees) (degrees * M_PI / 180)

static const unsigned int MEGABYTES = 1 << 20;
static unsigned long long PHYSICAL_MEMORY;

static double screenWidth;
static double screenHeight;
static UIDeviceOrientation orientationOld;

__strong static id ramInfoObject;

static HBPreferences *pref;
static BOOL enabled;
static BOOL showOnLockScreen;
static BOOL showUsedRam;
static NSString *usedRAMPrefix;
static BOOL showFreeRam;
static NSString *freeRAMPrefix;
static BOOL showTotalPhysicalRam;
static NSString *totalRAMPrefix;
static NSString *separator;
static BOOL backgroundColorEnabled;
static float backgroundCornerRadius;
static BOOL customBackgroundColorEnabled;
static UIColor *customBackgroundColor;
static double portraitX;
static double portraitY;
static double landscapeX;
static double landscapeY;
static BOOL followDeviceOrientation;
static double width;
static double height;
static long fontSize;
static BOOL boldFont;
static BOOL customTextColorEnabled;
static UIColor *customTextColor;
static long alignment;
static double updateInterval;
static BOOL enableDoubleTap;
static NSString *doubleTapIdentifier;
static BOOL enableHold;
static NSString *holdIdentifier;
static BOOL enableBlackListedApps;
static NSArray *blackListedApps;

static NSString* getMemoryStats()
{
	mach_port_t host_port;
	mach_msg_type_number_t host_size;
	vm_size_t pagesize;
	vm_statistics_data_t vm_stat;
	natural_t mem_used, mem_free;
	NSMutableString* mutableString = [[NSMutableString alloc] init];

	host_port = mach_host_self();
	host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
	host_page_size(host_port, &pagesize);
	if(host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) == KERN_SUCCESS)
	{
		if(showUsedRam)
		{
			mem_used = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize / MEGABYTES;
			[mutableString appendString: [NSString stringWithFormat:@"%@%uMB", usedRAMPrefix, mem_used]];
		}
		if(showFreeRam)
		{
			mem_free = vm_stat.free_count * pagesize / MEGABYTES;
			if([mutableString length] != 0) [mutableString appendString: separator];
			[mutableString appendString: [NSString stringWithFormat:@"%@%uMB", freeRAMPrefix, mem_free]];
		}
		if(showTotalPhysicalRam)
		{
			if([mutableString length] != 0) [mutableString appendString: separator];
			[mutableString appendString: [NSString stringWithFormat:@"%@%lluMB", totalRAMPrefix, PHYSICAL_MEMORY]];
		}
	}
	return [mutableString copy];
}

static void orientationChanged()
{
	if(followDeviceOrientation && ramInfoObject) 
		[ramInfoObject updateOrientation];
}

static void loadDeviceScreenDimensions()
{
	UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
	if(orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight)
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.height;
		screenHeight = [[UIScreen mainScreen] bounds].size.width;
	}
	else
	{
		screenWidth = [[UIScreen mainScreen] bounds].size.width;
		screenHeight = [[UIScreen mainScreen] bounds].size.height;
	}
}

@implementation UILabelWithInsets

- (void)drawTextInRect: (CGRect)rect
{
    UIEdgeInsets insets = {0, 5, 0, 5};
    [super drawTextInRect: UIEdgeInsetsInsetRect(rect, insets)];
}

@end

@implementation RamInfo

	- (id)init
	{
		self = [super init];
		if(self)
		{
			@try
			{
				ramInfoWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, width, height)];
				[ramInfoWindow setHidden: NO];
				[ramInfoWindow setAlpha: 1];
				[ramInfoWindow _setSecure: YES];
				[ramInfoWindow setUserInteractionEnabled: YES];
				[[ramInfoWindow layer] setAnchorPoint: CGPointZero];
				
				ramInfoLabel = [[UILabelWithInsets alloc] initWithFrame: CGRectMake(0, 0, width, height)];
				[ramInfoLabel setNumberOfLines: 1];
				[[ramInfoLabel layer] setMasksToBounds: YES];
				[ramInfoWindow addSubview: ramInfoLabel];

				UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(openDoubleTapApp)];
				[tapGestureRecognizer setNumberOfTapsRequired: 2];
				[ramInfoWindow addGestureRecognizer: tapGestureRecognizer];

				UILongPressGestureRecognizer *holdGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget: self action: @selector(openHoldApp)];
				[ramInfoWindow addGestureRecognizer: holdGestureRecognizer];

				[self updateFrame];

				[NSTimer scheduledTimerWithTimeInterval: updateInterval target: self selector: @selector(updateText) userInfo: nil repeats: YES];

				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, 0);
				CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
			}
			@catch (NSException *e) {}
		}
		return self;
	}

	- (void)updateFrame
	{
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_updateFrame) object: nil];
		[self performSelector: @selector(_updateFrame) withObject: nil afterDelay: 0.3];
	}

	- (void)_updateFrame
	{
		if(showOnLockScreen) [ramInfoWindow setWindowLevel: 1051];
		else [ramInfoWindow setWindowLevel: 1000];

		[self updateRAMInfoLabelProperties];
		[self updateRAMInfoSize];

		orientationOld = nil;
		[self updateOrientation];
	}

	- (void)updateRAMInfoLabelProperties
	{
		if(boldFont) [ramInfoLabel setFont: [UIFont boldSystemFontOfSize: fontSize]];
		else [ramInfoLabel setFont: [UIFont systemFontOfSize: fontSize]];

		[ramInfoLabel setTextAlignment: alignment];

		if(customTextColorEnabled)
			[ramInfoLabel setTextColor: customTextColor];

		if(!backgroundColorEnabled)
			[ramInfoLabel setBackgroundColor: [UIColor clearColor]];
		else
		{
			[[ramInfoLabel layer] setCornerRadius: backgroundCornerRadius];
			[[ramInfoLabel layer] setContinuousCorners: YES];
			
			if(customBackgroundColorEnabled)
				[ramInfoLabel setBackgroundColor: customBackgroundColor];
		}
	}

	- (void)updateRAMInfoSize
	{
		CGRect frame = [ramInfoLabel frame];
		frame.size.width = width;
		frame.size.height = height;
		[ramInfoLabel setFrame: frame];

		frame = [ramInfoWindow frame];
		frame.size.width = width;
		frame.size.height = height;
		[ramInfoWindow setFrame: frame];
	}

	- (void)updateOrientation
	{
		if(!followDeviceOrientation)
		{
			CGRect frame = [ramInfoWindow frame];
			frame.origin.x = portraitX;
			frame.origin.y = portraitY;
			[ramInfoWindow setFrame: frame];
		} 
		else
		{
			UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
			if(orientation == orientationOld)
				return;
			
			CGAffineTransform newTransform;
			CGRect frame = [ramInfoWindow frame];

			switch (orientation)
			{
				case UIDeviceOrientationLandscapeRight:
				{
					frame.origin.x = landscapeY;
					frame.origin.y = screenHeight - landscapeX;
					newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationLandscapeLeft:
				{
					frame.origin.x = screenWidth - landscapeY;
					frame.origin.y = landscapeX;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationPortraitUpsideDown:
				{
					frame.origin.x = screenWidth - portraitX;
					frame.origin.y = screenHeight - portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
					break;
				}
				case UIDeviceOrientationPortrait:
				default:
				{
					frame.origin.x = portraitX;
					frame.origin.y = portraitY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
					break;
				}
			}

			[UIView animateWithDuration: 0.3f animations:
			^{
				[ramInfoWindow setTransform: newTransform];
				[ramInfoWindow setFrame: frame];
				orientationOld = orientation;
			} completion: nil];
		}
	}

	- (void)updateTextColor: (UIColor*)color
	{
		CGFloat r;
    	[color getRed: &r green: nil blue: nil alpha: nil];
		if(r == 0 || r == 1)
		{
			if(!customTextColorEnabled) [ramInfoLabel setTextColor: color];
			if(backgroundColorEnabled && !customBackgroundColorEnabled) 
			{
				if(r == 0) [ramInfoLabel setBackgroundColor: [[UIColor whiteColor] colorWithAlphaComponent: 0.5]];
				else [ramInfoLabel setBackgroundColor: [[UIColor blackColor] colorWithAlphaComponent: 0.5]];
			}	

		}
	}

	- (void)updateText
	{
		if(ramInfoWindow && ramInfoLabel)
		{
			if(![[%c(SBCoverSheetPresentationManager) sharedInstance] _isEffectivelyLocked])
			{
				if(blackListedApps && [blackListedApps containsObject: [(SBApplication*)[(SpringBoard*)[UIApplication sharedApplication] _accessibilityFrontMostApplication] bundleIdentifier]])
					[ramInfoWindow setHidden: YES];
				else
				{
					[ramInfoWindow setHidden: NO];
					[ramInfoLabel setText: getMemoryStats()];
				}
			}
			else [ramInfoWindow setHidden: YES];
		}
	}

	- (void)openDoubleTapApp
	{
		if(enableDoubleTap && doubleTapIdentifier)
			[[UIApplication sharedApplication] launchApplicationWithIdentifier: doubleTapIdentifier suspended: NO];
	}

	- (void)openHoldApp
	{
		if(enableHold && holdIdentifier)
			[[UIApplication sharedApplication] launchApplicationWithIdentifier: holdIdentifier suspended: NO];
	}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching: (id)application
{
	%orig;

	loadDeviceScreenDimensions();
	if(!ramInfoObject) 
		ramInfoObject = [[RamInfo alloc] init];
}

%end

%hook _UIStatusBar

-(void)setForegroundColor: (UIColor*)color
{
	%orig;
	
	if(ramInfoObject && [self styleAttributes] && [[self styleAttributes] imageTintColor]) 
		[ramInfoObject updateTextColor: [[self styleAttributes] imageTintColor]];
}

%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if(!pref) pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.raminfo13prefs"];
	enabled = [pref boolForKey: @"enabled"];
	showOnLockScreen = [pref boolForKey: @"showOnLockScreen"];
	showUsedRam = [pref boolForKey: @"showUsedRam"];
	usedRAMPrefix = [pref objectForKey: @"usedRAMPrefix"];
	showFreeRam = [pref boolForKey: @"showFreeRam"];
	freeRAMPrefix = [pref objectForKey: @"freeRAMPrefix"];
	showTotalPhysicalRam = [pref boolForKey: @"showTotalPhysicalRam"];
	totalRAMPrefix = [pref objectForKey: @"totalRAMPrefix"];
	separator = [pref objectForKey: @"separator"];
	backgroundColorEnabled = [pref boolForKey: @"backgroundColorEnabled"];
	backgroundCornerRadius = [pref floatForKey: @"backgroundCornerRadius"];
	customBackgroundColorEnabled = [pref boolForKey: @"customBackgroundColorEnabled"];
	portraitX = [pref floatForKey: @"portraitX"];
	portraitY = [pref floatForKey: @"portraitY"];
	landscapeX = [pref floatForKey: @"landscapeX"];
	landscapeY = [pref floatForKey: @"landscapeY"];
	followDeviceOrientation = [pref boolForKey: @"followDeviceOrientation"];
	width = [pref floatForKey: @"width"];
	height = [pref floatForKey: @"height"];
	fontSize = [pref integerForKey: @"fontSize"];
	boldFont = [pref boolForKey: @"boldFont"];
	customTextColorEnabled = [pref boolForKey: @"customTextColorEnabled"];
	alignment = [pref integerForKey: @"alignment"];
	updateInterval = [pref doubleForKey: @"updateInterval"];
	enableDoubleTap = [pref boolForKey: @"enableDoubleTap"];
	enableHold = [pref boolForKey: @"enableHold"];
	enableBlackListedApps = [pref boolForKey: @"enableBlackListedApps"];

	if(backgroundColorEnabled && customBackgroundColorEnabled || customTextColorEnabled)
	{
		NSDictionary *preferencesDictionary = [NSDictionary dictionaryWithContentsOfFile: @"/var/mobile/Library/Preferences/com.johnzaro.raminfo13prefs.colors.plist"];
		customBackgroundColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customBackgroundColor"] withFallback: @"#000000:0.50"];
		customTextColor = [SparkColourPickerUtils colourWithString: [preferencesDictionary objectForKey: @"customTextColor"] withFallback: @"#FF9400"];
	}

	if(enableDoubleTap)
	{
		NSArray *doubleTapApp = [SparkAppList getAppListForIdentifier: @"com.johnzaro.raminfo13prefs.gestureApps" andKey: @"doubleTapApp"];
		if(doubleTapApp && [doubleTapApp count] == 1)
			doubleTapIdentifier = doubleTapApp[0];
	}

	if(enableHold)
	{
		NSArray *holdApp = [SparkAppList getAppListForIdentifier: @"com.johnzaro.raminfo13prefs.gestureApps" andKey: @"holdApp"];
		if(holdApp && [holdApp count] == 1)
			holdIdentifier = holdApp[0];
	}

	if(enableBlackListedApps)
		blackListedApps = [SparkAppList getAppListForIdentifier: @"com.johnzaro.raminfo13prefs.blackListedApps" andKey: @"blackListedApps"];
	else
		blackListedApps = nil;

	if(ramInfoObject) 
	{
		[ramInfoObject updateFrame];
		[ramInfoObject updateText];
	}	
}

%ctor
{
	@autoreleasepool
	{
		pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.raminfo13prefs"];
		[pref registerDefaults:
		@{
			@"enabled": @NO,
			@"showOnLockScreen": @NO,
			@"showUsedRam": @NO,
			@"usedRAMPrefix": @"U: ",
			@"showFreeRam": @NO,
			@"freeRAMPrefix": @"F: ",
			@"showTotalPhysicalRam": @NO,
			@"totalRAMPrefix": @"T: ",
			@"separator": @", ",
			@"backgroundColorEnabled": @NO,
			@"backgroundCornerRadius": @6,
			@"customBackgroundColorEnabled": @NO,
			@"portraitX": @298,
			@"portraitY": @2,
			@"landscapeX": @750,
			@"landscapeY": @2,
			@"followDeviceOrientation": @NO,
			@"width": @55,
			@"height": @12,
			@"fontSize": @8,
			@"boldFont": @NO,
			@"customTextColorEnabled": @NO,
			@"alignment": @0,
			@"updateInterval": @2.0,
			@"enableDoubleTap": @NO,
			@"enableHold": @NO,
			@"enableBlackListedApps": @NO
    	}];

		settingsChanged(NULL, NULL, NULL, NULL, NULL);

		if(enabled && (showUsedRam || showFreeRam || showTotalPhysicalRam))
		{
			PHYSICAL_MEMORY = [NSProcessInfo processInfo].physicalMemory / MEGABYTES;

			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.johnzaro.raminfo13prefs/reloadprefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);
			
			%init;
		}
	}
}