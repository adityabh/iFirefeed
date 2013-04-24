//
//  FirefeedSearch.m
//  iFirefeed
//
//  Created by Greg Soltis on 4/23/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "FirefeedSearch.h"
#import "UIImageView+WebCache.h"

#define CHAR_THRESHOLD 3

@interface NSString (FirefeedSearch)

- (BOOL) startsWithString:(NSString *)other;

@end

@implementation NSString (FirefeedSearch)

- (BOOL) startsWithString:(NSString *)other {
    return [[self substringToIndex:other.length] isEqualToString:other];
}

@end

@interface SearchResult : NSObject

@property (strong, nonatomic) NSString* name;
@property (strong, nonatomic) NSString* userId;
@property (readonly, nonatomic) NSString* displayName;

@end

@implementation SearchResult

- (NSString *) displayName {
    return [[self.name stringByReplacingOccurrencesOfString:@"_" withString:@" "] capitalizedString];
}

- (NSURL *) picURLSmall {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture/?return_ssl_resources=1&width=48&height=48", self.userId]];
}
@end

@protocol NameSearchDelegate;

@interface NameSearch : NSObject {
    NSString* _stem;
    NSString* _term;
    Firebase* _root;
    FirebaseHandle _firstNameHandle;
    NSMutableArray* _firstNameResults;
}

- (id) initWithRef:(Firebase *)ref andStem:(NSString *)stem;

- (BOOL) containsTerm:(NSString *)term;
- (BOOL) updateTerm:(NSString *)term;

@property (weak, nonatomic) id<NameSearchDelegate> delegate;

@end

@protocol NameSearchDelegate <NSObject>

- (void) resultsDidChange:(NSArray *)results;

@end

@implementation NameSearch

- (id) initWithRef:(Firebase *)ref andStem:(NSString *)stem {
    self = [super init];
    if (self) {
        _stem = [stem substringToIndex:CHAR_THRESHOLD];
        _term = stem;
        _root = ref;
        _firstNameResults = [[NSMutableArray alloc] init];
        [self startSearch];
    }
    return self;
}

- (void) dealloc {
    [[_root childByAppendingPath:@"search/firstName"] removeObserverWithHandle:_firstNameHandle];
}

- (void) startSearch {
    __weak NameSearch* weakSelf = self;
    _firstNameHandle = [[[_root childByAppendingPath:@"search/firstName"] queryStartingAtPriority:nil andChildName:_stem] observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {

        [weakSelf newFirstNameResult:snapshot];
    }];
}

- (void) newFirstNameResult:(FDataSnapshot *)snapshot {
    SearchResult* result = [[SearchResult alloc] init];
    //result.name = snapshot.name;
    result.userId = snapshot.value;
    result.name = [snapshot.name substringToIndex:(snapshot.name.length - (result.userId.length + 1))];
    [_firstNameResults addObject:result];
    if ([result.name startsWithString:_term]) {
        [self raiseFilteredResults];
    }
    //[self.delegate resultsDidChange:_firstNameResults];

}

- (void) raiseFilteredResults {
    NSMutableArray* results = [[NSMutableArray alloc] init];
    for (SearchResult* result in _firstNameResults) {
        if ([result.name startsWithString:_term]) {
            [results addObject:result];
        }
    }
    [self.delegate resultsDidChange:results];
}

- (BOOL) containsTerm:(NSString *)term {
    if (term.length < CHAR_THRESHOLD) {
        return NO;
    } else {
        return [term startsWithString:_stem];
    }
}

- (BOOL) updateTerm:(NSString *)term {
    _term = term;
    [self raiseFilteredResults];
    return NO;
}

@end

@interface FirefeedSearch () <NameSearchDelegate, UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) Firebase* root;
@property (strong, nonatomic) NSString* searchBase;
@property (strong, nonatomic) NSString* searchTerm;
@property (strong, nonatomic) NameSearch* currentSearch;
@property (strong, nonatomic) NSArray* currentResults;


@end

@implementation FirefeedSearch

- (id) initWithRef:(Firebase *)ref {
    self = [super init];
    if (self) {
        self.root = ref;
        self.searchTerm = @"";
        self.searchBase = nil;
        self.currentResults = @[];
    }
    return self;
}

- (void) setResultsTable:(UITableView *)resultsTable {
    _resultsTable = resultsTable;
    _resultsTable.delegate = self;
    _resultsTable.dataSource = self;
}

- (void) resultsDidChange:(NSArray *)results {
    self.currentResults = results;
    [self.resultsTable reloadData];
}

- (void) startSearch:(NSString *)text {
    if (text.length >= CHAR_THRESHOLD) {
        self.currentSearch = [[NameSearch alloc] initWithRef:_root andStem:text];
        self.currentSearch.delegate = self;
    }
}

- (void) stopSearch {
    self.currentSearch = nil;
    [self resultsDidChange:@[]];
}

- (BOOL) searchTextDidUpdate:(NSString *)text {
    if (self.currentSearch) {
        // We have a term
        if ([self.currentSearch containsTerm:text]) {
            return [self.currentSearch updateTerm:text];
        } else {
            [self stopSearch];
            return YES;
        }
    } else {
        // No current term. Save this one if it's longer than 3 chars
        [self startSearch:text];
    }
    return NO;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentResults.count;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString* CellIdentifier = @"SearchResult";

    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.backgroundColor = [UIColor clearColor];
    SearchResult* result = [self.currentResults objectAtIndex:indexPath.row];
    cell.textLabel.text = result.displayName;
    [cell.imageView setImageWithURL:result.picURLSmall placeholderImage:[UIImage imageNamed:@"placekitten.png"]];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SearchResult* result = [self.currentResults objectAtIndex:indexPath.row];
    [self.delegate userIdWasSelected:result.userId];
}

@end
