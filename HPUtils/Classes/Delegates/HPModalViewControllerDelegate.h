//
//  HPModalViewControllerDelegate.h
//  HPUtils
//
//  Created by Taylan Pinçe on 12-06-11.
//  Copyright (c) 2012 Hippo Foundry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@protocol HPModalViewControllerDelegate <NSObject>
@required
- (void)modalViewControllerDidClose:(UIViewController *)modalController;
@end
