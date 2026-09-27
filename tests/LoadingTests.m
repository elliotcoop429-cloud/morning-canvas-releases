#define main MorningCanvasAppMain
#import "../MorningCanvas.m"
#undef main

@interface LoadingTestController : DashboardController
@property(nonatomic) NSInteger dismissCount;
@property(nonatomic) NSInteger pageCount;
@property(nonatomic) BOOL failSecondPage;
@property(nonatomic, copy) NSString *nextPage;
@end

@implementation LoadingTestController
- (NSView *)view { return nil; }
- (void)dismissLoadingScreen:(id)sender { self.dismissCount++; }
- (NSArray *)fetchPage:(NSURL *)url token:(NSString *)token run:(SchoolLoadRun *)run nextURL:(NSURL **)nextURL error:(NSError **)error {
    self.pageCount++;
    if (self.failSecondPage && self.pageCount == 2) {
        *error = [NSError errorWithDomain:@"Test" code:1 userInfo:nil];
        return nil;
    }
    if (self.pageCount == 1) *nextURL = [NSURL URLWithString:self.nextPage];
    return @[@{ @"id": @(self.pageCount) }];
}
@end

#define CHECK(condition, message) do { if (!(condition)) { NSLog(@"FAIL: %@", message); return 1; } } while (0)

int main(void) {
    @autoreleasepool {
        LoadingTestController *controller = [LoadingTestController new];
        controller.refreshInProgress = YES;
        controller.calendarRefreshInProgress = YES;
        [controller finishLoadingScreenIfReady];
        CHECK(controller.dismissCount == 0, @"Both sources pending");
        controller.refreshInProgress = NO;
        [controller finishLoadingScreenIfReady];
        CHECK(controller.dismissCount == 0, @"Calendar still pending");
        controller.refreshInProgress = YES;
        controller.calendarRefreshInProgress = NO;
        [controller finishLoadingScreenIfReady];
        CHECK(controller.dismissCount == 0, @"Canvas still pending");
        controller.refreshInProgress = NO;
        controller.canvasLoadError = @"Canvas failed";
        [controller finishLoadingScreenIfReady];
        CHECK(controller.dismissCount == 0 && !controller.hasFinishedInitialLoad, @"Canvas failure keeps cover visible");
        controller.canvasLoadError = nil;
        controller.calendarLoadError = @"Calendar failed";
        [controller finishLoadingScreenIfReady];
        CHECK(controller.dismissCount == 0, @"Calendar failure keeps cover visible");
        controller.calendarLoadError = nil;
        [controller finishLoadingScreenIfReady];
        CHECK(controller.dismissCount == 1 && controller.hasFinishedInitialLoad, @"Successful retry reveals dashboard");

        NSError *error = nil;
        controller.nextPage = [CanvasBaseURL stringByAppendingString:@"/api/v1/test?page=2"];
        NSArray *items = [controller fetchJSON:@"/api/v1/test" token:@"test-only" error:&error];
        CHECK(items.count == 2 && !error, @"All pages are loaded");
        controller.pageCount = 0;
        controller.failSecondPage = YES;
        items = [controller fetchJSON:@"/api/v1/test" token:@"test-only" error:&error];
        CHECK(items == nil && error, @"Failed second page never returns partial results");
        controller.failSecondPage = NO;
        for (NSString *link in @[@"https://example.com/api/v1/test", @"http://pinecrest.instructure.com/api/v1/test", [CanvasBaseURL stringByAppendingString:@"/api/v1/test"]]) {
            controller.pageCount = 0;
            controller.nextPage = link;
            error = nil;
            items = [controller fetchJSON:@"/api/v1/test" token:@"test-only" error:&error];
            CHECK(items == nil && error && controller.pageCount == 1, @"Unsafe or cyclic page link rejected before fetching");
        }
        SchoolLoadRun *expired = [SchoolLoadRun new];
        expired.deadline = NSProcessInfo.processInfo.systemUptime - 1;
        controller.pageCount = 0;
        error = nil;
        items = [controller fetchJSON:@"/api/v1/test" token:@"test-only" run:expired error:&error];
        CHECK(items == nil && error.code == NSURLErrorTimedOut && controller.pageCount == 0, @"Expired batch cannot issue new page requests");
        [expired cancel];
        SchoolLoadRun *stalled = [SchoolLoadRun new];
        controller.activeLoadRun = stalled;
        controller.refreshInProgress = YES;
        NSInteger before = controller.dismissCount;
        [controller expireLoadRun:stalled];
        CHECK(stalled.cancelled && !controller.refreshInProgress && controller.canvasLoadError.length, @"Watchdog cancels stalled load and enables retry");
        CHECK(controller.dismissCount == before, @"Timeout never reveals incomplete data");
        SchoolLoadRun *retry = [SchoolLoadRun new];
        controller.activeLoadRun = retry;
        controller.refreshInProgress = YES;
        [controller expireLoadRun:stalled];
        CHECK(controller.activeLoadRun == retry && controller.refreshInProgress && !retry.cancelled, @"Old timeout cannot cancel new retry");
        [retry cancel];
        NSLog(@"PASS: readiness, failures, retry, pagination, timeouts, cancellation, stale-run protection");
    }
    return 0;
}
