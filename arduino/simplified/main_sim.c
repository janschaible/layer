#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef uint8_t byte;

#define SS_RFID 9
#define SS_EEPROM 8
#define S_UNLOCK 7

#define CommandReg 0x01
#define ComIrqReg 0x04
#define DivIrqReg 0x05
#define ErrorReg 0x06
#define FIFODataReg 0x09
#define FIFOLevelReg 0x0A
#define ControlReg 0x0C
#define BitFramingReg 0x0D
#define CollReg 0x0E
#define ModeReg 0x11
#define TxModeReg 0x12
#define RxModeReg 0x13
#define TxControlReg 0x14
#define TxASKReg 0x15
#define CRCResultRegH 0x21
#define CRCResultRegL 0x22
#define ModWidthReg 0x24
#define TModeReg 0x2A
#define TPrescalerReg 0x2B
#define TReloadRegH 0x2C
#define TReloadRegL 0x2D
#define VersionReg 0x37

struct Uid {
  byte size;
  byte uidByte[10];
  byte sak;
} uid;

uint8_t iBlockPCB = 0x02;

void printHex(byte b) { printf("%02X", b); fflush(stdout); }

void printHexSpaced(byte b) { printf("%02X ", b); fflush(stdout); }

void printHexBuf(const byte *data, byte len) {
  for (byte i = 0; i < len; i++) {
    printHexSpaced(data[i]);
  }
}

void wrReg(byte reg, byte val) {
  printf("SPI TX: ");
  printHex(reg << 1);
  printf(" ");
  printHex(val);
  printf("\n");
  fflush(stdout);
}

byte rdReg(byte reg) {
  printf("SPI TX: ");
  printHex(0x80 | (reg << 1));
  printf(" 00");
  printf("\n");
  fflush(stdout);
  return 0x92;
}

byte calculateCRC(byte *data, byte length, byte *result) {
  printf(">>> calculateCRC\n");
  fflush(stdout);
  wrReg(CommandReg, 0x00);
  wrReg(DivIrqReg, 0x04);
  wrReg(FIFOLevelReg, 0x80);
  for (byte i = 0; i < length; i++)
    wrReg(FIFODataReg, data[i]);
  wrReg(CommandReg, 0x03);
  result[0] = 0x00;
  result[1] = 0x00;
  printf("<<< calculateCRC\n");
  fflush(stdout);
  return 1;
}

byte PCD_TransceiveData(byte *sendData, byte sendLen, byte *backData,
                        byte *backLen, byte *validBits, byte rxAlign,
                        bool checkCRC) {

  printf(">>> PCD_TransceiveData (sendLen=%d)\n", sendLen);
  fflush(stdout);
  wrReg(CommandReg, 0x00);
  wrReg(ComIrqReg, 0x7F);
  wrReg(FIFOLevelReg, 0x80);
  for (byte i = 0; i < sendLen; i++)
    wrReg(FIFODataReg, sendData[i]);
  byte bf = (rxAlign << 4) + (validBits ? *validBits : 0);
  wrReg(BitFramingReg, bf);
  wrReg(CommandReg, 0x0C);
  wrReg(BitFramingReg, rdReg(BitFramingReg) | 0x80);

  if (backData && backLen) {
    *backLen = 2;
    backData[0] = 0x00;
    backData[1] = 0x00;
  }
  printf("<<< PCD_TransceiveData\n");
  fflush(stdout);
  return 1;
}

bool PICC_IsNewCardPresent() {
  printf(">>> PICC_IsNewCardPresent\n");
  fflush(stdout);
  wrReg(TxModeReg, 0x00);
  wrReg(RxModeReg, 0x00);
  wrReg(ModWidthReg, 0x26);
  byte buffer[2], bufferSize = sizeof(buffer), cmd = 0x26, validBits = 7;
  bool result = false;
  if (PCD_TransceiveData(&cmd, 1, buffer, &bufferSize, &validBits, 0, false)) {
    if (bufferSize != 2)
      result = false;
    else
      result = true;
  } else {
    result = false;
  }
  printf("<<< PICC_IsNewCardPresent (result=%d)\n", result);
  fflush(stdout);
  return result;
}

bool PICC_ReadCardSerial() {
  printf(">>> PICC_ReadCardSerial\n");
  fflush(stdout);
  uid.size = 0;
  wrReg(CollReg, 0x80);

  byte buffer[9] = {0x93, 0x20};
  byte backData[5], backLen = 5;
  if (!PCD_TransceiveData(buffer, 2, backData, &backLen, NULL, 0, false)) {
    printf("<<< PICC_ReadCardSerial (failed at anticoll)\n");
    fflush(stdout);
    return false;
  }

  buffer[1] = 0x70;
  buffer[2] = backData[0];
  buffer[3] = backData[1];
  buffer[4] = backData[2];
  buffer[5] = backData[3];
  buffer[6] = backData[4];
  byte crc[2];
  if (!calculateCRC(buffer, 7, crc)) {
    printf("<<< PICC_ReadCardSerial (failed at CRC)\n");
    fflush(stdout);
    return false;
  }
  buffer[7] = crc[0];
  buffer[8] = crc[1];

  byte sakBuf[3], sakLen = 3;
  if (!PCD_TransceiveData(buffer, 9, sakBuf, &sakLen, NULL, 0, false)) {
    printf("<<< PICC_ReadCardSerial (failed at select)\n");
    fflush(stdout);
    return false;
  }

  uid.size = 4;
  for (byte i = 0; i < 4; i++)
    uid.uidByte[i] = backData[i];
  uid.sak = sakBuf[0];
  printf("<<< PICC_ReadCardSerial (ok)\n");
  fflush(stdout);
  return true;
}

bool sendIBlock(byte *payload, byte payloadLen, byte *response,
                byte *responseLen) {
  printf(">>> sendIBlock (payloadLen=%d)\n", payloadLen);
  fflush(stdout);
  byte frame[64];
  frame[0] = iBlockPCB;
  memcpy(frame + 1, payload, payloadLen);
  wrReg(FIFOLevelReg, 0x80);
  bool ok = PCD_TransceiveData(frame, payloadLen + 1, response, responseLen,
                               NULL, 0, false) == 1;
  if (ok)
    iBlockPCB ^= 0x01;
  printf("<<< sendIBlock (ok=%d)\n", ok);
  fflush(stdout);
  return ok;
}

bool doRATS(byte *response, byte *responseLen) {
  printf(">>> doRATS\n");
  fflush(stdout);
  byte rats[] = {0xE0, 0x50};
  wrReg(TxModeReg, 0x80);
  wrReg(RxModeReg, 0x00);
  byte status = PCD_TransceiveData(rats, sizeof(rats), response, responseLen,
                                   NULL, 0, false);
  if (status == 1) {
    wrReg(RxModeReg, 0x80);
    wrReg(BitFramingReg, 0x00);
    wrReg(TModeReg, 0x8D);
    wrReg(TPrescalerReg, 0x3E);
    printf("<<< doRATS (ok)\n");
    fflush(stdout);
    return true;
  } else {
    printf("<<< doRATS (failed)\n");
    fflush(stdout);
    return false;
  }
}

void get_EEPROM(byte *buffer, byte length, byte address, byte command) {
  printf("EEPROM TX: %02X %02X\n", command, address);
}

int main() {
  printf("\n\n==================================\n");
  printf("   LAYR GUARDIAN - DEBUG MODE\n");
  printf("==================================\n");

  printf("[1] SPI Bus Started (mock)\n");

  wrReg(CommandReg, 0x0F);
  rdReg(CommandReg);

  wrReg(TxModeReg, 0x00);
  wrReg(RxModeReg, 0x00);
  wrReg(ModWidthReg, 0x26);
  wrReg(TModeReg, 0x80);
  wrReg(TPrescalerReg, 0xA9);
  wrReg(TReloadRegH, 0x03);
  wrReg(TReloadRegL, 0xE8);
  wrReg(TxASKReg, 0x40);
  wrReg(ModeReg, 0x3D);

  byte tc = rdReg(TxControlReg);
  if ((tc & 0x03) != 0x03)
    wrReg(TxControlReg, tc | 0x03);

  printf("[2] Reader Firmware Version: 0x");
  byte v = rdReg(VersionReg);
  printf("%02X\n\n", v);
  fflush(stdout);

  if (v == 0x00 || v == 0xFF) {
    printf("!!! CRITICAL FAILURE !!!\n");
    return 1;
  }

  printf("Ready — simulating card read...\n\n");

  printf("=== CARD DETECTION LOOP ===\n");
  fflush(stdout);
  iBlockPCB = 0x02;

  if (!PICC_IsNewCardPresent()) {
    printf("No card present, exiting\n");
    return 0;
  }
  if (!PICC_ReadCardSerial()) {
    printf("Failed to read card serial\n");
    return 0;
  }

  printf("=== ISO-DEP ESTABLISHMENT ===\n");
  fflush(stdout);
  wrReg(TxModeReg, 0x80);

  byte atsBuffer[32], atsLen = sizeof(atsBuffer);
  if (!doRATS(atsBuffer, &atsLen)) {
    printf("RATS failed\n");
    goto halt;
  }

  printf("=== APPLICATION SELECT ===\n");
  fflush(stdout);
  {
    byte selectCmd[] = {0x00, 0xA4, 0x04, 0x00, 0x06, 0xF0,
                        0x00, 0x00, 0x0C, 0xDC, 0x00};
    byte selectResp[32], selectLen = sizeof(selectResp);

    if (sendIBlock(selectCmd, sizeof(selectCmd), selectResp, &selectLen) != 1) {
      printf("FIFO failed\n");
      goto halt;
    }

    printf("=== GET CARD ID ===\n");
    fflush(stdout);
    byte getIdCmd[] = {0x80, 0x12, 0x00, 0x00, 0x00};
    byte idRespRFID[32], idLen = sizeof(idRespRFID);

    if (sendIBlock(getIdCmd, sizeof(getIdCmd), idRespRFID, &idLen) != 1)
      goto halt;

    printf("\nCard UID: ");
    for (byte i = 0; i < idLen; i++) {
      printHexSpaced(idRespRFID[i]);
    }
    printf("\n");

    printf("=== EEPROM VERIFY ===\n");
    fflush(stdout);
    byte idRespEEPROM[16];
    get_EEPROM(idRespEEPROM, 16, 0x00, 0x03);

    printf("\n[ACCESS GRANTED]\n");
  }

halt:
  wrReg(TxModeReg, 0x00);
  return 0;
}
