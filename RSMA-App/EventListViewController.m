//
//  EventListlViewController.m
//  RSMA-App
//
//  Created by Slyter, Ryan Douglas on 11/7/14.
//  Copyright (c) 2014 Slyter, Ryan Douglas. All rights reserved.
//

#import "EventListViewController.h"
#import "EventDetailViewController.h"
#import "RosterListViewController.h"
#import "AppDelegate.h"
#import "AFOauth2Manager.h"


@import CloudKit;
@interface EventListlViewController ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@end


@implementation EventListlViewController{
    NSMutableArray *eventsList;
}

-(void)probeForNewID:(NSString*) usr DeviceTok:(NSString*) tok{
    
    //Set up the initial query to see if the UserID already exists
    CKContainer *container = [CKContainer defaultContainer];
    CKDatabase *publicDB = [container publicCloudDatabase];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"UserID = %@", usr]; //needs to be changed accordingly
    CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Members" predicate: predicate];
    
    [publicDB performQuery:query inZoneWithID:nil completionHandler:^(NSArray*results, NSError*error){
        if (error){
            NSLog(@"%@",[error localizedDescription]);
        }
        else{
            //Case where the there were no Member records had that UserID
            if ([results count] == 0){
                CKRecord *record = [[CKRecord alloc] initWithRecordType:@"Members"];
                record[@"UserID"] = usr;
                record[@"DeviceIDs"] = @[tok];
                [publicDB saveRecord:record completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
                    // Error handling for failed save to public database
                    if (saveError){
//                        NSLog(@"%@",[error localizedDescription]);
                    }else{
//                        NSLog(@"Saved record ID is: %@", [savedRecord recordID]);
                    }
                }]; //We don't actually do anything with the record once it's saved.
                
            }else{
                //The Record exists so we need to fetch it and update it with the device token
                CKRecord* targetRecord = [results objectAtIndex:0]; //**THIS ASSUMES THERE'S ONLY 1 RECORD!!!
 
//                NSLog(@"Fetched record was found with UserID: %@", targetRecord[@"UserID"]);
                //Perform the fetch
                [publicDB fetchRecordWithID:[targetRecord recordID] completionHandler:^(CKRecord *fetchedRecord, NSError *error) {
                    //Fetch didn't work
                    if (error){
                        NSLog(@"%@",[error localizedDescription]);
                    }else{
                        
                        NSArray* temp = fetchedRecord[@"DeviceIDs"];
                        if ([temp indexOfObject: tok] == NSNotFound){
                            temp = [temp arrayByAddingObject:tok];
                            fetchedRecord[@"DeviceIDs"] = temp;
                        }
                        [publicDB saveRecord: fetchedRecord completionHandler:^(CKRecord* reSavedRecord, NSError *error){
                            if (error){
                                NSLog(@"%@",[error localizedDescription]);
                            }else{
                                //NSLog(@"ReSaved was fetched and its recordID is: %@", [reSavedRecord recordID]);
                            }
                        }];
                         //Else we don't even need to re-save the record
                    }
                }];
            }
        }
        
    }];
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.currentView = self;
    
    eventsList = appDelegate.eventList;
    [self.activityIndicator startAnimating];
    self.activityIndicator.hidden = NO;
    //RYAN TEST CODE: TEST TO SEE IF WE CAN NOW ADD THE USER ID TO DATABASE WITH A DEVICE ID, OR IF ALREADY THERE JUST ADD DEVICE ID
    //New:only do this if the flag for iCloud authorization is checked
    if (appDelegate.iCloudFlag){
        if (appDelegate.deviceTok == nil){
            [self probeForNewID:appDelegate.userID DeviceTok: @"Sim"];
        }else{
            [self probeForNewID:appDelegate.userID DeviceTok: appDelegate.deviceTok];
        }
    }
    //[self probeForNewID:@"7777" DeviceTok: @"6666"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadEvents:)
                                                 name:@"reloadEventlist"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gotError:)
                                                 name:@"error"
                                               object:nil];


}
-(void)gotError:(NSNotification*) notification{
    if ([notification.object isKindOfClass:[NSError class]])
    {
        NSError *message = [notification object];
        // do stuff here with your message data
        NSLog(@"got error: %@", message.localizedDescription);
        AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        appDelegate.teamSnapCookie = nil;
        //        NSHTTPCookie *cookie;
        for(NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]){
            //is a team snap cookie
            if([cookie.domain isEqualToString:@"auth.teamsnap.com"]){
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
            }
        }
        //        MainMenuViewController *mainMenuViewController = (MainMenuViewController*);
        UIAlertController * alert=   [UIAlertController
                                      alertControllerWithTitle:@"Error Receiving Data From TeamSnap"
                                      message:message.localizedDescription
                                      preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction
                             actionWithTitle:@"Log back in"
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                                 [self dismissViewControllerAnimated:YES completion:nil];
                             }];
        [alert addAction:ok];
        
        [self presentViewController:alert animated:YES completion:nil];
        //        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        NSLog(@"Error, object not recognised.");
    }
}
-(void)reloadEvents:(NSNotification*) notification {
//    NSLog(@"got reload notification");
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];

    int count = (int)[appDelegate.eventList count];
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:@"application.json" forHTTPHeaderField:@"Content-Type"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", appDelegate.token] forHTTPHeaderField:@"Authorization"];

    for(int i = 0; i < count; i++){
//        NSLog(@"location_href: %@", [appDelegate.eventList[i] objectForKey:@"location_href"]);
        [manager GET:[appDelegate.eventList[i] objectForKey:@"location_href"]
          parameters:nil
             success:^(AFHTTPRequestOperation *operation, id responseObject) {
//                 NSLog(@"JSON: %@", responseObject);
                 NSArray *data = responseObject[@"collection"][@"items"][0][@"data"];
//                 NSLog(@"count: %d",[data count]);
                 int dataCount = (int)[data count];
                 for(int j = 0; j < dataCount; j++){
                     if(![[data[j] objectForKey:@"name"] isEqual:@"name"]){
                         continue;
                     }else{
                         [appDelegate.eventList[i] setObject:[data[j] objectForKey:@"value"] forKey:@"location_name"];
//                         NSLog(@"location_name: %@", [appDelegate.eventList[i] objectForKey:@"location_name"]);
                     }
                 }
             }
             failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                 NSLog(@"Error: %@", error);
             }];
    }
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//#warning Incomplete method implementation.
    // Return the number of rows in the section.
    //return [self.colors count];
    return [eventsList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *simpleTableIdentifier = @"ELcell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier forIndexPath:indexPath];

    NSString *cellText = @"";
    NSString *cellDetailText = @"";
    if([[eventsList objectAtIndex:indexPath.row] objectForKey:@"is_game"] &&
       [[[eventsList objectAtIndex:indexPath.row] objectForKey:@"name"] isEqual:@""]){
        cellText = [cellText stringByAppendingString:@"Game "];
    }
    if(![[[eventsList objectAtIndex:indexPath.row] objectForKey:@"name"] isEqual:@""]){
        cellText = [cellText stringByAppendingString:[[eventsList objectAtIndex:indexPath.row] objectForKey:@"name"]];
    }
    //    NSLog(@"start_date: %@",[[events objectAtIndex:indexPath.row] objectForKey:@"start_date"]);
    
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    NSDate *date = [dateFormatter dateFromString:[[eventsList objectAtIndex:indexPath.row] objectForKey:@"start_date"]];
//    NSLog(@"date: %@", date);
    dateFormatter.dateFormat = @"EEEE dd MMMM yyyy HH:mm";
//    NSLog(@"%@",[dateFormatter stringFromDate:date]);
    
    cellDetailText = [cellDetailText stringByAppendingString:[dateFormatter stringFromDate:date]];
    cell.detailTextLabel.text = cellDetailText;
    cell.textLabel.text = cellText;
    return cell;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.selectedEvent = eventsList[indexPath.row];
//    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"showEventDetail" object:self]];
    [self performSegueWithIdentifier:@"ShowDetailSegue" sender:self];
}

//This method is implemented on navigated pages so that going
//back in nagivation will be kept track of for push notfications
//handling
- (void)viewWillDisappear:(BOOL)animated {
    //grab the parent controller and save it to currentView
    NSInteger currentVCIndex = [self.navigationController.viewControllers indexOfObject:self.navigationController.topViewController];
    RosterListViewController *parent = (RosterListViewController *)[self.navigationController.viewControllers objectAtIndex:currentVCIndex];
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    appDelegate.currentView = parent;
//    NSLog(@"PARENT IS: %@", parent);
}

@end
