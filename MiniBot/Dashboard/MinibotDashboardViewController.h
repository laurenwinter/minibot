//
//  MinibotDashboardViewController.h
//  MiniBot
//
//  Created by Lauren Winter on 4/14/15.
//  Copyright (c) 2015 WinterRobotik. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <CoreMotion/CoreMotion.h>
#import "RFduinoManagerDelegate.h"
#import "RFduino.h"

@class RFduinoManager;
@class RFduino;

@interface MinibotDashboardViewController : UIViewController <RFduinoManagerDelegate, RFduinoDelegate>
{
    RFduinoManager *rfduinoManager;
}

@property(strong, nonatomic) RFduino *rfduino;

@end
