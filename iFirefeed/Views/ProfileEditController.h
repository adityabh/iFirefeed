//
//  ProfileEditController.h
//  iFirefeed
//
//  Created by Greg Soltis on 4/8/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MOGlassButton.h"

@interface ProfileEditController : UIViewController

@property (weak, nonatomic) IBOutlet MOGlassButton *bioEdit;
@property (weak, nonatomic) IBOutlet MOGlassButton *locationEdit;

@property (weak, nonatomic) IBOutlet UITextView *bioText;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@end
