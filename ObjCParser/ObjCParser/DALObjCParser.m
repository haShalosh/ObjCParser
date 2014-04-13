//
//  DALObjCParser.m
//  ObjCParser
//
//  Created by Daniel Leber on 7/9/12.
//	Copyright (c) 2012 Daniel Leber
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "DALObjCParser.h"
#import <objc/runtime.h>

NSString *const DALObjCParserErrorDomain = @"com.danielleber.DALObjCParser";

@interface DALObjCParser ()

@property (nonatomic, strong) NSString *statement;
- (NSInvocation *)invocationWithError:(NSError **)error;

@property (nonatomic, strong) NSCharacterSet *squareBracketInverseCharacterSet;
@property (nonatomic, strong) NSCharacterSet *curlyBraceInverseCharacterSet;
@property (nonatomic, strong) NSCharacterSet *classNameCharacterSet;
@property (nonatomic, strong) NSCharacterSet *hexadecimalCharacterSet;
@property (nonatomic, strong) NSCharacterSet *methodNameCharacterSet;
@property (nonatomic, strong) NSCharacterSet *parameterObjectCharacterSet;
@property (nonatomic, strong) NSCharacterSet *stringCharacterSet;
@property (nonatomic, strong) NSCharacterSet *whitespaceCharacterSet;

@end

@implementation DALObjCParser

#pragma mark - Public

+ (NSInvocation *)invocationForStatement:(NSString *)statement error:(NSError *__autoreleasing *)error
{
	NSInvocation *invocation = nil;
	
	DALObjCParser *parser = [[DALObjCParser alloc] initWithStatement:statement];
	invocation = [parser invocationWithError:error];
	
	return invocation;
}

#pragma mark - Object lifecycle

- (id)initWithStatement:(NSString *)statement
{
	self = [super init];
	if (self)
	{
		_statement = statement;
	}
	return self;
}

#pragma mark - Parsing

- (NSInvocation *)invocationWithError:(NSError *__autoreleasing *)error
{
	// Invocation to create and return
	NSInvocation *invocation = nil;
	NSError *returnError = nil;
	
	// Scan statement
	NSString *statement = self.statement;
	NSScanner *scanner = [NSScanner scannerWithString:statement];
	while (scanner.scanLocation < statement.length)
	{
		// Setup
		Class theClass = nil;
		id theObject = nil;
		SEL theSelector = nil;
		
		NSString *tempString = nil;
		
		// Beginning of Method, open square bracket '['
		if ([scanner scanUpToString:@"[" intoString:NULL])
		{
			scanner.scanLocation++;
		}
		else if ([scanner scanString:@"[" intoString:NULL])
		{
			// do nothing...
		}
		else
		{
			NSString *errorString = [NSString stringWithFormat:@"Expected '[' at index: %d, but found: %@", scanner.scanLocation, [statement substringWithRange:NSMakeRange(scanner.scanLocation, 1)]];
			returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
											  code:DALObjCParserErrorStartingOpenBracketNotFound
										  userInfo:@{NSLocalizedDescriptionKey: errorString}];
			NSLog(@"Error! %@", errorString);
			break;
		}
		
		[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
		tempString = nil;
		
		// Memory address
		if ([scanner scanString:@"0x" intoString:NULL])
		{
			NSString *memAddress = nil;
			[scanner scanCharactersFromSet:self.hexadecimalCharacterSet intoString:&memAddress];
			
			theObject = [self objectForMemoryAddress:memAddress];
		}
		// Nested method, open square bracket '['
		else if ([scanner scanString:@"[" intoString:&tempString])
		{
			// Range of sub statement
			scanner.scanLocation--;
			NSRange subStatementRange = [self rangeOfStatementInString:[statement substringFromIndex:(scanner.scanLocation)]];
			
			// Set scanner location past sub statement
			scanner.scanLocation += subStatementRange.length;
			
			// Sub statement string
			NSString *subStatement = [statement substringWithRange:subStatementRange];
			
			// Parse sub statement
			NSError *objectError = nil;
			NSInvocation *objectInvocation = [[self class] invocationForStatement:subStatement error:&objectError];
			if (objectInvocation)
			{
				[objectInvocation invoke];
				
				NSString *methodReturnType = @([[objectInvocation methodSignature] methodReturnType]);
				if ([methodReturnType isEqualToString:[NSString stringWithFormat:@"%c", _C_ID]])
				{
					[objectInvocation getReturnValue:&theObject];
				}
			}
			// Error, unable to parse statement
			else
			{
				returnError = objectError;
				break;
			}
		}
		// Class name
		else if ([scanner scanCharactersFromSet:self.classNameCharacterSet intoString:&tempString])
		{
			// Class
			theClass = NSClassFromString(tempString);
			if (theClass)
			{
				tempString = nil;
			}
			// Error, name is not a valid class
			else
			{
				NSString *errorString = [NSString stringWithFormat:@"Invalid class name at index %d: %@", scanner.scanLocation, tempString];
				returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
												  code:DALObjCParserErrorClassNameInvalid
											  userInfo:@{NSLocalizedDescriptionKey: errorString}];
				NSLog(@"Error! %@", errorString);
				break;
			}
		}
		// Error, missing open square bracket
		else
		{
			NSString *errorString = [NSString stringWithFormat:@"Expected class name at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
			returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
											  code:DALObjCParserErrorClassNameNotFound
										  userInfo:@{NSLocalizedDescriptionKey: errorString}];
			NSLog(@"Error! %@", errorString);
			break;
		}
		
		// Method name setup
		NSUInteger capacity = (statement.length - scanner.scanLocation);
		NSMutableString *selectorName = [NSMutableString stringWithCapacity:capacity];
		int numberOfMethodParameters = 0; // Used for parsing parameter objects
		
		NSUInteger methodNameScanLocation = scanner.scanLocation;
		BOOL isParsingMethodName = YES; // Set to NO when done
		
		// Parse method name
		while (isParsingMethodName && scanner.scanLocation < statement.length)
		{
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			tempString = nil;
			
			// Method name
			if ([scanner scanCharactersFromSet:self.methodNameCharacterSet intoString:&tempString])
			{
				[selectorName appendString:tempString];
				
				[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
				tempString = nil;
				
				// Parameter separator ':'
				if ([scanner scanString:@":" intoString:&tempString])
				{
					numberOfMethodParameters++;
					
					[selectorName appendString:tempString];
					
					[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
					tempString = nil;
					
					// Parameter object name
					if ([scanner scanString:@"@" intoString:NULL])
					{
						BOOL numberOfNonEscapedQuotations = 0;
						while (numberOfNonEscapedQuotations < 2)
						{
							[scanner scanUpToString:@"\"" intoString:NULL];
							[scanner scanString:@"\"" intoString:NULL];
							
							NSString *quotationPreviousCharacter = [statement substringWithRange:NSMakeRange(scanner.scanLocation - 2, 1)];
							// TODO: Implement checking whether this backslash '\' is already escaped
							if ([quotationPreviousCharacter isEqualToString:@"\\"] == NO)
							{
								numberOfNonEscapedQuotations++;
							}
						}
					}
					else if ([scanner scanCharactersFromSet:self.parameterObjectCharacterSet intoString:NULL])
					{
						// Do nothing...
					}
					// Parameter is struct
					else if ([scanner scanString:@"{" intoString:&tempString])
					{
						// Scan past command
						scanner.scanLocation--;
						scanner.scanLocation += [self rangeOfStructInString:[statement substringFromIndex:(scanner.scanLocation)]].length;
					}
					// Parameter is command
					else if ([scanner scanString:@"[" intoString:&tempString])
					{
						// Scan past command
						scanner.scanLocation--;
						scanner.scanLocation += [self rangeOfStatementInString:[statement substringFromIndex:(scanner.scanLocation)]].length;
					}
					// Error, no valid parameter
					else
					{
						NSString *errorString = [NSString stringWithFormat:@"Selector parameter #%d missing at statement index %d", numberOfMethodParameters, scanner.scanLocation];
						returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
														  code:DALObjCParserErrorParameterNotFound
													  userInfo:@{NSLocalizedDescriptionKey: errorString}];
						NSLog(@"Error! %@", errorString);
						break;
					}
				}
			}
			// Error, no method name
			else
			{
				NSString *errorString = [NSString stringWithFormat:@"Expected method name at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
				returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
												  code:DALObjCParserErrorMethodNameNotFound
											  userInfo:@{NSLocalizedDescriptionKey: errorString}];
				NSLog(@"Error! %@", errorString);
				break;
			}
			
			// End of method, closing square bracket ']'
			if ([scanner scanString:@"]" intoString:NULL])
			{
				scanner.scanLocation--;
				isParsingMethodName = NO;
			}
		}
		
		// Error while parsing method name
		if (isParsingMethodName)
			break;
		
		// Method selector
		theSelector = NSSelectorFromString(selectorName);
		selectorName = nil;
		
		// Create invocation from class
		if (theClass)
		{
			// Error, class doesn't respond to selector
			if ([theClass respondsToSelector:theSelector] == NO)
			{
				NSString *errorString = [NSString stringWithFormat:@"Class '%@' doesn't respond to selector: %@", NSStringFromClass(theClass), NSStringFromSelector(theSelector)];
				returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
												  code:	DALObjCParserErrorClassDoesNotRespondToSelector
											  userInfo:@{NSLocalizedDescriptionKey: errorString}];
				NSLog(@"Error! %@", errorString);
				break;
			}
			
			NSMethodSignature *methodSignature = [theClass methodSignatureForSelector:theSelector];
			invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
			invocation.target = theClass;
			invocation.selector = theSelector;
		}
		// Create invocation from object
		else if (theObject)
		{
			// Error, object doesn't respond to selector
			if ([theObject respondsToSelector:theSelector] == NO)
			{
				NSString *errorString = [NSString stringWithFormat:@"Instance of '%@' doesn't respond to selector: %@", NSStringFromClass([theObject class]), NSStringFromSelector(theSelector)];
				returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
												  code:	DALObjCParserErrorInstanceDoesNotRespondToSelector
											  userInfo:@{NSLocalizedDescriptionKey: errorString}];
				NSLog(@"Error! %@", errorString);
				break;
			}
			
			NSMethodSignature *methodSignature = [theObject methodSignatureForSelector:theSelector];
			invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
			invocation.target = theObject;
			invocation.selector = theSelector;
			[invocation retainArguments];
		}
		// Error, no class or object
		else
		{
			NSLog(@"Error! Unable to create invocation!");
			break;
		}
		
		// Method parameters
		if (numberOfMethodParameters)
		{
			scanner.scanLocation = methodNameScanLocation;
		}
		
		// Iterate through selector parameters
		for (int index = 2; (index - 2) < numberOfMethodParameters; index++)
		{
			// Method name, ignore
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			[scanner scanCharactersFromSet:self.methodNameCharacterSet intoString:NULL];
			
			// Parameter separator ':', ignore
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			[scanner scanString:@":" intoString:NULL];
			
			[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
			tempString = nil;
			
			// Parameter
			// String
			if ([scanner scanString:@"@" intoString:NULL])
			{
				[scanner scanString:@"\"" intoString:NULL];
				
				// TODO: Implement supporting backslash '\' encoded characters
				NSMutableString *stringContents = [[NSMutableString alloc] initWithCapacity:(statement.length - scanner.scanLocation)];
				BOOL isScanningParameterString = YES;
				while (isScanningParameterString && scanner.scanLocation < statement.length)
				{
					tempString = nil;
					[scanner scanUpToString:@"\"" intoString:&tempString];
					[stringContents appendString:tempString];
					
					NSString *quotationPreviousCharacter = [statement substringWithRange:NSMakeRange(scanner.scanLocation - 2, 1)];
					// TODO: Implement checking whether this backslash '\' is already escaped
					if ([quotationPreviousCharacter isEqualToString:@"\\"])
					{
						tempString = nil;
						[scanner scanString:@"\"" intoString:&tempString];
						[stringContents appendString:tempString];
					}
					else
					{
						[scanner scanString:@"\"" intoString:NULL];
						isScanningParameterString = NO;
					}
				}
				
				NSString *argument = [NSString stringWithString:stringContents];
				
				[invocation setArgument:&argument atIndex:index];
			}
			// Memory address
			else if ([scanner scanString:@"0x" intoString:NULL])
			{
				NSString *memAddress = nil;
				[scanner scanCharactersFromSet:self.hexadecimalCharacterSet intoString:&memAddress];
				
				id argument = [self objectForMemoryAddress:memAddress];
				[invocation setArgument:&argument atIndex:index];
			}
			// Primitive type
			else if ([scanner scanCharactersFromSet:self.parameterObjectCharacterSet intoString:&tempString])
			{
				const char *parameterType = nil;
				
				NSString *compareString = [tempString uppercaseString];
				if ([compareString isEqualToString:@"NO"])
				{
					parameterType = [[NSString stringWithFormat:@"%c", _C_BOOL] UTF8String];
					BOOL parameterValue = YES;
					[invocation setArgument:&parameterValue atIndex:index];
				}
				else if ([compareString isEqualToString:@"YES"])
				{
					parameterType = [[NSString stringWithFormat:@"%c", _C_BOOL] UTF8String];
					BOOL parameterValue = YES;
					[invocation setArgument:&parameterValue atIndex:index];
				}
				else if ([compareString isEqualToString:@"NIL"])
				{
					parameterType = [[NSString stringWithFormat:@"%c", _C_VOID] UTF8String];
					void *parameterValue = nil;
					[invocation setArgument:&parameterValue atIndex:index];
				}
				else
				{
					NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
					NSNumber *stringNumber = [numberFormatter numberFromString:tempString];
					
					if (stringNumber)
					{
						BOOL isNegative = NO;
						BOOL hasDecimal = NO;
						
						if ([[tempString substringWithRange:NSMakeRange(0, 1)] isEqualToString:@"-"])
							isNegative = YES;
						
						if ([tempString rangeOfString:@"."].location != NSNotFound)
							hasDecimal = YES;
						
						if (hasDecimal)
						{
							parameterType = [[NSString stringWithFormat:@"%c", _C_FLT] UTF8String];
							float parameterValue = [stringNumber floatValue];
							[invocation setArgument:&parameterValue atIndex:index];
						}
						else
						{
							if (isNegative)
							{
								parameterType = [[NSString stringWithFormat:@"%c", _C_LNG_LNG] UTF8String];
								long long parameterValue = [stringNumber longLongValue];
								[invocation setArgument:&parameterValue atIndex:index];
							}
							else
							{
								parameterType = [[NSString stringWithFormat:@"%c", _C_ULNG_LNG] UTF8String];
								unsigned long long parameterValue = [stringNumber unsignedLongLongValue];
								[invocation setArgument:&parameterValue atIndex:index];
							}
						}
					}
				}
				
				if (parameterType == nil)
				{
					NSString *errorString = [NSString stringWithFormat:@"Unknown parameter at index %d: %@", (index - 2), tempString];
					returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
													  code:DALObjCParserErrorParameterTypeUnknown
												  userInfo:@{NSLocalizedDescriptionKey: errorString}];
					NSLog(@"Error! %@", errorString);
					break;
				}
			}
			// Struct
			else if ([scanner scanString:@"{" intoString:&tempString])
			{
				NSInteger numberOfCurlyBracePairs = 0;
				
				// Range of sub statement
				scanner.scanLocation--;
				NSRange subStatementRange = [self rangeOfStructInString:[statement substringFromIndex:(scanner.scanLocation)] numberOfCurlyBracePairs:&numberOfCurlyBracePairs];
				subStatementRange.location = scanner.scanLocation;
				
				// Set scanner location past sub statement
				scanner.scanLocation += subStatementRange.length;
				
				// Sub statement string
				NSString *subStatement = [statement substringWithRange:subStatementRange];
				
				switch (numberOfCurlyBracePairs)
				{
					case 1:
					{
						CGPoint point = CGPointFromString(subStatement);
						[invocation setArgument:&point atIndex:index];
						break;
					}
					case 3:
					{
						CGRect rect = CGRectFromString(subStatement);
						[invocation setArgument:&rect atIndex:index];
						break;
					}
						
					default:
					{
						NSString *errorString = [NSString stringWithFormat:@"Struct '%@' does not conform to a CGPoint/CGSize or CGRect", subStatement];
						returnError = [NSError errorWithDomain:@"com.thedanielleber.DLStamementParser"
														  code:DALObjCParserErrorParameterIsInvalidStruct
													  userInfo:@{NSLocalizedDescriptionKey: errorString}];
						NSLog(@"Error! %@", errorString);
						break;
					}
				}
			}
			// Command
			else if ([scanner scanString:@"[" intoString:&tempString])
			{
				// Range of sub statement
				scanner.scanLocation--;
				NSRange subStatementRange = [self rangeOfStatementInString:[statement substringFromIndex:(scanner.scanLocation)]];
				subStatementRange.location = scanner.scanLocation;
				
				// Set scanner location past sub statement
				scanner.scanLocation += subStatementRange.length;
				
				// Sub statement string
				NSString *subStatement = [statement substringWithRange:subStatementRange];
				
				NSError *parameterError = nil;
				NSInvocation *parameterInvocation = [[self class] invocationForStatement:subStatement error:&parameterError];
				if (parameterInvocation)
				{
					[parameterInvocation invoke];
					
					void *parameterReturnValue = nil;
					[parameterInvocation getReturnValue:&parameterReturnValue];
					
					NSString *parameterReturnType = @([[parameterInvocation methodSignature] methodReturnType]);
					NSString *theInvocationArgumentType = @([[invocation methodSignature] getArgumentTypeAtIndex:index]);
					if ([parameterReturnType isEqualToString:theInvocationArgumentType])
					{
						[invocation setArgument:&parameterReturnValue atIndex:index];
					}
					else
					{
						NSString *errorString = [NSString stringWithFormat:@"Selector parameter %d command at statement index %d return type '%@' different from selector argument type '%@'. Command: %@", index, scanner.scanLocation, parameterReturnType, theInvocationArgumentType, subStatement];
						returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
														  code:DALObjCParserErrorParameterReturnValueDifferentFromSelectorArgumentValue
													  userInfo:@{NSLocalizedDescriptionKey: errorString}];
						NSLog(@"Error! %@", errorString);
						break;
					}
				}
				else
				{
					returnError = parameterError;
					break;
				}
			}
			// Error, no valid parameter
			else
			{
				NSString *errorString = [NSString stringWithFormat:@"Expected parameter at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
				returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
												  code:DALObjCParserErrorParameterNotFound
											  userInfo:@{NSLocalizedDescriptionKey: errorString}];
				NSLog(@"Error! %@", errorString);
				break;
			}
		}
		
		// Error parsing parameters
		if (numberOfMethodParameters == NSUIntegerMax || returnError)
			break;
		
		// End of command, close square bracket ']'
		if ([scanner scanString:@"]" intoString:NULL] == NO)
		{
			NSString *errorString = [NSString stringWithFormat:@"Expected ']' at index %d, but found: %@", scanner.scanLocation, [statement substringFromIndex:scanner.scanLocation]];
			returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
											  code:DALObjCParserErrorClosingCloseBracketNotFound
										  userInfo:@{NSLocalizedDescriptionKey: errorString}];
			NSLog(@"Error! %@", errorString);
			break;
		}
		
		if (returnError)
			break;
		
		[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
		
		// TODO: implement parsing multiple commands
		if ([scanner scanString:@";" intoString:NULL])
		{
		}
		
		// Finish scanning through remainder of statement
		[scanner scanCharactersFromSet:self.whitespaceCharacterSet intoString:NULL];
	}
	
	// Error
	if (returnError)
	{
		// Don't return the invocation if there was an error
		invocation = nil;
		
		// Set error pointer
		if (error != NULL)
		{
			*error = returnError;
		}
	}
	else if (invocation == nil && error != NULL)
	{
		NSString *errorString = [NSString stringWithFormat:@"Unknown error occured parsing: %@", statement];
		returnError = [NSError errorWithDomain:DALObjCParserErrorDomain
										  code:DALObjCParserErrorUnknown
									  userInfo:@{NSLocalizedDescriptionKey: errorString}];
		NSLog(@"Error! %@", errorString);
		
		*error = returnError;
	}
	
	// Return status of parsing statement
	return invocation;
}

#pragma mark - Ranges

- (NSRange)rangeOfStatementInString:(NSString *)string
{
	int numberOfBracketsOpen = 0;
	NSRange range = NSMakeRange(NSUIntegerMax, 0);
	
	NSScanner *scanner = [NSScanner scannerWithString:string];
	while (scanner.scanLocation < string.length)
	{
		if ([scanner scanString:@"[" intoString:NULL])
		{
			if (range.location == NSUIntegerMax)
				range.location = scanner.scanLocation;
			
			numberOfBracketsOpen++;
		}
		else if ([scanner scanString:@"]" intoString:NULL])
		{
			numberOfBracketsOpen--;
			
			if (numberOfBracketsOpen == 0)
			{
				range.length = scanner.scanLocation;
				break;
			}
		}
		else
		{
			[scanner scanCharactersFromSet:self.squareBracketInverseCharacterSet intoString:NULL];
		}
	}
	
	// The end of the string was reached without closing all of the brackets opened
	if (numberOfBracketsOpen > 0)
	{
		range.location = 0;
		range.length = 0;
	}
	
	return range;
}

- (NSRange)rangeOfStructInString:(NSString *)string
{
	return [self rangeOfStructInString:string numberOfCurlyBracePairs:NULL];
}

- (NSRange)rangeOfStructInString:(NSString *)string numberOfCurlyBracePairs:(NSInteger *)numberOfCurlyBracePairs
{
	NSInteger curlyBracePairs = 0;
	
	int numberOfOpenCurlyBracePairs = 0;
	NSRange range = NSMakeRange(NSUIntegerMax, 0);
	
	NSScanner *scanner = [NSScanner scannerWithString:string];
	while (scanner.scanLocation < string.length)
	{
		if ([scanner scanString:@"{" intoString:NULL])
		{
			if (range.location == NSUIntegerMax)
				range.location = scanner.scanLocation;
			
			numberOfOpenCurlyBracePairs++;
		}
		else if ([scanner scanString:@"}" intoString:NULL])
		{
			if (numberOfOpenCurlyBracePairs)
				curlyBracePairs++;
			
			numberOfOpenCurlyBracePairs--;
			
			if (numberOfOpenCurlyBracePairs == 0)
			{
				range.length = scanner.scanLocation;
				break;
			}
		}
		else
		{
			[scanner scanCharactersFromSet:self.curlyBraceInverseCharacterSet intoString:NULL];
		}
	}
	
	// The end of the string was reached without closing all of the curly brackets opened
	if (numberOfOpenCurlyBracePairs > 0)
	{
		range.location = 0;
		range.length = 0;
		curlyBracePairs = 0;
	}
	
	if (numberOfCurlyBracePairs != NULL)
		*numberOfCurlyBracePairs = curlyBracePairs;
	
	return range;
}

- (id)objectForMemoryAddress:(NSString *)memoryAddress
{
	id theObject = nil;
	
	unsigned addr = 0;
	NSScanner *scanner = [NSScanner scannerWithString:memoryAddress];
	[scanner scanHexInt:&addr];
	theObject = (__bridge id)((void *)addr);
	
	return theObject;
}

#pragma mark - Character sets

- (NSCharacterSet *)squareBracketInverseCharacterSet
{
	if (_squareBracketInverseCharacterSet == nil)
	{
		_squareBracketInverseCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"[]"] invertedSet];
	}
	return _squareBracketInverseCharacterSet;
}

- (NSCharacterSet *)curlyBraceInverseCharacterSet
{
	if (_curlyBraceInverseCharacterSet == nil)
	{
		_curlyBraceInverseCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"{}"] invertedSet];
	}
	return _curlyBraceInverseCharacterSet;
}

- (NSCharacterSet *)classNameCharacterSet
{
	if (_classNameCharacterSet == nil)
	{
		_classNameCharacterSet = [NSCharacterSet alphanumericCharacterSet];
	}
	return _classNameCharacterSet;
}

- (NSCharacterSet *)hexadecimalCharacterSet
{
	if (_hexadecimalCharacterSet == nil)
	{
		_hexadecimalCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
	}
	return _hexadecimalCharacterSet;
}

- (NSCharacterSet *)methodNameCharacterSet
{
	if (_methodNameCharacterSet == nil)
	{
		_methodNameCharacterSet = [self.classNameCharacterSet copy];
	}
	return _methodNameCharacterSet;
}

- (NSCharacterSet *)parameterObjectCharacterSet
{
	if (_parameterObjectCharacterSet == nil)
	{
		NSMutableCharacterSet *parameterObjectCharacterSet = [NSMutableCharacterSet alphanumericCharacterSet];
		[parameterObjectCharacterSet addCharactersInString:@".-"];
		_parameterObjectCharacterSet = parameterObjectCharacterSet;
	}
	return _parameterObjectCharacterSet;
}

- (NSCharacterSet *)stringCharacterSet
{
	if (_stringCharacterSet == nil)
	{
		_stringCharacterSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"\"\\"];
	}
	return _stringCharacterSet;
}

- (NSCharacterSet *)whitespaceCharacterSet
{
	if (_whitespaceCharacterSet == nil)
	{
		_whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	}
	return _whitespaceCharacterSet;
}

@end
