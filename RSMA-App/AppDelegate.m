//
//  AppDelegate.m
//  RSMA-App
//
//  Created by Slyter, Ryan Douglas on 11/7/14.
//  Copyright (c) 2014 Slyter, Ryan Douglas. All rights reserved.
//

#import "AppDelegate.h"
#import "MainMenuViewController.h"

@import CloudKit;
@interface AppDelegate ()

@end

@implementation AppDelegate
@synthesize window;
@synthesize navController;
@synthesize token;
@synthesize prefDict;
@synthesize path;
@synthesize filepath;
@synthesize rosterList;
@synthesize eventList;
@synthesize userID;
@synthesize teamSnapCookie;
@synthesize selectedEvent;
@synthesize chosenTeam;
@synthesize deviceTok;
@synthesize currentView;
@synthesize iCloudFlag;

-(void)checkIcloudAccount{
    dispatch_group_t iCloudCheck = dispatch_group_create();
    dispatch_group_enter(iCloudCheck);
    CKContainer *container = [CKContainer defaultContainer];
    [container accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
        if (!error){
            //NSLog(@"Account STATUS IS %ld", (long)accountStatus);            
            if (accountStatus != CKAccountStatusAvailable){
                iCloudFlag = false;
            }else{
                iCloudFlag = true;
            }
            dispatch_group_leave(iCloudCheck);
        }
    }];
    dispatch_group_wait(iCloudCheck, DISPATCH_TIME_FOREVER);
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
//    NSLog(@"application:handleOpenURL:%@",url);
    if ([[url scheme] isEqualToString:@"rsma"]) {
//        NSLog(@"rsma scheme");
        NSString *URLString = [url absoluteString];
        NSArray *components = [URLString componentsSeparatedByString:@"="];
        NSArray *tokenContainedIn = [components[1] componentsSeparatedByString:@"&"];

        //NSString *query = [components lastObject];
//        NSLog(@"token: %@",tokenContainedIn[0]);
        token = tokenContainedIn[0];
        // WIP : need to fix parse
        
        NSString *queryString = url.query;
        NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
        NSArray *urlComponents = [queryString componentsSeparatedByString:@"&"];
        
        for (NSString *keyValuePair in urlComponents)
        {
            NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
            NSString *key = [[pairComponents firstObject] stringByRemovingPercentEncoding];
            NSString *value = [[pairComponents lastObject] stringByRemovingPercentEncoding];
            
            [queryStringDictionary setObject:value forKey:key];
        }
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"gotTokenNotifications" object:self]];
        return YES;
    }
    return NO;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    rosterList = [[NSMutableArray alloc] init];
    eventList = [[NSMutableArray alloc] init];

    //Set iCloud account to true and check for iCloud accoutn sign in
    iCloudFlag = true;
    [self checkIcloudAccount];
    
    [window addSubview: navController.view];
    [window makeKeyAndVisible];
    NSLog(@"finished launching");
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    for(cookie in [cookieJar cookies]){
        //NSLog(@"cookie: %@", cookie);
        NSLog(@"cookies!");
        if([cookie.domain isEqualToString:@"auth.teamsnap.com"]){
//            NSLog(@"appdel cookie check on launch: %@", cookie);
            
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main"
                                                                 bundle:nil];
            MainMenuViewController *LoginController =
                [storyboard instantiateViewControllerWithIdentifier:@"mainMenu"];
            [LoginController loadWebView];
        }
    }

    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        NSLog(@"iOS version sufficient");
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    
    /** case app was opened from a push notification **/
    //got reference code from stack overflow : http://stackoverflow.com/questions/16393673/detect-if-the-app-was-launched-opened-from-a-push-notification
    UILocalNotification* notification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if(notification){
        [self application:application didReceiveRemoteNotification:(NSDictionary*)notification];
    }
    
    return YES;
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSString *token1 = [[deviceToken description] stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token1 = [token1 stringByReplacingOccurrencesOfString:@" " withString:@""];
    //NSLog(@"content---%@", token1);
    self.deviceTok = token1;
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error{
    //NSLog(@"%@", [error localizedDescription]);
    self.deviceTok = nil;
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo{
    /**
     handle what we will do when we receive a remote notification and the application is launched by the
     user from the notification
     **/
    NSLog(@"userInfo from notification is: %@",userInfo);

    [self checkIcloudAccount];
    if (!self.iCloudFlag){
        NSLog(@"Current view is: %@", self.currentView);
        return;
    }
    
    NSString *riderID, *eventID;

    riderID = [userInfo valueForKey:@"riderID"];
    eventID = [userInfo valueForKey:@"eventID"];
    //create a pop-up that asks if they will be willing to give a ride "yes" "no".
    //if "yes" update in cloud kit
    //if "no" dismiss and do nothing.
    NSString* player_name;
    for (int z = 0; z < [rosterList count]; z++){
        NSMutableDictionary* team = [rosterList objectAtIndex:z];
        if ([[team objectForKey:@"members"] objectForKey:riderID] != nil){
            NSLog(@"REQUESTING RIDER'S NAME IS: %@", [[team objectForKey:@"members"] objectForKey:riderID]);
            player_name = [[team objectForKey:@"members"] objectForKey:riderID];
        }
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ride Share"
                                                                   message:[NSString stringWithFormat:
                                                                            @"Would you like to give %@ a ride?", player_name]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Accept"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action){
                                                //accept button handler
                                                //*******START OF CLOUDKIT CODE
                                                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"EventID = %@ AND RiderID = %@", eventID, riderID];
                                                CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Rides" predicate: predicate];
                                                CKContainer *container = [CKContainer defaultContainer];
                                                CKDatabase *publicDB = [container publicCloudDatabase];
                                                [publicDB performQuery:query inZoneWithID:nil completionHandler:^(NSArray*results, NSError*error){
                                                    if (!error){
                                                        NSLog(@"No error in getting ride from CK after PUSH");
                                                        CKRecord* rec = [results objectAtIndex:0];
                                                        if (![rec[@"DriverID"] isEqualToString:@"not assigned"]){
                                                            NSLog(@"Rider has already by offered by another member.");
                                                            /** untested: need three devices **/
                                                            UIAlertController *subAlert = [UIAlertController alertControllerWithTitle:@"Ride Share"
                                                                                                                           message:[NSString stringWithFormat:
                                                                                                                                    @"Someone Beat you to it! Ride already given."]
                                                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                                                            [subAlert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
                                                            [currentView presentViewController:subAlert animated:YES completion:nil];
                                                            return;
                                                        }
                                                        rec[@"DriverID"] = userID;
                                                        //NOW SAVE THE CHANGED RECORD TO CLOUDKIT
                                                        [publicDB saveRecord:rec completionHandler:^(CKRecord *recres, NSError *err){
                                                            if (err){
                                                                NSLog(@"Save Record Error: ");
                                                                NSLog(@"%@",[err localizedDescription]);
                                                            }else{
                                                                
                                                                NSLog(@"Changed PUSH sought record properly saved.");
                                                                
                                                            }
                                                        }];
                                                    }
                                                    if (error){
                                                        NSLog(@"Error querying for PUSH ride: %@",[error localizedDescription]);
                                                    }
                                                    
                                                }];
                                                //*******END OF CLOUDKIT CODE
                                                
                                            }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Deny"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    NSLog(@"current view: %@",currentView);
    
    [currentView presentViewController:alert animated:YES completion:nil];
    
    
}
- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    //set the cookie acceptance policy since its shared among apps and can be changed without knowing.
//    NSLog(@"CurrentView is %@", self.currentView);
    [self checkIcloudAccount];
//    NSLog(@"iCloud Flag is %d", self.iCloudFlag);
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
- (void)dealloc {
    /*
     this method and the calls within it are from the grapefruit book but since we have ARC checked it doesn't like them. Leaving here for just in case
     */
    //[navController release];
    //[window release];
    //[super dealloc];
}
@end
