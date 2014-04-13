//
//  DALViewController.m
//  ObjCParser
//
//  Created by Daniel Leber on 4/12/14.
//  Copyright (c) 2014 Daniel Leber. All rights reserved.
//

#import "DALViewController.h"
#import "DALObjCParser.h"

@interface DALViewController ()

@end

@implementation DALViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	self.statementTextField.returnKeyType = UIReturnKeyGo;
	self.statementTextField.text = [self randomExampleStatement];

	self.textFieldsMemoryAddressLabel.text = [NSString stringWithFormat:@"Text field's memory address: %p", self.statementTextField];
	self.viewsMemoryAddressLabel.text = [NSString stringWithFormat:@"View's memory address: %p", self.view];
	self.contentSubviewMemoryAddressLabel.text = [NSString stringWithFormat:@"Content subview's memory address: %p", self.contentSubview];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - View lifecycle

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	[self.statementTextField becomeFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	NSString *statement = textField.text;
	NSError *error = nil;
	NSInvocation *invocation = [DALObjCParser invocationForStatement:statement error:&error];
	if (error)
	{
		[[[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
	}
	else
	{
		[invocation invoke];
	}
	
	[textField resignFirstResponder];
	
	return NO;
}

- (NSString *)randomExampleStatement
{
	NSArray *statements = @[@"[[[UIAlertView alloc] initWithTitle:@\"Title\" message:@\"Message\" delegate:nil cancelButtonTitle:@\"OK\" otherButtonTitles:nil] show]",
							[NSString stringWithFormat:@"[%p setBackgroundColor:[UIColor blueColor]]", self.contentSubview],
							[NSString stringWithFormat:@"[%p removeFromSuperview]", self.contentSubview],
							[NSString stringWithFormat:@"[%p addSubview:[[UIButton alloc] initWithFrame:{{100, 100}, {50, 30}}]]", self.contentSubview],
							[NSString stringWithFormat:@"[%p addSubview:%p]", self.contentSubview, self.statementTextField]];
	
	NSUInteger index = (arc4random() % [statements count]);
	NSString *statemnt = statements[index];
	
	return statemnt;
}

@end
