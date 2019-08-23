#import "FlutterOpentokPlugin.h"
#import <flutter_opentok/flutter_opentok-Swift.h>
#import "UserAgent.h"

@implementation FlutterOpentokPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterOpentokPlugin registerWithRegistrar:registrar];
}
@end
