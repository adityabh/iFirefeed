//
//  UserCell.m
//  iFirefeed
//
//  Created by Greg Soltis on 4/5/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "UserCell.h"
#import "UIImageView+WebCache.h"

@implementation UserCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void) configureForUser:(FirefeedUser *)user atRow:(NSInteger)row {
    [self configureForUser:user atRow:row target:nil selector:nil];
}

- (void) configureForUser:(FirefeedUser *)user atRow:(NSInteger)row target:(id)target selector:(SEL)selector {

    self.nameLabel.text = user.fullName;
    [self.profilePic setImageWithURL:user.picURLSmall placeholderImage:[UIImage imageNamed:@"placekitten.png"]];
    self.bioText.contentOffset = CGPointZero;
    self.bioText.contentInset = UIEdgeInsetsMake(-10, -5, -5, -5);
    self.bioText.text = user.bio;
    self.profileButton.tag = row;
    if (target && selector) {
        [self.profileButton addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
    }
}

@end
