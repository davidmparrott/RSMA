//
//  RootViewController.h
//  
//
//  Created by David Michael Parrott on 2/10/15.
//
//

#import <UIKit/UIKit.h>

@interface RootViewController : UINavigationController
<UITableViewDelegate, UITableViewDataSource> { NSArray *controllers;
}

@property (nonatomic, retain) NSArray *controllers;
@end
