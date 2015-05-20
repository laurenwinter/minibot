//
//  MinibotDashboardViewController.m
//  MiniBot
//
//  Created by Lauren Winter on 4/14/15.
//  Copyright (c) 2015 WinterRobotik. All rights reserved.
//

#import "MinibotDashboardViewController.h"
#import "RFduinoManager.h"
#import "RFduino.h"

#import "MeterView.h"
#import "F3BarGauge.h"

/** @def CC_DEGREES_TO_RADIANS
 converts degrees to radians
 */
#define CC_DEGREES_TO_RADIANS(__ANGLE__) ((__ANGLE__) * 0.01745329252f) // PI / 180

/** @def CC_RADIANS_TO_DEGREES
 converts radians to degrees
 */
#define CC_RADIANS_TO_DEGREES(__ANGLE__) ((__ANGLE__) * 57.29577951f) // PI * 180

@implementation MinibotDashboardViewController {
 
    CMMotionManager *motionManager;
    NSTimer *timedThread;
    
    int output;
    int value[4];
    
    int lastSpeedValue;
    int lastSteerValue;
    int maxSpeed;
    
    BOOL driveActive;
    BOOL magnetActive;
    BOOL armActive;
    
    NSMutableData *rxData;
    NSString *rxMessage;
    int messagesReceived;
    
    BOOL appInForeground;
    
    __weak IBOutlet UIButton *bleConnectButton;
    __weak IBOutlet UILabel *statusLabel;
    __weak IBOutlet UIButton *driveButton;
    __weak IBOutlet UIButton *weaponButton;
    __weak IBOutlet UIButton *magnetButton;
    
    __weak IBOutlet MeterView *speedometerView;
    
    __weak IBOutlet F3BarGauge *rightBarGauge;
    __weak IBOutlet F3BarGauge *leftBarGauge;
    
    __weak IBOutlet F3BarGauge *accLeftGauge;
    __weak IBOutlet F3BarGauge *accCenterGauge;
    __weak IBOutlet F3BarGauge *accRightGauge;
    
    __weak IBOutlet UIImageView *hudImageBackground;
    
    __weak IBOutlet UIView *rightPanGestureView;
    __weak IBOutlet UIView *leftPanGestureView;
}

int zeroRange = 5;
int zeroSteerRange = 25;
int maxSpeedChange = 20;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        rfduinoManager = [RFduinoManager sharedRFduinoManager];

        // initialize the core motion manager for accelerometer and gyro
        motionManager = [[CMMotionManager alloc] init];
        motionManager.deviceMotionUpdateInterval = 1.0/60.0;
        if (motionManager.isDeviceMotionAvailable) {
            [motionManager startDeviceMotionUpdates];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    rfduinoManager.delegate = self;

    for (int i = 0; i < 4; i++)
        value[i] = 90;
    
    [self.rfduino setDelegate:self];
    
    rxData = [[NSMutableData alloc] init];
    rxMessage = nil;
    messagesReceived = 0;
    
    output = 0;
    
    bleConnectButton.hidden = YES;
    statusLabel.text = @"Scanning for Minibot";
    
    maxSpeed = 100;
    
    lastSteerValue = 0;
    lastSpeedValue = 0;
    
    driveActive = NO;
    
    appInForeground = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification object:nil];
    
    // Speed Meter View
    speedometerView.textLabel.text = @"m/sec";
    speedometerView.textLabel.font = [UIFont fontWithName:@"AvenirNext" size:18.0];
    speedometerView.lineWidth = 1.5;
    speedometerView.minorTickLength = 15.0;
    speedometerView.needle.width = 3.0;
    speedometerView.textLabel.textColor = [UIColor colorWithRed:0.7 green:0.85 blue:0.95 alpha:1.0];
    speedometerView.needle.tintColor = [UIColor redColor];
    speedometerView.value = 0.0;

    // Steering bar gauges
    rightBarGauge.outerBorderColor = UIColor.blackColor;
    rightBarGauge.warningBarColor = UIColor.cyanColor;
    rightBarGauge.warnThreshold = 0.4;
    rightBarGauge.dangerThreshold = 0.8;
    leftBarGauge.outerBorderColor = UIColor.blackColor;
    leftBarGauge.warningBarColor = UIColor.cyanColor;
    leftBarGauge.warnThreshold = 0.4;
    leftBarGauge.dangerThreshold = 0.8;
    leftBarGauge.reverse = YES;
    
    // Acc bar gauges
    accLeftGauge.outerBorderColor = UIColor.blackColor;
    accLeftGauge.holdPeak = YES;
    
    accCenterGauge.outerBorderColor = UIColor.blackColor;
    accCenterGauge.holdPeak = YES;

    accRightGauge.outerBorderColor = UIColor.blackColor;
    accRightGauge.holdPeak = YES;
    
    // Left pan speed control view
    UIPanGestureRecognizer *leftPanGesture = [UIPanGestureRecognizer.alloc initWithTarget:self action:@selector(panSpeedAction:)];
    leftPanGesture.minimumNumberOfTouches = 1;
    leftPanGesture.maximumNumberOfTouches = 1;
    leftPanGesture.delegate = self;
    [leftPanGestureView addGestureRecognizer:leftPanGesture];
    
    // Right pan steer control view
    UIPanGestureRecognizer *rightPanGesture = [UIPanGestureRecognizer.alloc initWithTarget:self action:@selector(panSteerAction:)];
    rightPanGesture.minimumNumberOfTouches = 1;
    rightPanGesture.maximumNumberOfTouches = 1;
    rightPanGesture.delegate = self;
    [rightPanGestureView addGestureRecognizer:rightPanGesture];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [timedThread invalidate];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Was 0.25, trying 0.1 sec
    timedThread = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timeMotionTransmit) userInfo:nil repeats:YES];
}


-(void)appDidBecomeActive:(NSNotification*)note
{
    appInForeground = YES;
}

-(void)appWillResignActive:(NSNotification*)note
{
    appInForeground = NO;
    driveActive = NO;
    magnetActive = NO;
    armActive = NO;
}

-(void)appWillTerminate:(NSNotification*)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    
}

- (void)didReceive:(NSData *)data
{
    //NSLog(@"data = %@", data);
    
    [rxData appendBytes:([data bytes]) length:data.length];
    
    NSString *rxString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    //NSLog(@" : %@", rxString);
    
    [self handleMessage:rxString];
}

- (void) handleMessage:(NSString *)message {
    // NSLog(@"Valid message from robot: %@",message);

    // Parse the x, y and z accel data
    NSRange range = NSMakeRange (0, 4);
    NSString *substring = [message substringWithRange:range];
    NSNumber *intXValue = [NSNumber numberWithInt:[substring intValue]];
    //[self setAccelSprite:damageXSprite value:intXValue.intValue];
    
    range = NSMakeRange (4, 4);
    substring = [message substringWithRange:range];
    NSNumber *intYValue = [NSNumber numberWithInt:[substring intValue]];
    //[self setAccelSprite:damageYSprite value:intYValue.intValue];
    
    range = NSMakeRange (8, 4);
    substring = [message substringWithRange:range];
    NSNumber *intZValue = [NSNumber numberWithInt:[substring intValue]];
    //[self setAccelSprite:damageZSprite value:intZValue.intValue];
    
    accLeftGauge.value = intXValue.floatValue/250.0;
    accCenterGauge.value = intZValue.floatValue/100.0;
    accRightGauge.value = intYValue.floatValue/250.0;
    
    //NSLog(@"x:%d y:%d z:%d", intXValue.intValue, intYValue.intValue, intZValue.intValue);

    statusLabel.text = @""; //[NSString stringWithFormat:@"x:%d y:%d z:%d", intXValue.intValue, intYValue.intValue, intZValue.intValue];
    //[self setDamage:intXValue.intValue accY:intYValue.intValue accZ:intZValue.intValue];
}

-(void) timeMotionTransmit {
    // timed update method that gets device motion and transmits it to the toy

    if (!appInForeground)
        return;
    
    if (!self.rfduino)
        return;
    
    int speed = 0;
    int speedVal = 0;
    int steer = 0;
    int steerVal = 0;
    int weapon = armActive ? 5 : 80; // 80 LEFT, 5 RIGHT
                                      //weapon = weapon + 25;
    int magnet = magnetActive ? 10 : 0; // 0 off, 10 on

    CMDeviceMotion *currentDeviceMotion = motionManager.deviceMotion;
    CMAttitude *currentAttitude = currentDeviceMotion.attitude;
    // Convert the radians yaw value to degrees then round up/down
//    float yaw = roundf((float)(CC_RADIANS_TO_DEGREES(currentAttitude.yaw)));
    
    float pitch = roundf((float)(CC_RADIANS_TO_DEGREES(currentAttitude.pitch)));
    
//    if (lastSteerValue) {
        // Steer with UI control
        steerVal = lastSteerValue;
//    }
//    else {
//        // Linear steering
//        steerVal = ((pitch/60.0f) * -100);
//    }
    
    // Exponential steering
//    BOOL positive = (pitch > 0);
//    int exp = ceil(fabsf(pitch)/10);
//    steerVal = pow(2, exp);
//    if (positive) {
//        steerVal *= -1;
//    }

    //NSLog(@"Pitch %f, exp = %d, Steer %d",pitch, exp, steerVal);

    steerVal = steerVal < zeroSteerRange && steerVal > 0 ? 0 : steerVal > -zeroSteerRange && steerVal < 0 ? 0 : steerVal;
    steerVal = steerVal > 100 ? 100 : (steerVal < -100 ? -100 : steerVal);
    
    
    if (steerVal < 0) {
        leftBarGauge.value = 0;
        rightBarGauge.value = abs(steerVal)/90.0;
    } else {
        leftBarGauge.value = abs(steerVal)/90.0;
        rightBarGauge.value = 0;
    }
//    
//    float roll = roundf((float)(CC_RADIANS_TO_DEGREES(currentAttitude.roll)));
//    if (lastSpeedValue) {
        // Speed with UI control
        speedVal = lastSpeedValue;
//    } else {
//        speedVal = (roll/30.0f) * maxSpeed;
//    }
    
    speedVal = speedVal < zeroRange && speedVal > 0 ? 0 : speedVal > -zeroRange && speedVal < 0 ? 0 : speedVal;
    speedVal = speedVal > maxSpeed ? maxSpeed : (speedVal < -maxSpeed ? -maxSpeed : speedVal);

    speedometerView.value = abs(speedVal);

//    if (driveActive) {
//        steer = steerVal;
//        speed = speedVal;
//        //lastSpeedValue = speed;
//    } else {
        //lastSpeedValue = 0;
        steer = lastSteerValue;
        speed = lastSpeedValue;
        //NSLog(@"lastSpeed fwd = %d", lastSpeedValue);
//}
    
    //NSLog(@"Weapon Val = %d", weapon);
    
    [self sendToBotSteer:steer speed:speed weapon:weapon magnet:magnet];
    
//    NSString *controlString = [NSString stringWithFormat:@"%4d%4d%2d%2d", steer, speed, weapon, magnet];
//    NSData *dataString = [controlString dataUsingEncoding:NSASCIIStringEncoding];
//    //NSLog(@"%@, %@, length = %lu", controlString, dataString, (unsigned long)dataString.length);
//    //NSLog(@"%@", controlString);
//    [self.rfduino send:dataString];
    
    
    
    
    //weapon = weaponValue;

    //NSLog(@"steer: %d    speed: %d", steer, speed);
    
    //float speed = (pitch/30.0f) * 180.0f;
//    float speed = 90.0f + (pitch*3.0f);
//    speed = speed > 180.0 ? 180.0 : (speed < 0.0 ? 0.0 : speed);
//    
//    NSLog(@"yaw: %f    roll: %f     pitch: %f    speed: %f", yaw, roll, pitch, speed);
    
    //    // control the rage of speed schange
    //    //        if (speed > zeroRange && speed > lastSpeedValue) {
    //    //            if (speed - lastSpeedValue > maxSpeedChange) {
    //    //                speed = lastSpeedValue + maxSpeedChange;
    //    //            }
    //    //        } else if (speed < zeroRange && lastSpeedValue - speed > maxSpeedChange) {
    //    //            speed = lastSpeedValue - maxSpeedChange;
    //    //        }
    //    speed = speed < zeroRange && speed > 0 ? 0 : speed > -zeroRange && speed < 0 ? 0 : speed;
    //    speed = speed > maxSpeed ? maxSpeed : (speed < -maxSpeed ? -maxSpeed : speed);
    //
    //    lastSpeedValue = speed;
    //NSLog(@"yaw: %f    roll: %f     pitch: %f", yaw, roll, pitch);
    //NSLog(@"steer: %d    speed: %d", steer, speed);
    
    
//    if (speed == 180) {
//        speed = 179;
//    } else if (speed < 100 && speed > 80) {
//        // zero out this noise
//        speed = 90;
//    }
//    // 90 is zero speed, < 90 is reverse, > 90 is forward
//    int speed2 = 180 - speed;
//    uint8_t bytesAll[] = { speed, speed2 };
//    NSData* dataAll = [NSData dataWithBytes:(void*)&bytesAll length:2];
    
//    } else {
//        lastSpeedValue = 0;
//    }
//    msg = [NSString stringWithFormat:@"%4d%4d%4d", steer, speed, weapon];

//    uint8_t bytesAll[] = { steer, speed, weapon };
//    NSData* dataAll = [NSData dataWithBytes:(void*)&bytesAll length:3];
//    [self.rfduino send:dataAll];
    
}

- (void)sendToBotSteer:(int)steer speed:(int)speed weapon:(int)weapon magnet:(int)magnet
{
    NSString *controlString = [NSString stringWithFormat:@"%4d%4d%2d%2d", steer, speed, weapon, magnet];
    NSData *dataString = [controlString dataUsingEncoding:NSASCIIStringEncoding];
    //NSLog(@"%@, %@, length = %lu", controlString, dataString, (unsigned long)dataString.length);
    //NSLog(@"%@", controlString);
    [self.rfduino send:dataString];

}

- (IBAction)disconnect:(id)sender
{
    NSLog(@"disconnect pressed");
    
    [timedThread invalidate];
    
    [self.rfduino disconnect];
}


- (IBAction)bleConnectAction:(id)sender {
    
    RFduino *rfduino = [[rfduinoManager rfduinos] objectAtIndex:0];
    
//    if (! rfduino.outOfRange) {
        [rfduinoManager connectRFduino:rfduino];
        
        [accLeftGauge resetPeak];
        [accCenterGauge resetPeak];
        [accRightGauge resetPeak];
//    }
}

- (IBAction)driveButtonDownAction:(id)sender {
    driveActive = YES;
}

- (IBAction)driveButtonAction:(UIButton *)sender {
    driveActive = NO;
}

- (IBAction)magnetButtonDownAction:(id)sender {
    //magnetActive = YES;
    armActive = NO;
    hudImageBackground.image = [UIImage imageNamed:@"hud-fuchsia.png"];
}

- (IBAction)magnetButtonAction:(id)sender {
    //magnetActive = NO;
    armActive = YES;
    hudImageBackground.image = [UIImage imageNamed:@"hud-green.png"];
}

- (IBAction)weaponButtonAction:(UIButton *)sender {
    //armActive = NO;
}

- (IBAction)armButtonDownAction:(UIButton *)sender {
    //armActive = YES;
}

#pragma mark - Gesture recognizers
- (void)panSteerAction:(UIPanGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            lastSteerValue = 0;
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint velocity = [recognizer velocityInView:leftPanGestureView];
            // CGFloat magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
            // NSLog(@"right pan velocity: %f, %f, %f", velocity.x, velocity.y, magnitude);
            
            if (fabs(velocity.x) < 100 && abs(lastSteerValue) > 2) {
                lastSteerValue = lastSteerValue > 0 ? 65 : -65;
            } else {
                lastSteerValue = -0.15 * velocity.x;
            }
        }
            break;
        case UIGestureRecognizerStateEnded: {
            
            lastSteerValue = 0;
        }
            break;
        default:
            break;
    }
}

- (void)panSpeedAction:(UIPanGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            lastSpeedValue = 0;
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint position = [recognizer locationInView:leftPanGestureView];
            // NSLog(@"pos = %f", position.y);

            float center = leftPanGestureView.frame.size.height/2;
            
            if (position.y < center) {
                // Forward
                lastSpeedValue = (center - position.y) * (maxSpeed/center) * 1.2;
                // NSLog(@"lastSpeed fwd = %d", lastSpeedValue);

            } else {
                // Reverse
                lastSpeedValue = -1.0 * (position.y - center) * (maxSpeed/center) * 1.2;
                //NSLog(@"lastSpeed rvs = %d", lastSpeedValue);
            }
        }
            break;
        case UIGestureRecognizerStateEnded: {
            
            lastSpeedValue = 0;
            
            //            [self sendToBotSteer:0 speed:0 weapon:0 magnet:0];
            
            
            //            CGPoint velocity = [recognizer velocityInView:leftPanGestureView];
            //            CGFloat magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
            //            NSLog(@"Ended... left pan velocity: %f, %f, %f", velocity.x, velocity.y, magnitude);
            
            //            float slideFactor = 0.00005 * magnitude;
            //            CGPoint finalPoint = CGPointMake(sticker.center.x + (velocity.x * slideFactor),
            //                                             sticker.center.y + (velocity.y * slideFactor));
            //            finalPoint = [self clampToBoundary:finalPoint withSize:sticker.bounds.size];
            //
            //            CGFloat distance = [self distance:sticker.center to:finalPoint] / self.bounds.size.height;
            //            distance *= 0.5;
            //
            //            [self.delegate panelDrawUpdate:self duration:distance];
            //            [UIView animateWithDuration:distance delay:0
            //                                options:kAnimationOptions
            //                             animations:^
            //             {
            //             sticker.center = finalPoint;
            //             } completion:^(BOOL finished) {
            //                 [self.delegate panelDrawUpdate:self duration:0];
            //                 [self.delegate panelChanged:self];
            //             }];
        }
            break;
        default:
            break;
    }
}

//- (void)panSpeedAction:(UIPanGestureRecognizer *)recognizer
//{
//    switch (recognizer.state) {
//        case UIGestureRecognizerStateBegan: {
//            lastSpeedValue = 0;
//        }
//            break;
//        case UIGestureRecognizerStateChanged: {
//            CGPoint velocity = [recognizer velocityInView:leftPanGestureView];
//            // CGFloat magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
//            //NSLog(@"left pan velocity: %f, %f, %f", velocity.x, velocity.y, magnitude);
//            
//            if (fabs(velocity.x) < 100 && abs(lastSpeedValue) > 2) {
//                lastSpeedValue = lastSpeedValue > 0 ? 45 : - 45;
//            } else {
//                lastSpeedValue = -0.1 * velocity.x;
//            }
//            
//            //            int steerVal = -0.1 * velocity.x;
//            //            steerVal = steerVal < zeroSteerRange && steerVal > 0 ? 0 : steerVal > -zeroSteerRange && steerVal < 0 ? 0 : steerVal;
//            //            steerVal = steerVal > 100 ? 100 : (steerVal < -100 ? -100 : steerVal);
//            //
//            //            [self sendToBotSteer:steerVal speed:0 weapon:0 magnet:0];
//            
//            
//        }
//            break;
//        case UIGestureRecognizerStateEnded: {
//            
//            lastSpeedValue = 0;
//            
//            //            [self sendToBotSteer:0 speed:0 weapon:0 magnet:0];
//            
//            
//            //            CGPoint velocity = [recognizer velocityInView:leftPanGestureView];
//            //            CGFloat magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
//            //            NSLog(@"Ended... left pan velocity: %f, %f, %f", velocity.x, velocity.y, magnitude);
//            
//            //            float slideFactor = 0.00005 * magnitude;
//            //            CGPoint finalPoint = CGPointMake(sticker.center.x + (velocity.x * slideFactor),
//            //                                             sticker.center.y + (velocity.y * slideFactor));
//            //            finalPoint = [self clampToBoundary:finalPoint withSize:sticker.bounds.size];
//            //
//            //            CGFloat distance = [self distance:sticker.center to:finalPoint] / self.bounds.size.height;
//            //            distance *= 0.5;
//            //
//            //            [self.delegate panelDrawUpdate:self duration:distance];
//            //            [UIView animateWithDuration:distance delay:0
//            //                                options:kAnimationOptions
//            //                             animations:^
//            //             {
//            //             sticker.center = finalPoint;
//            //             } completion:^(BOOL finished) {
//            //                 [self.delegate panelDrawUpdate:self duration:0];
//            //                 [self.delegate panelChanged:self];
//            //             }];
//        }
//            break;
//        default:
//            break;
//    }
//}

#pragma mark - RfduinoDiscoveryDelegate Manager methods

- (void)didDiscoverRFduino:(RFduino *)rfduino
{
    NSLog(@"didDiscoverRFduino");
    bleConnectButton.hidden = NO;
    statusLabel.text = @"Minibot Found";
}

- (void)didUpdateDiscoveredRFduino:(RFduino *)rfduino
{
    NSLog(@"didUpdateRFduino");
    
}

- (void)didConnectRFduino:(RFduino *)rfduino
{
    NSLog(@"didConnectRFduino");
    statusLabel.text = @"Minibot Active";
    
    [self resetMotion];
    
    [rfduinoManager stopScan];
}

- (void)didLoadServiceRFduino:(RFduino *)rfduino
{
    bleConnectButton.hidden = YES;
    self.rfduino = rfduino;
    [rfduino setDelegate:self];
}

- (void)didDisconnectRFduino:(RFduino *)rfduino
{
    NSLog(@"didDisconnectRFduino");
    
    self.rfduino = nil;
    
    statusLabel.text = @"Minibot Disconnected";

    [self resetMotion];

    [rfduinoManager startScan];
}

- (void)resetMotion
{
    lastSteerValue = 0;
    lastSpeedValue = 0;
}

@end
