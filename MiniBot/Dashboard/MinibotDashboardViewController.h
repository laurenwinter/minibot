//
//  MinibotDashboardViewController.h
//  MiniBot
//
//  Created by Lauren Winter on 4/14/15.
//  Copyright (c) 2015 WinterRobotik. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <CoreMotion/CoreMotion.h>
#import "RFduino.h"

@interface MinibotDashboardViewController : UIViewController <RFduinoDelegate>

@property(strong, nonatomic) RFduino *rfduino;

@end
