//
//  AppDelegate.h
//  RSMA-App
//
//  Created by Slyter, Ryan Douglas on 11/7/14.
//  Copyright (c) 2014 Slyter, Ryan Douglas. All rights reserved.
//

#import <UIKit/UIKit.h>
@import CloudKit;
@interface AppDelegate : NSObject <UIApplicationDelegate>{
    IBOutlet UIWindow *window;
    IBOutlet UINavigationController *navController;
    NSString *token;
    
    NSMutableDictionary *prefDict;
    NSString *path;
    NSString *filepath;
}

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) UINavigationController *navController;
@property (nonatomic, retain) NSString *token;
@property (strong, nonatomic) NSMutableDictionary *prefDict;
@property (strong, nonatomic) NSString *path;
@property (strong, nonatomic) NSString *filepath;
@property (strong, nonatomic) NSMutableArray *rosterList;
@property (strong, nonatomic) NSMutableArray *eventList;
@property (strong, nonatomic) NSString *userID;
@property (strong, nonatomic) NSHTTPCookie *teamSnapCookie;
@property (strong, nonatomic) NSMutableDictionary *teamSnapCookiefields;
@property (strong, nonatomic) NSDictionary *selectedEvent;
@property (nonatomic) NSInteger chosenTeam;
@property (strong, nonatomic) NSString* deviceTok;
@property (assign, nonatomic) id currentView;
@property (atomic) BOOL iCloudFlag;


@end

