//
//  ObjCParserTests.m
//  ObjCParserTests
//
//  Created by Daniel Leber on 4/12/14.
//  Copyright (c) 2014 Daniel Leber. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DALObjCParser.h"

@interface ObjCParserTests : XCTestCase

@end

@implementation ObjCParserTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - Invalid statements

- (void)testUnbalancedBrackets
{
	NSError *error = nil;
	NSInvocation *invocation = [DALObjCParser invocationForStatement:@"[[NSArray new]" error:&error];
	XCTAssertNil(invocation, @"Invocation should be nil. %@", invocation);
	XCTAssert(error, @"Error shouldn't be nil.");
}

#pragma mark - Syntax

- (void)testSingleBrackets
{
	NSError *error = nil;
	NSInvocation *invocation = [DALObjCParser invocationForStatement:@"[NSArray version]" error:&error];
	id target = [invocation target];
	XCTAssertTrue(target, @"Error code: %@; description: %@", @([error code]), [error localizedDescription]);
}

#pragma mark - Objects

- (void)testObjectClass
{
	NSError *error = nil;
	NSInvocation *invocation = [DALObjCParser invocationForStatement:@"[NSArray new]" error:&error];
	id target = [invocation target];
	XCTAssertTrue(target, @"Error code: %@; description: %@", @([error code]), [error localizedDescription]);
}

- (void)testObjectNestedReturnObject
{
	NSError *error = nil;
	NSInvocation *invocation = [DALObjCParser invocationForStatement:@"[[NSArray alloc] init]" error:&error];
	id target = [invocation target];
	XCTAssertTrue(target, @"Error code: %@; description: %@", @([error code]), [error localizedDescription]);
}

- (void)testObjectMemoryAddress
{
	NSObject *anObject = @YES;
	NSString *statement = [NSString stringWithFormat:@"[%p description]", anObject];
	
	NSError *error = nil;
	NSInvocation *invocation = [DALObjCParser invocationForStatement:statement error:&error];
	XCTAssert(invocation, @"Invocation shouldn't be nil.");
	XCTAssertNil(error, @"Error should be nil. %@", error);
	
	[invocation invoke];
	
	NSString *invocationDescription = nil;
	[invocation getReturnValue:&invocationDescription];
	
	NSString *anObjectDescription = [anObject description];
	
	XCTAssert([invocationDescription isEqualToString:anObjectDescription], @"Should be equal:\n%@\n%@", invocationDescription, anObjectDescription);
}

#pragma mark - Parameters

- (void)testParameterNSStringLiteral
{
#warning Implement this.
}

//#warning A UTF8 String literal as a parameter is not yet supported.
//- (void)testParameterUTF8StringLiteral
//{
//#warning Implement this.
//}

//#warning An array literal as a parameter is not yet supported.
//- (void)testParameterArrayLiteral
//{
//#warning Implement this.
//}

//#warning A dictionary literal as a parameter is not yet supported.
//- (void)testParameterDictinaryLiteral
//{
//#warning Implement this.
//}

- (void)testParameterMemoryAddress
{
#warning Implement this.
}

- (void)testParameterPrimitiveNo
{
#warning Implement this.
}

- (void)testParameterPrimitiveYes
{
#warning Implement this.
}

- (void)testParameterPrimitiveNil
{
#warning Implement this.
}

- (void)testParameterPrimitiveInt
{
#warning Implement this.
}

- (void)testParameterPrimitiveFloat
{
#warning Implement this.
}

- (void)testParameterPrimitivePositiveDouble
{
#warning Implement this.
}

- (void)testParameterPrimitiveNegativeDouble
{
#warning Implement this.
}

- (void)testParameterStructCGPoint
{
#warning Implement this.
}

- (void)testParameterStructCGRect
{
#warning Implement this.
}

- (void)testParameterNestedStatement
{
#warning Implement this.
}

//#warning A class as a parameter is not yet supported.
//- (void)testParameterClass
//{
//#warning Implement this.
//}

@end
