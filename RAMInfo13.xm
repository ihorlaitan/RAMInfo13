#import "RAMInfo13.h"

#import <Cephei/HBPreferences.h>
#import <mach/mach_init.h>
#import <mach/mach_host.h>

static const unsigned int MEGABYTES = 1 << 20;
static unsigned long long PHYSICAL_MEMORY;

static NSString *cachedString;

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
static long alignment;
static double updateInterval;

static NSString* getMemoryStats()
{
	mach_port_t host_port;
	mach_msg_type_number_t host_size;
	vm_size_t pagesize;
	vm_statistics_data_t vm_stat;
	natural_t mem_used, mem_free;
	NSMutableString* string = [[NSMutableString alloc] init];

	host_port = mach_host_self();
	host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
	host_page_size(host_port, &pagesize);
	if(host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) == KERN_SUCCESS)
	{
		if(showUsedRam)
		{
			mem_used = (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize / MEGABYTES;
			[string appendString: [NSString stringWithFormat:@"%@%uMB", usedRAMPrefix, mem_used]];
		}
		if(showFreeRam)
		{
			mem_free = vm_stat.free_count * pagesize / MEGABYTES;
			if([string length] != 0) [string appendString: separator];
			[string appendString: [NSString stringWithFormat:@"%@%uMB", freeRAMPrefix, mem_free]];
		}
		if(showTotalPhysicalRam)
		{
			if([string length] != 0) [string appendString: separator];
			[string appendString: [NSString stringWithFormat:@"%@%lluMB", totalRAMPrefix, PHYSICAL_MEMORY]];
		}
	}
	return string;
}

%hook _UIStatusBarForegroundView

%property(nonatomic, retain) UILabel *ramLabel;

-(id)initWithFrame: (CGRect)arg1
{
	@autoreleasepool
	{
		self = %orig;

		if(!self.ramLabel)
		{
			self.ramLabel = [[UILabel alloc] initWithFrame: CGRectMake(locationX, locationY, width, height)];
			self.ramLabel.font = [UIFont systemFontOfSize: fontSize];
			self.ramLabel.textAlignment = alignment;
			
			self.ramLabel.adjustsFontSizeToFitWidth = NO;

			[NSTimer scheduledTimerWithTimeInterval: 2.1 repeats: YES block: ^(NSTimer *timer)
			{
				if(![[%c(SBCoverSheetPresentationManager) sharedInstance] isPresented] && self && self.ramLabel)
				{
					if([self.superview.superview.superview isKindOfClass: %c(CCUIStatusBar)])
					{
						if(!self.ramLabel.hidden) self.ramLabel.hidden = YES;
					}
					else
					{
						self.ramLabel.hidden = NO;
						self.ramLabel.text = cachedString;
					}
				}
				else if(!self.ramLabel.hidden) self.ramLabel.hidden = YES;
			}];
			[self addSubview: self.ramLabel];
		}
		return self;
	}
}

%end

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
			@"alignment": @0,
			@"updateInterval": @2.0
    	}];

		enabled = [pref boolForKey: @"enabled"];
		if(enabled)
		{
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
			
			alignment = [pref integerForKey: @"alignment"];

			updateInterval = [pref doubleForKey: @"updateInterval"];

			if(showUsedRam || showFreeRam || showTotalPhysicalRam)
			{
				if(showTotalPhysicalRam) PHYSICAL_MEMORY = [NSProcessInfo processInfo].physicalMemory / MEGABYTES;

				[NSTimer scheduledTimerWithTimeInterval: updateInterval repeats: YES block: ^(NSTimer *timer)
				{
					if(![[%c(SBCoverSheetPresentationManager) sharedInstance] isPresented]) cachedString = getMemoryStats();
				}];

				%init;
			}
		}
	}
}