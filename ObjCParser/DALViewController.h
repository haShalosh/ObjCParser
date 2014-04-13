//
//  DALViewController.h
//  ObjCParser
//
//  Created by Daniel Leber on 4/12/14.
//  Copyright (c) 2014 Daniel Leber. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DALViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *statementTextField;
@property (weak, nonatomic) IBOutlet UILabel *textFieldsMemoryAddressLabel;

@property (weak, nonatomic) IBOutlet UILabel *viewsMemoryAddressLabel;

@property (weak, nonatomic) IBOutlet UIView *contentSubview;
@property (weak, nonatomic) IBOutlet UILabel *contentSubviewMemoryAddressLabel;


@end
