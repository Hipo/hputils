# This project is deprecated and is only kept here for reference purposes. Our more modern networking and locations libraries replaced the functionality contained within this single framework: HIPNetworking, HIPLocationManager, HIPSocialAuth

***

HPUtils - Hippo Foundry's iOS Utility Classes
=============================================

HPUtils is a static iOS library from [Hippo Foundry](http://hippofoundry.com). 
Main functionality of the library revolves around network requests and image 
processing. A list of available functionality is below:

* Fully managed, NSOperation-based request and network connectivity handling
* Multi-threaded image processing for resizing and storage
* Disk-based, persistent cache system
* Authentication management, keychain integration and automated HTTP BasicAuth
* Shared location manager with cache and intelligent requirement degradation
* Amazon S3 file upload support
* Automated crash logging and reporting
* Grid-based UIScrollView subclass with support for high performance cell recycling
* UITableView subclass with support for automated request cancellation as the 
	table is scrolled and cells are recycled
* NSString category with SHA1, UUID, MD5 support
* NSObject category for parsing NSDate, UIColor, NSURL, NSInteger and CGFloat 
	values from any object using keys
* UIDevice category for determining device type and capabilities
* NSData category for base64 support

We also provide some utility classes for activity indication and a  bunch of categories to extend SDK components.

Documented classes are listed below, but documentation of the project is 
currently a work in progress. For any questions or suggestions, email 
[Taylan Pince](mailto:taylan@hippofoundry.com).


Installation
------------

HPUtils is no longer available for pre-iOS4 projects. To add the static library 
to your builds, simply copy the HPUtils.framework directory to an appropriate 
location on your project path and add it through Xcode. You will also have to 
update your build settings and make sure -ObjC and -all_load are added under 
Other Linker Flags. Finally, make sure you have the following libraries included: 

* Security.framework
* CoreLocation.framework
* SystemConfiguration.framework
* CrashReporter.framework - can be obtained from [Plausible Labs](http://code.google.com/p/plcrashreporter/)

You can then include the following import statement and you will be good to go:

	#import <HPUtils/HPUtils.h>

You can view a list of documented class references below.
