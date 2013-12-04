//
//  SearchController.m
//  newsyc
//
//  Created by Quin Hoxie on 6/2/11.
//

#import "SearchController.h"
#import "SubmissionTableCell.h"
#import "CommentListController.h"
#import "LoadingIndicatorView.h"
#import "UIColor+Orange.h"
#import "AppDelegate.h"

@implementation SearchController

- (id)initWithSession:(HNSession *)session_ {
    if ((self = [super init])) {
        session = [session_ retain];
    }

    return self;
}

- (void)loadView {
    [super loadView];
    
    searchBar = [[UISearchBar alloc] init];
    [searchBar sizeToFit];
    [searchBar setPlaceholder:@"Search Financier News"];
    [searchBar setFrame:CGRectMake(0, 0, [[self view] bounds].size.width, [searchBar bounds].size.height)];
    [searchBar setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth];
    [searchBar setDelegate:self];

    coloredView = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, [[self view] bounds].size.width, [searchBar bounds].size.height)];
    [coloredView setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth];
    [[self view] addSubview:coloredView];
    
    facetControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Interesting", @"Recent", nil]];
    [facetControl setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth];
    [facetControl addTarget:self action:@selector(facetSelected:) forControlEvents:UIControlEventValueChanged];
    [facetControl setSegmentedControlStyle:UISegmentedControlStyleBar];
    [facetControl setSelectedSegmentIndex:0];
    [facetControl sizeToFit];
    [facetControl setFrame:CGRectMake(([coloredView bounds].size.height - [facetControl bounds].size.height) / 2, ([coloredView bounds].size.height - [facetControl bounds].size.height) / 2, [coloredView bounds].size.width - ((([coloredView bounds].size.height - [facetControl bounds].size.height) / 2) * 2), [facetControl bounds].size.height)];
    [coloredView addSubview:facetControl];
    
    tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, [coloredView bounds].size.height, [[self view] bounds].size.width, [[self view] bounds].size.height - [coloredView bounds].size.height)];
    [tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [tableView setDelegate:self];
    [tableView setDataSource:self];
    [[self view] addSubview:tableView];
    
    indicator = [[LoadingIndicatorView alloc] initWithFrame:[tableView frame]];
    [indicator setBackgroundColor:[UIColor whiteColor]];
    [indicator setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [indicator setHidden:YES];
    [[self view] addSubview:indicator];
    
    emptyResultsView = [[UILabel alloc] initWithFrame:[tableView frame]];
    [emptyResultsView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [emptyResultsView setText:@"No Results"];
    [emptyResultsView setTextAlignment:NSTextAlignmentCenter];
    [emptyResultsView setFont:[UIFont systemFontOfSize:17.0f]];
    [emptyResultsView setTextColor:[UIColor grayColor]];
    [emptyResultsView setFrame:[tableView frame]];
    [[self view] addSubview:emptyResultsView];
}

- (HNAPISearch *)searchAPI {
	if (searchAPI == nil) {
		searchAPI = [[HNAPISearch alloc] initWithSession:session];
	}
    
	return searchAPI;
}

- (void)backgroundTouched:(id)sender {
	[searchBar resignFirstResponder];
}

- (void)performSearch {
    if ([[searchBar text] length] > 0) {
        searchPerformed = YES;
        [[self searchAPI] performSearch:[searchBar text]];
        
        [emptyResultsView setHidden:YES];
        [indicator setHidden:NO];
    } else {
        [indicator setHidden:YES];
        [emptyResultsView setHidden:NO];
    }
}

- (void)facetSelected:(id)sender {
	[searchBar resignFirstResponder];

	if ([facetControl selectedSegmentIndex] == 0) {
		[searchAPI setSearchType:kHNSearchTypeInteresting];
	} else {
		[searchAPI setSearchType:kHNSearchTypeRecent];
	}
    
	if (searchPerformed) {
		[self performSearch];
	}
}

- (void)searchBarSearchButtonClicked:(id)sender {
	[searchBar resignFirstResponder];
	[self performSearch];
}

- (void)viewDidLoad {
	[super viewDidLoad];
    
    // This is a hack, but it's all that's available right now.
    UITextField *searchBarTextField = nil;
    for (UIView *subview in [searchBar subviews]) {
        if ([subview isKindOfClass:[UITextField class]]) {
            searchBarTextField = (UITextField *)subview;
            break;
        }
    }
    [searchBarTextField setEnablesReturnKeyAutomatically:NO];
        
	searchPerformed = NO;
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(receivedResults:) name:@"searchDone" object:nil];
}

- (void)receivedResults:(NSNotification *)notification {
    [indicator setHidden:YES];
    [emptyResultsView setHidden:NO];
    
	if ([notification userInfo] == nil) {
		UIAlertView *alert = [[UIAlertView alloc]
							  initWithTitle:@"Unable to Connect"
							  message:@"Could not connect to search server. Please try again."
							  delegate:nil
							  cancelButtonTitle:@"Continue"
							  otherButtonTitles:nil];
		[alert show];
		[alert release];
	} else {
		NSDictionary *dict = [notification userInfo];
        [entries release];
		entries = [[dict objectForKey:@"array"] retain];
        
		if ([entries count] != 0) {
			[emptyResultsView setHidden:YES];
            [tableView setContentOffset:CGPointZero animated:NO];
		}

        [tableView reloadData];
	}
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [entries count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    HNEntry *entry = [entries objectAtIndex:[indexPath row]];
    return [SubmissionTableCell heightForEntry:entry withWidth:[[self view] bounds].size.width];
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SubmissionTableCell *cell = (SubmissionTableCell *) [tableView dequeueReusableCellWithIdentifier:@"submission"];
    if (cell == nil) cell = [[[SubmissionTableCell alloc] initWithReuseIdentifier:@"submission"] autorelease];
    HNEntry *entry = [entries objectAtIndex:[indexPath row]];
    [cell setSubmission:entry];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    HNEntry *entry = [entries objectAtIndex:[indexPath row]];
    
    CommentListController *controller = [[CommentListController alloc] initWithSource:entry];
    [[self navigationController] pushController:[controller autorelease] animated:YES];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [entries release];
    entries = nil;
    [searchBar release];
    searchBar = nil;
    [tableView release];
    tableView = nil;
    [facetControl release];
    facetControl = nil;
    [emptyResultsView release];
    emptyResultsView = nil;
    [coloredView release];
    coloredView = nil;
    [indicator release];
    indicator = nil;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    
    UIViewController *parentController = [[self navigationController] topViewController];
    UINavigationItem *navigationItem = [parentController navigationItem];
	[navigationItem setTitleView:searchBar];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) {
        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
    }
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"disable-orange"]) {
        [searchBar setTintColor:[UIColor mainOrangeColor]];
        [facetControl setTintColor:[UIColor mainOrangeColor]];
        [coloredView setTintColor:[UIColor orangeColor]];
    } else {
        [searchBar setTintColor:nil];
        [facetControl setTintColor:nil];
        [coloredView setTintColor:nil];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [searchBar resignFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

    UIViewController *parentController = [[self navigationController] topViewController];
    UINavigationItem *navigationItem = [parentController navigationItem];
	[navigationItem setTitleView:nil];
}

- (void)dealloc {
    [entries release];
    [searchBar release];
    [tableView release];
    [facetControl release];
    [emptyResultsView release];
    [coloredView release];
    [searchAPI release];
    [indicator release];
    [session release];

    [super dealloc];
}

AUTOROTATION_FOR_PAD_ONLY

@end
