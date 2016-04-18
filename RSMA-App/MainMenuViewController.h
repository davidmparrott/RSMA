//
//  MainMenuViewController.h
//  RSMA-App
//
//  Created by David on 2/8/15.
//  Copyright (c) 2015 Slyter, Ryan Douglas. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MainMenuViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIWebView *webView;
//@property (strong, nonatomic) IBOutlet UIWebView *webView;

-(void)loadWebView;
@end
