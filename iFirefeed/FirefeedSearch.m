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
#define IS_VALID_CHAR(c) (c != '.' && c != '#' && c != '$' && c != '/' && c != '[' && c != ']')

@interface TupleRefHandle : NSObject

@property (strong, nonatomic) FQuery* ref;
@property (nonatomic) FirebaseHandle handle;

@end

@implementation TupleRefHandle

@end

@interface NSString (FirefeedSearch)

- (NSString *) nextLowerCaseKey;
- (BOOL) isValidKey;

@end

@implementation NSString (FirefeedSearch)

- (NSString *) nextLowerCaseKey {
    unichar c = [self characterAtIndex:self.length - 1];

    if (c == USHRT_MAX) {
        // Seems unlikely, but we should handle it
        return nil;
    } else {
        do {
            c++;
        } while (!IS_VALID_CHAR(c));

        return [NSString stringWithFormat:@"%@%c", [self substringToIndex:self.length - 1], c];
    }
}

- (BOOL) isValidKey {
    for (int i = 0; i < self.length; ++i) {
        if (!IS_VALID_CHAR([self characterAtIndex:i])) {
            return NO;
        }
    }
    return YES;
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
    //NSString* _stem;
    NSString* _term;
    Firebase* _root;
    NSMutableArray* _handles;
    NSMutableArray* _firstNameResults;
    NSMutableArray* _lastNameResults;
    NSArray* _stems;
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
        //_stem = [stem substringToIndex:CHAR_THRESHOLD];
        _term = stem;
        _root = ref;
        _firstNameResults = [[NSMutableArray alloc] init];
        _lastNameResults = [[NSMutableArray alloc] init];
        _handles = [[NSMutableArray alloc] init];
        _stems = [self generateStems:stem];
        [self startSearch];
    }
    return self;
}

- (NSArray *) generateStems:(NSString *)stem {
    stem = [[stem substringToIndex:CHAR_THRESHOLD] lowercaseString];
    NSMutableArray* stems = [[NSMutableArray alloc] init];
    [stems addObject:stem];
    for (int i = 0; i < CHAR_THRESHOLD; ++i) {
        unichar c = [stem characterAtIndex:i];
        if (c == ' ') {
            // Add a search for the pipe character
            NSString* prefix = c > 0 ? [stem substringToIndex:i] : @"";
            NSString* postfix = c < stem.length - 1 ? [stem substringFromIndex:i + 1] : @"";
            NSString* pipeStem = [NSString stringWithFormat:@"%@%c%@", prefix, '|', postfix];
            [stems addObject:pipeStem];
        }
    }
    return stems;
}

- (void) dealloc {
    for (TupleRefHandle* tuple in _handles) {
        [tuple.ref removeObserverWithHandle:tuple.handle];
    }
}

- (void) startSearchForStem:(NSString *)stem {
    __weak NameSearch* weakSelf = self;
    NSString* endKey = [stem nextLowerCaseKey];
    FQuery* firstNameQuery = [[_root childByAppendingPath:@"search/firstName"] queryStartingAtPriority:nil andChildName:stem];
    FQuery* lastNameQuery = [[_root childByAppendingPath:@"search/lastName"] queryStartingAtPriority:nil andChildName:stem];
    if (endKey) {
        firstNameQuery = [firstNameQuery queryEndingAtPriority:nil andChildName:endKey];
        lastNameQuery = [lastNameQuery queryEndingAtPriority:nil andChildName:endKey];
    }
    FirebaseHandle handle = [firstNameQuery observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        [weakSelf newFirstNameResult:snapshot];
    }];
    TupleRefHandle* tuple = [[TupleRefHandle alloc] init];
    tuple.ref = firstNameQuery;
    tuple.handle = handle;
    [_handles addObject:tuple];

    handle = [lastNameQuery observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        [weakSelf newLastNameResult:snapshot];
    }];
    tuple = [[TupleRefHandle alloc] init];
    tuple.ref = lastNameQuery;
    tuple.handle = handle;
    [_handles addObject:tuple];
}

- (void) startSearch {
    for (NSString* stem in _stems) {
        [self startSearchForStem:stem];
    }
}

- (void) newFirstNameResult:(FDataSnapshot *)snapshot {
    SearchResult* result = [[SearchResult alloc] init];
    //result.name = snapshot.name;
    result.userId = snapshot.value;
    NSArray* segments = [[snapshot.name stringByReplacingOccurrencesOfString:@"," withString:@"."] componentsSeparatedByString:@"|"];
    result.name = [NSString stringWithFormat:@"%@ %@", [segments objectAtIndex:0], [segments objectAtIndex:1]];
    //result.name = [snapshot.name substringToIndex:(snapshot.name.length - (result.userId.length + 1))];
    [_firstNameResults addObject:result];
    if ([result.name hasPrefix:_term]) {
        [self raiseFilteredResults];
    }
    //[self.delegate resultsDidChange:_firstNameResults];

}

- (void) newLastNameResult:(FDataSnapshot *)snapshot {
    SearchResult* result = [[SearchResult alloc] init];
    result.userId = snapshot.value;
    // need to figure out how to handle this
    NSArray* segments = [[snapshot.name stringByReplacingOccurrencesOfString:@"," withString:@"."] componentsSeparatedByString:@"|"];
    result.name = [NSString stringWithFormat:@"%@, %@", [segments objectAtIndex:0], [segments objectAtIndex:1]];
    [_lastNameResults addObject:result];
    if ([result.name hasPrefix:_term]) {
        [self raiseFilteredResults];
    }
}

- (void) raiseFilteredResults {
    NSMutableArray* results = [[NSMutableArray alloc] init];
    for (SearchResult* result in _firstNameResults) {
        if ([result.name hasPrefix:_term]) {
            [results addObject:result];
        }
    }
    for (SearchResult* result in _lastNameResults) {
        if ([result.name hasPrefix:_term]) {
            [results addObject:result];
        }
    }
    [self.delegate resultsDidChange:results];
}

- (BOOL) containsTerm:(NSString *)term {
    if (term.length < CHAR_THRESHOLD) {
        return NO;
    } else {
        for (NSString* stem in _stems) {
            if ([term hasPrefix:stem]) {
                return YES;
            }
        }
        return NO;
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
    NSString* term = [text lowercaseString];
    if (![term isValidKey]) {
        [self stopSearch];
        return YES;
    } else if (self.currentSearch) {
        // We have a term
        if ([self.currentSearch containsTerm:term]) {
            return [self.currentSearch updateTerm:term];
        } else {
            [self stopSearch];
            return YES;
        }
    } else {
        // No current term. Save this one if it's longer than 3 chars
        [self startSearch:term];
        return NO;
    }
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
