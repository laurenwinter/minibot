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
    int maxSpeed;
    
    __weak IBOutlet UIButton *bleConnectButton;
    __weak IBOutlet UILabel *statusLabel;
    __weak IBOutlet UIButton *driveButton;
    __weak IBOutlet UIButton *weaponButton;
    __weak IBOutlet UIButton *magnetButton;
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
    
    UIColor *start = [UIColor colorWithRed:58/255.0 green:108/255.0 blue:183/255.0 alpha:0.15];
    UIColor *stop = [UIColor colorWithRed:58/255.0 green:108/255.0 blue:183/255.0 alpha:0.45];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    //gradient.frame = [self.view bounds];
    gradient.frame = CGRectMake(0, 0, 1024, 1024);
    gradient.colors = [NSArray arrayWithObjects:(id)start.CGColor, (id)stop.CGColor, nil];
    [self.view.layer insertSublayer:gradient atIndex:0];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    
    [tap setCancelsTouchesInView:NO];
    [self.view addGestureRecognizer:tap];
    
    output = 0;
    
    bleConnectButton.hidden = YES;
    statusLabel.text = @"Scanning for Minibot";
    
    maxSpeed = 100;
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [timedThread invalidate];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    timedThread = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeMotionTransmit) userInfo:nil repeats:YES];
}

-(void) timeMotionTransmit {
    // timed update method that gets device motion and transmits it to the toy

    int speed = 0;
    int steer = 0;
    int weapon = 800; // 800 off, 250 on
    NSString* msg = @"";

    //if (deadmanEnabled && driverAlive) {

    CMDeviceMotion *currentDeviceMotion = motionManager.deviceMotion;
    CMAttitude *currentAttitude = currentDeviceMotion.attitude;
    // Convert the radians yaw value to degrees then round up/down
//    float yaw = roundf((float)(CC_RADIANS_TO_DEGREES(currentAttitude.yaw)));
    
    float pitch = roundf((float)(CC_RADIANS_TO_DEGREES(currentAttitude.pitch)));
    steer = ((pitch/60.0f) * -100);
    steer = steer < zeroSteerRange && steer > 0 ? 0 : steer > -zeroSteerRange && steer < 0 ? 0 : steer;
    steer = steer > 100 ? 100 : (steer < -100 ? -100 : steer);
    
    float roll = roundf((float)(CC_RADIANS_TO_DEGREES(currentAttitude.roll)));
    speed = (roll/30.0f) * maxSpeed;
    speed = speed < zeroRange && speed > 0 ? 0 : speed > -zeroRange && speed < 0 ? 0 : speed;
    speed = speed > maxSpeed ? maxSpeed : (speed < -maxSpeed ? -maxSpeed : speed);
    
    lastSpeedValue = speed;
    
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
    
    NSString *controlString = [NSString stringWithFormat:@"%4d%4d%4d", steer, speed, weapon];
    NSData *dataString = [controlString dataUsingEncoding:NSASCIIStringEncoding];
    NSLog(@"%@, %@, length = %lu", controlString, dataString, (unsigned long)dataString.length);
    [self.rfduino send:dataString];
}

- (IBAction)disconnect:(id)sender
{
    NSLog(@"disconnect pressed");
    
    [timedThread invalidate];
    
    [self.rfduino disconnect];
}


- (IBAction)bleConnectAction:(id)sender {
}

- (IBAction)driveButtonAction:(id)sender {
}

- (IBAction)magnetButtonAction:(id)sender {
}

- (IBAction)weaponButtonAction:(id)sender {
}

#pragma mark - RfduinoDiscoveryDelegate methods

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
    
    [rfduinoManager stopScan];
}

- (void)didLoadServiceRFduino:(RFduino *)rfduino
{
//    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
//    MinibotDashboardViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"dashboardViewController"];
//    viewController.rfduino = rfduino;
//    
//    [[self navigationController] pushViewController:viewController animated:YES];
}

- (void)didDisconnectRFduino:(RFduino *)rfduino
{
    NSLog(@"didDisconnectRFduino");
    
    [rfduinoManager startScan];
}

@end
