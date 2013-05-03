//
//  FirefeedAuth.h
//  iFirefeed
//
//  Created by Greg Soltis on 4/8/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FirebaseAuthClient/FirebaseAuthClient.h>

//#define _FB_DEBUG

#ifdef _FB_DEBUG
// debug
#define kFacebookAppId @"321090668014055"
#define kFirebaseRoot @"http://firefeed.fblocal.com:9000"

#else

// Public
#define kFacebookAppId @"104907529680402"
#define kFirebaseRoot @"http://firefeed.firebaseio.com"

#endif

@interface FirefeedAuth : NSObject

+ (long) watchAuthForRef:(Firebase *)ref withBlock:(void (^)(NSError* error, FAUser* user))block;
+ (void) stopWatchingAuthForRef:(Firebase *)ref withHandle:(long)handle;
+ (void) loginRef:(Firebase *)ref toFacebookAppWithId:(NSString *)appId;
+ (void) logoutRef:(Firebase *)ref;

@end
