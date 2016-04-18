//
//  MainMenuViewController.m
//  RSMA-App
//
//  Created by David on 2/8/15.
//  Copyright (c) 2015 Slyter, Ryan Douglas. All rights reserved.
//

#import "MainMenuViewController.h"
#import "AFOauth2Manager.h"
#import "AppDelegate.h"
#import "SSKeychain.h"
#import "SSKeychainQuery.h"
#import <Security/Security.h>
#import "RosterListViewController.h"

@import UIKit;
@interface MainMenuViewController () <UIWebViewDelegate>{
    
}
@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic) NSString *token;
//- (IBAction)LoginPressed:(id)sender;
- (IBAction)loginPressed:(id)sender;

@end

@implementation MainMenuViewController
@synthesize webView;


-(void)loadWebView{
    // Do any additional setup after loading the view.
    NSURL *url = [NSURL URLWithString:@"https://auth.teamsnap.com/oauth/authorize?client_id=7e7b3ff662a91f4771164bc0981e0a8cae9bb6049cb9512f42292ac9f88f7c4c&redirect_uri=rsma://callback&response_type=token"];
    //    NSLog(@"url: %@", url);
    NSURLRequest *reqest = [[NSURLRequest alloc] initWithURL:url];
    [webView loadRequest:reqest];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self.view viewWithTag:100].hidden = YES;
    NSLog(@"webViewDidFinishLoad");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    AppDelegate *appdel = [[UIApplication sharedApplication] delegate];
    appdel.currentView = self;
    
    webView.delegate = self;
    [self.view addSubview:webView];
    
    // Start the throbber to check if the user exists
    [_activityIndicator startAnimating];
    _activityIndicator.tag = 100;
    [self.view addSubview:_activityIndicator];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gotToken:) name:@"gotTokenNotifications" object:nil];
    
    //if no cookie is set have user login with TeamSnap credentials
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    //    NSLog(@"checking cookie");
    for(cookie in [cookieJar cookies]){
        //is a team snap cookie
        if([cookie.domain isEqualToString:@"auth.teamsnap.com"]){
            if(![cookie isSessionOnly]){
                //                NSLog(@"set webview to hidden");
                [self loadWebView];
            }
        }
    }
    self.loginButton.hidden = NO;
}

-(void)gotToken:(NSNotification*) notification {
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    [self setToken:appDelegate.token];
    NSLog(@"token: %@", appDelegate.token);
    
    [self performSegueWithIdentifier:@"login" sender:self];
}

-(void)viewWillAppear:(BOOL)animated{
    [self loadWebView];   
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSLog(@"in segue");
    AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if ([[segue identifier] isEqualToString:@"login"]){
        
        /*
         In order to populate the rosterList we have to do a couple queries to TeamSnap
         The first query /me will get a list us the href that allows us to list all
         of the teams associated with the logged in user.
         
         To accomplish this we must parse the serialized JSON response.
         
         Once we have that URL we create another request, the response to which will
         have all of the team data that we will then parse in order to populate the
         rosterList.
         */
        //Create the HTTP manager and format the request for OAUTH bearer token
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        [manager.requestSerializer setValue:@"application.json" forHTTPHeaderField:@"Content-Type"];
        [manager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", _token] forHTTPHeaderField:@"Authorization"];
        
        //perform /me query
        [manager GET:@"https://api.teamsnap.com/v3/me"
          parameters:nil
             success:^(AFHTTPRequestOperation *operation, id responseObject) {
                 //                 NSLog(@"%@",responseObject);
                 //get the links dictionary
                 if([[responseObject[@"collection"][@"items"][0] objectForKey:@"links"] isKindOfClass:[NSDictionary class]]){
                     NSLog(@"links is Dictionary");
                 }
                 if([[responseObject[@"collection"][@"items"][0] objectForKey:@"links"] isKindOfClass:[NSArray class]]){
                     NSLog(@"links is Array of");
                 }
                 NSDictionary *links = [responseObject[@"collection"][@"items"][0] objectForKey:@"links"];
                 /*
                  We are only interested in the teams href. In order to get at it we have to
                  do some more parsing.
                  
                  example of links dictionary structure
                  "links": [
                  {
                  "href": "https://api.teamsnap.com/v3/members/search?user_id=3844886",
                  "rel": "members"
                  },
                  {
                  "href": "https://api.teamsnap.com/v3/teams/search?user_id=3844886",
                  "rel": "teams"
                  }
                  ]
                  */
                 //                 NSLog(@"%@", links[0]);
                 for(id key in links){
                     //we only want the teams entry so no need to iterate over any others
                     if(![key[@"rel"]  isEqual: @"teams"]){
                         //                         NSLog(@"teams URL: %@", key[@"rel"]);
                         continue;
                     }
                     //                     we now have to iterate over the entries in the dictionary
                     for(id key0 in key){
                         //we only want the URL not the word 'teams'
                         if(![key[key0]  isEqual: @"teams"]){
                             NSArray *items = [key[@"href"] componentsSeparatedByString:@"="];
                             //                             NSLog(@"UID: %@",items[1]);
                             appDelegate.userID = items[1];
                             //                             NSLog(@"URL: %@", key[key0]);
                             /*
                              At last we are able to perform the query that will get us a JSON object containing
                              the information about what teams are associated with the logged in user.
                              
                              The query is performed using the URL we parsed out of the initial response
                              that is contained in key[key0]
                              XXXXX Change these names later!! XXXXX
                              */
                             [manager GET:key[key0]
                               parameters:nil
                                  success:^(AFHTTPRequestOperation *operation, id responseObject2) {
                                      //                                 NSLog(@"JSON: %@", responseObject);
                                      NSArray *teamsResponse = responseObject2[@"collection"][@"items"];
                                      //get size of teams array
                                      NSUInteger size = [teamsResponse count];
                                      if([teamsResponse isKindOfClass:[NSDictionary class]]){
                                          NSLog(@"teamsResponse is Dictionary");
                                      }
                                      if([teamsResponse isKindOfClass:[NSArray class]]){
                                          NSLog(@"teamsResponse is Array of length:%lu", (unsigned long)size);
                                      }
                                      //iterate over all teams
                                      for(int i = 0; i < size; i++){
                                          
                                          NSMutableDictionary *rosterEntry = [[NSMutableDictionary alloc] init];
                                          for(id key in teamsResponse[i]){
                                              NSLog(@"key: %@", key);
                                              if([key isEqual:@"data"]){
                                                  NSArray *dataArray = [teamsResponse[i] objectForKey:key];
                                                  NSUInteger dataArraySize = [dataArray count];
                                                  for(int j = 0; j < dataArraySize; j++){
                                                      if(!([[dataArray[j] objectForKey:@"name"] isEqual:@"id"])){
                                                          continue;
                                                      }
                                                      if([[dataArray[j] objectForKey:@"name"] isEqual:@"id"]){
                                                          NSString *idValue = [dataArray[j] objectForKey:@"value"];
                                                          [rosterEntry setObject:idValue forKey:@"id"];
                                                          while(!([[dataArray[j] objectForKey:@"name"] isEqual:@"name"])){
                                                              j++;
                                                          }
                                                          NSString *nameValue = [dataArray[j] objectForKey:@"value"];
                                                          [rosterEntry setObject:nameValue forKey:@"name"];
                                                      }
                                                  }
                                                  
                                              }
                                              if([key isEqual:@"links"]){
                                                  NSArray *linksArray = [teamsResponse[i] objectForKey:key];
                                                  NSUInteger linksArraySize = [linksArray count];
                                                  for(int j = 0; j < linksArraySize; j++){
                                                      if(([[linksArray[j] objectForKey:@"rel"] isEqual:@"events"])){
                                                          NSString *eventsURL = [linksArray[j] objectForKey:@"href"];
                                                          NSLog(@"eventsURL: %@",eventsURL);
                                                          [rosterEntry setObject:eventsURL forKey:@"href"];
                                                      }
                                                      if(([[linksArray[j] objectForKey:@"rel"] isEqual:@"members"])){
                                                          NSString *membersURL = [linksArray[j] objectForKey:@"href"];
                                                          NSLog(@"membersURL: %@",membersURL);
                                                          [rosterEntry setObject:membersURL forKey:@"membershref"];
                                                          
                                                          
                                                          
                                                          //*******RYAN GOING OFF OF DAVIDS CODE HERE TO GET MEMBERS NAMES/IDS
                                                          //*******FOR A SPECIFIC TEAM
                                                          
                                                          
                                                          [manager GET:[rosterEntry objectForKey:@"membershref"]
                                                            parameters:nil
                                                               success:^(AFHTTPRequestOperation *operation, id responseObject3) {
                                                                   NSMutableDictionary* teammates = [[NSMutableDictionary alloc] init]; //create roster for this team
                                                                   
                                                                   //NSLog(@"JSON: %@", responseObject3);
                                                                   NSArray* items3 = responseObject3[@"collection"][@"items"];
                                                                   for (int x = 0; x < [items3 count]; x++){
                                                                       NSArray* dataitems3 = [[items3 objectAtIndex: x] objectForKey:@"data"];
                                                                       NSString* first = nil;
                                                                       NSString* last = nil;
                                                                       NSString* user_id = nil;
                                                                       NSString* full_name = nil;
                                                                       for (int v = 0; v < [dataitems3 count]; v++){
                                                                           
                                                                           if ([[[dataitems3 objectAtIndex: v] objectForKey: @"name"] isEqual: @"first_name"]){
                                                                               first = [[dataitems3 objectAtIndex: v] objectForKey: @"value"];
                                                                               //NSLog(@"first: %@", first);
                                                                           }
                                                                           if ([[[dataitems3 objectAtIndex: v] objectForKey: @"name"] isEqual: @"last_name"]){
                                                                               last = [[dataitems3 objectAtIndex: v] objectForKey: @"value"];
                                                                               NSString* temp = [first stringByAppendingString:@" "];
                                                                               //NSLog(@"last: %@", last);
                                                                               full_name = [temp stringByAppendingString:last];
                                                                               
                                                                           }
                                                                           
                                                                           if ([[[dataitems3 objectAtIndex: v] objectForKey: @"name"] isEqual: @"user_id"]){
                                                                               //NSLog(@"user_id: %@", [[dataitems3 objectAtIndex: v] objectForKey: @"value"]);
                                                                               if ([[dataitems3 objectAtIndex: v] objectForKey: @"value"] == [NSNull null] || [[dataitems3 objectAtIndex: v] objectForKey: @"value"] == nil){
                                                                                   continue;
                                                                               }else{
                                                                                   
                                                                                   user_id = [NSString stringWithFormat:@"%@", [[dataitems3 objectAtIndex: v] objectForKey: @"value"]];
                                                                                   //NSLog(@"Member with ID: %@ %@, id=%@", first, last, user_id);
                                                                                   if (full_name != nil){
                                                                                       teammates[user_id] = full_name;
                                                                                   }else{
                                                                                       teammates[user_id] = @"(no name)";
                                                                                   }
                                                                               }
                                                                           }
                                                                       }
                                                                   }
                                                                   //Finished processing one team, now add the member dictionary to roster entry
                                                                   [rosterEntry setObject:teammates forKey:@"members"];
                                                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //                                                               NSLog(@"Error: %@", error);
                                                                   NSLog(@"error: %@",error.localizedDescription);
                                                                   [[NSNotificationCenter defaultCenter] postNotificationName:@"error" object:error];
                                                               }];
                                                      }
                                                  }
                                              }
                                          }
                                          [appDelegate.rosterList addObject:rosterEntry];
                                      }
                                      [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"reloadRosterlist" object:self]];
                                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                      //                                 NSLog(@"Error: %@", error);
                                      NSLog(@"error: %@",error.localizedDescription);
                                      [[NSNotificationCenter defaultCenter] postNotificationName:@"error" object:error];
                                  }];
                         }
                     }
                 }
             }
             failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                 //                 NSLog(@"Error: %@", error);
                 
                 NSLog(@"error: %@",error.localizedDescription);
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"error" object:error];
                 
             }];
    }
    /** checks if we have the teamsnap cookie. if so it will save the cookie into the teamSnapCookie var in appdel  **/
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSLog(@"cookie stuff");
    for(cookie in [cookieJar cookies]){
        //is a team snap cookie
        if([cookie.domain isEqualToString:@"auth.teamsnap.com"]){
            if([cookie isSessionOnly]){
                AppDelegate *appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
                NSMutableDictionary *teamSnapCookieProperties = [NSMutableDictionary dictionary];
                [teamSnapCookieProperties setObject:cookie.domain forKey:NSHTTPCookieDomain];
                [teamSnapCookieProperties setObject:cookie.value forKey:NSHTTPCookieValue];
                [teamSnapCookieProperties setObject:cookie.name forKey:NSHTTPCookieName];
                [teamSnapCookieProperties setObject:cookie.path forKey:NSHTTPCookiePath];
                [teamSnapCookieProperties setObject:[[NSDate date] dateByAddingTimeInterval:2629743] forKey:NSHTTPCookieExpires];
                
                appDelegate.teamSnapCookie = [NSHTTPCookie cookieWithProperties:teamSnapCookieProperties];
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:appDelegate.teamSnapCookie];
                //                NSLog(@"set team snap cookie: %@", appDelegate.teamSnapCookie);
                break;
            }else{
                //is sessionless already.
                webView.hidden = YES;
                break;
            }
        }
    }
}

-(void)setToken:(NSString *)token{
    _token = token;
    //    NSLog(@"set token Main Menu: %@", token);
}
- (IBAction)loginPressed:(id)sender {
    webView.hidden = NO;
    [self loadWebView];
}
@end
