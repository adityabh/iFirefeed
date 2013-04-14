//
//  Firefeed.m
//  iFirefeed
//
//  Created by Greg Soltis on 4/2/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "Firefeed.h"
#import <Firebase/Firebase.h>
#import <FirebaseAuthClient/FirebaseAuthClient.h>
#import "FirefeedAuth.h"
#import "FirefeedSpark.h"

typedef void (^ffbt_void_nserror)(NSError* err);
typedef void (^ffbt_void_nserror_dict)(NSError* err, NSDictionary* dict);

@interface FeedHandlers : NSObject

@property (nonatomic) FirebaseHandle childAddedHandle;
@property (nonatomic) FirebaseHandle childRemovedHandle;
@property (strong, nonatomic) FirefeedUser* user;
@property (strong, nonatomic) Firebase* ref;

@end

@implementation FeedHandlers


@end



@interface Firefeed () <FirefeedUserDelegate>

@property (strong, nonatomic) Firebase* root;
@property (strong, nonatomic) NSMutableDictionary* feeds;
@property (strong, nonatomic) NSMutableArray* users;
@property (strong, nonatomic) NSMutableArray* sparks;
@property (nonatomic) long serverTimeOffset;
@property (nonatomic) FirebaseHandle timeOffsetHandle;
@property (strong, nonatomic) FirefeedUser* loggedInUser;
@property (strong, nonatomic) Firebase* userRef;

@end

@implementation Firefeed


+ (void) logDiagnostics {
    NSLog(@"Running w/ Firebase %@", [Firebase sdkVersion]);
    NSLog(@"Running w/ FirebaseAuthClient %@", [FirebaseAuthClient sdkVersion]);
    NSLog(@"bundle id: %@", [NSBundle mainBundle].bundleIdentifier);
}


- (id) initWithUrl:(NSString *)rootUrl {
    self = [super init];
    if (self) {
        self.root = [[Firebase alloc] initWithUrl:rootUrl];

        __weak Firefeed* weakSelf = self;
        self.timeOffsetHandle = [[self.root childByAppendingPath:@".info/serverTimeOffset"] observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {

            id val = snapshot.value;
            if (val != [NSNull null]) {
                weakSelf.serverTimeOffset = [(NSNumber *)val longValue];
            }
        }];
        self.serverTimeOffset = 0;

        // Auth handled via a global singleton. Prevents modules squashing eachother
        [FirefeedAuth watchAuthForRef:self.root withBlock:^(NSError *error, FAUser *user) {
            if (error) {
                NSLog(@"ERROR: %@", error);
            } else {
                [weakSelf onAuthStatus:user];
            }
        }];
        
        self.feeds = [[NSMutableDictionary alloc] init];
        self.users = [[NSMutableArray alloc] init];
        self.sparks = [[NSMutableArray alloc] init];
    }
    return self;
}


- (void) dealloc {
    [[self.root childByAppendingPath:@".info/serverTimeOffset"] removeObserverWithHandle:_timeOffsetHandle];
}

- (void) cleanup {
    for (NSString* url in self.feeds) {
        FeedHandlers* handle = [self.feeds objectForKey:url];
        [self stopObservingFeed:handle];
    }
    [self.feeds removeAllObjects];
    [self stopObservingLoginStatus];
    [self cleanupUsers];
    [self cleanupSparks];
}

- (void) stopObservingFeed:(FeedHandlers *)handle {
    [handle.ref removeObserverWithHandle:handle.childAddedHandle];
    [handle.ref removeObserverWithHandle:handle.childRemovedHandle];
    if (handle.user) {
        [handle.user stopObserving];
    }
}

- (void) stopObservingLoginStatus {
    if (self.loggedInUser) {
        [self.loggedInUser stopObserving];
        self.loggedInUser = nil;
    }
}

- (void) cleanupUsers {
    for (FirefeedUser* user in self.users) {
        [user stopObserving];
    }
    [self.users removeAllObjects];
}

- (void) cleanupSparks {
    for (FirefeedSpark* spark in self.sparks) {
        [spark stopObserving];
    }
    [self.sparks removeAllObjects];
}

- (void) logListens {
    NSLog(@"Firefeed outstanding observers");
    for (NSString* key in self.feeds) {
        NSLog(@"Feed: %@", key);
    }

    for (FirefeedUser* user in self.users) {
        NSLog(@"User: %@", user);
    }
    if (self.loggedInUser) {
        NSLog(@"logged in user: %@", self.loggedInUser);
    }
    NSLog(@"End outstanding observers");
}

- (BOOL) userIsLoggedInUser:(NSString *)userId {
    return self.loggedInUser && [userId isEqualToString:self.loggedInUser.userId];
}

- (void) login {
    [FirefeedAuth loginRef:self.root toFacebookAppWithId:kFacebookAppId];
}

- (void) logout {
    [FirefeedAuth logoutRef:self.root];
}

- (void) onAuthStatus:(FAUser *)user {
    if (user) {
        // A user is logged in
        NSString* fullName = [user.thirdPartyUserData objectForKey:@"name"];
        NSString* name = [user.thirdPartyUserData objectForKey:@"first_name"];
        self.userRef = [[self.root childByAppendingPath:@"users"] childByAppendingPath:user.userId];
        // We shouldn't get this if we already have a user...
        assert(self.loggedInUser == nil);
        self.loggedInUser = [FirefeedUser loadFromRoot:self.root withUserData:@{@"name": name, @"fullName": fullName, @"userId": user.userId} completionBlock:^(FirefeedUser *user) {
            [user updateFromRoot:self.root];
            self.loggedInUser.delegate = self;
            [self.delegate loginStateDidChange:user];
        }];

    } else {
        if (self.loggedInUser) {
            // TODO: handle this in the auth class
            /*Firebase* peopleRef = [[self.root childByAppendingPath:@"people"] childByAppendingPath:self.loggedInUser.userId];
            Firebase* presenceRef = [peopleRef childByAppendingPath:@"presence"];
            [presenceRef removeValue];
            [presenceRef cancelDisconnectOperations];*/
            [self.loggedInUser stopObserving];
        }
        self.loggedInUser = nil;
        [self.delegate loginStateDidChange:nil];
    }
    
}

- (void) observeFolloweesForUser:(NSString *)userId {
    __weak Firefeed* weakSelf = self;

    [FirefeedUser loadFromRoot:self.root withUserId:userId completionBlock:^(FirefeedUser *followingUser) {
        Firebase* ref = [[[self.root childByAppendingPath:@"users"] childByAppendingPath:userId] childByAppendingPath:@"following"];

        NSString* feedId = ref.description;
        FeedHandlers* handles = [[FeedHandlers alloc] init];
        handles.user = followingUser;
        handles.ref = ref;
        handles.childAddedHandle = [ref observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
            if (weakSelf) {
                NSString* followerId = snapshot.name;
                FirefeedUser* user = [FirefeedUser loadFromRoot:weakSelf.root withUserId:followerId completionBlock:^(FirefeedUser *user) {
                    [weakSelf.delegate follower:followingUser startedFollowing:user];
                }];
                [weakSelf.users addObject:user];
            }
            
        }];

        handles.childRemovedHandle = [ref observeEventType:FEventTypeChildRemoved withBlock:^(FDataSnapshot *snapshot) {
            if (weakSelf) {
                NSString* followerId = snapshot.name;
                FirefeedUser* user = [FirefeedUser loadFromRoot:weakSelf.root withUserId:followerId completionBlock:^(FirefeedUser *user) {
                    [weakSelf.delegate follower:followingUser stoppedFollowing:user];
                }];
                [weakSelf.users addObject:user];
            }
        }];
        [self.feeds setObject:handles forKey:feedId];

    }];
}


- (void) observeFollowersForUser:(NSString *)userId {
    __weak Firefeed* weakSelf = self;
    [FirefeedUser loadFromRoot:self.root withUserId:userId completionBlock:^(FirefeedUser *followedUser) {
        Firebase* ref = [[[self.root childByAppendingPath:@"users"] childByAppendingPath:userId] childByAppendingPath:@"followers"];

        NSString* feedId = ref.description;
        FeedHandlers* handles = [[FeedHandlers alloc] init];
        handles.user = followedUser;
        handles.ref = ref;
        handles.childAddedHandle = [ref observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
            if (weakSelf) {
                NSString* followerId = snapshot.name;
                FirefeedUser* user = [FirefeedUser loadFromRoot:weakSelf.root withUserId:followerId completionBlock:^(FirefeedUser *user) {
                    [weakSelf.delegate follower:user startedFollowing:followedUser];
                }];
                [weakSelf.users addObject:user];
            }

        }];

        handles.childRemovedHandle = [ref observeEventType:FEventTypeChildRemoved withBlock:^(FDataSnapshot *snapshot) {
            if (weakSelf) {
                NSString* followerId = snapshot.name;
                FirefeedUser* user = [FirefeedUser loadFromRoot:weakSelf.root withUserId:followerId completionBlock:^(FirefeedUser *user) {
                    [weakSelf.delegate follower:user stoppedFollowing:followedUser];
                }];
                [weakSelf.users addObject:user];
            }
        }];
        [self.feeds setObject:handles forKey:feedId];
        
    }];
}

- (NSString *) observeFeed:(Firebase *)ref withCount:(NSUInteger)count {
    FQuery* query = [ref queryLimitedToNumberOfChildren:count];

    NSString* feedId = ref.description;
    __weak Firefeed* weakSelf = self;
    FirebaseHandle childAddedHandle = [query observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        if (weakSelf) {
            NSString* sparkId = snapshot.name;

            FirefeedSpark* spark = [FirefeedSpark loadFromRoot:self.root withSparkId:sparkId block:^(FirefeedSpark* spark) {
                
                [weakSelf.delegate spark:spark wasAddedToTimeline:feedId];
            }];
            [weakSelf.sparks addObject:spark];
            /*Firebase* sparkRef = [[self.root childByAppendingPath:@"sparks"] childByAppendingPath:sparkId];

            FeedHandlers* handle = [weakSelf.feeds objectForKey:feedId];
            FirebaseHandle valueHandle = [sparkRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                NSMutableDictionary* spark = [(NSDictionary *)snapshot.value mutableCopy];
                NSString* author = [spark objectForKey:@"author"];
                [spark setObject:[weakSelf picUrlForAuthor:author] forKey:@"pic"];
                [weakSelf.delegate spark:spark wasAddedToTimeline:feedId];
            }];
            [handle.valueHandles setObject:[NSNumber numberWithInt:valueHandle] forKey:sparkRef.description];*/
        }
    }];

    FirebaseHandle childRemovedHandle = [query observeEventType:FEventTypeChildRemoved withBlock:^(FDataSnapshot *snapshot) {

    }];

    FeedHandlers* handlers = [[FeedHandlers alloc] init];
    handlers.ref = ref;
    handlers.childAddedHandle = childAddedHandle;
    handlers.childRemovedHandle = childRemovedHandle;
    [self.feeds setObject:handlers forKey:feedId];
    return feedId;
}


- (void) stopObservingTimeline:(NSString *)timeline {
    FeedHandlers* handlers = [self.feeds objectForKey:timeline];
    if (handlers) {
        [self stopObservingFeed:handlers];
        [self.feeds removeObjectForKey:timeline];
    }
}

- (NSString *) observeSparksForUser:(NSString *)userId {
    Firebase* ref = [[[self.root childByAppendingPath:@"users"] childByAppendingPath:userId] childByAppendingPath:@"sparks"];
    return [self observeFeed:ref withCount:50];
}

- (NSString *) observeLoggedInUserTimeline {
    if (!self.loggedInUser) {
        return nil;
    } else {
        Firebase* ref = [[[self.root childByAppendingPath:@"users"] childByAppendingPath:self.loggedInUser.userId] childByAppendingPath:@"feed"];
        return [self observeFeed:ref withCount:100];
    }
}

- (NSString *) observeLatestSparks {
    Firebase* ref = [self.root childByAppendingPath:@"recent-sparks"];
    return [self observeFeed:ref withCount:50];
}



- (double) currentTimestamp {
    return ([[NSDate date] timeIntervalSince1970] * 1000.0) + self.serverTimeOffset;
}

- (void) postSpark:(NSString *)text completionBlock:(ffbt_void_nserror)block {
    Firebase* sparkRef = [[self.root childByAppendingPath:@"sparks"] childByAutoId];
    NSString* sparkRefId = sparkRef.name;

    NSNumber* ts = [NSNumber numberWithDouble:[self currentTimestamp]];
    NSDictionary* spark = @{@"author": self.loggedInUser.userId, @"by": self.loggedInUser.fullName, @"content": text, @"timestamp": ts};

    ffbt_void_nserror userBlock = [block copy];
    __weak Firefeed* weakSelf = self;
    [sparkRef setValue:spark withCompletionBlock:^(NSError *error) {
        if (error) {
            userBlock(error);
        } else if (weakSelf) {
            // Do fanout
            // Add spark to list of sparks sent by this user
            [[[weakSelf.userRef childByAppendingPath:@"sparks"] childByAppendingPath:sparkRefId] setValue:@YES];

            // Add spark to the user's own feed
            [[[weakSelf.userRef childByAppendingPath:@"feed"] childByAppendingPath:sparkRefId] setValue:@YES];

            // Mark the user as having recently sparked.
            Firebase* recentUsersRef = [weakSelf.root childByAppendingPath:@"recent-users"];
            [[recentUsersRef childByAppendingPath:weakSelf.loggedInUser.userId] setValue:@YES andPriority:ts];

            Firebase* recentSparksRef = [weakSelf.root childByAppendingPath:@"recent-sparks"];
            [[recentSparksRef childByAppendingPath:sparkRefId] setValue:@YES andPriority:ts];

            // fanout to followers
            [[weakSelf.userRef childByAppendingPath:@"followers"] observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                for (FDataSnapshot* childSnap in snapshot.children) {
                    NSString* followerId = childSnap.name;
                    [[[[[weakSelf.root childByAppendingPath:@"users"] childByAppendingPath:followerId] childByAppendingPath:@"feed"] childByAppendingPath:sparkRefId] setValue:@YES];
                }
            }];
            userBlock(nil);
        }
    }];
}

- (void) observeUserInfo:(NSString *)userId {
    __weak Firefeed* weakSelf = self;
    FirefeedUser* user = [FirefeedUser loadFromRoot:weakSelf.root withUserId:userId completionBlock:^(FirefeedUser *user) {
        [weakSelf.delegate userDidUpdate:user];
    }];
    [self.users addObject:user];
}

- (void) startFollowingUser:(NSString *)userId {
    Firebase* userRef = [[self.root childByAppendingPath:@"users"] childByAppendingPath:self.loggedInUser.userId];

    Firebase* followingRef = [[userRef childByAppendingPath:@"following"] childByAppendingPath:userId];
    [followingRef setValue:@YES withCompletionBlock:^(NSError *error) {
        Firebase* followerRef = [[self.root childByAppendingPath:@"users"] childByAppendingPath:userId];

        [[[followerRef childByAppendingPath:@"followers"] childByAppendingPath:self.loggedInUser.userId] setValue:@YES];

        // Now, copy some sparks into our feed
        Firebase* feedRef = [userRef childByAppendingPath:@"feed"];
        [[[followerRef childByAppendingPath:@"sparks"] queryLimitedToNumberOfChildren:25] observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {

            for (FDataSnapshot* childSnap in snapshot.children) {
                [[feedRef childByAppendingPath:childSnap.name] setValue:@YES];
            }
        }];
    }];
}

- (void) stopFollowingUser:(NSString *)userId {
    Firebase* userRef = [[self.root childByAppendingPath:@"users"] childByAppendingPath:self.loggedInUser.userId];

    Firebase* followingRef = [[userRef childByAppendingPath:@"following"] childByAppendingPath:userId];
    [followingRef removeValueWithCompletionBlock:^(NSError *error) {
        Firebase* followerRef = [[self.root childByAppendingPath:@"users"] childByAppendingPath:userId];

        [[[followerRef childByAppendingPath:@"followers"] childByAppendingPath:self.loggedInUser.userId] removeValue];
    }];
}

- (void) saveUser:(FirefeedUser *)user {
    [user updateFromRoot:self.root];
}

- (void) userDidUpdate:(FirefeedUser *)user {
    [self.delegate userDidUpdate:user];
}

@end