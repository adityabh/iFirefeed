//
//  ProfileEditController.m
//  iFirefeed
//
//  Created by Greg Soltis on 4/8/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "ProfileEditController.h"
#import "ComposeViewController.h"
#import "Firefeed.h"

typedef enum {BIO, LOCATION, NONE} UserProperty;

@interface ProfileEditController () <FirefeedDelegate, ComposeViewControllerDelegate>

@property (strong, nonatomic) Firefeed* firefeed;
@property (strong, nonatomic) FirefeedUser* user;
@property (nonatomic) UserProperty currentlyEditing;

@end

@implementation ProfileEditController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Edit Profile" image:[UIImage imageNamed:@"edit.png"] tag:0];
        self.firefeed = [[Firefeed alloc] initWithUrl:kFirebaseRoot];
        self.firefeed.delegate = self;
        self.currentlyEditing = NONE;
    }
    return self;
}

- (UINavigationItem *) navigationItem {
    UINavigationItem* item = [super navigationItem];
    UIBarButtonItem* logoutBtn = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];
    item.leftBarButtonItem = logoutBtn;
    UILabel* titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100.0f, 44.0f)];
    titleLabel.text = @"Profile";
    titleLabel.textColor = [UIColor colorWithRed:0x7b / 255.0f green:0x5f / 255.0f blue:0x11 / 255.0f alpha:1.0f];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    item.titleView = titleLabel;
    return item;
}

- (void) showLoggedInUI {

    [self.bioEdit setupAsYellowButton];
    [self.locationEdit setupAsYellowButton];
    [self updateUserDetails];
    [self.bioEdit addTarget:self action:@selector(composeBio) forControlEvents:UIControlEventTouchUpInside];
    [self.locationEdit addTarget:self action:@selector(composeLocation) forControlEvents:UIControlEventTouchUpInside];
}


- (void) logout {
    [self.firefeed logout];
}

- (void) updateUserDetails {
    self.bioText.text = self.user.bio;
    self.locationLabel.text = self.user.location;
}

- (void) composeBio {
    ComposeViewController* composer = [[ComposeViewController alloc] init];
    composer.delegate = self;
    self.currentlyEditing = BIO;
    [composer presentFromRootViewControllerWithText:self.user.bio submitButtonTitle:@"Save" headerTitle:@"Edit Bio" characterLimit:141];
}

- (void) composeLocation {
    ComposeViewController* composer = [[ComposeViewController alloc] init];
    composer.delegate = self;
    self.currentlyEditing = LOCATION;
    [composer presentFromRootViewControllerWithText:self.user.location submitButtonTitle:@"Save" headerTitle:@"Edit Location" characterLimit:80];
}

- (void) composeViewController:(ComposeViewController *)composeViewController didFinishWithText:(NSString *)text {

    if (text != nil) {
        if (self.currentlyEditing == BIO) {
            self.user.bio = text;
        } else if (self.currentlyEditing == LOCATION) {
            self.user.location = text;
        }
        [self.firefeed saveUser:self.user];
    }
    [composeViewController dismissViewControllerAnimated:YES completion:nil];
    self.currentlyEditing = NONE;
}

- (void) showLoggedOutUI {
    self.tabBarController.selectedIndex = 2;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    [self showLoggedInUI];
}

- (void) loginStateDidChange:(FirefeedUser *)user {
    if (user) {
        self.user = user;
    } else {
        self.user = nil;
        [self showLoggedOutUI];
    }
}

- (void) userDidUpdate:(FirefeedUser *)user {
    [self updateUserDetails];
}

// No-ops

- (void) spark:(FirefeedSpark *)spark wasAddedToTimeline:(NSString *)timeline {

}

- (void) spark:(FirefeedSpark *)spark wasOverflowedFromTimeline:(NSString *)timeline {

}

- (void) follower:(FirefeedUser *)follower startedFollowing:(FirefeedUser *)followee {

}

- (void) follower:(FirefeedUser *)follower stoppedFollowing:(FirefeedUser *)followee {
    
}

@end
