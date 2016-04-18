//
//  TableViewController.m
//  RSMA-App
//
//  Created by David Michael Parrott on 2/7/15.
//  Copyright (c) 2015 Slyter, Ryan Douglas. All rights reserved.
//

#import "RosterListViewController.h"
#import "AppDelegate.h"
#import "AFOauth2Manager.h"
#import "EventListViewController.h"
#import "MainMenuViewController.h"


@interface RosterListViewController ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end


@implementation RosterListViewController
{
    NSMutableArray *roster;
}

-(void)iCloudNotify{
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if (!appDelegate.iCloudFlag){
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Not signed into iCloud"
                                                                       message:[NSString stringWithFormat:
                                                                                @"You must be signed into iCloud without child permissions to use this app. Please sign into iCloud before using this app"]
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
    // Do any additional setup after loading the view, typically from a nib.
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.currentView = self;
    [self.activityIndicator startAnimating];
    self.activityIndicator.hidden = NO;
    roster = appDelegate.rosterList;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadRoster:)
                                                 name:@"reloadRosterlist"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gotError:)
                                                 name:@"error"
                                               object:nil];
    [self iCloudNotify];
    
//    NSLog(@"cookie check: %@", appDelegate.teamSnapCookie);
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
-(void)reloadRoster:(NSNotification*) notification {
    NSLog(@"got reload notification");
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;
    [self.tableView reloadData];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [roster count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"RLcell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier forIndexPath:indexPath];
    /*
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }*/
    cell.textLabel.text = [[roster objectAtIndex:indexPath.row] objectForKey:@"name"];
    return cell;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    //NSLog(@"Selected row of section >> %ld", (long)indexPath.row);
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.chosenTeam = indexPath.row;
    NSDictionary *selectedEntry = roster[indexPath.row];

    //Create the HTTP manager and format the request for OAUTH bearer token
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:@"application.json" forHTTPHeaderField:@"Content-Type"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", appDelegate.token] forHTTPHeaderField:@"Authorization"];
    
    //perform /me query
    [manager GET:[selectedEntry objectForKey:@"href"]
      parameters:nil
         success:^(AFHTTPRequestOperation *operation, id responseObject) {
//             NSLog(@"%@",responseObject);
             //get the links dictionary
//             NSLog(@"count: %lu", (unsigned long)[responseObject[@"collection"][@"items"] count]);
             if([responseObject[@"collection"][@"items"] isKindOfClass:[NSDictionary class]]){
//                 NSLog(@"items is Dictionary");
             }
             if([responseObject[@"collection"][@"items"] isKindOfClass:[NSArray class]]){
//                 NSLog(@"items is Array");
//                 NSLog(@"%@",responseObject[@"collection"][@"items"]);
             }
             NSArray *items = responseObject[@"collection"][@"items"];
             int itemsSize = (int)[items count];
             for(int i = 0; i < itemsSize; i++){
                 NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
//                 NSLog(@"i=%i content:%@ is Dictionary:%d",i,items[i], [items[i] isKindOfClass:[NSDictionary class]]);
                 NSDictionary *data = [items[i] objectForKey:@"data"];
//                 NSLog(@"itemData: %@",itemData);
                 for(id dataDictEntry in data){
//                     NSLog(@"dataDictEntry: %@",dataDictEntry);
                     for(id dataDictEntryKey in dataDictEntry){
//                         NSLog(@"dataDictEntryKey: %@ val: %@",dataDictEntryKey,[dataDictEntry objectForKey:dataDictEntryKey]);
                         
                         if([[dataDictEntry objectForKey:dataDictEntryKey] isEqual:@"id"]){
//                             NSLog(@"got id: %@", [dataDictEntry objectForKey:@"value"]);
                             [event setObject:[dataDictEntry objectForKey:@"value"] forKey:@"id"];
                         }
                         else if([[dataDictEntry objectForKey:dataDictEntryKey] isEqual:@"start_date"]){
                             NSDateFormatter *dateFormatterUTC = [[NSDateFormatter alloc] init];
                             [dateFormatterUTC setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
                             [dateFormatterUTC setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
                             NSDate *eventDateUTC = [dateFormatterUTC dateFromString:[dataDictEntry objectForKey:@"value"]];
                             
                             NSDateFormatter *dateFormatterLocal = [[NSDateFormatter alloc] init];
                             [dateFormatterLocal setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
                             [dateFormatterLocal setTimeZone:[NSTimeZone systemTimeZone]];
                             
                             NSDate *localDate = [dateFormatterUTC dateFromString:[dateFormatterLocal stringFromDate:eventDateUTC]];
                             NSDate *localNowDate = [dateFormatterUTC dateFromString:[dateFormatterLocal stringFromDate:[NSDate date]]];

                             if ([localDate compare:localNowDate] == NSOrderedDescending) {
//                                 NSLog(@"eventDate is later than currentDate");
                             } else if ([localDate compare:localNowDate] == NSOrderedAscending) {
//                                 NSLog(@"eventDate is earlier than currentDate");
                                 [indexes addIndex:[appDelegate.eventList count]];

                             } else {
//                                 NSLog(@"dates are the same");
                             }
//                             NSLog(@"got state_date: %@", [dataDictEntry objectForKey:@"value"]);
                             [event setObject:[dateFormatterLocal stringFromDate:eventDateUTC] forKey:@"start_date"];
                         }
                         else if ([[dataDictEntry objectForKey:dataDictEntryKey] isEqual:@"name"]){
//                             NSLog(@"got name: %@", [dataDictEntry objectForKey:@"value"]);
                             [event setObject:[dataDictEntry objectForKey:@"value"] forKey:@"name"];
                         }
                         else if ([[dataDictEntry objectForKey:dataDictEntryKey] isEqual:@"is_game"]){
                             //                             NSLog(@"got name: %@", [dataDictEntry objectForKey:@"value"]);
                             [event setObject:[dataDictEntry objectForKey:@"value"] forKey:@"is_game"];
                         }
                     }
                 }
                 NSArray *links = [items[i] objectForKey:@"links"];
//                 NSLog(@"links: %@ isDictionary: %d",links, [links isKindOfClass:[NSDictionary class]]);
                 for(int i = 0; i < [links count]; i++){
                     if([[links[i] objectForKey:@"rel"] isEqual:@"location"]){
//                         NSLog(@"got location link: %@", [links[i] objectForKey:@"href"]);
                         [event setObject:[links[i] objectForKey:@"href"] forKey:@"location_href"];
                     }
                     else if([[links[i] objectForKey:@"rel"] isEqual:@"opponent"]){
//                         NSLog(@"got opponent link: %@", [links[i] objectForKey:@"href"]);
                         [event setObject:[links[i] objectForKey:@"href"] forKey:@"opponent_href"];
                     }
                 }

                 [appDelegate.eventList addObject:event];
             }
             /*****************************************
              comment out the following line if you want to see old events
              *****************************************/
             [appDelegate.eventList removeObjectsAtIndexes:indexes];
             [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"reloadEventlist" object:self]];
             
         }
         failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//             NSLog(@"Error: %@", error);
             [[NSNotificationCenter defaultCenter] postNotificationName:@"error" object:error];

         }];
    
    [self performSegueWithIdentifier:@"ShowEventList" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

}

- (void)viewWillAppear:(BOOL)animated {
    /*
     It is necessary to clear out appDelegate.eventList every time this view appears
     or else every time you pick a new team that team's events will just get added
     to the array
     */
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    [appDelegate.eventList removeAllObjects];
    
}
@end

