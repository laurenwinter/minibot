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
    
    BOOL driveActive;
    
    NSMutableData *rxData;
    NSString *rxMessage;
    int messagesReceived;
    
    __weak IBOutlet UIButton *bleConnectButton;
    __weak IBOutlet UILabel *statusLabel;
    __weak IBOutlet UIButton *driveButton;
    __weak IBOutlet UIButton *weaponButton;
    __weak IBOutlet UIButton *magnetButton;
    
    __weak IBOutlet MeterView *speedometerView;

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
    
    driveActive = NO;
    
    // Meter View
    speedometerView.textLabel.text = @"km/h";
    speedometerView.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-BoldItalic" size:18.0];
    speedometerView.lineWidth = 2.5;
    speedometerView.minorTickLength = 15.0;
    speedometerView.needle.width = 3.0;
    speedometerView.textLabel.textColor = [UIColor colorWithRed:0.7 green:1.0 blue:1.0 alpha:1.0];
    
    speedometerView.value = 0.0;
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [timedThread invalidate];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    timedThread = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(timeMotionTransmit) userInfo:nil repeats:YES];
}

- (void)didReceive:(NSData *)data
{
    NSLog(@"data = %@", data);
    
    [rxData appendBytes:([data bytes]) length:data.length];
    
    NSString *rxString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSLog(@" : %@", rxString);
}

- (void)parseData {
    return;
    
    NSString *rxString = [[NSString alloc] initWithData:rxData encoding:NSASCIIStringEncoding];
    NSLog(@"ASCII bytes read: %@", rxString);
    rxMessage = nil;
    for (int i = 0; i < [rxString length]; i++) {
        char c = [rxString characterAtIndex:i];
        if (c == '<') {
            // beginning of a message string
            rxMessage = @"<";
        } else if (c == '>') {
            // end of a message string
            if ([rxMessage length] == 25) {
                // valid message
                rxMessage = [rxMessage stringByAppendingString:@">"];
                [self handleMessage:rxMessage];
                rxMessage = nil;
                messagesReceived++;
                // remove all buffer chars up through the >
                [rxData replaceBytesInRange:NSMakeRange(0, i + 1) withBytes:NULL length:0];
                break;
            }
        } else if (c == '#') {
            // ping message
            NSLog(@"Ping from robot");
            messagesReceived++;
            rxMessage = nil;
            // remove all buffer chars up through the #
            [rxData replaceBytesInRange:NSMakeRange(0, i + 1) withBytes:NULL length:0];
        } else if (i > 0 && rxMessage != nil && [rxMessage length] > 0 && [rxMessage length] < 25) {
            // a char so append to the rxMessage
            rxMessage = [NSString stringWithFormat:@"%@%c", rxMessage, c];
        }
    }
    if ([rxData length] > 100) {
        [rxData replaceBytesInRange:NSMakeRange(0, [rxData length]) withBytes:NULL length:0];;
    }
}

- (void) handleMessage:(NSString *)message {
    NSLog(@"Valid message from robot: %@",message);
//    NSRange textRange;
//    textRange =[message rangeOfString:@"ACCL"];
//    
//    if(textRange.location != NSNotFound)
//        {
//        // Driver is alive
//        [statusSprite setTexture:[[CCTextureCache sharedTextureCache] addImage:@"lego_dist1.png"]];
//        [driverSprite setTexture:[[CCTextureCache sharedTextureCache] addImage:@"lego_leds_big1.png"]];
//        driverAlive = YES;
//        
//        }
//    
//    textRange =[message rangeOfString:@"ACCD"];
//    if(textRange.location != NSNotFound)
//        {
//        // // Driver is dead
//        [statusSprite setTexture:[[CCTextureCache sharedTextureCache] addImage:@"lego_fail5.png"]];
//        [driverSprite setTexture:[[CCTextureCache sharedTextureCache] addImage:@"lego_leds_big2.png"]];
//        driverAlive = NO;
//        }
//    
//    // Parse the x, y and z accel data
//    NSRange range = NSMakeRange (5, 4);
//    NSString *substring = [message substringWithRange:range];
//    NSNumber *intXValue = [NSNumber numberWithInt:[substring intValue]];
//    [self setAccelSprite:damageXSprite value:intXValue.intValue];
//    
//    range = NSMakeRange (9, 4);
//    substring = [message substringWithRange:range];
//    NSNumber *intYValue = [NSNumber numberWithInt:[substring intValue]];
//    [self setAccelSprite:damageYSprite value:intYValue.intValue];
//    
//    range = NSMakeRange (13, 4);
//    substring = [message substringWithRange:range];
//    NSNumber *intZValue = [NSNumber numberWithInt:[substring intValue]];
//    [self setAccelSprite:damageZSprite value:intZValue.intValue];
//    
//    [self setDamage:intXValue.intValue accY:intYValue.intValue accZ:intZValue.intValue];
//    
//    range = NSMakeRange (17, 4);
//    substring = [message substringWithRange:range];
//    NSNumber *intValue = [NSNumber numberWithInt:[substring intValue]];
//    //NSLog(@"Sonar = %@", intValue);
//    
//    range = NSMakeRange (21, 4);
//    substring = [message substringWithRange:range];
//    intValue = [NSNumber numberWithInt:[substring intValue]];
//    //NSLog(@"Commands = %@", intValue);
}

-(void) timeMotionTransmit {
    // timed update method that gets device motion and transmits it to the toy

    if (!self.rfduino)
        return;
    
    int speed = 0;
    int steer = 0;
    int weapon = 800; // 800 off, 250 on
                      //NSString* msg = @"";

    if (driveActive) {

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
    } else {
        lastSpeedValue = 0;
    }
    
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
    
    speedometerView.value = speed;
    
    NSString *controlString = [NSString stringWithFormat:@"%4d%4d%4d", steer, speed, weapon];
    NSData *dataString = [controlString dataUsingEncoding:NSASCIIStringEncoding];
    //NSLog(@"%@, %@, length = %lu", controlString, dataString, (unsigned long)dataString.length);
    NSLog(@"%@", controlString);
    [self.rfduino send:dataString];
    
    [self parseData];
}

- (IBAction)disconnect:(id)sender
{
    NSLog(@"disconnect pressed");
    
    [timedThread invalidate];
    
    [self.rfduino disconnect];
}


- (IBAction)bleConnectAction:(id)sender {
    
    RFduino *rfduino = [[rfduinoManager rfduinos] objectAtIndex:0];
    
    if (! rfduino.outOfRange) {
        [rfduinoManager connectRFduino:rfduino];
    }
}

- (IBAction)driveButtonDownAction:(id)sender {
    driveActive = YES;
}

- (IBAction)driveButtonAction:(UIButton *)sender {
    driveActive = NO;
}

- (IBAction)magnetButtonAction:(id)sender {
}

- (IBAction)weaponButtonAction:(id)sender {
}

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

    [rfduinoManager startScan];
}

@end
