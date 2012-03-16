//
//  CGLGeoDataProviderGoogle.m
//  CoreGeoLocation
//
//  Created by Karl Adam on 09.09.15.
//  Copyright 2009 Yahoo. All rights reserved.
//

#import "CGLGeoDataProviderGoogle.h"
#import "CGLGeoRequest.h"
#import "CGLGeoLocation.h"
#import "CGLURLRequestLoader.h"

#import "CGLXML.h"
#import "NSString+CGLURLLoadingAdditions.h"

#import <libxml/parser.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>


@interface CGLGeoDataProviderGoogle ()
@property (nonatomic, readwrite, retain) NSMutableDictionary *requestsMapping;

- (CGLGeoLocation *)_geoLocationFromXML:(NSString *)inXMLString;
@end


@implementation CGLGeoDataProviderGoogle

- (id)init {
	if (self = [super init]) {
		self.requestsMapping = [NSMutableDictionary dictionaryWithCapacity:15];
	}
	return self;
}

- (oneway void)dealloc {
	self.apiKey = nil;
	self.requestsMapping = nil;
	
	[super dealloc];
}

@synthesize apiKey = apiKey_;
@synthesize requestsMapping = requestsMapping_;

#pragma mark -

- (BOOL)canHandleRequest:(CGLGeoRequest *)inRequest {
	BOOL canHandleRequest = NO;
	
	
	if ([self.apiKey length]) {
		canHandleRequest = [super canHandleRequest:inRequest];
	}
	
	return canHandleRequest;
}

- (void)performRequest:(CGLGeoRequest *)inRequest {
	NSString *query = nil;
    NSString *firstParam = nil;
	if ([inRequest address]) {
		query = [inRequest address];
        firstParam = [NSString stringWithString:@"address"];
	} else if ([inRequest location]) {
		CLLocationCoordinate2D coordinate = [[inRequest location] coordinate];
		query = [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude];
        firstParam = [NSString stringWithString:@"latlng"];
	}
	
	if (query) {
		NSMutableString *urlString = [NSMutableString stringWithString:@"http://maps.googleapis.com/maps/api/geocode/json?"];
		
		[urlString appendFormat:@"%@=%@&", firstParam, [query cglEscapedURLEncodedString]];
		[urlString appendString:@"sensor=true&oe=utf-8"];
        NSLog(@"urlString: %@", urlString);
		
		NSURLRequest *loadRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
		
		[CGLURLRequestLoader loaderWithRequest:loadRequest target:self action:@selector(loader:loadedData:usingEncoding:)];
		[self.requestsMapping setObject:inRequest forKey:loadRequest];
	}
}

- (void)loader:(CGLURLRequestLoader *)inLoader loadedData:(NSData *)inData usingEncoding:(NSStringEncoding)inEncoding {
	CGLGeoLocation *geoLocation = nil;
	NSString *responseString = [[NSString alloc] initWithData:inData encoding:inEncoding];
	
	if (responseString) {
		NSLog(@"responseString: %@", responseString);
		geoLocation = [self _geoLocationFromJSON:responseString];
	}
	
	[self.delegate geoLocation:geoLocation determinedForRequest:[self.requestsMapping objectForKey:[inLoader urlRequest]]];
	[self.requestsMapping removeObjectForKey:[inLoader urlRequest]];
	
	[responseString release];
}

- (CGLGeoLocation *)_geoLocationFromJSON:(NSString *)inJSONString {
	CGLGeoLocation *geoLocation = nil;
	
	if ([inJSONString length]) {
		
		NSString *address = nil;
		NSString *city = nil;
		NSString *state = nil;
		NSString *zip = nil;
		NSString *country = nil;
		NSString *latitude = nil;
		NSString *longitude = nil;
        
        // Create new SBJSON parser object
        SBJsonParser *parser = [[[SBJsonParser alloc] init] autorelease];
        
        // http://maps.googleapis.com/maps/api/geocode/json?latlng=40.714224,-73.961452&sensor=true_or_false
        
        // parse the JSON response into an object
        // Here we're using NSArray since we're parsing an array of JSON status objects
        NSDictionary *data = (NSDictionary *) [parser objectWithString:inJSONString error:nil];
                
        NSArray *results = (NSArray *) [data objectForKey:@"results"];
        
        for (NSDictionary *result in results) {
            //NSLog(@"test: %@", [test description]);
            NSArray *address_components = (NSArray *) [result objectForKey:@"address_components"];
            
            for (NSDictionary *address_component in address_components) {
                NSDictionary *types = [address_component objectForKey:@"types"];
                NSLog(@"types: %@", [types description]);
                for (NSString *type in types) {
                    NSLog(@"type: %@", type);
                    if ([type isEqualToString: @"postal_code"]) {
                        zip = [address_component objectForKey:@"long_name"];
                        NSLog(@"postal code: %@", zip);
                    }
                    if ([type isEqualToString: @"locality"]) {
                        city = [address_component objectForKey:@"long_name"];
                        NSLog(@"city: %@", city);
                    }
                    if ([type isEqualToString: @"administrative_area_level_1"]) {
                        state = [address_component objectForKey:@"short_name"];
                        NSLog(@"state: %@", state);
                    }
                    if ([type isEqualToString: @"country"]) {
                        country = [address_component objectForKey:@"short_name"];
                        NSLog(@"country: %@", country);
                    }
                }
            }
            
            // the full address will be the first address
            if (address==nil) {
                address = [result objectForKey:@"formatted_address"];
            }
        }
        
       /* NSArray *address_components = (NSArray *) [results objectForKey:@"address_components"];
        
        for (NSDictionary *address_component in address_components) {
            NSDictionary *types = [address_component objectForKey:@"types"];
            NSLog(@"descripton: %@", [types description]);
            for (NSString *type in types) {
                NSLog(@"type: %@", type);
                if ([type isEqualToString: @"postal_code"]) {
                    zip = [address_component objectForKey:@"long_name"];
                    NSLog(@"postal code: %@", zip);
                }
            }
        }*/
			
            /*
			address = [NSString stringWithUTF8String:(const char *)xmlNodeGetContent(nameNode)];
			city = [NSString stringWithUTF8String:(const char *)xmlNodeGetContent(localityNameNode)];
			state = [NSString stringWithUTF8String:(const char *)xmlNodeGetContent(administrativeAreaNameNode)];
			zip = [NSString stringWithUTF8String:(const char *)xmlNodeGetContent(postalCodeNumberNode)];
			country = [NSString stringWithUTF8String:(const char *)xmlNodeGetContent(countryNameNode)];
             */
        
        //NSString *coordinates = [NSString stringWithUTF8String:(const char *)xmlNodeGetContent(coordinateNode)];
        //NSArray *coordinateParts = [coordinates componentsSeparatedByString:@","];
        //latitude = [coordinateParts objectAtIndex:0];
        //longitude = [coordinateParts objectAtIndex:1];
        
        // for reversing the address in to lat and long
        //if (latitude && longitude) {
        CLLocation *location = [[CLLocation alloc] initWithLatitude:[latitude doubleValue] longitude:[longitude doubleValue]];
        geoLocation = [[[CGLGeoLocation alloc] initWithAddress:address city:city state:state zip:zip country:country andCoreLocation:location] autorelease];
        [location release];
        //}
        //CLLocation *location = nil;
	}
	
	return geoLocation;	
}

@end

