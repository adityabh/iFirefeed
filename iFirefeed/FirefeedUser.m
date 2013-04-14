//
//  FirefeedUser.m
//  iFirefeed
//
//  Created by Greg Soltis on 4/7/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "FirefeedUser.h"

@interface FirefeedUser ()

@property (nonatomic) FirebaseHandle valueHandle;
@property (nonatomic) BOOL loaded;
@property (strong, nonatomic) Firebase* ref;

@end

@implementation FirefeedUser

typedef void (^ffbt_void_ffuser)(FirefeedUser* user);

+ (FirefeedUser *) loadFromRoot:(Firebase *)root withUserId:(NSString *)userId completionBlock:(void (^)(FirefeedUser *))block {
    return [self loadFromRoot:root withUserData:@{@"userId": userId} completionBlock:block];
}

+ (FirefeedUser *) loadFromRoot:(Firebase *)root withUserData:(NSDictionary *)userData completionBlock:(ffbt_void_ffuser)block {
    ffbt_void_ffuser userBlock = [block copy];
    NSString* userId = [userData objectForKey:@"userId"];
    Firebase* peopleRef = [[root childByAppendingPath:@"people"] childByAppendingPath:userId];

    return [[FirefeedUser alloc] initRef:peopleRef initialData:userData andBlock:userBlock];
}

- (id) initRef:(Firebase *)ref initialData:(NSDictionary *)userData andBlock:(ffbt_void_ffuser)userBlock {
    self = [super init];
    if (self) {
        self.loaded = NO;
        self.userId = ref.name;
        self.bio = [userData objectForKey:@"bio"];
        self.name = [userData objectForKey:@"name"];
        self.fullName = [userData objectForKey:@"fullName"];
        self.location = [userData objectForKey:@"location"];
        self.ref = ref;
        self.valueHandle = [ref observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {

            id val = snapshot.value;
            if (val == [NSNull null]) {
                // First login

            } else {
                NSString* prop = [val objectForKey:@"bio"];
                if (prop) {
                    self.bio = prop;
                }
                prop = [val objectForKey:@"name"];
                if (prop) {
                    self.name = prop;
                }
                prop = [val objectForKey:@"fullName"];
                if (prop) {
                    self.fullName = prop;
                }
                prop = [val objectForKey:@"location"];
                if (prop) {
                    self.location = prop;
                }
            }


            if (self.loaded) {
                // just call the delegate
                [self.delegate userDidUpdate:self];
            } else {
                userBlock(self);
            }
            self.loaded = YES;
        }];
    }
    return self;
}

- (void) stopObserving {
    [_ref removeObserverWithHandle:_valueHandle];
    _valueHandle = NSNotFound;
}


- (void) updateFromRoot:(Firebase *)root {
    Firebase* peopleRef = [[root childByAppendingPath:@"people"] childByAppendingPath:_userId];
    [peopleRef updateChildValues:@{@"bio": _bio, @"name": _name, @"fullName": _fullName, @"location": _location}];
}

- (void) setBio:(NSString *)bio {
    if (!bio) {
        _bio = @"";
    } else {
        _bio = bio;
    }
}

- (void) setName:(NSString *)name {
    if (!name) {
        _name = @"";
    } else {
        _name = name;
    }
}

- (void) setFullName:(NSString *)fullName {
    if (!fullName) {
        _fullName = @"";
    } else {
        _fullName = fullName;
    }
}

- (void) setLocation:(NSString *)location {
    if (!location) {
        _location = @"";
    } else {
        _location = location;
    }
}

- (NSURL *) picUrl {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture/?return_ssl_resources=1&width=96&height=96", self.userId]];
}

- (NSURL *) picURLSmall {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture/?return_ssl_resources=1&width=48&height=48", self.userId]];
}

- (BOOL) isEqual:(id)object {
    return [object isKindOfClass:[self class]] && [self.userId isEqualToString:[object userId]];
}

- (NSString *) description {
    return [NSString stringWithFormat:@"User %@", _userId];
}

@end
