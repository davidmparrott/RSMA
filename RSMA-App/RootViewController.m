//
//  RootViewController.m
//  
//
//  Created by David Michael Parrott on 2/10/15.
//
//

#import "RootViewController.h"
#import "AppDelegate.h"
#import "RosterListViewController.h"


@interface RootViewController ()

@end

@implementation RootViewController
@synthesize controllers;

- (void)viewDidLoad {
    self.title = @"Root Level";
    NSMutableArray *array = [[NSMutableArray alloc] init];
    self.controllers = array;
    //[array release];
    [super viewDidLoad];
//    AppDelegate *appdel = [[UIApplication sharedApplication] delegate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark -
#pragma mark Table Data Source Methods
- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return [self.controllers count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *RootViewControllerCell= @"RootViewControllerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:
                             RootViewControllerCell];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]init];
    }
    // Configure the cell
    NSUInteger row = [indexPath row];
    RosterListViewController *controller = [controllers objectAtIndex:row];
    cell.textLabel.text = controller.title;
    //cell.image = controller.rowImage;
    return cell;
}
#pragma mark -
#pragma mark Table View Delegate Methods
- (UITableViewCellAccessoryType)tableView:(UITableView *)tableView
         accessoryTypeForRowWithIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellAccessoryDisclosureIndicator;
}
- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = [indexPath row];
    RosterListViewController *nextController = [self.controllers
                                                 objectAtIndex:row];
    AppDelegate *delegate =
    [[UIApplication sharedApplication] delegate];
    [delegate.navController pushViewController:nextController
                                      animated:YES];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
