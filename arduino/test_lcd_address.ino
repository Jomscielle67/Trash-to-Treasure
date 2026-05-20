/*
 * I2C LCD ADDRESS SCANNER
 * Upload this to your Arduino to find the correct LCD I2C address
 */

#include <Wire.h>

void setup() {
  Wire.begin();
  Serial.begin(9600);
  
  Serial.println("\n🔍 I2C LCD Address Scanner");
  Serial.println("===========================\n");
  
  delay(1000);
}

void loop() {
  byte error, address;
  int devices = 0;

  Serial.println("Scanning I2C bus...\n");

  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();

    if (error == 0) {
      Serial.print("✅ Device found at 0x");
      if (address < 16) Serial.print("0");
      Serial.print(address, HEX);
      Serial.println(" !");
      
      // Common LCD addresses
      if (address == 0x27) {
        Serial.println("   → This is likely your LCD (0x27)");
      } else if (address == 0x3F) {
        Serial.println("   → This is likely your LCD (0x3F)");
      } else if (address == 0x20) {
        Serial.println("   → This could be your LCD (0x20)");
      }
      
      devices++;
    }
  }

  if (devices == 0) {
    Serial.println("❌ No I2C devices found!");
    Serial.println("\nCheck connections:");
    Serial.println("  - LCD SDA → Arduino A4 (or SDA)");
    Serial.println("  - LCD SCL → Arduino A5 (or SCL)");
    Serial.println("  - LCD VCC → Arduino 5V");
    Serial.println("  - LCD GND → Arduino GND");
  } else {
    Serial.print("\n✅ Found ");
    Serial.print(devices);
    Serial.println(" device(s)\n");
  }

  Serial.println("\n=== Scanning again in 5 seconds ===\n");
  delay(5000);
}
