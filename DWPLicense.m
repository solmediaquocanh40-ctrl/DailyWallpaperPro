// DWPLicense.m — DailyWallpaperPro 1.0.11
// Mang nguyen mau FG5License cua Fake5G 1.1.13 (da chay that tren may
// anh) sang, doi tien to DWP + them BUOC MA MAY cho key phu theo yeu cau
// cua anh: key phu chi kich hoat duoc tren dung 1 may co ma may khop.

#import "DWPLicense.h"
#import "DWPShared.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>

static NSString * const DWP_LIC_KEY       = @"licenseKey";
static NSString * const DWP_LIC_TRIAL     = @"trialStart";
static NSString * const DWP_LIC_MAXSEEN   = @"maxSeen";
static NSString * const DWP_LIC_ACT       = @"actStart";
static NSString * const DWP_LIC_ACTHASH   = @"actKeyHash";

#pragma mark - Ma may

static NSString *DWPRawDeviceID(void) {
    static NSString *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *found = nil;
        // MGCopyAnswer nhan CFStringRef (khai bao trong MobileGestalt.h cua
        // Theos). Ban 1.0.5 khai bao prototype SAI kieu const char* va
        // truyen UTF8String — ham doi con tro chuoi C thanh object nen
        // vang ngay lan goi dau tien, dung luc trang Cai dat hien o Ma may
        // (bang chung log 1.0.5: specifiers nap xong 46 muc nhung khong co
        // dong hoan tat doc dinh danh, vang 2/2 lan mo trang).
        DWPLog(@"ban quyen: doc dinh danh may — bat dau (MGCopyAnswer)");
        CFTypeRef (*mgCopyAnswer)(CFStringRef) = (CFTypeRef (*)(CFStringRef))dlsym(RTLD_DEFAULT, "MGCopyAnswer");
        if (mgCopyAnswer) {
            for (NSString *q in @[@"UniqueDeviceID", @"SerialNumber"]) {
                CFTypeRef v = mgCopyAnswer((__bridge CFStringRef)q);
                if (v) {
                    id obj = CFBridgingRelease(v);
                    if ([obj isKindOfClass:[NSString class]] && [(NSString *)obj length] > 0) { found = obj; break; }
                }
            }
        }
        DWPLog(@"ban quyen: doc dinh danh may — MGCopyAnswer %@", found ? @"CO ket qua" : @"khong co, lui ve IOKit");
        if (!found) {
            io_service_t svc = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                           IOServiceMatching("IOPlatformExpertDevice"));
            if (svc) {
                CFTypeRef v = IORegistryEntryCreateCFProperty(svc, CFSTR("IOPlatformUUID"),
                                                              kCFAllocatorDefault, 0);
                if (v) {
                    id obj = CFBridgingRelease(v);
                    if ([obj isKindOfClass:[NSString class]] && [(NSString *)obj length] > 0) found = obj;
                }
                IOObjectRelease(svc);
            }
        }
        cached = found ?: @"";
        DWPLog(@"ban quyen: doc dinh danh may %@ (dai %lu)", found ? @"OK" : @"THAT BAI — dung chuoi rong",
               (unsigned long)cached.length);
    });
    return cached;
}

NSString *DWPLicenseMachineCode(void) {
    NSData *d = [DWPRawDeviceID() dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(d.bytes, (CC_LONG)d.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:16];
    for (int i = 0; i < 8; i++) [hex appendFormat:@"%02X", digest[i]];
    return [NSString stringWithFormat:@"%@-%@-%@-%@",
            [hex substringWithRange:NSMakeRange(0, 4)], [hex substringWithRange:NSMakeRange(4, 4)],
            [hex substringWithRange:NSMakeRange(8, 4)], [hex substringWithRange:NSMakeRange(12, 4)]];
}

// Dau buoc may nam trong payload da ky: SHA-256(ma may chuan hoa)[:8]
static NSData *DWPMachineBinding(void) {
    NSString *norm = [[DWPLicenseMachineCode() stringByReplacingOccurrencesOfString:@"-" withString:@""]
                      uppercaseString];
    NSData *d = [norm dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(d.bytes, (CC_LONG)d.length, digest);
    return [NSData dataWithBytes:digest length:8];
}

#pragma mark - Kho 3 noi cho moc ban quyen (prefs + Keychain + file)

static NSString *DWPKeyHash(NSString *key) {
    NSData *d = [[key uppercaseString] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(d.bytes, (CC_LONG)d.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:16];
    for (int i = 0; i < 8; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

static NSString *DWPStateFilePath(void) {
    return @"/var/mobile/Documents/.dwpstate";
}

static void DWPParseStateString(NSString *s, NSTimeInterval *start, NSTimeInterval *maxSeen, NSTimeInterval *act, NSString **actHash) {
    if (![s isKindOfClass:[NSString class]] || s.length == 0) return;
    NSArray<NSString *> *parts = [s componentsSeparatedByString:@"|"];
    if (parts.count >= 1 && [parts[0] doubleValue] > 0) {
        *start = (*start > 0) ? MIN(*start, [parts[0] doubleValue]) : [parts[0] doubleValue];
    }
    if (parts.count >= 2 && [parts[1] doubleValue] > 0) *maxSeen = MAX(*maxSeen, [parts[1] doubleValue]);
    if (parts.count >= 3 && [parts[2] doubleValue] > 0) {
        if (*act <= 0 || [parts[2] doubleValue] < *act) {
            *act = [parts[2] doubleValue];
            if (actHash) *actHash = (parts.count >= 4) ? parts[3] : @"";
        }
    }
}

static NSString *DWPKeychainStateString(void) {
    NSDictionary *q = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"com.anhdang.dailywallpaperpro.state",
        (__bridge id)kSecAttrAccount: @"state",
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef out = NULL;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)q, &out);
    if (st != errSecSuccess || !out) return nil;
    NSData *d = CFBridgingRelease(out);
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}

static void DWPKeychainSetStateString(NSString *s) {
    NSDictionary *q = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"com.anhdang.dailywallpaperpro.state",
        (__bridge id)kSecAttrAccount: @"state"
    };
    SecItemDelete((__bridge CFDictionaryRef)q);
    NSMutableDictionary *add = [q mutableCopy];
    add[(__bridge id)kSecValueData] = [s dataUsingEncoding:NSUTF8StringEncoding];
    add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
}

static NSString *DWPFileStateString(void) {
    NSData *d = [NSData dataWithContentsOfFile:DWPStateFilePath()];
    if (!d || d.length == 0) return nil;
    NSMutableData *plain = [NSMutableData dataWithLength:d.length];
    const unsigned char *in = d.bytes;
    unsigned char *out = plain.mutableBytes;
    const char *mask = "DWPK";
    for (NSUInteger i = 0; i < d.length; i++) out[i] = in[i] ^ (unsigned char)mask[i % 4] ^ 0x5A;
    return [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
}

static void DWPFileSetStateString(NSString *s) {
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *obf = [NSMutableData dataWithLength:d.length];
    const unsigned char *in = d.bytes;
    unsigned char *out = obf.mutableBytes;
    const char *mask = "DWPK";
    for (NSUInteger i = 0; i < d.length; i++) out[i] = in[i] ^ (unsigned char)mask[i % 4] ^ 0x5A;
    [obf writeToFile:DWPStateFilePath() atomically:YES];
}

static void DWPLoadState(NSTimeInterval *startOut, NSTimeInterval *maxSeenOut, NSTimeInterval *actOut, NSString **actHashOut, BOOL *dirtyOut) {
    NSTimeInterval start = 0, maxSeen = 0, act = 0;
    NSString *actHash = @"";
    id ps = DWPPrefObject(DWP_LIC_TRIAL);
    id pm = DWPPrefObject(DWP_LIC_MAXSEEN);
    id pa = DWPPrefObject(DWP_LIC_ACT);
    id ph = DWPPrefObject(DWP_LIC_ACTHASH);
    if ([ps isKindOfClass:[NSNumber class]] && [ps doubleValue] > 0) start = [ps doubleValue];
    if ([pm isKindOfClass:[NSNumber class]] && [pm doubleValue] > 0) maxSeen = [pm doubleValue];
    if ([pa isKindOfClass:[NSNumber class]] && [pa doubleValue] > 0) act = [pa doubleValue];
    if ([ph isKindOfClass:[NSString class]]) actHash = ph;
    DWPParseStateString(DWPKeychainStateString(), &start, &maxSeen, &act, &actHash);
    DWPParseStateString(DWPFileStateString(), &start, &maxSeen, &act, &actHash);

    NSTimeInterval nowReal = [[NSDate date] timeIntervalSince1970];
    BOOL dirty = NO;
    if (start <= 0) { start = nowReal; dirty = YES; }
    NSTimeInterval effNow = MAX(nowReal, maxSeen);
    if (effNow > maxSeen + 60) { maxSeen = effNow; dirty = YES; }
    if (dirtyOut) *dirtyOut = dirty;
    if (startOut) *startOut = start;
    if (maxSeenOut) *maxSeenOut = effNow;
    if (actOut) *actOut = act;
    if (actHashOut) *actHashOut = actHash;
}

static void DWPPersistState(NSTimeInterval start, NSTimeInterval maxSeen, NSTimeInterval act, NSString *actHash) {
    DWPSetPref(DWP_LIC_TRIAL, @((long long)start));
    DWPSetPref(DWP_LIC_MAXSEEN, @((long long)maxSeen));
    DWPSetPref(DWP_LIC_ACT, @((long long)act));
    DWPSetPref(DWP_LIC_ACTHASH, actHash ?: @"");
    NSString *s = [NSString stringWithFormat:@"%lld|%lld|%lld|%@",
                   (long long)start, (long long)maxSeen, (long long)act, actHash ?: @""];
    DWPKeychainSetStateString(s);
    DWPFileSetStateString(s);
}

#pragma mark - Kiem key ECDSA P-256

// Khoa cong khai (diem chua nen 65 byte, base64) — cap voi private_key.pem
// giu rieng o ~/workspace/DailyWallpaperPro-license/, KHONG len GitHub.
static NSString * const DWPPublicKeyB64 =
    @"BO//8vQnFg+rV92hXMHhWWHHGUchPWKbHBKPCHb1Wau0rmmELzRtS5er83XdU2J4Yy8sVCe2LCSBWLBPC7PyOqg=";

static NSData *DWPBase32Decode(NSString *s) {
    static const char *alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    NSMutableData *out = [NSMutableData data];
    int buffer = 0, bitsLeft = 0;
    for (NSUInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '=') break;
        const char *p = strchr(alpha, (char)c);
        if (!p) return nil;
        buffer = (buffer << 5) | (int)(p - alpha);
        bitsLeft += 5;
        if (bitsLeft >= 8) {
            bitsLeft -= 8;
            unsigned char byte = (unsigned char)((buffer >> bitsLeft) & 0xFF);
            [out appendBytes:&byte length:1];
        }
    }
    return out;
}

static BOOL DWPVerifyKey(NSString *key, NSInteger *kindOut, NSString **nameOut, BOOL *machineMismatchOut) {
    if (machineMismatchOut) *machineMismatchOut = NO;
    if (![key isKindOfClass:[NSString class]]) return NO;
    NSString *clean = [[key uppercaseString] stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    clean = [clean stringByReplacingOccurrencesOfString:@"-" withString:@""];
    clean = [clean stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (![clean hasPrefix:@"DWP1"]) return NO;
    NSData *blob = DWPBase32Decode([clean substringFromIndex:4]);
    if (!blob || blob.length < 8 + 40) return NO;
    const unsigned char *b = blob.bytes;
    if (memcmp(b, "DWPK", 4) != 0 || b[4] != 1) return NO;
    NSInteger kind = b[5];
    if (kind != 1 && kind != 3 && kind != 4) return NO;
    NSUInteger nameLen = b[6];
    NSUInteger payloadLen = 7 + nameLen + (kind == 3 ? 8 : 0);
    if (blob.length <= payloadLen) return NO;
    NSString *name = [[NSString alloc] initWithBytes:b + 7 length:nameLen encoding:NSUTF8StringEncoding];
    if (!name) return NO;
    if (kind == 3) {
        NSData *bound = [blob subdataWithRange:NSMakeRange(7 + nameLen, 8)];
        if (![bound isEqualToData:DWPMachineBinding()]) {
            if (machineMismatchOut) *machineMismatchOut = YES;
            return NO;
        }
    }
    NSData *payload = [blob subdataWithRange:NSMakeRange(0, payloadLen)];
    NSData *sigDER = [blob subdataWithRange:NSMakeRange(payloadLen, blob.length - payloadLen)];

    NSData *pubRaw = [[NSData alloc] initWithBase64EncodedString:DWPPublicKeyB64 options:0];
    if (!pubRaw || pubRaw.length != 65) return NO;
    NSDictionary *attrs = @{
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
        (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPublic,
        (__bridge id)kSecAttrKeySizeInBits: @256
    };
    CFErrorRef err = NULL;
    SecKeyRef pub = SecKeyCreateWithData((__bridge CFDataRef)pubRaw,
                                           (__bridge CFDictionaryRef)attrs, &err);
    if (!pub) { if (err) CFRelease(err); return NO; }
    // Chu ky trong key la DER — dung dinh dang X962 doi (bai hoc ZUS 1.2.x)
    BOOL ok = SecKeyVerifySignature(pub, kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                    (__bridge CFDataRef)payload, (__bridge CFDataRef)sigDER, &err);
    if (err) CFRelease(err);
    CFRelease(pub);
    if (!ok) return NO;
    if (kindOut) *kindOut = kind;
    if (nameOut) *nameOut = name;
    return YES;
}

#pragma mark - API ban quyen

DWPLicState DWPLicenseCurrentState(NSInteger *daysLeftOut, NSString **nameOut) {
    NSTimeInterval start = 0, effNow = 0, act = 0;
    NSString *actHash = @"";
    BOOL dirty = NO;
    DWPLoadState(&start, &effNow, &act, &actHash, &dirty);
    if (dirty) DWPPersistState(start, effNow, act, actHash);

    id savedObj = DWPPrefObject(DWP_LIC_KEY);
    NSString *savedKey = [savedObj isKindOfClass:[NSString class]] ? savedObj : @"";
    NSInteger kind = 0;
    NSString *name = nil;
    if (savedKey.length > 0 && DWPVerifyKey(savedKey, &kind, &name, NULL)) {
        if (nameOut) *nameOut = name;
        if (kind == 1) {
            if (daysLeftOut) *daysLeftOut = -1;
            return DWPLicStatePermanent;
        }
        if (act <= 0) {
            act = effNow;
            actHash = DWPKeyHash(savedKey);
            DWPPersistState(start, effNow, act, actHash);
        }
        NSTimeInterval remain = (act + 3 * 86400) - effNow;
        if (remain > 0) {
            if (daysLeftOut) *daysLeftOut = (NSInteger)ceil(remain / 86400.0);
            return DWPLicStateTimed;
        }
        if (daysLeftOut) *daysLeftOut = 0;
        return DWPLicStateTimedExpired;
    }

    NSTimeInterval remain = (start + 3 * 86400) - effNow;
    if (remain > 0) {
        if (daysLeftOut) *daysLeftOut = (NSInteger)ceil(remain / 86400.0);
        return DWPLicStateTrial;
    }
    if (daysLeftOut) *daysLeftOut = 0;
    return DWPLicStateTrialExpired;
}

BOOL DWPLicenseActive(void) {
    DWPLicState st = DWPLicenseCurrentState(NULL, NULL);
    return st == DWPLicStateTrial || st == DWPLicStatePermanent || st == DWPLicStateTimed;
}

BOOL DWPLicenseHasActiveKey(void) {
    DWPLicState st = DWPLicenseCurrentState(NULL, NULL);
    return st == DWPLicStatePermanent || st == DWPLicStateTimed;
}

NSString *DWPLicenseStatusText(void) {
    NSInteger days = 0;
    NSString *name = nil;
    DWPLicState st = DWPLicenseCurrentState(&days, &name);
    switch (st) {
        case DWPLicStateTrial:
            return [NSString stringWithFormat:DWPT(@"Đang dùng thử — còn %ld ngày", @"Trial — %ld day(s) left"), (long)days];
        case DWPLicStateTrialExpired:
            return DWPT(@"Đã hết hạn dùng thử — nhập key để kích hoạt", @"Trial expired — enter a key to activate");
        case DWPLicStatePermanent:
            return [NSString stringWithFormat:DWPT(@"Đã kích hoạt — %@ (vĩnh viễn)", @"Activated — %@ (permanent)"), name ?: @""];
        case DWPLicStateTimed:
            return [NSString stringWithFormat:DWPT(@"Đã kích hoạt — %@ (còn %ld ngày)", @"Activated — %@ (%ld day(s) left)"), name ?: @"", (long)days];
        case DWPLicStateTimedExpired:
            return DWPT(@"Key đã hết hạn 3 ngày — nhập key mới", @"Key expired after 3 days — enter a new key");
    }
    return @"";
}

BOOL DWPLicenseTryActivateKey(NSString *key, NSString **nameOut, NSString **errorOut) {
    NSInteger kind = 0;
    NSString *name = nil;
    BOOL mismatch = NO;
    NSString *clean = [key stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!DWPVerifyKey(clean, &kind, &name, &mismatch)) {
        if (errorOut) {
            *errorOut = mismatch
                ? DWPT(@"Key này được cấp cho máy khác. Gửi em mã máy của máy này để em cấp key riêng.", @"This key was issued for another device. Send me this device's machine code for its own key.")
                : DWPT(@"Key chưa đúng — kiểm tra lại key đã dán.", @"Invalid key — check the pasted key.");
        }
        DWPLog(@"ban quyen: dan key SAI (dai %lu ky tu, sai may: %@)", (unsigned long)clean.length, mismatch ? @"CO" : @"khong");
        return NO;
    }
    NSTimeInterval start = 0, effNow = 0, act = 0;
    NSString *actHash = @"";
    BOOL dirty = NO;
    DWPLoadState(&start, &effNow, &act, &actHash, &dirty);
    id oldObj = DWPPrefObject(DWP_LIC_KEY);
    NSString *oldKey = [oldObj isKindOfClass:[NSString class]] ? oldObj : @"";
    if (kind == 3 || kind == 4) {
        NSString *hash = DWPKeyHash(clean);
        if (act > 0 && [actHash isEqualToString:hash]) {
            // Cung key da tung kich hoat: GIU moc dau tien — xoa key roi
            // nhap lai cung khong keo dai duoc han.
        } else if (act > 0 && actHash.length == 0 && [oldKey isEqualToString:clean]) {
            actHash = hash;
        } else {
            act = effNow;
            actHash = hash;
        }
        if (act <= 0) { act = effNow; actHash = hash; }
    }
    DWPSetPref(DWP_LIC_KEY, clean);
    DWPPersistState(start, effNow, act, actHash);
    if (nameOut) *nameOut = name;
    DWPLog(@"ban quyen: DA KICH HOAT kind=%ld ten=%@ maMay=%@", (long)kind, name, DWPLicenseMachineCode());
    return YES;
}
