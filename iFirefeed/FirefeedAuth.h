//
//  FirefeedAuth.h
//  iFirefeed
//
//  Created by Greg Soltis on 4/8/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FirebaseAuthClient/FirebaseAuthClient.h>

@interface FirefeedAuth : NSObject

+ (long) watchAuthForRef:(Firebase *)ref withBlock:(void (^)(NSError* error, FAUser* user))block;
+ (void) stopWatchingAuthForRef:(Firebase *)ref withHandle:(long)handle;
+ (void) loginRef:(Firebase *)ref toFacebookAppWithId:(NSString *)appId;
+ (void) logoutRef:(Firebase *)ref;

@end
