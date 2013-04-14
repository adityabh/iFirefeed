//
//  UserCell.h
//  iFirefeed
//
//  Created by Greg Soltis on 4/5/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FirefeedUser.h"

@interface UserCell : UITableViewCell

- (void) configureForUser:(FirefeedUser *)user atRow:(NSInteger)row;
- (void) configureForUser:(FirefeedUser *)user atRow:(NSInteger)row target:(id)target selector:(SEL)selector;

@property (weak, nonatomic) IBOutlet UIImageView *profilePic;
@property (weak, nonatomic) IBOutlet UIButton *profileButton;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UITextView *bioText;

@end
