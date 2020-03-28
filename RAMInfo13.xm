#import "RAMInfo13.h"

#import <Cephei/HBPreferences.h>
#import <mach/mach_init.h>
#import <mach/mach_host.h>

#define DegreesToRadians(degrees) (degrees * M_PI / 180)
#define IS_iPAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

static const unsigned int MEGABYTES = 1 << 20;
static unsigned long long PHYSICAL_MEMORY;

static double screenWidth;
static double screenHeight;
static UIDeviceOrientation orientationOld;

__strong static id ramInfoObject;

static HBPreferences *pref;
static BOOL enabled;
static BOOL showUsedRam;
static NSString *usedRAMPrefix;
static BOOL showFreeRam;
static NSString *freeRAMPrefix;
static BOOL showTotalPhysicalRam;
static NSString *totalRAMPrefix;
static NSString *separator;
static double locationX;
static double locationY;
static double width;
static double height;
static long fontSize;
static BOOL boldFont;
static long alignment;
static double updateInterval;

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
	if(IS_iPAD && ramInfoObject) 
		[ramInfoObject orientationChanged];
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

@implementation RamInfo

	- (id)init
	{
		self = [super init];
		if(self)
		{
			@try
			{
				ramInfoWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, width, height)];
				[ramInfoWindow setWindowLevel: 1000];
				[ramInfoWindow setHidden: NO];
				[ramInfoWindow setAlpha: 1];
				[ramInfoWindow _setSecure: YES];
				[ramInfoWindow setUserInteractionEnabled: NO];
				
				ramInfoLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, width, height)];
				[ramInfoLabel setNumberOfLines: 1];
				[ramInfoLabel setFont: [UIFont systemFontOfSize: fontSize]];
				[ramInfoLabel setTextAlignment: alignment];
				[(UIView *)ramInfoWindow addSubview: ramInfoLabel];
				
				[self orientationChanged];

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
		[ramInfoWindow setFrame: CGRectMake(0, 0, width, height)];
		[ramInfoLabel setFrame: CGRectMake(0, 0, width, height)];
		if(boldFont) [ramInfoLabel setFont: [UIFont boldSystemFontOfSize: fontSize]];
		else [ramInfoLabel setFont: [UIFont systemFontOfSize: fontSize]];
		[ramInfoLabel setTextAlignment: alignment];
		[self orientationChanged];
	}

	- (void)updateText
	{
		if(ramInfoWindow && ramInfoLabel)
		{
			if(![[%c(SBCoverSheetPresentationManager) sharedInstance] isPresented] && ![[%c(SBControlCenterController) sharedInstance] isVisible])
			{
				[ramInfoWindow setHidden: NO];
				[ramInfoLabel setText: getMemoryStats()];
			}
			else [ramInfoWindow setHidden: YES];
		}
	}

	- (void)updateColor: (UIColor*)color
	{
		[ramInfoLabel setTextColor: color];
	}

	- (void)orientationChanged
	{
		if(!IS_iPAD)
		{
			CGRect frame = [ramInfoWindow frame];
			frame.origin.x = locationX;
			frame.origin.y = locationY;
			[ramInfoWindow setFrame: frame];
		}
		else
		{
			UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
			if(orientation == orientationOld)
				return;
			
			CGAffineTransform newTransform;
			int newLocationX;
			int newLocationY;

			switch (orientation)
			{
				case UIDeviceOrientationLandscapeRight:
				{
					newLocationX = locationY;
					newLocationY = (screenHeight - width - locationX);
					newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationLandscapeLeft:
				{
					newLocationX = (screenWidth - height - locationY);
					newLocationY = locationX;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
					break;
				}
				case UIDeviceOrientationPortraitUpsideDown:
				{
					newLocationX = screenWidth - locationX - width;
					newLocationY = (screenHeight - height - locationY);
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
					break;
				}
				case UIDeviceOrientationPortrait:
				default:
				{
					newLocationX = locationX;
					newLocationY = locationY;
					newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
					break;
				}
			}

			[UIView animateWithDuration: 0.3f animations:
			^{
				[ramInfoWindow setTransform: newTransform];
				CGRect frame = [ramInfoWindow frame];
				frame.origin.x = newLocationX;
				frame.origin.y = newLocationY;
				[ramInfoWindow setFrame: frame];
				orientationOld = orientation;
			} completion: nil];
		}
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
		[ramInfoObject updateColor: [[self styleAttributes] imageTintColor]];
}

%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if(!pref) pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.raminfo13prefs"];
	enabled = [pref boolForKey: @"enabled"];
	showUsedRam = [pref boolForKey: @"showUsedRam"];
	usedRAMPrefix = [pref objectForKey: @"usedRAMPrefix"];
	showFreeRam = [pref boolForKey: @"showFreeRam"];
	freeRAMPrefix = [pref objectForKey: @"freeRAMPrefix"];
	showTotalPhysicalRam = [pref boolForKey: @"showTotalPhysicalRam"];
	totalRAMPrefix = [pref objectForKey: @"totalRAMPrefix"];
	separator = [pref objectForKey: @"separator"];
	locationX = [pref floatForKey: @"locationX"];
	locationY = [pref floatForKey: @"locationY"];
	width = [pref floatForKey: @"width"];
	height = [pref floatForKey: @"height"];
	fontSize = [pref integerForKey: @"fontSize"];
	boldFont = [pref boolForKey: @"boldFont"];
	alignment = [pref integerForKey: @"alignment"];
	updateInterval = [pref doubleForKey: @"updateInterval"];

	if(ramInfoObject) 
		[ramInfoObject updateFrame];
}

%ctor
{
	@autoreleasepool
	{
		pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.raminfo13prefs"];
		[pref registerDefaults:
		@{
			@"enabled": @NO,
			@"showUsedRam": @NO,
			@"usedRAMPrefix": @"U: ",
			@"showFreeRam": @NO,
			@"freeRAMPrefix": @"F: ",
			@"showTotalPhysicalRam": @NO,
			@"totalRAMPrefix": @"T: ",
			@"separator": @", ",
			@"locationX": @298,
			@"locationY": @2,
			@"width": @55,
			@"height": @12,
			@"fontSize": @8,
			@"boldFont": @NO,
			@"alignment": @0,
			@"updateInterval": @2.0
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