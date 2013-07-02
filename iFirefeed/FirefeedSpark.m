//
//  FirefeedSpark.m
//  iFirefeed
//
//  Created by Greg Soltis on 4/10/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "FirefeedSpark.h"

@interface FirefeedSpark ()

@property (nonatomic) FirebaseHandle valueHandle;
@property (nonatomic) BOOL loaded;
@property (strong, nonatomic) Firebase* ref;

@end

typedef void (^ffbt_void_ffspark)(FirefeedSpark* spark);

@implementation FirefeedSpark

+ (FirefeedSpark *) loadFromRoot:(Firebase *)root withSparkId:(NSString *)sparkId block:(ffbt_void_ffspark)block {

    ffbt_void_ffspark userBlock = [block copy];
    Firebase* sparkRef = [[root childByAppendingPath:@"sparks"] childByAppendingPath:sparkId];
    return [[FirefeedSpark alloc] initWithRef:sparkRef andBlock:userBlock];
}


- (id) initWithRef:(Firebase *)ref andBlock:(ffbt_void_ffspark)block {
    self = [super init];
    if (self) {
        self.ref = ref;
        // Load the data for this spark from Firebase
        self.valueHandle = [ref observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            id rawVal = snapshot.value;
            if (rawVal == [NSNull null]) {
                block(nil);
            } else {
                NSDictionary* val = rawVal;
                self.authorId = [val objectForKey:@"author"];
                self.authorName = [val objectForKey:@"by"];
                self.content = [val objectForKey:@"content"];
                self.timestamp = [(NSNumber *)[val objectForKey:@"timestamp"] doubleValue];
                block(self);
            }
        }];
    }
    return self;
}

- (NSComparisonResult) compare:(FirefeedSpark *)other {
    // If two sparks have the same id, consider them equivalent
    return [self.ref.name compare:other.ref.name];
}

- (void) stopObserving {
    [self.ref removeObserverWithHandle:self.valueHandle];
}

- (NSURL *) authorPicURL {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture/?return_ssl_resources=1&width=48&height=48", self.authorId]];
}

@end
