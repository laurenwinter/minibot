#include <Servo.h>
#include <RFduinoBLE.h>

//Servo s1;
//Servo s2;
//Servo s3;
Servo s4;

int steerValue;
int speedValue;
int weaponValue;

String receiveString;

int servo1Speed;
int servo2Speed;
bool speedChanged;

void setup() {
  //Serial.begin(115200);
    Serial.begin(9600);

  
  servo1Speed = 90;
  servo2Speed = 90;
  speedChanged = false;
  
  //s1.attach(2);
  //s2.attach(3);
  //s3.attach(4);
  s4.attach(5);
  
  //RFDuino setup
  RFduinoBLE.deviceName = "PlanX MiniBot";
  RFduinoBLE.advertisementData = "data";
  RFduinoBLE.advertisementInterval = MILLISECONDS(300);
  RFduinoBLE.txPowerLevel = -20;  // (-20dbM to +4 dBm)
 
  //RFduinoBLE.advertisementInterval = 675;
  
  RFduinoBLE.begin();
  
  //Serial.println("RFduino BLE stack started");

}

void loop() {
  // RFduino_ULPDelay(INFINITE);
  
  while (RFduinoBLE.radioActive);

  //Serial.write("Hello Worldz: ");
  //delay(1000);
  
  if (speedChanged && receiveString.length() > 0) {
    /*
    Serial.println("servo 1:");
    Serial.println(servo1Speed);
    Serial.println("servo 2:");
    Serial.println(servo2Speed);
    */

    // Create the 26 char ARM protocol string and send it
    // "<DRH ddddsssswwww   0   0>" <DRIV-100-100 800   0   0>
    // dddd = Direction (-100 to 100)
    // ssss = Speed (-100 to 100)
    // wwww = Weapon (250 to 800)
    Serial.print("<DRIV");
    Serial.print(receiveString);
    Serial.print("   0   0>");

    
    //s1.write(servo1Speed);
    //s2.write(servo2Speed);
    speedChanged = false;
  }
}

void RFduinoBLE_onReceive(char *data, int len){
  if (len == 12) {
    speedChanged = true;
    receiveString = "";
    
    for (int i = 0; i < len; i++) {
      receiveString += data[i];
    }
    //Serial.println(receiveString);
    //servo1Speed = data[0];
    //servo2Speed = data[1];
  } else {
    Serial.println(len);
    Serial.println(data);
    Serial.println("not 12");  
  }
  
  /*
  int servo = data[0];
  int degree = data[1];
    
  if (bitRead(servo, 1))
    s1.write(degree);
  if (bitRead(servo, 2))
    s2.write(degree);
  if (bitRead(servo, 3))
    s3.write(degree);
  if (bitRead(servo, 4))
    s4.write(degree);
    */
}
