//
//  HPImageLoadingTableViewController.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPAPIManager.h"
#import "HPImageOperation.h"
#import "HPRequestOperation.h"
#import "HPImageLoadingTableViewController.h"


@interface HPImageLoadingTableViewController (PrivateMethods)
- (void)cancelAllLoadOperations;
- (void)cancelAllProcessOperations;
- (void)cancelLoadOperationsForHiddenCells;
- (void)cancelProcessOperationsForHiddenCells;
@end


@implementation HPImageLoadingTableViewController

@synthesize tableView = _tableView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tableView = [[UITableView alloc] initWithFrame:self.contentView.bounds 
                                              style:UITableViewStylePlain];
    
    [_tableView setDelegate:self];
    [_tableView setDataSource:self];
    [_tableView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | 
                                     UIViewAutoresizingFlexibleHeight)];
    
    [self.contentView addSubview:_tableView];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    
	[self cancelAllLoadOperations];
	[self cancelAllProcessOperations];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self cancelLoadOperationsForHiddenCells];
	[self cancelProcessOperationsForHiddenCells];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	if (!decelerate) {
		[self cancelLoadOperationsForHiddenCells];
		[self cancelProcessOperationsForHiddenCells];
	}
}

- (void)cancelLoadOperationsForHiddenCells {
	for (HPRequestOperation *request in [[HPAPIManager sharedManager] activeRequestOperations]) {
		if ([request isExecuting] && request.indexPath != nil) {
			UITableViewCell *cell = [_tableView cellForRowAtIndexPath:request.indexPath];
			
			if (cell == nil) {
				[request cancel];
			}
		}
	}
}

- (void)cancelAllLoadOperations {
	for (HPRequestOperation *request in [[HPAPIManager sharedManager] activeRequestOperations]) {
		if ([request isExecuting] && request.indexPath != nil) {
			[request cancel];
		}
	}
}

- (void)cancelProcessOperationsForHiddenCells {
	for (HPImageOperation *operation in [[HPAPIManager sharedManager] activeProcessOperations]) {
		if ([operation isKindOfClass:[HPImageOperation class]] && [operation isExecuting] && operation.indexPath != nil) {
			UITableViewCell *cell = [_tableView cellForRowAtIndexPath:operation.indexPath];
			
			if (cell == nil) {
				[operation cancel];
			}
		}
	}
}

- (void)cancelAllProcessOperations {
	for (HPImageOperation *operation in [[HPAPIManager sharedManager] activeProcessOperations]) {
		if ([operation isKindOfClass:[HPAPIManager class]] && [operation isExecuting] && operation.indexPath != nil) {
			[operation cancel];
		}
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [_tableView setDelegate:nil];
    [_tableView setDataSource:nil];
    
    [_tableView release], _tableView = nil;
}

- (void)dealloc {
    [_tableView setDelegate:nil];
    [_tableView setDataSource:nil];
    
    [_tableView release], _tableView = nil;
    
    [super dealloc];
}

@end
