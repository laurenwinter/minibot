/*
The sketch accepts a Bluetooth Low Energy 4 connection from an
iPhone and accepts commands from the iPhone to run upto 4
standard servos.

This sketch is suppose to work with the rfduinoServo application.

It receives two bytes from the iPhone.  The first byte contains
the servos to set (bit1 = servo a, bit2 = servo b, etc), and
the value is the number of degrees (0-180) to position the servo
too.
*/

/*
 Copyright (c) 2014 OpenSourceRF.com.  All right reserved.

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 See the GNU Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include <Servo.h>
#include <RFduinoBLE.h>

Servo s1;
Servo s2;
Servo s3;
Servo s4;

int servo1Speed;
int servo2Speed;
bool speedChanged;

void setup() {
  Serial.begin(9600);
  
  servo1Speed = 90;
  servo2Speed = 90;
  speedChanged = false;
  
  s1.attach(2);
  s2.attach(3);
  s3.attach(4);
  s4.attach(5);
  RFduinoBLE.advertisementInterval = 675;
  RFduinoBLE.advertisementData = "-servo";
  RFduinoBLE.begin();
}

void loop() {
  // RFduino_ULPDelay(INFINITE);
  
  while (RFduinoBLE.radioActive);
  
  if (speedChanged) {
    Serial.println("servo 1:");
    Serial.println(servo1Speed);
    Serial.println("servo 2:");
    Serial.println(servo2Speed);

    s1.write(servo1Speed);
    s2.write(servo2Speed);
    speedChanged = false;
  }
}

void RFduinoBLE_onReceive(char *data, int len){
  if (len == 2) {
    speedChanged = true;
    servo1Speed = data[0];
    servo2Speed = data[1];
  }    
//  int servo = data[0];
//  int degree = data[1];
//    
//  if (bitRead(servo, 1)) {
//    //while (RFduinoBLE.radioActive);
//    s1.write(degree);
//  }
//  if (bitRead(servo, 2)){
//    //while (RFduinoBLE.radioActive);
//    s2.write(degree);
//  }
//  if (bitRead(servo, 3)) {
//    //while (RFduinoBLE.radioActive);
//    s3.write(degree);
//  }
//  if (bitRead(servo, 4)) {
//    //while (RFduinoBLE.radioActive);
//    s4.write(degree);
//  }
}
