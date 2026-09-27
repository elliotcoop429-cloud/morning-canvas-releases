#define main MorningCanvasAppMain
#import "../MorningCanvas.m"
#undef main

@interface MediaTestController : DashboardController
@property(nonatomic, copy) NSString *testRoot;
@property(nonatomic) BOOL allowSharing;
@property(nonatomic) NSUInteger shareCount;
@end
@implementation MediaTestController
- (NSString *)backgroundStorageRoot { return [self.testRoot stringByAppendingPathComponent:@"managed"]; }
- (void)authenticateSharingWithCompletion:(void (^)(BOOL))completion { completion(self.allowSharing); }
- (void)presentSharePicker:(NSButton *)sender { self.shareCount++; }
- (void)renderClassList {}
- (void)showSelectedTab {}
@end

@interface TestUpdater : NSObject
@property(nonatomic) BOOL automaticallyChecksForUpdates;
@property(nonatomic) BOOL automaticallyDownloadsUpdates;
@end
@implementation TestUpdater
@end
@interface TestUpdaterController : NSObject
@property(nonatomic, strong) TestUpdater *updater;
@end
@implementation TestUpdaterController
@end

#define CHECK(condition, message) do { if (!(condition)) { NSLog(@"FAIL: %@", message); return 1; } } while (0)

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSString *domain = NSProcessInfo.processInfo.processName;
        CHECK([domain isEqualToString:@"MorningCanvasMediaTests"], @"Isolated test preference domain");
        [defaults removePersistentDomainForName:domain];
        MediaTestController *controller = [MediaTestController new];
        controller.testRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [NSFileManager.defaultManager createDirectoryAtPath:controller.testRoot withIntermediateDirectories:YES attributes:nil error:nil];
        // Setting a view directly avoids school network requests and saved credentials.
        controller.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 700)];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:controller.view.frame styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.contentView = controller.view;
        NSMutableArray *urls = [NSMutableArray array];
        for (NSUInteger i = 0; i < 2; i++) {
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:256 pixelsHigh:128 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            memset(bitmap.bitmapData, i ? 200 : 80, bitmap.bytesPerRow * bitmap.pixelsHigh);
            NSURL *url = [NSURL fileURLWithPath:[controller.testRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"photo%lu.png", (unsigned long)i]]];
            [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToURL:url atomically:YES];
            [urls addObject:url];
        }
        CHECK([controller backgroundVideosMuted], @"Videos default to muted");
        CHECK([controller slideshowEnabled] && [controller slideshowInterval] == 30, @"Slideshow defaults");
        [defaults setDouble:-5 forKey:@"backgroundSlideshowInterval"];
        CHECK([controller slideshowInterval] == 30, @"Bad timing falls back safely");
        [defaults setObject:[urls[0] path] forKey:@"backgroundMediaPath"];
        [defaults setObject:@"image" forKey:@"backgroundMediaType"];
        CHECK([controller backgroundPhotoPaths].count == 1, @"Legacy image migration");
        NSError *error = nil;
        CHECK([controller importBackgroundURLs:urls video:NO error:&error], @"Multiple photos imported");
        NSArray *photos = [controller backgroundPhotoPaths];
        CHECK(photos.count == 2, @"Both photos saved");
        CHECK([[NSData dataWithContentsOfURL:urls[0]] isEqual:[NSData dataWithContentsOfFile:photos[0]]], @"Full-resolution originals preserved byte for byte");
        [controller configureBackgroundMedia];
        CHECK(controller.slideshowTimer.valid, @"Slideshow timer running");
        NSImage *first = controller.backgroundImageView.image;
        [controller advanceBackgroundPhoto];
        CHECK(controller.backgroundImageView.image != first && controller.slideshowIndex == 1, @"Next photo shown");
        CHECK(controller.backgroundImageView.image.cacheMode == NSImageCacheNever, @"No low-resolution image cache");
        [controller advanceBackgroundPhoto];
        CHECK(controller.slideshowIndex == 0, @"Slideshow wraps");
        [defaults setBool:NO forKey:@"backgroundSlideshowEnabled"];
        [controller restartSlideshowTimer];
        CHECK(controller.slideshowTimer == nil, @"Slideshow can pause");
        CHECK((![controller importBackgroundURLs:@[urls[0], [NSURL fileURLWithPath:@"/missing-photo.png"]] video:NO error:&error]), @"Invalid import rejected");
        CHECK([[controller backgroundPhotoPaths] isEqual:photos], @"Failed import keeps existing backgrounds");
        [controller shareApp:nil];
        CHECK(controller.shareCount == 0, @"Failed or canceled authentication prevents sharing");
        controller.allowSharing = YES;
        [controller shareApp:nil];
        CHECK(controller.shareCount == 1, @"Successful authentication allows sharing");
        [defaults setBool:NO forKey:@"backgroundVideosMuted"];
        CHECK(![controller backgroundVideosMuted], @"Mute preference can turn off");
        TestUpdaterController *updates = [TestUpdaterController new];
        updates.updater = [TestUpdater new];
        updates.updater.automaticallyChecksForUpdates = YES;
        updates.updater.automaticallyDownloadsUpdates = YES;
        controller.updaterController = (id)updates;
        [controller changeAppearance:nil];
        [controller.photoTransitionChoice selectItemWithTitle:@"Slide"];
        controller.automaticUpdatesCheckbox.state = NSControlStateValueOff;
        controller.muteVideoCheckbox.state = NSControlStateValueOn;
        [controller applyAppearanceChoice:nil];
        CHECK(!updates.updater.automaticallyChecksForUpdates && !updates.updater.automaticallyDownloadsUpdates, @"Off disables checks and automatic downloads");
        CHECK([controller backgroundVideosMuted], @"Apply saves mute preference");
        CHECK([[defaults stringForKey:@"photoTransition"] isEqual:@"Slide"], @"Transition choice is saved");
        [window displayIfNeeded];
        [controller advanceBackgroundPhoto];
        if (!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
            CATransition *transition = (CATransition *)[controller.backgroundImageView.layer animationForKey:kCATransition];
            CHECK([transition.type isEqual:kCATransitionPush], @"Slide transition is attached to photo layer");
            [defaults setObject:@"Fade" forKey:@"photoTransition"];
            [controller advanceBackgroundPhoto];
            transition = (CATransition *)[controller.backgroundImageView.layer animationForKey:kCATransition];
            CHECK([transition.type isEqual:kCATransitionFade], @"Fade transition is attached to photo layer");
        }
        [defaults setObject:@"None" forKey:@"photoTransition"];
        [controller advanceBackgroundPhoto];
        CHECK(![controller.backgroundImageView.layer animationForKey:kCATransition], @"None removes any previous photo transition");
        [controller changeAppearance:nil];
        controller.automaticUpdatesCheckbox.state = NSControlStateValueOn;
        [controller cancelAppearance:nil];
        CHECK(!updates.updater.automaticallyChecksForUpdates, @"Cancel does not change update preferences");
        [controller changeAppearance:nil];
        controller.automaticUpdatesCheckbox.state = NSControlStateValueOn;
        [controller applyAppearanceChoice:nil];
        CHECK(updates.updater.automaticallyChecksForUpdates && updates.updater.automaticallyDownloadsUpdates, @"On restores checks and automatic downloads");
        [controller clearBackgroundMedia:nil];
        CHECK([controller backgroundPhotoPaths].count == 0 && !controller.slideshowTimer && !controller.backgroundImageView, @"Clear stops playback and removes selection");
        CHECK([NSFileManager.defaultManager fileExistsAtPath:[urls[0] path]], @"Original files are never deleted");
        [NSFileManager.defaultManager removeItemAtPath:controller.testRoot error:nil];
        [defaults removePersistentDomainForName:domain];
        NSLog(@"PASS: migration, original image quality, slideshow, pause, import rollback, sharing gate, mute, update on/off, cancel, cleanup");
    }
    return 0;
}
