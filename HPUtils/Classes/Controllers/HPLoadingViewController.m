//
//  HPLoadingViewController.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPLoadingView.h"
#import "HPLoadingViewController.h"


@implementation HPLoadingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        
    }
    
    return self;
}

#pragma mark - View lifecycle

- (void)loadView {
    _loadingView = [[HPLoadingView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    
    self.view = _loadingView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self startLoadingAnimated:NO];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [_loadingView release], _loadingView = nil;
}

- (UIView *)contentView {
    if ([self isViewLoaded]) {
        return _loadingView.contentView;
    } else {
        return nil;
    }
}

#pragma mark - Load calls

- (void)startLoadingAnimated:(BOOL)animated {
    [_loadingView startLoadingAnimated:animated];
}

- (void)endLoadingWithSuccess:(BOOL)success animated:(BOOL)animated {
    [_loadingView endLoadingWithSuccess:success animated:animated];
}

- (void)endLoadingWithMessage:(NSString *)message animated:(BOOL)animated {
    [_loadingView endLoadingWithMessage:message animated:animated];
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [_loadingView release], _loadingView = nil;
    
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
