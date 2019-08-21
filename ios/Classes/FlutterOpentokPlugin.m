#import "FlutterOpentokPlugin.h"
#import <flutter_opentok/flutter_opentok-Swift.h>

@implementation FlutterOpentokPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterOpentokPlugin registerWithRegistrar:registrar];
}
@end
