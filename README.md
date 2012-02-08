HPUtils - Hippo Foundry's iOS Utility Classes
=============================================

HPUtils is a static iOS library from [Hippo Foundry](http://hippofoundry.com). 
Main functionality of the library revolves around network requests and image 
processing. We also provide some utility classes for activity indication and a 
bunch of categories to extend SDK components.

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

You can then #import <HPUtils/HPUtils.h> and you will be good to go. You can 
view the list of class references below.
