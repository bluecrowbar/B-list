//
//  GeneralTests.m
//  GeneralTests
//
//  Created by Steven Vandeweghe on 4/22/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import "GeneralTests.h"
#import "BListDocument+Extras.h"

@implementation GeneralTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}


- (void)testAlternativeNames
{
	NSURL *URL1 = [NSURL fileURLWithPath:@"Delhaize.blist"];
	NSURL *URL2 = [NSURL fileURLWithPath:@"Delhaize (1).blist"];
	NSArray *existingURLs = @[URL1];
	NSString *altName = [BListDocument bcb_alternativeNameForProposedName:@"Delhaize" withExistingURLs:existingURLs];
	XCTAssertEqualObjects(altName, @"Delhaize (1)");
	altName = [BListDocument bcb_alternativeNameForProposedName:@"delhaize" withExistingURLs:existingURLs];
	XCTAssertEqualObjects(altName, @"delhaize (1)");
	existingURLs = @[URL1, URL2];
	altName = [BListDocument bcb_alternativeNameForProposedName:@"Delhaize" withExistingURLs:existingURLs];
	XCTAssertEqualObjects(altName, @"Delhaize (2)");
	altName = [BListDocument bcb_alternativeNameForProposedName:@"Delhaize (1)" withExistingURLs:existingURLs];
	XCTAssertEqualObjects(altName, @"Delhaize (2)");
}

@end
