//
//  ViewController.m
//  RSMA-App
//
//  Created by Slyter, Ryan Douglas on 11/7/14.
//  Copyright (c) 2014 Slyter, Ryan Douglas. All rights reserved.
//

#import "EventDetailViewController.h"
#import "EventListViewController.h"
#import "AppDelegate.h"
#import "AFNetworking.h"


@import CloudKit; //NEWLY ADDED FOR CLOUDKIT
@interface EventDetailViewController ()
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation EventDetailViewController{
    NSMutableArray *eventsList;
}

-(void)iCloudNotify{
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if (!appDelegate.iCloudFlag){
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Not signed in to iCloud"
                                                                       message:[NSString stringWithFormat:
                                                                                @"You must be signed into iCloud without child permissions to use this feature. Press Home Key and sign into iCloud."]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Okay"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction* action){
                                                    
                                                }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    return;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.currentView = self;
    
    _selectedTeam = [[appDelegate.rosterList objectAtIndex: appDelegate.chosenTeam] objectForKey:@"members"];
    _activityIndicator.hidden = YES;
    [_activityIndicator stopAnimating];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showDetail:) name:@"showEventDetail" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gotError:)
                                                 name:@"error"
                                               object:nil];

    eventsList = appDelegate.eventList;
    _Rides = [[NSMutableArray alloc]init];

    
    _userID = appDelegate.userID;
    
    //***NEW CODE FOR CLOUDKIT***//
    //NOTE: THIS CODE ASSUMED WE HAVE AN EVENT ID, AND USER ID OF CURRENT USER ALONG WITH DEVICE TOKEN
    if (!appDelegate.iCloudFlag)return;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"EventID = %@", [[appDelegate.selectedEvent valueForKey:@"id"] stringValue]];
    
    CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Rides" predicate: predicate];
    CKContainer *container = [CKContainer defaultContainer];
    CKDatabase *publicDB = [container publicCloudDatabase];
    [publicDB performQuery:query inZoneWithID:nil completionHandler:^(NSArray*results, NSError*error){
        if (!error){
           
            if ([results count] != 0){
                for (CKRecord* rideRecord in results){
                    //NSLog(@"Ride %d: %@", _numRides, [rideRecord objectForKey:@"RiderID"]);
                    [_Rides addObject:rideRecord];
                }
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_activityIndicator stopAnimating];
                        _activityIndicator.hidden = YES;
                        [self.tableView reloadData];
                    });
                });
            }
        }
        if (error){
            NSLog(@"error1: %@",[error localizedDescription]);
        }
    }];
    
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
-(void)showDetail:(NSNotification*)notification{
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    //#warning Potentially incomplete method implementation.
    
    // Return the number of sections.
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    //For each section, you must return here it's label
    if(section == 0) return @"Event Details";
    else if (section == 1) return @"Need a Ride?";
    else{return @"Current Rides to Event";}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    dispatch_group_t taskGroup = dispatch_group_create();
    NSMutableArray *tokensToSend = [[NSMutableArray alloc] init];

    //CASE "Ride": User selected a "Rides" row that need to update with their userID and reload the table
    if (indexPath.section == 2){
        UITableViewCell* selectedCell = [tableView cellForRowAtIndexPath:indexPath];
        [tableView deselectRowAtIndexPath:indexPath animated:true];

        //If not signed into an iCloud account, we wont let the user do anything with the cell
        if (!appDelegate.iCloudFlag){
            [self iCloudNotify];
            return;
        }
        
        //Ride row was selected so update it with users ID
        //push to CK and update row in the tableView
        if ([selectedCell.detailTextLabel.text isEqualToString:@"No driver assigned yet."]){
            if ([[_Rides objectAtIndex:indexPath.row][@"RiderID"] isEqualToString:_userID]){
//                NSLog(@"You can't give yourself a ride!");
                UIAlertController *alertController =
                [UIAlertController alertControllerWithTitle:@"You can't give yourself a ride!"
                                                    message:nil
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                    style:UIAlertActionStyleCancel
                                                                  handler:nil]];
                [self presentViewController:alertController animated:YES completion:^{}];
                return;
            }
            //For now assume we have the driver's ID locally
            CKRecord* ret = [_Rides objectAtIndex:indexPath.row];
            ret[@"DriverID"] = _userID;
            CKContainer *container = [CKContainer defaultContainer];
            CKDatabase *publicDB = [container publicCloudDatabase];
            
            /*******/
            [publicDB fetchRecordWithID:ret.recordID completionHandler:^(CKRecord *record, NSError*error){
            
                if (error){
                    NSLog(@"%@",[error localizedDescription]);
                    ret[@"DriverID"] = @"not assigned";
                }else{
                    
//                    NSLog(@"Record was properly fetched.");
                    [record setObject:_userID forKey:@"DriverID"];
                    [publicDB saveRecord:record completionHandler:^(CKRecord *res, NSError *err){
                        if (err){
//                            NSLog(@"Completion Block");
                            NSLog(@"%@",[err localizedDescription]);
                        }else{
                            
//                            NSLog(@"Saved record is: %@", res[@"DriverID"]);
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [_activityIndicator stopAnimating];
                                    _activityIndicator.hidden = YES;
                                    [self.tableView reloadData];
                                    
                                    UIAlertController *Alert = [UIAlertController alertControllerWithTitle:@"Ride Given!"
                                                                                                      message:[NSString stringWithFormat:
                                                                                                               @"Officially giving a ride."]
                                                                                               preferredStyle:UIAlertControllerStyleAlert];
                                    [Alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
                                    [appDelegate.currentView presentViewController:Alert animated:YES completion:nil];

                                });
                            });
                        }
                    }];
                }
            }];
            
        }
    }
    //CASE "NAR": User selects NAR button so new record needs to be added to database
    
    else if (indexPath.section == 1){
        //Check for iCloud account and return if not signed in
        if (!appDelegate.iCloudFlag){
            [self iCloudNotify];
            [tableView deselectRowAtIndexPath:indexPath animated:true];
            return;
        }
        //else start logic to notify riders
        [tableView deselectRowAtIndexPath:indexPath animated:true];
        [_activityIndicator startAnimating];
        _activityIndicator.hidden = NO;
        for (int i = 0; i < [_Rides count]; i++){
            CKRecord* temp = [_Rides objectAtIndex:i];
            if ([temp[@"RiderID"] isEqualToString: _userID]){
                NSLog(@"This user ID is already in a ride match.");
                [_activityIndicator stopAnimating];
                _activityIndicator.hidden = YES;
//                NSLog(@"You can't give yourself a ride!");
                UIAlertController *alertController =
                [UIAlertController alertControllerWithTitle:@"You have already requested a ride to this event!"
                                                    message:nil
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                    style:UIAlertActionStyleCancel
                                                                  handler:nil]];
                [self presentViewController:alertController animated:YES completion:^{}];
                return; //Do nothing if that userID has already been matched to a Driver
            }
        }
         //**Now a new record needs to be created and saved for this Events and reloaded**
        //NSLog(@"This user ID is not a ride and needs to be sent out.");
        CKContainer *container = [CKContainer defaultContainer];
        CKDatabase *publicDB = [container publicCloudDatabase];
        
        CKRecord *record = [[CKRecord alloc] initWithRecordType:@"Rides"];
        record[@"RiderID"] = _userID;
        record[@"DriverID"] = @"not assigned";
        //NSString *idString = [NSString stringWithFormat:@"%@",[NSString stringWithFormat: @"%ld", (long)[appDelegate.selectedEvent valueForKey:@"id"]]];
        NSString *idString = [[appDelegate.selectedEvent objectForKey:@"id"]stringValue];
        //NSLog(@"Width of eventid val: %zu", sizeof([appDelegate.selectedEvent objectForKey:@"id"]));
//        NSLog(@"Actual event id is: %@", [appDelegate.selectedEvent objectForKey:@"id"]);
//        NSLog(@"New NAR record from Event id: %@", idString);
        record[@"EventID"] = idString;

        dispatch_group_enter(taskGroup);
        [publicDB saveRecord:record completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
            // Error handling for failed save to public database
            if (saveError){
                NSLog(@"error: %@",[saveError localizedDescription]);
//                [record delete:[record recordID]];
                [_activityIndicator stopAnimating];
                _activityIndicator.hidden = YES;
                return;
            }else{
//                NSLog(@"Saved record ID is: %@", [savedRecord recordID]);
                [_Rides addObject:record];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_activityIndicator stopAnimating];
                        _activityIndicator.hidden = YES;
                        [self.tableView reloadData];
                        
                    });
                });
                //RYAN'S NEWEST CODE 4/9 - get all the team member id's for selected team
                /**********************************************************************/
                //NSLog(@"Team id: %ld", appDelegate.chosenTeam);
                NSMutableDictionary* teamEntry = [[appDelegate.rosterList objectAtIndex:appDelegate.chosenTeam] objectForKey:@"members"];

                for (id key in teamEntry){
                    
//                    NSLog(@"Teammate id: %@", key);
//                    NSLog(@"Teammate name: %@", teamEntry[key]);
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"UserID = %@", key];
                    CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Members" predicate: predicate];
                    dispatch_group_enter(taskGroup);
                    [publicDB performQuery:query inZoneWithID:nil completionHandler:^(NSArray*results, NSError*error){
                        if (!error){
                            if ([results count] != 0){
                                CKRecord* rec = [results objectAtIndex:0];
                                NSArray* devices = [rec objectForKey:@"DeviceIDs"];
                                for (NSString* dev in devices){
                                    if ([dev isEqualToString:@"Sim"]){
//                                        NSLog(@"Sim");
                                        continue; //skip over calls made by simulator
                                    }else if(![dev isEqualToString:appDelegate.deviceTok]){
//                                        NSLog(@"adding token %@ to tokensToSend", dev);
                                        [tokensToSend addObject:dev];
                                    }
                                }
                            }else{
                                NSLog(@"The user hasn't used this app yet.");
                            }
                        }
                        if (error){
                            NSLog(@"error1: %@",[error localizedDescription]);
                        }
                        dispatch_group_leave(taskGroup);
                    }];
                }
//                NSLog(@"needed eventID: %@", [appDelegate.selectedEvent[@"id"] stringValue]);
//                NSLog(@"needed userID: %@", _userID);
                /**********************************************************************/
            }
        dispatch_group_leave(taskGroup);
        }];
//We don't actually do anything with the record once it's saved.
        dispatch_group_wait(taskGroup, DISPATCH_TIME_FOREVER);
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        //manager.responseSerializer = [AFJSONResponseSerializer serializer];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        //***********************IMPORTANT
        //You must not have large extraneous spaces here. Somehow it screws up
        //    NSDictionary *msg = @{@"tokens":tokensToSend,@"payload" : @{ @"aps" : @{ @"alert" : @"RSMA test notification JSON style",@"sound" : @"default"},@"riderID" : @"1234",@"eventID" : @"5678"}};
        NSDictionary *msg = @{@"tokens":tokensToSend,@"payload" : @{ @"aps" : @{ @"alert" : @"Someone on your team needs a ride!",@"sound" : @"default"},@"riderID" : _userID,@"eventID" : [[appDelegate.selectedEvent objectForKey:@"id"]stringValue]}};
        //    NSLog(@"msg to james: %@",msg);
        [manager POST:@"http://rsma.cs420.net:9001"
           parameters:msg
              success:^(AFHTTPRequestOperation *operation, id responseObject) {
//                  NSLog(@"success resposne from James: %@", operation.responseString);
//                  
//                  UIAlertController *alertController =
//                  [UIAlertController alertControllerWithTitle:@"Request Sent!"
//                                                      message:nil
//                                               preferredStyle:UIAlertControllerStyleAlert];
//                  [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
//                                                                      style:UIAlertActionStyleCancel
//                                                                    handler:nil]];
//                  [self presentViewController:alertController animated:YES completion:^{}];
                  
              }
              failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  NSLog(@"error resposne from James: %@", operation.responseString);
              }];
        
    }

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    if (section == 0)return 3;
    if (section == 1)return 1;
    else{
        if ([_Rides count] == 0){
            return 1;
        }

        return [_Rides count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];

    if (indexPath.section == 2){
    
    static NSString *CellIdentifier = @"RideCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
        if ([_Rides count] != 0){
            CKRecord* temp = [_Rides objectAtIndex:indexPath.row];
            cell.detailTextLabel.textColor = [UIColor redColor];
            cell.textLabel.text = [_selectedTeam objectForKey:[temp objectForKey:@"RiderID"]];
            if ([[temp objectForKey:@"DriverID"] isEqualToString:@"not assigned"]){
                cell.detailTextLabel.text = @"No driver assigned yet.";
            }else{
                cell.detailTextLabel.text = [_selectedTeam objectForKey:[temp objectForKey:@"DriverID"]];
            }
            return cell;
        }
        else{
            if (!appDelegate.iCloudFlag){
                cell.textLabel.text = @"You cannot view rides.";
                cell.detailTextLabel.text = @"Sign into iCloud to use this feature.";
                return cell;
            }
            cell.textLabel.text = @"No rides assigned for this event yet.";
            cell.detailTextLabel.text = @"Click 'REQUEST RIDE' to request rides.";
            return cell;
        }
    }
    if (indexPath.section == 1){
       static NSString *CellIdentifier = @"NARCell";
       UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
       cell.backgroundColor = [UIColor yellowColor];
       cell.textLabel.textColor = [UIColor redColor];
       cell.textLabel.text = @"REQUEST A RIDE";
       return cell;
    }
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if (indexPath.row == 0){
//        NSLog(@"name: %@", [appDelegate.selectedEvent objectForKey:@"name"]);
        if([[[eventsList objectAtIndex:indexPath.row] objectForKey:@"name"] isEqual:@""]){
            cell.textLabel.text = @"Game";
        }else{
            cell.textLabel.text = [appDelegate.selectedEvent objectForKey:@"name"]; //event name
    
        }
    }
    else if (indexPath.row == 1){
//        NSLog(@"time: %@", [appDelegate.selectedEvent objectForKey:@"start_date"]);
        NSString *cellDetailText = @"";
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        NSDate *date = [dateFormatter dateFromString:[appDelegate.selectedEvent objectForKey:@"start_date"]];
//        NSLog(@"date: %@", date);
        dateFormatter.dateFormat = @"EEEE dd MMMM yyyy HH:mm";
//        NSLog(@"%@",[dateFormatter stringFromDate:date]);
        cell.textLabel.text = [cellDetailText stringByAppendingString:[dateFormatter stringFromDate:date]];  //event time
    }
    else{
//        NSLog(@"href: %@", [appDelegate.selectedEvent objectForKey:@"location_href"]);
       cell.textLabel.text = [appDelegate.selectedEvent objectForKey:@"location_name"];  //event location
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
//    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if(indexPath.section == 2){
        if (editingStyle == UITableViewCellEditingStyleDelete) {
            [_activityIndicator startAnimating];
            _activityIndicator.hidden = NO;
            NSLog(@"trying to delete a ride");
            CKRecord* rec = [_Rides objectAtIndex:indexPath.row];
            if (![rec[@"RiderID"] isEqualToString: _userID] && ![rec[@"DriverID"] isEqualToString: _userID]){
                    //user isn't eligible to delete this
                UIAlertController *alertController =
                [UIAlertController alertControllerWithTitle:@"You can't cancel a ride you aren't participating in!"
                                                    message:nil
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                    style:UIAlertActionStyleCancel
                                                                  handler:nil]];
                [self presentViewController:alertController animated:YES completion:^{}];
                [self.tableView reloadData];
                
            }
//            self.navigationItem.backBarButtonItem.enabled = NO;
            self.navigationItem.hidesBackButton = YES;
            /*****************
             Actual Cloudkit Code
             *****************/
            NSArray* recsToDelete = [NSArray arrayWithObjects: rec.recordID, nil];
            CKContainer *container = [CKContainer defaultContainer];
            CKDatabase *publicDB = [container publicCloudDatabase];
            CKModifyRecordsOperation *deleteOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:nil recordIDsToDelete:recsToDelete];
            //Note: there should be no need to have a save policy since we're unconditionally deleting one record
            deleteOp.modifyRecordsCompletionBlock = ^(NSArray *saved, NSArray* deleted, NSError* error){
                if (!error){
                    //successful deletion
                    [_Rides removeObjectAtIndex:indexPath.row];
                    NSLog(@"no error deleting ride");
                    UIAlertController *alertController =
                    [UIAlertController alertControllerWithTitle:@"Ride was successfully cancelled."
                                                        message:nil
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                        style:UIAlertActionStyleCancel
                                                                      handler:nil]];
                    [self presentViewController:alertController animated:YES completion:^{
                        [_activityIndicator stopAnimating];
                        _activityIndicator.hidden = YES;
                        [self.tableView reloadData];
//                        self.navigationItem.backBarButtonItem.enabled = YES;
                        self.navigationItem.hidesBackButton = NO;

                    }];
//                    [_activityIndicator stopAnimating];
//                    _activityIndicator.hidden = YES;
//                    [self.tableView reloadData];
                    
                }else{
                    NSLog(@"error deleting from CK: error: %@", [error localizedDescription]);
                    UIAlertController *alertController =
                    [UIAlertController alertControllerWithTitle:@"Ride deletion failed, error connecting to database."
                                                        message:nil
                                                 preferredStyle:UIAlertControllerStyleAlert];
                    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                                        style:UIAlertActionStyleCancel
                                                                      handler:nil]];
                    [self presentViewController:alertController animated:YES completion:^{
                        [_activityIndicator stopAnimating];
                        _activityIndicator.hidden = YES;}];
                    [self.tableView reloadData];
                }
            };
            [publicDB addOperation:deleteOp];
            
            
        } else {
            
            //            NSLog(@"Unhandled editing style! %ld", editingStyle);
        }

    }else{
        return;
    }
}

-(BOOL)tableView:(UITableView*)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == 2){
        return YES;
    }
    /****************************
     in order to enble delete the above code must not be commented out
     ***************************/
    return NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData]; // to reload selected cell
}

//This method is implemented on navigated pages so that going
//back in nagivation will be kept track of for push notfications
//handling
- (void)viewWillDisappear:(BOOL)animated {
    //grab the parent controller and save it to currentView
    NSInteger currentVCIndex = [self.navigationController.viewControllers indexOfObject:self.navigationController.topViewController];
    EventListlViewController *parent = (EventListlViewController *)[self.navigationController.viewControllers objectAtIndex:currentVCIndex];
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    appDelegate.currentView = parent;
//    NSLog(@"PARENT IS: %@", parent);
}

@end
