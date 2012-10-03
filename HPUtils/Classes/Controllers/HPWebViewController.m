//
//  HPWebViewController.m
//  HPUtils
//
//  Created by Taylan Pince on 11-04-26.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPWebViewController.h"


@interface HPWebViewController (PrivateMethods)
- (void)didTapCloseButton:(id)sender;
- (void)didTapStopButton:(id)sender;
- (void)didTapReloadButton:(id)sender;
- (void)didTapBackButton:(id)sender;
- (void)didTapForwardButton:(id)sender;
- (void)updateUtilityBar;
@end


@implementation HPWebViewController

@synthesize webView = _webView;
@synthesize delegate;

- (id)initWithURL:(NSURL *)url {
	self = [super initWithNibName:nil bundle:nil];
	
    if (self) {
		_url = [url copy];
        _loadInProgress = NO;
    }
	
    return self;
}

#pragma mark - View lifecycle

- (void)loadView {
	_webView = [[UIWebView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	
	[_webView setDelegate:self];
	[_webView setScalesPageToFit:YES];
    [_webView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | 
                                   UIViewAutoresizingFlexibleHeight)];
	
	self.view = _webView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
    if (self.delegate != nil) {
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                     target:self
                                                                                     action:@selector(didTapCloseButton:)];
        
        [self.navigationItem setLeftBarButtonItem:closeButton];
        
        [closeButton release];
    }
	
	_loadIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    
	UIBarButtonItem *loadItem = [[UIBarButtonItem alloc] initWithCustomView:_loadIndicator];
	
	[_loadIndicator setHidesWhenStopped:YES];
	
	[self.navigationItem setRightBarButtonItem:loadItem];
	
	[loadItem release];
    
    UIButton *reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    [reloadButton setImage:[UIImage imageNamed:@"btn-web-refresh.png"] forState:UIControlStateNormal];
    [reloadButton addTarget:self action:@selector(didTapReloadButton:) forControlEvents:UIControlEventTouchUpInside];
    [reloadButton sizeToFit];
    
    UIButton *prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    [prevButton setEnabled:NO];
    [prevButton setFrame:CGRectMake(0.0, 0.0, 39.0, 33.0)];
    [prevButton setImage:[UIImage imageNamed:@"btn-web-previous.png"] forState:UIControlStateNormal];
    [prevButton addTarget:self action:@selector(didTapBackButton:) forControlEvents:UIControlEventTouchUpInside];
    [prevButton sizeToFit];
    
    [nextButton setEnabled:NO];
    [nextButton setFrame:CGRectMake(40.0, 0.0, 39.0, 33.0)];
    [nextButton setImage:[UIImage imageNamed:@"btn-web-next.png"] forState:UIControlStateNormal];
    [nextButton addTarget:self action:@selector(didTapForwardButton:) forControlEvents:UIControlEventTouchUpInside];
    [nextButton sizeToFit];
    
    UIBarButtonItem *prevBarButton = [[UIBarButtonItem alloc] initWithCustomView:prevButton];
    UIBarButtonItem *nextBarButton = [[UIBarButtonItem alloc] initWithCustomView:nextButton];
    UIBarButtonItem *reloadBarButton = [[UIBarButtonItem alloc] initWithCustomView:reloadButton];
    UIBarButtonItem *separatorBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace 
                                                                                        target:nil 
                                                                                        action:nil];

    UIBarButtonItem *fixedBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace 
                                                                                    target:nil 
                                                                                    action:nil];
    
    [prevBarButton setWidth:prevButton.bounds.size.width];
    [nextBarButton setWidth:nextButton.bounds.size.width];
    [reloadBarButton setWidth:reloadButton.bounds.size.width];
    [fixedBarButton setWidth:10.0];
    
    [self setToolbarItems:[NSArray arrayWithObjects:
                           prevBarButton, fixedBarButton, nextBarButton, 
                           separatorBarButton, reloadBarButton, nil]];
    
    [fixedBarButton release];
    [nextBarButton release];
    [prevBarButton release];
    [reloadBarButton release];
    [separatorBarButton release];
    
    [self.navigationController setToolbarHidden:NO animated:NO];
	
	[_webView loadRequest:[NSURLRequest requestWithURL:_url]];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [_webView release], _webView = nil;
    [_loadIndicator release], _loadIndicator = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return YES;
}

#pragma mark - Button actions

- (void)didTapCloseButton:(id)sender {
	[delegate webViewControllerDidClose:self];
}

- (void)didTapBackButton:(id)sender {
    [_webView goBack];
}

- (void)didTapForwardButton:(id)sender {
    [_webView goForward];
}

- (void)didTapReloadButton:(id)sender {
    [_webView reload];
}

- (void)didTapStopButton:(id)sender {
    [_webView stopLoading];
}

- (void)updateUtilityBar {
    NSString *pageTitle = [_webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    
    if (pageTitle == nil || [pageTitle isEqualToString:@""]) {
        pageTitle = [[_webView.request URL] absoluteString];
    }
    
    [self setTitle:pageTitle];
    
    if (_webView.loading) {
        if (!_loadInProgress) {
            _loadInProgress = YES;
            
            [_loadIndicator startAnimating];
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            
            UIButton *stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
            
            [stopButton setImage:[UIImage imageNamed:@"btn-web-stop.png"] forState:UIControlStateNormal];
            [stopButton addTarget:self action:@selector(didTapStopButton:) forControlEvents:UIControlEventTouchUpInside];
            [stopButton sizeToFit];
            
            UIBarButtonItem *stopBarButton = [[UIBarButtonItem alloc] initWithCustomView:stopButton];
            
            [stopBarButton setWidth:stopButton.bounds.size.width];
            
            NSMutableArray *toolbarItems = [self.toolbarItems mutableCopy];
            
            [toolbarItems replaceObjectAtIndex:4
                                    withObject:stopBarButton];
            
            [self setToolbarItems:toolbarItems animated:YES];
            
            [toolbarItems release];
            [stopBarButton release];
        }
    } else if (_loadInProgress) {
        _loadInProgress = NO;
        
        [_loadIndicator stopAnimating];
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        
        UIButton *reloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
        
        [reloadButton setImage:[UIImage imageNamed:@"btn-web-refresh.png"] forState:UIControlStateNormal];
        [reloadButton addTarget:self action:@selector(didTapReloadButton:) forControlEvents:UIControlEventTouchUpInside];
        [reloadButton sizeToFit];
        
        UIBarButtonItem *reloadBarButton = [[UIBarButtonItem alloc] initWithCustomView:reloadButton];
        
        [reloadBarButton setWidth:reloadButton.bounds.size.width];
        
        NSMutableArray *toolbarItems = [self.toolbarItems mutableCopy];
        
        [toolbarItems replaceObjectAtIndex:4
                                withObject:reloadBarButton];
        
        [self setToolbarItems:toolbarItems animated:YES];
        
        [toolbarItems release];
        [reloadBarButton release];
    }
    
    [(UIButton *)[(UIBarButtonItem *)[self.toolbarItems objectAtIndex:0] customView] setEnabled:[_webView canGoBack]];
    [(UIButton *)[(UIBarButtonItem *)[self.toolbarItems objectAtIndex:2] customView] setEnabled:[_webView canGoForward]];
}

#pragma mark - UIWebViewDelegate calls

- (void)webViewDidStartLoad:(UIWebView *)webView {
	[self updateUtilityBar];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[self updateUtilityBar];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self updateUtilityBar];
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
	[_url release], _url = nil;
    [_webView release], _webView = nil;
    [_loadIndicator release], _loadIndicator = nil;
	
    [super dealloc];
}

@end
