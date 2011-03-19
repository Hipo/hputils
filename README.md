HPUtils - Hippo Foundry's iOS Utility Classes
=============================================

HPUtils is a static iOS library from [Hippo Foundry](http://hippofoundry.com). 
Main functionality of the library revolves around network requests and image 
processing. We also provide some utility classes for activity indication and a 
bunch of categories to extend SDK components.

Some descriptions of the classes are included below, but to learn how to use 
them please check out the header files. For any questions or suggestions, 
feel free to open an issue ticket here on GitHub or email [Taylan Pince](mailto:taylan@hippofoundry.com).

* * *

Installation
------------

If you are building for iOS 4+, there are no requirements for build. If you 
would like to support pre-iOS4 systems, you will have to compile with PLBlocks. 
HPUtils already includes the PLBlocks Runtime, but you might have to install 
the [PLBlocks SDK](http://code.google.com/p/plblocks/) if you haven't already 
done so.

Open the project in Xcode and build once you are ready. HPUtils.framework will 
be created as a combined static library under build/. Drag and drop the 
HPUtils.framework into your own project's Dependencies folder and then add it 
as a framework to your project.

You can then #import <HPUtils/HPUtils.h> and you will be good to go.

* * *

HPCacheManager
--------------

This is a singleton cache manager that injects itself into the shared URL cache. 
Unlike the iOS cache, it's capable of storing items on disk, in the application's 
own cache directory. It will also automatically clear stale cache over time.

It also has a special cache class, HPCacheItem, that stores additional data 
with a cached object. When you load an item from cache, an instance of 
HPCacheItem will be returned, which will give you the obejct's MIME type, 
cached time as well as its cache path.


HPRequestManager
----------------

This is a singleton object that handles request and processing operations. It 
also contains some utility methods for handling URL encoding, converting 
arrays or dictionaries into POST variables, and parsing server responses.

HPRequestManager also keeps an eye on the network status of the device through 
Apple's Reachability class and it will send out network status change 
notifications whenever network status is modified.

This class also has a couple of utility methods for loading and resizing 
remote image resources. It can load a given image URL, resize it to the given 
dimensions and return it. Alternatively it can take a UIImage instance and 
resize it in a background thread, returning the results.

Under the hood, HPRequestManager makes use of two separate operation queues 
and HPRequestOperation  and HPImageOperation classes to manage its processes.


HPLocationManager
-----------------

This is a singleton class that acts as a light wrapper around CLLocationManager. 
The biggest improvement provided by HPLocationManager is its ability to 
degrade the accuracy requirement of a location request over time. So it will 
always try to get the best available location for you, but if several locations 
are returned and a few seconds pass by without a location that is accurate 
enough, it will lower its accuracy requirement and return the best available 
coordinates.

It's also capable of caching the last location and returning it without making
further requests. It doesn't keep the location manager running constantly, 
instead opting to turn it on/off as necessary.


HPLoadingWindow
---------------

This is a singleton UIWindow subclass that pops up blocking all UI elements, 
including the keyboard. It can be used to display a custom loading message 
during loading or processing. It can also be fired to display a confirmation.


HPLoadingViewController
-----------------------

This is a UIViewController subclass that provides a non-blocking activity 
indicator within the main view area. It's meant to be subclassed by another 
view controller, which would then create its own view(s) and inject them 
into the contentView property.


HPImageLoadingTableViewController
---------------------------------

This is a subclass of HPLoadingViewController that provides a table view. In 
addition to being a UITableViewController with a custom activity indicator, 
this class can also handle cancellation of unnecessary image requests as the 
table view scrolls up and down. It will automatically interface with 
HPRequestManager and cancel any image loading or processing operations that 
might be running for table cells that are no longer visible.


UIColor+HPColorAdditions
------------------------

Simple UIColor category that adds some additional color types:

	lightBlueBackgroundColor
	darkBlueForegroundColor


UIScreen+HPScaleAdditions
-------------------------

Adds a backwards compatible scaleRatio method to UIScreen.


NSString+HPHashAdditions
------------------------

Adds an SHA1Hash method to NSString for converting any string to SHA1.


NSDate+HPTimeSinceAdditions
---------------------------

Adds a timeSince method to NSDate for returning a Twitter-like, user friendly 
time since string (x days ago, just now, more than a year ago, etc.)


NSObject+HPKVCAdditions
-----------------------

Adds better KVC methods to any NSObject:

	nonNullValueForKey: # Useful for getting not-NSNull objects
	nonNilValueForKey: # Useful for geting non-nil objects (returns NSNull)
	URLValueForKey:
	CGFloatValueForKey:
	timeIntervalValueForKey:
	dateValueForKey:
	timeValueForKey:withDateFormat:
	dateValueForKey:withDateFormat:
	dateValueFromString:withDateFormat:
	colorValueWithHexStringForKey:


UIDevice+HPCapabilityAdditions
------------------------------

Adds backwards-compatible UIDevice utility methods:

	deviceType # Returns an HPDeviceType that you can check against
	platformCode # Returns the platform code (iPhone3,1, etc.)
	canMakePhoneCalls
	canScanBarcodes
	isTablet


* * *


License
-------

    The MIT License
    
    Copyright (c) 2009 Free Time Studios and Nathan Eror
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
