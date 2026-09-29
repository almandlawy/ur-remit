#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.urremit.mobile";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "LaunchBackground" asset catalog color resource.
static NSString * const ACColorNameLaunchBackground AC_SWIFT_PRIVATE = @"LaunchBackground";

/// The "DollarStack" asset catalog image resource.
static NSString * const ACImageNameDollarStack AC_SWIFT_PRIVATE = @"DollarStack";

/// The "DubaiSkyline" asset catalog image resource.
static NSString * const ACImageNameDubaiSkyline AC_SWIFT_PRIVATE = @"DubaiSkyline";

/// The "EuroStack" asset catalog image resource.
static NSString * const ACImageNameEuroStack AC_SWIFT_PRIVATE = @"EuroStack";

/// The "PoundStack" asset catalog image resource.
static NSString * const ACImageNamePoundStack AC_SWIFT_PRIVATE = @"PoundStack";

#undef AC_SWIFT_PRIVATE
