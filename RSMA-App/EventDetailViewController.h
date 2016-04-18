//
//  ViewUglyViewController.h
//  RSMA-App
//
//  Created by Slyter, Ryan Douglas on 11/7/14.
//  Copyright (c) 2014 Slyter, Ryan Douglas. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EventListViewController.h"

@import CloudKit;
@interface EventDetailViewController : UIViewController
@property int numRides; //NEW: nubmer of rides to populate Eventdetail with
@property NSMutableArray* Rides; //Array
@property NSString* userID;
@property (nonatomic, strong) NSString* selectedEvent;
@property (nonatomic, strong) NSMutableDictionary* selectedTeam;

@end