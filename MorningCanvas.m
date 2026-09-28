#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <WebKit/WebKit.h>
#import <AVKit/AVKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <Security/Security.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Sparkle/Sparkle.h>
#import <objc/runtime.h>
#import <libxml/HTMLparser.h>
#import <libxml/xpath.h>

static NSString *const CanvasBaseURL = @"https://pinecrest.instructure.com";
static NSString *const KeychainService = @"com.elliot.morningcanvas";
static char OriginalTextStyleKey;
#import "GuiLayout.h"

@interface ConfettiView : NSView
@end
@implementation ConfettiView
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end

@interface SchoolLoadRun : NSObject
@property(nonatomic) NSTimeInterval deadline;
@property(atomic) BOOL cancelled;
@property(nonatomic, strong) NSURLSession *session;
- (void)cancel;
@end

@implementation SchoolLoadRun
- (instancetype)init {
    if ((self = [super init])) {
        self.deadline = NSProcessInfo.processInfo.systemUptime + 60;
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 15;
        config.timeoutIntervalForResource = 20;
        config.HTTPMaximumConnectionsPerHost = 3;
        self.session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}
- (void)cancel {
    self.cancelled = YES;
    [self.session invalidateAndCancel];
}
@end

@interface AspectFillImageView : NSImageView
@end

@implementation AspectFillImageView
- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    self.needsDisplay = YES;
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSImage *image = self.image;
    if (!image || image.size.width <= 0 || image.size.height <= 0 || NSWidth(self.bounds) <= 0 || NSHeight(self.bounds) <= 0) return;

    CGFloat imageAspect = image.size.width / image.size.height;
    CGFloat viewAspect = NSWidth(self.bounds) / NSHeight(self.bounds);
    NSRect source = NSMakeRect(0, 0, image.size.width, image.size.height);
    if (imageAspect > viewAspect) {
        CGFloat width = image.size.height * viewAspect;
        source.origin.x = (image.size.width - width) / 2.0;
        source.size.width = width;
    } else {
        CGFloat height = image.size.width / viewAspect;
        source.origin.y = (image.size.height - height) / 2.0;
        source.size.height = height;
    }
    [image drawInRect:self.bounds
             fromRect:source
            operation:NSCompositingOperationSourceOver
             fraction:1.0
       respectFlipped:YES
                hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
}
@end

@interface LoadingAnimationView : WKWebView <WKNavigationDelegate>
@property(nonatomic) BOOL animationRequested;
- (void)setAnimating:(BOOL)animating;
@end

@implementation LoadingAnimationView
- (instancetype)initWithFrame:(NSRect)frame {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    if ((self = [super initWithFrame:frame configuration:config])) {
        self.navigationDelegate = self;
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        NSURL *folder = [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Loading"];
        [self loadFileURL:[folder URLByAppendingPathComponent:@"index.html"] allowingReadAccessToURL:folder];
    }
    return self;
}

- (void)setAnimating:(BOOL)animating {
    self.animationRequested = animating;
    [self evaluateJavaScript:[NSString stringWithFormat:@"window.setLoadingAnimation && window.setLoadingAnimation(%@)", animating ? @"true" : @"false"] completionHandler:nil];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self setAnimating:self.animationRequested];
}
@end

@interface DashboardController : NSViewController
@property(nonatomic, strong) NSSegmentedControl *tabs;
@property(nonatomic, strong) NSView *contentView;
@property(nonatomic, strong) NSScrollView *contentScrollView;
@property(nonatomic, strong) NSView *classListView;
@property(nonatomic, strong) NSScrollView *classScrollView;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSTextField *tokenEntryField;
@property(nonatomic, strong) NSTextField *calendarURLEntryField;
@property(nonatomic, strong) NSPopUpButton *appearanceChoices;
@property(nonatomic, strong) NSColorWell *customColorWell;
@property(nonatomic, strong) NSColorWell *glassTintColorWell;
@property(nonatomic, strong) NSSegmentedControl *glassModeControl;
@property(nonatomic, strong) NSSlider *glassOpacitySlider;
@property(nonatomic, strong) NSPanel *appearancePanel;
@property(nonatomic, strong) NSSlider *backgroundDimmingSlider;
@property(nonatomic, strong) NSTextField *backgroundMediaLabel;
@property(nonatomic, strong) NSImageView *backgroundImageView;
@property(nonatomic, strong) AVPlayerView *backgroundVideoView;
@property(nonatomic, strong) AVQueuePlayer *backgroundPlayer;
@property(nonatomic, strong) AVPlayerLooper *backgroundLooper;
@property(nonatomic, strong) NSView *backgroundOverlay;
@property(nonatomic, strong) NSVisualEffectView *mainTabGlass;
@property(nonatomic, strong) NSSharingServicePicker *sharingPicker;
@property(nonatomic, strong) LAContext *sharingAuthentication;
@property(nonatomic, strong) NSTimer *slideshowTimer;
@property(nonatomic) NSUInteger slideshowIndex;
@property(nonatomic, strong) NSButton *slideshowCheckbox;
@property(nonatomic, strong) NSPopUpButton *slideshowIntervalChoice;
@property(nonatomic, strong) NSPopUpButton *photoTransitionChoice;
@property(nonatomic, strong) NSButton *muteVideoCheckbox;
@property(nonatomic, strong) NSButton *automaticUpdatesCheckbox;
@property(nonatomic, strong) NSButton *confettiCheckbox;
@property(nonatomic, strong) NSButton *customTextCheckbox;
@property(nonatomic, strong) NSColorWell *textColorWell;
@property(nonatomic, strong) NSColorWell *linkColorWell;
@property(nonatomic, strong) NSMutableSet<NSString *> *expandedGradeCourses;
@property(nonatomic, copy) NSArray<NSDictionary *> *weeklyOverviews;
@property(nonatomic, copy) NSArray<NSDictionary *> *displayedOverviews;
@property(nonatomic, copy) NSString *overviewError;
@property(nonatomic) BOOL overviewLoading;
@property(nonatomic) BOOL overviewLoaded;
@property(nonatomic) BOOL initialAutomaticUpdates;
@property(nonatomic, copy) NSString *cachedCanvasToken;
@property(nonatomic) BOOL checkedKeychain;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, strong) NSTimer *clockTimer;
@property(nonatomic) BOOL refreshInProgress;
@property(nonatomic, strong) SchoolLoadRun *activeLoadRun;
@property(nonatomic, strong) NSTimer *loadingWatchdog;
@property(nonatomic) BOOL calendarRefreshInProgress;
@property(nonatomic) BOOL hasFinishedInitialLoad;
@property(nonatomic, strong) NSVisualEffectView *loadingScreen;
@property(nonatomic, strong) NSProgressIndicator *loadingSpinner;
@property(nonatomic, strong) LoadingAnimationView *loadingAnimation;
@property(nonatomic, strong) NSStackView *loadingRecoveryControls;
@property(nonatomic, copy) NSString *canvasLoadError;
@property(nonatomic, copy) NSString *calendarLoadError;
@property(nonatomic, strong) NSTextField *loadingStatusLabel;
@property(nonatomic, strong) SPUStandardUpdaterController *updaterController;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *roomAssignments;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *calendarColorAssignments;
@property(nonatomic, copy) NSArray<NSDate *> *calendarWeekDates;
@property(nonatomic) NSInteger selectedCalendarDayIndex;
@property(nonatomic, strong) NSView *currentTimeLine;
@property(nonatomic, strong) NSTextField *currentTimeLabel;
@property(nonatomic, strong) NSDate *calendarTimelineStart;
@property(nonatomic, strong) NSDate *calendarTimelineDate;
@property(nonatomic) CGFloat calendarTimelineTop;
@property(nonatomic) CGFloat calendarTimelineScale;
@property(nonatomic) CGFloat calendarTimelineHeight;
@property(nonatomic, copy) NSArray<NSDictionary *> *courses;
@property(nonatomic, strong) NSNumber *selectedCourseId;
@property(nonatomic, copy) NSArray<NSDictionary *> *announcements;
@property(nonatomic, copy) NSArray<NSDictionary *> *displayedAnnouncements;
@property(nonatomic, copy) NSArray<NSDictionary *> *grades;
@property(nonatomic, copy) NSArray<NSDictionary *> *gradedAssignments;
@property(nonatomic, copy) NSArray<NSDictionary *> *displayedGradedAssignments;
@property(nonatomic, strong) NSMutableDictionary *gradeWeights;
@property(nonatomic, copy) NSArray<NSDictionary *> *calendarItems;
@property(nonatomic, copy) NSArray<NSDictionary *> *displayedCalendarItems;
@property(nonatomic, copy) NSString *calendarMessage;
@property(nonatomic, copy) NSArray<NSDictionary *> *testItems;
@property(nonatomic, copy) NSArray<NSDictionary *> *displayedTestItems;
@property(nonatomic, copy) NSArray<NSDictionary *> *todoItems;
@property(nonatomic, copy) NSArray<NSDictionary *> *displayedTodoItems;
@property(nonatomic, copy) NSArray<NSDictionary *> *submittedItems;
@property(nonatomic, copy) NSArray<NSDictionary *> *displayedSubmittedItems;
@property(nonatomic, copy) NSArray<NSDictionary *> *localCompletedItems;
@property(nonatomic, strong) NSMutableSet<NSString *> *checkedTodoKeys;
@end

@implementation DashboardController

- (NSTextField *)label:(NSString *)text frame:(NSRect)frame size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.frame = frame;
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    return label;
}

- (void)loadView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 660)];
    self.view = view;
    self.courses = @[];
    self.announcements = @[];
    self.grades = @[];
    self.gradedAssignments = @[];
    self.gradeWeights = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"gradeWeights"] mutableCopy] ?: [NSMutableDictionary dictionary];
    self.expandedGradeCourses = [NSMutableSet set];
    self.weeklyOverviews = @[];
    NSArray *savedCalendarItems = [NSUserDefaults.standardUserDefaults arrayForKey:@"cachedCalendarItems"];
    self.calendarItems = [savedCalendarItems isKindOfClass:NSArray.class] ? savedCalendarItems : @[];
    self.calendarMessage = @"";
    self.testItems = @[];
    self.todoItems = @[];
    self.submittedItems = @[];
    self.localCompletedItems = [NSUserDefaults.standardUserDefaults arrayForKey:@"localCompletedItems"] ?: @[];
    NSDictionary *savedRooms = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"roomAssignments"] ?: @{};
    self.roomAssignments = [savedRooms mutableCopy];
    NSDictionary *savedCalendarColors = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"calendarColorAssignments"] ?: @{};
    self.calendarColorAssignments = [savedCalendarColors mutableCopy];
    self.calendarWeekDates = [self schoolWeekDatesAroundDate:NSDate.date];
    self.selectedCalendarDayIndex = [self defaultCalendarDayIndex];
    self.calendarItems = [self calendarItemsByMergingNewItems:self.calendarItems];
    NSArray *savedChecks = [NSUserDefaults.standardUserDefaults stringArrayForKey:@"checkedTodoKeys"] ?: @[];
    self.checkedTodoKeys = [NSMutableSet setWithArray:savedChecks];
    [self applyTheme];
    [self configureBackgroundMedia];

    NSTextField *dashboardTitle = [self label:@"Morning Canvas" frame:NSMakeRect(28, 592, 324, 40) size:30 weight:NSFontWeightBold color:NSColor.labelColor];
    [view addSubview:dashboardTitle];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterFullStyle;
    NSTextField *dashboardDate = [self label:[dateFormatter stringFromDate:NSDate.date] frame:NSMakeRect(30, 566, 420, 22) size:13 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];
    [view addSubview:dashboardDate];

    NSView *shareGlass = [self glassViewWithFrame:NSMakeRect(360, 590, 72, 34) radius:8];
    [view addSubview:shareGlass];
    NSButton *shareButton = [NSButton buttonWithTitle:@"Share" target:self action:@selector(shareApp:)];
    shareButton.frame = NSMakeRect(364, 593, 64, 28);
    shareButton.bordered = NO;
    shareButton.toolTip = @"Share Morning Canvas with a friend";
    [view addSubview:shareButton];

    NSView *updateGlass = [self glassViewWithFrame:NSMakeRect(438, 590, 72, 34) radius:8];
    [view addSubview:updateGlass];
    NSButton *updateButton = [NSButton buttonWithTitle:@"Update" target:self action:@selector(checkForUpdates:)];
    updateButton.frame = NSMakeRect(442, 593, 64, 28);
    updateButton.bordered = NO;
    updateButton.toolTip = @"Check for a Morning Canvas update";
    [view addSubview:updateButton];

    NSView *connectGlass = [self glassViewWithFrame:NSMakeRect(516, 590, 120, 34) radius:8];
    [view addSubview:connectGlass];
    NSButton *connectButton = [NSButton buttonWithTitle:@"Connect Canvas" target:self action:@selector(connectCanvas:)];
    connectButton.frame = NSMakeRect(520, 593, 112, 28);
    connectButton.bordered = NO;
    [view addSubview:connectButton];

    NSView *calendarGlass = [self glassViewWithFrame:NSMakeRect(642, 590, 112, 34) radius:8];
    [view addSubview:calendarGlass];
    NSButton *calendarButton = [NSButton buttonWithTitle:@"Calendar URL" target:self action:@selector(connectCalendar:)];
    calendarButton.frame = NSMakeRect(646, 593, 104, 28);
    calendarButton.bordered = NO;
    calendarButton.toolTip = @"Add a Google Calendar link";
    [view addSubview:calendarButton];

    NSView *appearanceGlass = [self glassViewWithFrame:NSMakeRect(760, 590, 98, 34) radius:8];
    [view addSubview:appearanceGlass];
    NSButton *appearanceButton = [NSButton buttonWithTitle:@"Appearance" target:self action:@selector(changeAppearance:)];
    appearanceButton.frame = NSMakeRect(764, 593, 90, 28);
    appearanceButton.bordered = NO;
    [view addSubview:appearanceButton];

    NSView *refreshGlass = [self glassViewWithFrame:NSMakeRect(864, 590, 72, 34) radius:8];
    [view addSubview:refreshGlass];
    NSButton *refreshButton = [NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refresh:)];
    refreshButton.frame = NSMakeRect(868, 593, 64, 28);
    refreshButton.bordered = NO;
    [view addSubview:refreshButton];

    NSView *openGlass = [self glassViewWithFrame:NSMakeRect(938, 590, 98, 34) radius:8];
    [view addSubview:openGlass];
    NSButton *openButton = [NSButton buttonWithTitle:@"Open Canvas" target:self action:@selector(openCanvas:)];
    openButton.frame = NSMakeRect(942, 593, 90, 28);
    openButton.bordered = NO;
    [view addSubview:openButton];

    self.statusLabel = [self label:@"Not connected" frame:NSMakeRect(30, 536, 980, 22) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];
    [view addSubview:self.statusLabel];

    NSTextField *classesTitle = [self label:@"CLASSES" frame:NSMakeRect(30, 500, 190, 20) size:12 weight:NSFontWeightBold color:NSColor.secondaryLabelColor];
    [view addSubview:classesTitle];
    self.classScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(24, 82, 220, 408)];
    self.classScrollView.hasVerticalScroller = YES;
    self.classScrollView.drawsBackground = NO;
    self.classListView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 202, 408)];
    self.classScrollView.documentView = self.classListView;
    [view addSubview:self.classScrollView];

    NSBox *verticalLine = [[NSBox alloc] initWithFrame:NSMakeRect(257, 74, 1, 442)];
    verticalLine.boxType = NSBoxSeparator;
    [view addSubview:verticalLine];

    self.mainTabGlass = [self glassViewWithFrame:NSMakeRect(278, 492, 746, 34) radius:10];
    [view addSubview:self.mainTabGlass];
    self.tabs = [NSSegmentedControl segmentedControlWithLabels:@[@"Announcements", @"Grades", @"Calendar", @"Tests", @"To-do", @"Submitted", @"Weekly Overview"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(tabChanged:)];
    self.tabs.frame = NSMakeRect(282, 495, 738, 28);
    self.tabs.font = [NSFont systemFontOfSize:12];
    self.tabs.segmentStyle = NSSegmentStyleCapsule;
    self.tabs.selectedSegment = 4;
    [view addSubview:self.tabs];

    NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(278, 474, 746, 1)];
    line.boxType = NSBoxSeparator;
    [view addSubview:line];

    self.contentScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(278, 82, 746, 374)];
    self.contentScrollView.hasVerticalScroller = YES;
    self.contentScrollView.autohidesScrollers = NO;
    self.contentScrollView.drawsBackground = NO;
    self.contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 728, 374)];
    self.contentScrollView.documentView = self.contentView;
    [view addSubview:self.contentScrollView];

    NSTextField *dashboardFooter = [self label:@"Canvas data is read-only and the token is stored privately for your Mac account." frame:NSMakeRect(30, 27, 700, 20) size:11 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];
    [view addSubview:dashboardFooter];
    NSButton *quitButton = [NSButton buttonWithTitle:@"Quit" target:NSApp action:@selector(terminate:)];
    quitButton.frame = NSMakeRect(960, 20, 64, 30);
    [view addSubview:quitButton];

    // The designer controls presentation only; selectors and Canvas data stay in native code.
    NSDictionary *layoutViews = @{
        @"title":@[dashboardTitle], @"date":@[dashboardDate], @"status":@[self.statusLabel],
        @"classes-title":@[classesTitle], @"classes":@[self.classScrollView],
        @"vertical-rule":@[verticalLine], @"horizontal-rule":@[line],
        @"tabs":@[self.mainTabGlass,self.tabs], @"content":@[self.contentScrollView],
        @"footer":@[dashboardFooter], @"quit":@[quitButton],
        @"share":@[shareGlass,shareButton], @"update":@[updateGlass,updateButton],
        @"connect":@[connectGlass,connectButton], @"calendar":@[calendarGlass,calendarButton],
        @"appearance":@[appearanceGlass,appearanceButton], @"refresh":@[refreshGlass,refreshButton],
        @"open":@[openGlass,openButton]
    };
    NSURL *layoutURL = [NSBundle.mainBundle URLForResource:@"gui-layout" withExtension:@"json"];
    NSData *layoutData = layoutURL ? [NSData dataWithContentsOfURL:layoutURL] : nil;
    NSDictionary *layout = layoutData ? [NSJSONSerialization JSONObjectWithData:layoutData options:0 error:nil] : nil;
    MCApplyLayout(layout, view, layoutViews);

    [self renderClassList];
    [self showSelectedTab];
    if ([self canvasToken].length > 0) [self refresh:nil];
    else if ([self calendarURLString].length > 0) [self refreshCalendar];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2 * 60 * 60
                                                         target:self
                                                       selector:@selector(autoRefresh:)
                                                       userInfo:nil
                                                        repeats:YES];
    self.clockTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                       target:self
                                                     selector:@selector(updateCurrentTimeIndicator:)
                                                     userInfo:nil
                                                      repeats:YES];
    self.updaterController = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES updaterDelegate:nil userDriverDelegate:nil];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    NSSize viewport = self.view.frame.size;
    if (viewport.width <= 0 || viewport.height <= 0) return;

    const CGFloat dashboardWidth = 1040.0;
    const CGFloat dashboardHeight = 660.0;
    CGFloat scale = MIN(viewport.width / dashboardWidth, viewport.height / dashboardHeight);
    if (scale <= 0) return;

    NSSize logicalSize = NSMakeSize(viewport.width / scale, viewport.height / scale);
    NSRect centeredBounds = NSMakeRect((dashboardWidth - logicalSize.width) / 2.0,
                                       (dashboardHeight - logicalSize.height) / 2.0,
                                       logicalSize.width,
                                       logicalSize.height);
    if (!NSEqualRects(self.view.bounds, centeredBounds)) self.view.bounds = centeredBounds;

    self.backgroundImageView.frame = centeredBounds;
    self.backgroundVideoView.frame = centeredBounds;
    self.backgroundOverlay.frame = centeredBounds;
    self.loadingScreen.frame = centeredBounds;
    self.loadingAnimation.frame = self.loadingScreen.bounds;
}

- (void)showLoadingScreen:(NSString *)status {
    if (!self.loadingScreen) {
        NSVisualEffectView *screen = [[NSVisualEffectView alloc] initWithFrame:self.view.bounds];
        screen.material = NSVisualEffectMaterialWindowBackground;
        screen.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        screen.state = NSVisualEffectStateActive;
        self.loadingScreen = screen;

        self.loadingAnimation = [[LoadingAnimationView alloc] initWithFrame:screen.bounds];
        [screen addSubview:self.loadingAnimation];
        NSTextField *title = [self label:@"Morning Canvas" frame:NSZeroRect size:28 weight:NSFontWeightBold color:NSColor.labelColor];
        title.alignment = NSTextAlignmentCenter;
        self.loadingSpinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
        self.loadingSpinner.style = NSProgressIndicatorStyleSpinning;
        self.loadingSpinner.indeterminate = YES;
        self.loadingSpinner.displayedWhenStopped = NO;
        [self.loadingSpinner setAccessibilityLabel:@"Loading school data"];
        self.loadingStatusLabel = [self label:status frame:NSZeroRect size:14 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];
        self.loadingStatusLabel.alignment = NSTextAlignmentCenter;
        NSButton *retry = [NSButton buttonWithTitle:@"Try Again" target:self action:@selector(retryLoading:)];
        NSButton *canvas = [NSButton buttonWithTitle:@"Connect Canvas" target:self action:@selector(connectCanvas:)];
        NSButton *calendar = [NSButton buttonWithTitle:@"Calendar URL" target:self action:@selector(connectCalendar:)];
        self.loadingRecoveryControls = [NSStackView stackViewWithViews:@[retry, canvas, calendar]];
        self.loadingRecoveryControls.spacing = 8;
        self.loadingRecoveryControls.hidden = YES;
        NSStackView *stack = [NSStackView stackViewWithViews:@[title, self.loadingSpinner, self.loadingStatusLabel, self.loadingRecoveryControls]];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.alignment = NSLayoutAttributeCenterX;
        stack.spacing = 18;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [screen addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.centerXAnchor constraintEqualToAnchor:screen.centerXAnchor],
            [stack.centerYAnchor constraintEqualToAnchor:screen.centerYAnchor constant:165],
            [stack.widthAnchor constraintEqualToConstant:440],
            [self.loadingSpinner.widthAnchor constraintEqualToConstant:32],
            [self.loadingSpinner.heightAnchor constraintEqualToConstant:32],
            [self.loadingStatusLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor]
        ]];
    }
    self.loadingScreen.frame = self.view.bounds;
    self.loadingStatusLabel.stringValue = status;
    self.loadingScreen.hidden = NO;
    self.loadingRecoveryControls.hidden = YES;
    [self.view addSubview:self.loadingScreen positioned:NSWindowAbove relativeTo:nil];
    [self.loadingSpinner startAnimation:nil];
    [self.loadingAnimation setAnimating:YES];
}

- (void)dismissLoadingScreen:(id)sender {
    [self.loadingSpinner stopAnimation:nil];
    [self.loadingAnimation setAnimating:NO];
    self.loadingScreen.hidden = YES;
}

- (void)retryLoading:(id)sender {
    if (self.refreshInProgress || self.calendarRefreshInProgress) return;
    if ([self canvasToken].length > 0) [self refresh:sender];
    else {
        [self showLoadingScreen:@"Loading calendar..."];
        [self refreshCalendar];
    }
}

- (void)expireLoadRun:(SchoolLoadRun *)run {
    if (self.activeLoadRun != run || !self.refreshInProgress) return;
    [run cancel];
    self.activeLoadRun = nil;
    self.refreshInProgress = NO;
    self.canvasLoadError = @"Canvas took too long to load. Check your connection, then choose Try Again.";
    self.statusLabel.stringValue = self.canvasLoadError;
    [self finishLoadingScreenIfReady];
}

- (void)finishLoadingScreenIfReady {
    if (self.refreshInProgress || self.calendarRefreshInProgress) {
        if (!self.refreshInProgress) self.loadingStatusLabel.stringValue = @"Loading calendar...";
        return;
    }
    NSMutableArray *errors = [NSMutableArray array];
    if (self.canvasLoadError.length) [errors addObject:self.canvasLoadError];
    if (self.calendarLoadError.length) [errors addObject:self.calendarLoadError];
    if (errors.count > 0) {
        self.loadingStatusLabel.stringValue = [errors componentsJoinedByString:@"\n"];
        self.loadingRecoveryControls.hidden = NO;
        [self.loadingSpinner stopAnimation:nil];
        [self.loadingAnimation setAnimating:NO];
        return;
    }
    // Lay out the populated dashboard before removing its loading cover.
    [self.view layoutSubtreeIfNeeded];
    self.hasFinishedInitialLoad = YES;
    [self dismissLoadingScreen:nil];
}

- (void)tabChanged:(id)sender {
    [self renderClassList];
    [self showSelectedTab];
}

- (NSDate *)canvasDateFromString:(NSString *)timestamp {
    if (![timestamp isKindOfClass:NSString.class] || timestamp.length == 0) return nil;
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    NSDate *date = [formatter dateFromString:timestamp];
    if (date) return date;
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    return [formatter dateFromString:timestamp];
}

- (NSDate *)startOfCurrentWeek {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *today = [calendar startOfDayForDate:NSDate.date];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:today];
    NSInteger daysSinceMonday = (weekday + 5) % 7;
    return [calendar dateByAddingUnit:NSCalendarUnitDay value:-daysSinceMonday toDate:today options:0];
}

- (BOOL)timestampIsInCurrentWeek:(NSString *)timestamp {
    NSDate *date = [self canvasDateFromString:timestamp];
    return date && [date compare:[self startOfCurrentWeek]] != NSOrderedAscending;
}

- (BOOL)isTestAssignment:(NSDictionary *)assignment name:(NSString *)name {
    if ([assignment[@"quiz_id"] respondsToSelector:@selector(integerValue)] && [assignment[@"quiz_id"] integerValue] > 0) return YES;
    NSArray *submissionTypes = [assignment[@"submission_types"] isKindOfClass:NSArray.class] ? assignment[@"submission_types"] : @[];
    if ([submissionTypes containsObject:@"online_quiz"]) return YES;
    NSString *lower = name.lowercaseString ?: @"";
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"\\b(tests?|quizzes|quiz|exams?|midterms?|assessments?|knowledge check)\\b" options:0 error:nil];
    return [pattern firstMatchInString:lower options:0 range:NSMakeRange(0, lower.length)] != nil;
}

- (BOOL)isClassworkName:(NSString *)name {
    NSString *lower = [[name ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if ([lower hasPrefix:@"cw:"] || [lower hasPrefix:@"cw -"] || [lower hasPrefix:@"cw –"] || [lower hasPrefix:@"cw "]) return YES;
    return [lower containsString:@"classwork"] || [lower containsString:@"in class"] || [lower containsString:@"in-class"];
}

- (NSColor *)savedCustomBackgroundColor {
    NSArray *components = [NSUserDefaults.standardUserDefaults arrayForKey:@"customBackgroundColor"];
    if (components.count != 4) return [NSColor colorWithSRGBRed:0.78 green:0.9 blue:1.0 alpha:1.0];
    return [NSColor colorWithSRGBRed:[components[0] doubleValue] green:[components[1] doubleValue] blue:[components[2] doubleValue] alpha:[components[3] doubleValue]];
}

- (void)saveCustomBackgroundColor:(NSColor *)color {
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: color;
    [NSUserDefaults.standardUserDefaults setObject:@[@(rgb.redComponent), @(rgb.greenComponent), @(rgb.blueComponent), @(rgb.alphaComponent)] forKey:@"customBackgroundColor"];
}

- (NSColor *)savedGlassTintColor {
    NSArray *components = [NSUserDefaults.standardUserDefaults arrayForKey:@"glassTintColor"];
    if (components.count != 4) return [NSColor colorWithSRGBRed:0.28 green:0.62 blue:1.0 alpha:1.0];
    return [NSColor colorWithSRGBRed:[components[0] doubleValue]
                               green:[components[1] doubleValue]
                                blue:[components[2] doubleValue]
                               alpha:[components[3] doubleValue]];
}

- (void)saveGlassTintColor:(NSColor *)color {
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: color;
    [NSUserDefaults.standardUserDefaults setObject:@[@(rgb.redComponent), @(rgb.greenComponent), @(rgb.blueComponent), @(rgb.alphaComponent)]
                                             forKey:@"glassTintColor"];
}

- (BOOL)glassTintEnabled {
    if ([NSUserDefaults.standardUserDefaults objectForKey:@"glassTintEnabled"] == nil) return YES;
    return [NSUserDefaults.standardUserDefaults boolForKey:@"glassTintEnabled"];
}

- (CGFloat)glassOpacity {
    NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:@"glassOpacity"];
    return saved ? MAX(0.0, MIN(0.65, saved.doubleValue)) : 0.22;
}

- (void)applyGlassTintToView:(NSVisualEffectView *)glass {
    NSColor *tint = [self savedGlassTintColor];
    CGFloat opacity = [self glassOpacity];
    if ([self glassTintEnabled]) {
        glass.layer.backgroundColor = [tint colorWithAlphaComponent:opacity].CGColor;
        glass.layer.borderColor = [tint colorWithAlphaComponent:MIN(0.9, opacity + 0.36)].CGColor;
    } else {
        glass.layer.backgroundColor = [NSColor.whiteColor colorWithAlphaComponent:opacity * 0.42].CGColor;
        glass.layer.borderColor = [NSColor.whiteColor colorWithAlphaComponent:MIN(0.78, opacity + 0.28)].CGColor;
    }
}

- (void)refreshGlassViewsInView:(NSView *)view {
    if ([view isKindOfClass:NSVisualEffectView.class]) [self applyGlassTintToView:(NSVisualEffectView *)view];
    for (NSView *subview in view.subviews) [self refreshGlassViewsInView:subview];
}

- (NSVisualEffectView *)glassViewWithFrame:(NSRect)frame radius:(CGFloat)radius {
    NSVisualEffectView *glass = [[NSVisualEffectView alloc] initWithFrame:frame];
    glass.material = NSVisualEffectMaterialPopover;
    glass.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    glass.state = NSVisualEffectStateActive;
    glass.wantsLayer = YES;
    glass.layer.cornerRadius = radius;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.layer.borderWidth = 1;
    glass.layer.borderColor = [NSColor.whiteColor colorWithAlphaComponent:0.34].CGColor;
    glass.layer.shadowColor = NSColor.blackColor.CGColor;
    glass.layer.shadowOpacity = 0.15;
    glass.layer.shadowRadius = 8;
    glass.layer.shadowOffset = NSMakeSize(0, -2);
    [self applyGlassTintToView:glass];
    return glass;
}

- (void)updateBackgroundOverlay {
    if (!self.backgroundOverlay) return;
    NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:@"backgroundMediaDimming"];
    CGFloat amount = saved ? saved.doubleValue : 0.28;
    NSString *appearance = [self.view.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameDarkAqua, NSAppearanceNameAqua]];
    NSColor *tint = [appearance isEqualToString:NSAppearanceNameDarkAqua] ? NSColor.blackColor : NSColor.whiteColor;
    self.backgroundOverlay.layer.backgroundColor = [tint colorWithAlphaComponent:amount].CGColor;
}

- (void)configureBackgroundMedia {
    [self.slideshowTimer invalidate];
    self.slideshowTimer = nil;
    [self.backgroundPlayer pause];
    [self.backgroundImageView removeFromSuperview];
    [self.backgroundVideoView removeFromSuperview];
    [self.backgroundOverlay removeFromSuperview];
    self.backgroundImageView = nil;
    self.backgroundVideoView = nil;
    self.backgroundPlayer = nil;
    self.backgroundLooper = nil;
    self.backgroundOverlay = nil;

    NSString *path = [NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaPath"];
    NSString *type = [NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaType"];
    NSArray<NSString *> *photos = [self backgroundPhotoPaths];
    if (![type isEqualToString:@"video"] && photos.count) {
        self.slideshowIndex %= photos.count;
        path = photos[self.slideshowIndex];
    }
    if (path.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:path]) return;

    NSView *mediaView = nil;
    if ([type isEqualToString:@"video"]) {
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:path]];
        self.backgroundPlayer = [[AVQueuePlayer alloc] init];
        self.backgroundPlayer.muted = [self backgroundVideosMuted];
        self.backgroundLooper = [AVPlayerLooper playerLooperWithPlayer:self.backgroundPlayer templateItem:item];
        self.backgroundVideoView = [[AVPlayerView alloc] initWithFrame:self.view.bounds];
        self.backgroundVideoView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.backgroundVideoView.controlsStyle = AVPlayerViewControlsStyleNone;
        self.backgroundVideoView.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.backgroundVideoView.player = self.backgroundPlayer;
        mediaView = self.backgroundVideoView;
        [self.backgroundPlayer play];
    } else {
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
        if (!image) return;
        image.cacheMode = NSImageCacheNever;
        self.backgroundImageView = [[AspectFillImageView alloc] initWithFrame:self.view.bounds];
        self.backgroundImageView.wantsLayer = YES;
        self.backgroundImageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.backgroundImageView.image = image;
        self.backgroundImageView.imageAlignment = NSImageAlignCenter;
        mediaView = self.backgroundImageView;
    }

    if (self.view.subviews.count > 0) [self.view addSubview:mediaView positioned:NSWindowBelow relativeTo:self.view.subviews.firstObject];
    else [self.view addSubview:mediaView];
    self.backgroundOverlay = [[NSView alloc] initWithFrame:self.view.bounds];
    self.backgroundOverlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.backgroundOverlay.wantsLayer = YES;
    [self.view addSubview:self.backgroundOverlay positioned:NSWindowAbove relativeTo:mediaView];
    [self updateBackgroundOverlay];
    [self restartSlideshowTimer];
}

- (NSArray<NSString *> *)backgroundPhotoPaths {
    NSArray *saved = [NSUserDefaults.standardUserDefaults arrayForKey:@"backgroundPhotoPaths"];
    if (!saved) {
        NSString *legacy = [NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaPath"];
        if (![[NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaType"] isEqualToString:@"video"] && legacy.length) saved = @[legacy];
    }
    NSMutableArray *paths = [NSMutableArray array];
    for (id path in saved) {
        if ([path isKindOfClass:NSString.class] && [NSFileManager.defaultManager fileExistsAtPath:path]) [paths addObject:path];
    }
    return paths;
}

- (BOOL)backgroundVideosMuted {
    NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:@"backgroundVideosMuted"];
    return saved ? saved.boolValue : YES;
}

- (NSTimeInterval)slideshowInterval {
    double interval = [NSUserDefaults.standardUserDefaults doubleForKey:@"backgroundSlideshowInterval"];
    return interval >= 5 && interval <= 300 ? interval : 30;
}

- (BOOL)slideshowEnabled {
    NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:@"backgroundSlideshowEnabled"];
    return saved ? saved.boolValue : YES;
}

- (void)restartSlideshowTimer {
    [self.slideshowTimer invalidate];
    self.slideshowTimer = nil;
    if (!self.backgroundImageView || ![self slideshowEnabled] || [self backgroundPhotoPaths].count < 2) return;
    __weak DashboardController *weakSelf = self;
    self.slideshowTimer = [NSTimer timerWithTimeInterval:[self slideshowInterval] repeats:YES block:^(NSTimer *timer) {
        [weakSelf advanceBackgroundPhoto];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.slideshowTimer forMode:NSRunLoopCommonModes];
}

- (void)advanceBackgroundPhoto {
    NSArray<NSString *> *paths = [self backgroundPhotoPaths];
    if (paths.count < 2 || !self.backgroundImageView) {
        [self.slideshowTimer invalidate];
        self.slideshowTimer = nil;
        return;
    }
    for (NSUInteger attempt = 0; attempt < paths.count; attempt++) {
        self.slideshowIndex = (self.slideshowIndex + 1) % paths.count;
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:paths[self.slideshowIndex]];
        if (!image) continue;
        image.cacheMode = NSImageCacheNever;
        NSString *style = [NSUserDefaults.standardUserDefaults stringForKey:@"photoTransition"] ?: @"Fade";
        [self.backgroundImageView.layer removeAnimationForKey:kCATransition];
        if (![style isEqualToString:@"None"] && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
            CATransition *transition = [CATransition animation];
            transition.type = [style isEqualToString:@"Slide"] ? kCATransitionPush : kCATransitionFade;
            transition.subtype = kCATransitionFromRight;
            transition.duration = 0.6;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.backgroundImageView.layer addAnimation:transition forKey:kCATransition];
        }
        self.backgroundImageView.image = image;
        self.backgroundImageView.needsDisplay = YES;
        break;
    }
}

- (NSString *)backgroundMediaSummary {
    if (![[NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaType"] isEqualToString:@"video"]) {
        NSArray *paths = [self backgroundPhotoPaths];
        if (paths.count > 1) return [NSString stringWithFormat:@"%lu photos", (unsigned long)paths.count];
    }
    NSString *path = [NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaPath"];
    return path.length > 0 ? path.lastPathComponent : @"No image or video selected";
}

- (void)chooseBackgroundMedia:(id)sender {
    BOOL video = [sender tag] == 1;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = video ? @"Choose a Background Video" : @"Choose Background Photos";
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    panel.allowsMultipleSelection = !video;
    panel.allowedContentTypes = video ? @[UTTypeMovie] : @[UTTypeImage];
    if ([panel runModal] != NSModalResponseOK) return;
    NSError *error = nil;
    if (![self importBackgroundURLs:panel.URLs video:video error:&error]) {
        [self showMediaError:error];
        return;
    }
    self.backgroundMediaLabel.stringValue = [self backgroundMediaSummary];
    [self configureBackgroundMedia];
}

- (NSString *)backgroundStorageRoot {
    return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Morning Canvas"] stringByAppendingPathComponent:@"Backgrounds"];
}

- (void)showMediaError:(NSError *)error {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"The background could not be added.";
    alert.informativeText = error.localizedDescription ?: @"Try a different image or video.";
    [alert runModal];
}

- (BOOL)importBackgroundURLs:(NSArray<NSURL *> *)urls video:(BOOL)video error:(NSError **)error {
    if (!urls.count || (video && urls.count != 1)) return NO;
    NSString *directory = [[self backgroundStorageRoot] stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSMutableArray *paths = [NSMutableArray array];
    for (NSURL *source in urls) {
        if (!video && ![[NSImage alloc] initWithContentsOfURL:source]) {
            if (error) *error = [NSError errorWithDomain:@"MorningCanvas" code:1 userInfo:@{NSLocalizedDescriptionKey:@"One of the selected photos could not be opened."}];
            [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
            return NO;
        }
        NSString *filename = [NSString stringWithFormat:@"%lu-%@", (unsigned long)paths.count, source.lastPathComponent];
        NSString *destination = [directory stringByAppendingPathComponent:filename];
        if (![NSFileManager.defaultManager copyItemAtPath:source.path toPath:destination error:error]) {
            [NSFileManager.defaultManager removeItemAtPath:directory error:nil];
            return NO;
        }
        [paths addObject:destination];
    }
    // Commit preferences only after every original has been copied successfully.
    NSArray *oldPaths = [self backgroundPhotoPaths];
    NSString *oldVideo = [NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaPath"];
    [NSUserDefaults.standardUserDefaults setObject:paths.firstObject forKey:@"backgroundMediaPath"];
    [NSUserDefaults.standardUserDefaults setObject:video ? @"video" : @"image" forKey:@"backgroundMediaType"];
    [NSUserDefaults.standardUserDefaults setObject:video ? @[] : paths forKey:@"backgroundPhotoPaths"];
    self.slideshowIndex = 0;
    [self removeManagedBackgroundPaths:oldVideo ? [oldPaths arrayByAddingObject:oldVideo] : oldPaths];
    return YES;
}

- (void)removeManagedBackgroundPaths:(NSArray<NSString *> *)paths {
    NSString *root = [[self backgroundStorageRoot] stringByAppendingString:@"/"];
    for (NSString *path in paths) {
        NSString *resolved = path.stringByStandardizingPath.stringByResolvingSymlinksInPath;
        NSString *resolvedRoot = [[self backgroundStorageRoot].stringByResolvingSymlinksInPath stringByAppendingString:@"/"];
        if ([resolved hasPrefix:resolvedRoot] && [path hasPrefix:root]) {
            [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        }
    }
}

- (void)clearBackgroundMedia:(id)sender {
    NSString *path = [NSUserDefaults.standardUserDefaults stringForKey:@"backgroundMediaPath"];
    NSArray *photos = [self backgroundPhotoPaths];
    [self removeManagedBackgroundPaths:path ? [photos arrayByAddingObject:path] : photos];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"backgroundMediaPath"];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"backgroundMediaType"];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"backgroundPhotoPaths"];
    self.slideshowIndex = 0;
    self.backgroundMediaLabel.stringValue = [self backgroundMediaSummary];
    [self configureBackgroundMedia];
}

- (void)applyTheme {
    NSString *theme = [NSUserDefaults.standardUserDefaults stringForKey:@"appearanceTheme"] ?: @"System";
    NSColor *background = nil;
    if ([theme isEqualToString:@"Dark"]) {
        self.view.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        background = [NSColor colorWithSRGBRed:0.075 green:0.09 blue:0.11 alpha:1.0];
    } else if ([theme isEqualToString:@"Black"]) {
        self.view.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        background = [NSColor colorWithSRGBRed:0.025 green:0.025 blue:0.03 alpha:1.0];
    } else if ([theme isEqualToString:@"Custom"]) {
        background = [self savedCustomBackgroundColor];
        NSColor *rgb = [background colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: background;
        CGFloat brightness = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent;
        self.view.appearance = [NSAppearance appearanceNamed:brightness < 0.48 ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
    } else {
        self.view.appearance = [theme isEqualToString:@"System"] ? nil : [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        if ([theme isEqualToString:@"Green"]) background = [NSColor colorWithSRGBRed:0.88 green:0.96 blue:0.89 alpha:1.0];
        else if ([theme isEqualToString:@"Blue"]) background = [NSColor colorWithSRGBRed:0.88 green:0.94 blue:1.0 alpha:1.0];
        else if ([theme isEqualToString:@"Grey"]) background = [NSColor colorWithSRGBRed:0.82 green:0.84 blue:0.86 alpha:1.0];
        else if ([theme isEqualToString:@"Purple"]) background = [NSColor colorWithSRGBRed:0.93 green:0.89 blue:0.98 alpha:1.0];
        else if ([theme isEqualToString:@"Red"]) background = [NSColor colorWithSRGBRed:1.0 green:0.89 blue:0.89 alpha:1.0];
        else if ([theme isEqualToString:@"White"]) background = NSColor.whiteColor;
        else background = NSColor.windowBackgroundColor;
    }
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = background.CGColor;
    self.view.needsDisplay = YES;
    [self updateBackgroundOverlay];
}

- (void)changeAppearance:(id)sender {
    if (!self.appearancePanel) {
        self.appearancePanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 520, 360)
                                                          styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                            backing:NSBackingStoreBuffered
                                                              defer:NO];
        self.appearancePanel.title = @"Appearance";
        self.appearancePanel.floatingPanel = YES;
        NSView *appearanceView = self.appearancePanel.contentView;

        [appearanceView addSubview:[self label:@"Dashboard appearance" frame:NSMakeRect(24, 316, 412, 28) size:19 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        NSTabView *settingsTabs = [[NSTabView alloc] initWithFrame:NSMakeRect(20, 58, 480, 248)];
        [appearanceView addSubview:settingsTabs];

        NSView *themeView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 210)];
        [themeView addSubview:[self label:@"Color theme" frame:NSMakeRect(18, 164, 160, 22) size:13 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        self.appearanceChoices = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(18, 126, 364, 30) pullsDown:NO];
        [self.appearanceChoices addItemsWithTitles:@[@"System", @"White", @"Light", @"Grey", @"Black", @"Dark", @"Blue", @"Green", @"Purple", @"Red", @"Custom"]];
        [themeView addSubview:self.appearanceChoices];
        [themeView addSubview:[self label:@"Custom background" frame:NSMakeRect(18, 76, 142, 24) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.customColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(160, 73, 54, 30)];
        self.customColorWell.target = self;
        self.customColorWell.action = @selector(customColorChanged:);
        self.customColorWell.toolTip = @"Open the macOS color wheel";
        [themeView addSubview:self.customColorWell];
        NSButton *colorWheel = [NSButton buttonWithTitle:@"Color Wheel..." target:self action:@selector(openColorWheel:)];
        colorWheel.frame = NSMakeRect(224, 71, 108, 32);
        colorWheel.bezelStyle = NSBezelStyleRounded;
        [themeView addSubview:colorWheel];
        self.confettiCheckbox = [NSButton checkboxWithTitle:@"Confetti when work is checked off" target:nil action:nil];
        self.confettiCheckbox.frame = NSMakeRect(18, 20, 364, 26);
        [themeView addSubview:self.confettiCheckbox];
        NSTabViewItem *themeItem = [[NSTabViewItem alloc] initWithIdentifier:@"theme"];
        themeItem.label = @"Theme";
        themeItem.view = themeView;
        [settingsTabs addTabViewItem:themeItem];

        NSView *glassView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 210)];
        [glassView addSubview:[self label:@"Glass style" frame:NSMakeRect(18, 164, 136, 24) size:13 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        self.glassModeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Clear", @"Tinted"]
                                                                  trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                        target:nil
                                                                        action:nil];
        self.glassModeControl.frame = NSMakeRect(160, 161, 172, 30);
        self.glassModeControl.segmentStyle = NSSegmentStyleCapsule;
        [glassView addSubview:self.glassModeControl];

        [glassView addSubview:[self label:@"Tint color" frame:NSMakeRect(18, 112, 136, 24) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.glassTintColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(160, 109, 54, 30)];
        self.glassTintColorWell.toolTip = @"Choose the glass bubble tint";
        [glassView addSubview:self.glassTintColorWell];
        NSButton *glassColorWheel = [NSButton buttonWithTitle:@"Color Wheel..." target:self action:@selector(openGlassTintColorWheel:)];
        glassColorWheel.frame = NSMakeRect(224, 107, 108, 32);
        glassColorWheel.bezelStyle = NSBezelStyleRounded;
        [glassView addSubview:glassColorWheel];

        [glassView addSubview:[self label:@"Opacity" frame:NSMakeRect(18, 60, 136, 24) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.glassOpacitySlider = [NSSlider sliderWithValue:0.22 minValue:0 maxValue:0.65 target:nil action:nil];
        self.glassOpacitySlider.frame = NSMakeRect(160, 61, 210, 22);
        [glassView addSubview:self.glassOpacitySlider];
        NSTabViewItem *glassItem = [[NSTabViewItem alloc] initWithIdentifier:@"glass"];
        glassItem.label = @"Glass";
        glassItem.view = glassView;
        [settingsTabs addTabViewItem:glassItem];

        NSView *backgroundView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 210)];
        [backgroundView addSubview:[self label:@"Background media" frame:NSMakeRect(18, 164, 136, 22) size:13 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        NSButton *chooseMedia = [NSButton buttonWithTitle:@"Photos..." target:self action:@selector(chooseBackgroundMedia:)];
        chooseMedia.frame = NSMakeRect(152, 157, 78, 32);
        chooseMedia.toolTip = @"Choose one or more original-resolution photos";
        chooseMedia.bezelStyle = NSBezelStyleRounded;
        [backgroundView addSubview:chooseMedia];
        NSButton *chooseVideo = [NSButton buttonWithTitle:@"Video..." target:self action:@selector(chooseBackgroundMedia:)];
        chooseVideo.tag = 1;
        chooseVideo.frame = NSMakeRect(234, 157, 72, 32);
        chooseVideo.bezelStyle = NSBezelStyleRounded;
        [backgroundView addSubview:chooseVideo];
        NSButton *clearMedia = [NSButton buttonWithTitle:@"Remove" target:self action:@selector(clearBackgroundMedia:)];
        clearMedia.frame = NSMakeRect(310, 157, 72, 32);
        clearMedia.bezelStyle = NSBezelStyleRounded;
        [backgroundView addSubview:clearMedia];
        self.backgroundMediaLabel = [self label:@"" frame:NSMakeRect(18, 124, 364, 20) size:11 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];
        self.backgroundMediaLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.backgroundMediaLabel.maximumNumberOfLines = 1;
        [backgroundView addSubview:self.backgroundMediaLabel];

        [backgroundView addSubview:[self label:@"Dimming" frame:NSMakeRect(18, 76, 136, 22) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.backgroundDimmingSlider = [NSSlider sliderWithValue:0.28 minValue:0 maxValue:0.65 target:nil action:nil];
        self.backgroundDimmingSlider.frame = NSMakeRect(160, 77, 210, 22);
        [backgroundView addSubview:self.backgroundDimmingSlider];
        NSTabViewItem *backgroundItem = [[NSTabViewItem alloc] initWithIdentifier:@"background"];
        backgroundItem.label = @"Background";
        backgroundItem.view = backgroundView;
        [settingsTabs addTabViewItem:backgroundItem];

        NSView *playbackView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 210)];
        self.slideshowCheckbox = [NSButton checkboxWithTitle:@"Rotate background photos" target:nil action:nil];
        self.slideshowCheckbox.frame = NSMakeRect(18, 163, 364, 24);
        [playbackView addSubview:self.slideshowCheckbox];
        [playbackView addSubview:[self label:@"Change photo every" frame:NSMakeRect(18, 117, 160, 24) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.slideshowIntervalChoice = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(182, 115, 188, 28) pullsDown:NO];
        NSArray *intervals = @[@5, @15, @30, @60, @300];
        [self.slideshowIntervalChoice addItemsWithTitles:@[@"5 seconds", @"15 seconds", @"30 seconds", @"1 minute", @"5 minutes"]];
        for (NSUInteger i = 0; i < intervals.count; i++) [self.slideshowIntervalChoice itemAtIndex:i].tag = [intervals[i] integerValue];
        [playbackView addSubview:self.slideshowIntervalChoice];
        self.muteVideoCheckbox = [NSButton checkboxWithTitle:@"Mute background videos" target:nil action:nil];
        [playbackView addSubview:[self label:@"Photo transition" frame:NSMakeRect(18, 71, 160, 24) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.photoTransitionChoice = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(182, 69, 188, 28) pullsDown:NO];
        [self.photoTransitionChoice addItemsWithTitles:@[@"None", @"Fade", @"Slide"]];
        [playbackView addSubview:self.photoTransitionChoice];
        self.muteVideoCheckbox.frame = NSMakeRect(18, 22, 364, 24);
        [playbackView addSubview:self.muteVideoCheckbox];
        NSTabViewItem *playbackItem = [[NSTabViewItem alloc] initWithIdentifier:@"playback"];
        playbackItem.label = @"Playback";
        playbackItem.view = playbackView;
        [settingsTabs addTabViewItem:playbackItem];

        NSView *updatesView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 210)];
        self.automaticUpdatesCheckbox = [NSButton checkboxWithTitle:@"Automatic app updates" target:nil action:nil];
        self.automaticUpdatesCheckbox.frame = NSMakeRect(18, 162, 364, 26);
        [updatesView addSubview:self.automaticUpdatesCheckbox];
        NSButton *checkUpdates = [NSButton buttonWithTitle:@"Check for Updates..." target:self action:@selector(checkForUpdates:)];
        checkUpdates.frame = NSMakeRect(18, 110, 190, 32);
        checkUpdates.bezelStyle = NSBezelStyleRounded;
        [updatesView addSubview:checkUpdates];
        NSTabViewItem *updatesItem = [[NSTabViewItem alloc] initWithIdentifier:@"updates"];
        updatesItem.label = @"Updates";
        updatesItem.view = updatesView;
        [settingsTabs addTabViewItem:updatesItem];

        NSView *textView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 210)];
        self.customTextCheckbox = [NSButton checkboxWithTitle:@"Custom word colors" target:nil action:nil];
        self.customTextCheckbox.frame = NSMakeRect(18, 162, 364, 26);
        [textView addSubview:self.customTextCheckbox];
        [textView addSubview:[self label:@"Text and buttons" frame:NSMakeRect(18, 112, 160, 24) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.textColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(182, 109, 70, 30)];
        self.textColorWell.toolTip = @"Choose text and button color";
        [textView addSubview:self.textColorWell];
        [textView addSubview:[self label:@"Assignment links" frame:NSMakeRect(18, 60, 160, 24) size:13 weight:NSFontWeightRegular color:NSColor.labelColor]];
        self.linkColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(182, 57, 70, 30)];
        self.linkColorWell.toolTip = @"Choose assignment and announcement link color";
        [textView addSubview:self.linkColorWell];
        NSTabViewItem *textItem = [[NSTabViewItem alloc] initWithIdentifier:@"text"];
        textItem.label = @"Text";
        textItem.view = textView;
        [settingsTabs addTabViewItem:textItem];

        NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelAppearance:)];
        cancel.frame = NSMakeRect(336, 16, 76, 32);
        cancel.bezelStyle = NSBezelStyleRounded;
        [appearanceView addSubview:cancel];
        NSButton *apply = [NSButton buttonWithTitle:@"Apply" target:self action:@selector(applyAppearanceChoice:)];
        apply.frame = NSMakeRect(420, 16, 76, 32);
        apply.bezelStyle = NSBezelStyleRounded;
        apply.keyEquivalent = @"\r";
        [appearanceView addSubview:apply];
    }
    NSString *saved = [NSUserDefaults.standardUserDefaults stringForKey:@"appearanceTheme"] ?: @"System";
    [self.appearanceChoices selectItemWithTitle:saved];
    self.customColorWell.color = [self savedCustomBackgroundColor];
    self.confettiCheckbox.state = [self confettiEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    self.customTextCheckbox.state = [NSUserDefaults.standardUserDefaults boolForKey:@"customTextColors"] ? NSControlStateValueOn : NSControlStateValueOff;
    self.textColorWell.color = [self wordColorForKey:@"wordColor" fallback:NSColor.labelColor];
    self.linkColorWell.color = [self wordColorForKey:@"wordLinkColor" fallback:NSColor.controlAccentColor];
    self.glassTintColorWell.color = [self savedGlassTintColor];
    self.glassModeControl.selectedSegment = [self glassTintEnabled] ? 1 : 0;
    self.glassOpacitySlider.doubleValue = [self glassOpacity];
    NSNumber *savedDimming = [NSUserDefaults.standardUserDefaults objectForKey:@"backgroundMediaDimming"];
    self.backgroundDimmingSlider.doubleValue = savedDimming ? savedDimming.doubleValue : 0.28;
    self.backgroundMediaLabel.stringValue = [self backgroundMediaSummary];
    self.slideshowCheckbox.state = [self slideshowEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [self.photoTransitionChoice selectItemWithTitle:[NSUserDefaults.standardUserDefaults stringForKey:@"photoTransition"] ?: @"Fade"];
    [self.slideshowIntervalChoice selectItemWithTag:(NSInteger)[self slideshowInterval]];
    self.muteVideoCheckbox.state = [self backgroundVideosMuted] ? NSControlStateValueOn : NSControlStateValueOff;
    SPUUpdater *updater = self.updaterController.updater;
    self.initialAutomaticUpdates = updater.automaticallyChecksForUpdates || updater.automaticallyDownloadsUpdates;
    self.automaticUpdatesCheckbox.state = self.initialAutomaticUpdates ? NSControlStateValueOn : NSControlStateValueOff;
    self.appearancePanel.appearance = self.view.effectiveAppearance;
    [self.appearancePanel center];
    [self.appearancePanel makeKeyAndOrderFront:nil];
}

- (void)applyAppearanceChoice:(id)sender {
    [NSUserDefaults.standardUserDefaults setBool:self.confettiCheckbox.state == NSControlStateValueOn forKey:@"completionConfetti"];
    [NSUserDefaults.standardUserDefaults setBool:self.customTextCheckbox.state == NSControlStateValueOn forKey:@"customTextColors"];
    [self saveWordColor:self.textColorWell.color key:@"wordColor"];
    [self saveWordColor:self.linkColorWell.color key:@"wordLinkColor"];
    [self saveCustomBackgroundColor:self.customColorWell.color];
    [self saveGlassTintColor:self.glassTintColorWell.color];
    [NSUserDefaults.standardUserDefaults setBool:(self.glassModeControl.selectedSegment == 1) forKey:@"glassTintEnabled"];
    [NSUserDefaults.standardUserDefaults setDouble:self.glassOpacitySlider.doubleValue forKey:@"glassOpacity"];
    [NSUserDefaults.standardUserDefaults setObject:self.appearanceChoices.titleOfSelectedItem forKey:@"appearanceTheme"];
    [NSUserDefaults.standardUserDefaults setDouble:self.backgroundDimmingSlider.doubleValue forKey:@"backgroundMediaDimming"];
    [NSUserDefaults.standardUserDefaults setBool:self.slideshowCheckbox.state == NSControlStateValueOn forKey:@"backgroundSlideshowEnabled"];
    [NSUserDefaults.standardUserDefaults setObject:self.photoTransitionChoice.titleOfSelectedItem forKey:@"photoTransition"];
    [NSUserDefaults.standardUserDefaults setDouble:self.slideshowIntervalChoice.selectedItem.tag forKey:@"backgroundSlideshowInterval"];
    [NSUserDefaults.standardUserDefaults setBool:self.muteVideoCheckbox.state == NSControlStateValueOn forKey:@"backgroundVideosMuted"];
    self.backgroundPlayer.muted = [self backgroundVideosMuted];
    [self restartSlideshowTimer];
    BOOL automatic = self.automaticUpdatesCheckbox.state == NSControlStateValueOn;
    if (automatic != self.initialAutomaticUpdates) {
        self.updaterController.updater.automaticallyChecksForUpdates = automatic;
        self.updaterController.updater.automaticallyDownloadsUpdates = automatic;
    }
    [NSColorPanel.sharedColorPanel orderOut:nil];
    [self.appearancePanel orderOut:nil];
    [self applyTheme];
    [self refreshGlassViewsInView:self.view];
    [self renderClassList];
    [self showSelectedTab];
}

- (NSColor *)wordColorForKey:(NSString *)key fallback:(NSColor *)fallback {
    NSArray *components = [NSUserDefaults.standardUserDefaults arrayForKey:key];
    if (components.count != 3) return fallback;
    for (id value in components) if (![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue])) return fallback;
    return [NSColor colorWithSRGBRed:[components[0] doubleValue] green:[components[1] doubleValue] blue:[components[2] doubleValue] alpha:1];
}

- (void)saveWordColor:(NSColor *)color key:(NSString *)key {
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if (rgb) [NSUserDefaults.standardUserDefaults setObject:@[@(rgb.redComponent), @(rgb.greenComponent), @(rgb.blueComponent)] forKey:key];
}

- (void)applyWordColorsToView:(NSView *)view {
    BOOL custom = [NSUserDefaults.standardUserDefaults boolForKey:@"customTextColors"];
    NSColor *text = [self wordColorForKey:@"wordColor" fallback:NSColor.labelColor];
    if ([view isKindOfClass:NSTextField.class] && ![(NSTextField *)view isEditable]) {
        NSTextField *field = (NSTextField *)view;
        NSColor *original = objc_getAssociatedObject(field, &OriginalTextStyleKey);
        if (!original) {
            original = field.textColor ?: NSColor.labelColor;
            objc_setAssociatedObject(field, &OriginalTextStyleKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        field.textColor = custom ? text : original;
    } else if ([view isKindOfClass:NSButton.class] && ![view isKindOfClass:NSPopUpButton.class]) {
        NSButton *button = (NSButton *)view;
        NSAttributedString *original = objc_getAssociatedObject(button, &OriginalTextStyleKey);
        if (!original) {
            original = button.attributedTitle;
            objc_setAssociatedObject(button, &OriginalTextStyleKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSString *action = NSStringFromSelector(button.action) ?: @"";
        BOOL link = [@[@"openTodoItem:", @"openTestItem:", @"openAnnouncement:", @"openGradedAssignment:", @"openOverview:", @"openSubmittedItem:"] containsObject:action];
        NSColor *color = link ? [self wordColorForKey:@"wordLinkColor" fallback:NSColor.controlAccentColor] : text;
        button.contentTintColor = custom ? color : (link ? NSColor.controlAccentColor : nil);
        NSMutableAttributedString *title = [original mutableCopy];
        if (custom && title.length) [title addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, title.length)];
        button.attributedTitle = title;
    }
    for (NSView *child in view.subviews) [self applyWordColorsToView:child];
}

- (BOOL)confettiEnabled {
    NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:@"completionConfetti"];
    return saved ? saved.boolValue : YES;
}

- (void)celebrateCompletionAtPoint:(NSPoint)point {
    if (![self confettiEnabled] || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return;
    ConfettiView *overlay = [[ConfettiView alloc] initWithFrame:self.view.bounds];
    overlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    overlay.wantsLayer = YES;
    overlay.layer.masksToBounds = YES;
    [self.view addSubview:overlay positioned:NSWindowAbove relativeTo:nil];
    NSArray *colors = @[NSColor.systemPinkColor, NSColor.systemYellowColor, NSColor.systemTealColor, NSColor.systemBlueColor, NSColor.systemGreenColor];
    for (NSUInteger i = 0; i < 36; i++) {
        CALayer *piece = [CALayer layer];
        piece.bounds = CGRectMake(0, 0, 5 + arc4random_uniform(5), 4 + arc4random_uniform(6));
        piece.position = point;
        piece.backgroundColor = [colors[i % colors.count] CGColor];
        piece.opacity = 0;
        [overlay.layer addSublayer:piece];
        CGFloat dx = (NSInteger)arc4random_uniform(281) - 140;
        CGFloat rise = 70 + arc4random_uniform(140);
        CAKeyframeAnimation *flight = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        flight.values = @[[NSValue valueWithPoint:point], [NSValue valueWithPoint:NSMakePoint(point.x + dx * 0.5, point.y + rise)], [NSValue valueWithPoint:NSMakePoint(point.x + dx, point.y - 100)]];
        flight.keyTimes = @[@0, @0.4, @1];
        flight.calculationMode = kCAAnimationCubic;
        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @0;
        spin.toValue = @((NSInteger)arc4random_uniform(16) - 8);
        CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        fade.values = @[@1, @1, @0];
        fade.keyTimes = @[@0, @0.65, @1];
        flight.duration = spin.duration = fade.duration = 1.2;
        CAAnimationGroup *burst = [CAAnimationGroup animation];
        burst.animations = @[flight, spin, fade];
        burst.duration = 1.2;
        [piece addAnimation:burst forKey:@"confetti"];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [overlay removeFromSuperview]; });
}

- (void)cancelAppearance:(id)sender {
    [NSColorPanel.sharedColorPanel orderOut:nil];
    [self.appearancePanel orderOut:nil];
}

- (void)customColorChanged:(NSColorWell *)sender {
    [self.appearanceChoices selectItemWithTitle:@"Custom"];
}

- (void)openColorWheel:(id)sender {
    NSColorPanel *panel = NSColorPanel.sharedColorPanel;
    panel.showsAlpha = NO;
    panel.color = self.customColorWell.color;
    panel.target = self;
    panel.action = @selector(colorPanelChanged:);
    [panel makeKeyAndOrderFront:nil];
}

- (void)colorPanelChanged:(NSColorPanel *)sender {
    self.customColorWell.color = sender.color;
    [self.appearanceChoices selectItemWithTitle:@"Custom"];
}

- (void)openGlassTintColorWheel:(id)sender {
    NSColorPanel *panel = NSColorPanel.sharedColorPanel;
    panel.showsAlpha = NO;
    panel.color = self.glassTintColorWell.color;
    panel.target = self;
    panel.action = @selector(glassTintColorPanelChanged:);
    [panel makeKeyAndOrderFront:nil];
}

- (void)glassTintColorPanelChanged:(NSColorPanel *)sender {
    self.glassTintColorWell.color = sender.color;
}

- (void)renderClassList {
    NSClipView *clipView = self.classScrollView.contentView;
    BOOL hadScrollableRows = NSHeight(self.classListView.frame) > NSHeight(clipView.bounds) + 1;
    CGFloat previousScrollY = clipView.bounds.origin.y;
    for (NSView *subview in [self.classListView.subviews copy]) [subview removeFromSuperview];
    NSInteger count = self.courses.count + 1;
    CGFloat height = MAX(408, count * 42 + 10);
    self.classListView.frame = NSMakeRect(0, 0, 202, height);

    NSArray *rows = [@[@{@"name":@"All Classes", @"id":[NSNull null]}] arrayByAddingObjectsFromArray:self.courses];
    CGFloat y = height - 42;
    for (NSInteger index = 0; index < rows.count; index++) {
        NSDictionary *course = rows[index];
        NSButton *button = [NSButton buttonWithTitle:course[@"name"] target:self action:@selector(classSelected:)];
        button.tag = index;
        button.bordered = NO;
        button.alignment = NSTextAlignmentLeft;
        button.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        NSNumber *courseId = course[@"id"] == NSNull.null ? nil : course[@"id"];
        NSInteger urgency = 0;
        if (courseId && self.tabs.selectedSegment == 4) urgency = [self urgencyLevelForCourseId:courseId items:self.todoItems];
        else if (courseId && self.tabs.selectedSegment == 3) urgency = [self urgencyLevelForCourseId:courseId items:self.testItems];
        if (urgency > 0) {
            NSColor *dotColor = urgency == 3 ? NSColor.systemRedColor : (urgency == 2 ? NSColor.systemYellowColor : NSColor.systemGreenColor);
            NSView *dot = [[NSView alloc] initWithFrame:NSMakeRect(7, y + 12, 10, 10)];
            dot.wantsLayer = YES;
            dot.layer.backgroundColor = dotColor.CGColor;
            dot.layer.cornerRadius = 5;
            [self.classListView addSubview:dot];
        }
        BOOL selected = (!self.selectedCourseId && !courseId) || [self.selectedCourseId isEqual:courseId];
        NSVisualEffectView *bubble = [self glassViewWithFrame:NSMakeRect(23, y, 171, 34) radius:8];
        bubble.layer.shadowOpacity = 0.08;
        bubble.layer.shadowRadius = 4;
        if (selected) {
            NSColor *selectionColor = [self glassTintEnabled] ? [self savedGlassTintColor] : NSColor.controlAccentColor;
            bubble.layer.backgroundColor = [selectionColor colorWithAlphaComponent:MIN(0.75, [self glassOpacity] + 0.16)].CGColor;
            bubble.layer.borderWidth = 1.5;
        }
        [self.classListView addSubview:bubble];
        button.frame = NSMakeRect(31, y, 155, 34);
        button.state = selected ? NSControlStateValueOn : NSControlStateValueOff;
        [self.classListView addSubview:button];
        y -= 42;
    }
    CGFloat top = MAX(0, height - NSHeight(clipView.bounds));
    CGFloat targetY = hadScrollableRows ? MIN(MAX(0, previousScrollY), top) : top;
    dispatch_async(dispatch_get_main_queue(), ^{
        [clipView scrollToPoint:NSMakePoint(0, targetY)];
        [self.classScrollView reflectScrolledClipView:clipView];
    });
}

- (NSInteger)urgencyLevelForCourseId:(NSNumber *)courseId items:(NSArray<NSDictionary *> *)sourceItems {
    NSDateFormatter *parser = [[NSDateFormatter alloc] init];
    parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    parser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *today = [calendar startOfDayForDate:NSDate.date];
    NSSet *completedKeys = [NSSet setWithArray:[self.localCompletedItems valueForKey:@"completionKey"]];
    NSInteger mostUrgent = 0;
    for (NSDictionary *item in sourceItems) {
        if (courseId && ![item[@"courseId"] isEqual:courseId]) continue;
        NSString *itemKey = [self todoKeyForItem:item];
        if ([self.checkedTodoKeys containsObject:itemKey] || [completedKeys containsObject:itemKey]) continue;
        if (item[@"due"] == NSNull.null) continue;
        NSDate *due = [parser dateFromString:item[@"due"]];
        if (!due) continue;
        NSDate *dueDay = [calendar startOfDayForDate:due];
        NSInteger days = [[calendar components:NSCalendarUnitDay fromDate:today toDate:dueDay options:0] day];
        NSInteger urgency = 0;
        if (days <= 1) urgency = 3;
        else if (days <= 5) urgency = 2;
        else if (days <= 7) urgency = 1;
        mostUrgent = MAX(mostUrgent, urgency);
    }
    return mostUrgent;
}

- (void)classSelected:(NSButton *)sender {
    self.selectedCourseId = sender.tag == 0 ? nil : self.courses[sender.tag - 1][@"id"];
    [self renderClassList];
    [self showSelectedTab];
}

- (NSArray<NSDictionary *> *)items:(NSArray<NSDictionary *> *)items forSelectedClass:(NSString *)key {
    if (!self.selectedCourseId) return items;
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return [item[key] isEqual:self.selectedCourseId];
    }];
    return [items filteredArrayUsingPredicate:predicate];
}

- (void)connectCanvas:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Connect to Canvas";
    alert.informativeText = @"Create an access token in Canvas Account > Settings, then paste it below. Never paste this token into chat.";
    NSView *tokenBox = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 430, 30)];
    self.tokenEntryField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 3, 315, 24)];
    self.tokenEntryField.placeholderString = @"Canvas access token";
    self.tokenEntryField.usesSingleLineMode = YES;
    [tokenBox addSubview:self.tokenEntryField];
    NSButton *pasteButton = [NSButton buttonWithTitle:@"Paste Token" target:self action:@selector(pasteToken:)];
    pasteButton.frame = NSMakeRect(322, 0, 108, 30);
    pasteButton.bezelStyle = NSBezelStyleRounded;
    [tokenBox addSubview:pasteButton];
    alert.accessoryView = tokenBox;
    [alert addButtonWithTitle:@"Save Token"];
    [alert addButtonWithTitle:@"Open Canvas Settings"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert.window makeFirstResponder:self.tokenEntryField];
    NSModalResponse response = [alert runModal];
    NSString *token = [self.tokenEntryField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (response == NSAlertFirstButtonReturn && token.length > 0) {
        [self saveCanvasToken:token];
        self.tokenEntryField.stringValue = @"";
        [self refresh:nil];
    } else if (response == NSAlertSecondButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[CanvasBaseURL stringByAppendingString:@"/profile/settings"]]];
    }
    self.tokenEntryField = nil;
}

- (void)connectCalendar:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Google Calendar";
    alert.informativeText = @"Paste the 'Secret address in iCal format' from Google Calendar settings. The link stays private on this Mac.";
    NSView *urlBox = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 32)];
    self.calendarURLEntryField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 4, 376, 24)];
    self.calendarURLEntryField.placeholderString = @"https://calendar.google.com/calendar/ical/...";
    self.calendarURLEntryField.usesSingleLineMode = YES;
    self.calendarURLEntryField.stringValue = [self calendarURLString] ?: @"";
    [urlBox addSubview:self.calendarURLEntryField];
    NSButton *pasteButton = [NSButton buttonWithTitle:@"Paste Link" target:self action:@selector(pasteCalendarURL:)];
    pasteButton.frame = NSMakeRect(384, 1, 116, 30);
    pasteButton.bezelStyle = NSBezelStyleRounded;
    [urlBox addSubview:pasteButton];
    alert.accessoryView = urlBox;
    [alert addButtonWithTitle:@"Save Calendar"];
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert.window makeFirstResponder:self.calendarURLEntryField];
    NSModalResponse response = [alert runModal];
    NSString *urlString = [self.calendarURLEntryField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.calendarURLEntryField = nil;
    if (response == NSAlertSecondButtonReturn) {
        [NSFileManager.defaultManager removeItemAtURL:[self calendarURLFileURL] error:nil];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"cachedCalendarItems"];
        self.calendarItems = @[];
        self.calendarMessage = @"";
        self.calendarLoadError = nil;
        [self showSelectedTab];
        [self finishLoadingScreenIfReady];
        return;
    }
    if (response != NSAlertFirstButtonReturn) return;
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *scheme = url.scheme.lowercaseString;
    if (!url || (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"webcal"])) {
        NSAlert *invalid = [[NSAlert alloc] init];
        invalid.messageText = @"That calendar link is not valid";
        invalid.informativeText = @"Use the iCal link from Google Calendar settings.";
        [invalid runModal];
        return;
    }
    if ([scheme isEqualToString:@"webcal"]) urlString = [@"https://" stringByAppendingString:[urlString substringFromIndex:9]];
    if (![[self calendarURLString] isEqualToString:urlString]) {
        self.calendarItems = @[];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"cachedCalendarItems"];
    }
    [self saveCalendarURLString:urlString];
    self.tabs.selectedSegment = 2;
    [self refreshCalendar];
}

- (void)pasteCalendarURL:(id)sender {
    NSString *urlString = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
    if (urlString.length > 0) self.calendarURLEntryField.stringValue = [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)pasteToken:(id)sender {
    NSString *token = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    if (token.length > 0) {
        self.tokenEntryField.stringValue = [token stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [self.tokenEntryField selectText:nil];
    }
}

- (NSString *)canvasToken {
    if (self.checkedKeychain) return self.cachedCanvasToken;
    self.checkedKeychain = YES;

    NSURL *tokenURL = [self tokenFileURL];
    NSString *storedToken = [NSString stringWithContentsOfURL:tokenURL encoding:NSUTF8StringEncoding error:nil];
    storedToken = [storedToken stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (storedToken.length > 0) {
        self.cachedCanvasToken = storedToken;
        return self.cachedCanvasToken;
    }

    // Migrate an existing token only when Keychain allows access without showing a password dialog.
    LAContext *authenticationContext = [[LAContext alloc] init];
    authenticationContext.interactionNotAllowed = YES;
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService:KeychainService,
                            (__bridge id)kSecAttrAccount:@"canvas-access-token",
                            (__bridge id)kSecReturnData:@YES,
                            (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitOne,
                            (__bridge id)kSecUseAuthenticationContext:authenticationContext};
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess) return nil;
    NSData *data = CFBridgingRelease(result);
    self.cachedCanvasToken = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (self.cachedCanvasToken.length > 0) [self saveCanvasToken:self.cachedCanvasToken];
    return self.cachedCanvasToken;
}

- (NSURL *)tokenFileURL {
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [[support URLByAppendingPathComponent:@"Morning Canvas" isDirectory:YES] URLByAppendingPathComponent:@"canvas-token"];
}

- (NSURL *)calendarURLFileURL {
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [[support URLByAppendingPathComponent:@"Morning Canvas" isDirectory:YES] URLByAppendingPathComponent:@"calendar-url"];
}

- (NSString *)calendarURLString {
    NSString *urlString = [NSString stringWithContentsOfURL:[self calendarURLFileURL] encoding:NSUTF8StringEncoding error:nil];
    return [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)saveCalendarURLString:(NSString *)urlString {
    NSURL *url = [self calendarURLFileURL];
    NSURL *directory = url.URLByDeletingLastPathComponent;
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
    [urlString writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:url.path error:nil];
}

- (void)saveCanvasToken:(NSString *)token {
    NSURL *tokenURL = [self tokenFileURL];
    NSURL *directory = [tokenURL URLByDeletingLastPathComponent];
    NSDictionary *directoryPermissions = @{NSFilePosixPermissions:@0700};
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:directoryPermissions error:nil];
    [token writeToURL:tokenURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:tokenURL.path error:nil];
    self.cachedCanvasToken = token;
    self.checkedKeychain = YES;
}

- (id)fetchJSON:(NSString *)path token:(NSString *)token error:(NSError **)error {
    SchoolLoadRun *run = [SchoolLoadRun new];
    id result = [self fetchJSON:path token:token run:run error:error];
    [run.session finishTasksAndInvalidate];
    return result;
}

- (id)fetchJSON:(NSString *)path token:(NSString *)token run:(SchoolLoadRun *)run error:(NSError **)error {
    NSURL *url = [NSURL URLWithString:[CanvasBaseURL stringByAppendingString:path]];
    NSMutableArray *items = [NSMutableArray array];
    NSMutableSet *visited = [NSMutableSet set];
    while (url) {
        if (run.cancelled || NSProcessInfo.processInfo.systemUptime >= run.deadline || visited.count >= 250) {
            if (error) *error = [NSError errorWithDomain:@"MorningCanvas" code:NSURLErrorTimedOut userInfo:@{NSLocalizedDescriptionKey:@"Canvas is taking too long. Check your connection and try again."}];
            return nil;
        }
        NSURL *base = [NSURL URLWithString:CanvasBaseURL];
        // Never send the token to a pagination URL outside this Canvas server.
        if (![url.scheme isEqualToString:base.scheme] || ![url.host isEqualToString:base.host] ||
            ![(url.port ?: @443) isEqual:(base.port ?: @443)] || url.user || url.password ||
            ![url.path hasPrefix:@"/api/v1/"] || [visited containsObject:url.absoluteString]) {
            if (error) *error = [NSError errorWithDomain:@"MorningCanvas" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Canvas returned an invalid page link. Please try again."}];
            return nil;
        }
        [visited addObject:url.absoluteString];
        NSURL *next = nil;
        NSArray *page = [self fetchPage:url token:token run:run nextURL:&next error:error];
        if (!page) return nil;
        [items addObjectsFromArray:page];
        url = next;
    }
    return items;
}

- (NSArray *)fetchPage:(NSURL *)url token:(NSString *)token run:(SchoolLoadRun *)run nextURL:(NSURL **)nextURL error:(NSError **)error {
    return [self fetchResponse:url token:token run:run nextURL:nextURL expectArray:YES error:error];
}

- (id)fetchResponse:(NSURL *)url token:(NSString *)token run:(SchoolLoadRun *)run nextURL:(NSURL **)nextURL expectArray:(BOOL)expectArray error:(NSError **)error {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15];
    [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
    __block NSURLResponse *response = nil;
    __block NSError *responseError = nil;
    __block NSData *responseData = nil;
    dispatch_semaphore_t completed = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [run.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *reply, NSError *failure) {
        response = reply;
        responseError = failure;
        responseData = data;
        dispatch_semaphore_signal(completed);
    }];
    [task resume];
    NSTimeInterval remaining = MAX(0, MIN(20, run.deadline - NSProcessInfo.processInfo.systemUptime));
    if (dispatch_semaphore_wait(completed, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC))) != 0) {
        [task cancel];
        if (error) *error = [NSError errorWithDomain:@"MorningCanvas" code:NSURLErrorTimedOut userInfo:@{NSLocalizedDescriptionKey:@"Canvas is taking too long. Check your connection and try again."}];
        return nil;
    }
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    if (responseError || statusCode < 200 || statusCode >= 300 || !responseData) {
        if (error) *error = responseError ?: [NSError errorWithDomain:@"MorningCanvas" code:statusCode userInfo:@{NSLocalizedDescriptionKey:(statusCode == 401 ? @"Canvas rejected the token. Create a new token and reconnect." : @"Canvas could not be reached.")}];
        return nil;
    }
    id page = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:error];
    if (![page isKindOfClass:expectArray ? NSArray.class : NSDictionary.class]) {
        if (error && !*error) *error = [NSError errorWithDomain:@"MorningCanvas" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Canvas returned an unreadable list. Please try again."}];
        return nil;
    }
    NSString *links = [(NSHTTPURLResponse *)response valueForHTTPHeaderField:@"Link"] ?: @"";
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"<([^>]+)>\\s*;\\s*rel=\"next\"" options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *match = [pattern firstMatchInString:links options:0 range:NSMakeRange(0, links.length)];
    if (match) {
        *nextURL = [NSURL URLWithString:[links substringWithRange:[match rangeAtIndex:1]] relativeToURL:url].absoluteURL;
        if (!*nextURL) {
            if (error) *error = [NSError errorWithDomain:@"MorningCanvas" code:3 userInfo:@{NSLocalizedDescriptionKey:@"Canvas returned an invalid page link. Please try again."}];
            return nil;
        }
    }
    return page;
}

- (NSNumber *)scoreFromEnrollment:(NSDictionary *)enrollment {
    if (![enrollment isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *grades = [enrollment[@"grades"] isKindOfClass:NSDictionary.class] ? enrollment[@"grades"] : @{};
    NSArray *candidates = @[
        enrollment[@"override_score"] ?: NSNull.null,
        grades[@"current_score"] ?: NSNull.null,
        enrollment[@"computed_current_score"] ?: NSNull.null
    ];
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    for (id candidate in candidates) {
        if ([candidate isKindOfClass:NSNumber.class]) return candidate;
        if ([candidate isKindOfClass:NSString.class] && [candidate length] > 0) {
            NSNumber *number = [formatter numberFromString:candidate];
            if (number) return number;
        }
    }
    return nil;
}

- (NSString *)courseKeyForValue:(id)value {
    if (!value || value == NSNull.null) return @"";
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return @"";
}

- (BOOL)jsonBoolValue:(id)value {
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (NSString *)letterFromEnrollment:(NSDictionary *)enrollment {
    if (![enrollment isKindOfClass:NSDictionary.class]) return @"";
    NSDictionary *grades = [enrollment[@"grades"] isKindOfClass:NSDictionary.class] ? enrollment[@"grades"] : @{};
    NSArray *candidates = @[
        enrollment[@"override_grade"] ?: NSNull.null,
        grades[@"current_grade"] ?: NSNull.null,
        enrollment[@"computed_current_grade"] ?: NSNull.null
    ];
    for (id candidate in candidates) {
        if ([candidate isKindOfClass:NSString.class] && [candidate length] > 0) return candidate;
    }
    return @"";
}

- (NSString *)gradeURLFromEnrollment:(NSDictionary *)enrollment {
    if (![enrollment isKindOfClass:NSDictionary.class]) return @"";
    NSDictionary *grades = [enrollment[@"grades"] isKindOfClass:NSDictionary.class] ? enrollment[@"grades"] : @{};
    NSString *url = [grades[@"html_url"] isKindOfClass:NSString.class] ? grades[@"html_url"] : @"";
    if (url.length == 0 && [enrollment[@"html_url"] isKindOfClass:NSString.class]) url = enrollment[@"html_url"];
    return url ?: @"";
}

- (NSString *)unescapedCalendarText:(NSString *)text {
    NSString *value = [text stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, text.length)];
    value = [value stringByReplacingOccurrencesOfString:@"\\," withString:@","];
    value = [value stringByReplacingOccurrencesOfString:@"\\;" withString:@";"];
    return [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
}

- (NSDate *)calendarDateFromValue:(NSString *)value property:(NSString *)property allDay:(BOOL *)allDay {
    if (allDay) *allDay = [property containsString:@"VALUE=DATE"] || (value.length == 8 && ![value containsString:@"T"]);
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    if ([value hasSuffix:@"Z"]) {
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyyMMdd'T'HHmmss'Z'";
    } else if ([value containsString:@"T"]) {
        formatter.dateFormat = @"yyyyMMdd'T'HHmmss";
        NSRange tzRange = [property rangeOfString:@"TZID="];
        if (tzRange.location != NSNotFound) {
            NSString *tzName = [property substringFromIndex:NSMaxRange(tzRange)];
            NSRange separator = [tzName rangeOfString:@";"];
            if (separator.location != NSNotFound) tzName = [tzName substringToIndex:separator.location];
            formatter.timeZone = [NSTimeZone timeZoneWithName:tzName] ?: NSTimeZone.localTimeZone;
        } else formatter.timeZone = NSTimeZone.localTimeZone;
    } else {
        formatter.dateFormat = @"yyyyMMdd";
        formatter.timeZone = NSTimeZone.localTimeZone;
    }
    return [formatter dateFromString:value];
}

- (NSDictionary<NSString *, NSString *> *)calendarRecurrenceParts:(NSString *)rule {
    NSMutableDictionary *parts = [NSMutableDictionary dictionary];
    for (NSString *part in [rule componentsSeparatedByString:@";"]) {
        NSRange equals = [part rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        parts[[part substringToIndex:equals.location].uppercaseString] = [part substringFromIndex:NSMaxRange(equals)];
    }
    return parts;
}

- (NSInteger)calendarWeekdayForCode:(NSString *)code {
    NSArray *codes = @[@"", @"SU", @"MO", @"TU", @"WE", @"TH", @"FR", @"SA"];
    NSString *suffix = code.length >= 2 ? [[code substringFromIndex:code.length - 2] uppercaseString] : code.uppercaseString;
    return [codes indexOfObject:suffix] == NSNotFound ? 0 : [codes indexOfObject:suffix];
}

- (NSDate *)calendarMondayForDate:(NSDate *)date {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *day = [calendar startOfDayForDate:date];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:day];
    return [calendar dateByAddingUnit:NSCalendarUnitDay value:-((weekday + 5) % 7) toDate:day options:0];
}

- (NSArray<NSDictionary *> *)expandedCalendarEvents:(NSArray<NSDictionary *> *)events
                                         windowStart:(NSDate *)windowStart
                                           windowEnd:(NSDate *)windowEnd {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSMutableArray<NSDictionary *> *expanded = [NSMutableArray array];
    for (NSDictionary *source in events) {
        NSString *rule = source[@"rrule"];
        if (rule.length == 0) {
            [expanded addObject:source];
            continue;
        }

        NSDictionary *parts = [self calendarRecurrenceParts:rule];
        NSString *frequency = [parts[@"FREQ"] uppercaseString];
        if (![@[@"DAILY", @"WEEKLY"] containsObject:frequency]) {
            [expanded addObject:source];
            continue;
        }

        NSDate *sourceStart = source[@"start"];
        NSDate *sourceEnd = source[@"end"] ?: [sourceStart dateByAddingTimeInterval:[source[@"allDay"] boolValue] ? 24 * 60 * 60 : 45 * 60];
        NSTimeInterval duration = MAX(60, [sourceEnd timeIntervalSinceDate:sourceStart]);
        NSInteger interval = MAX(1, [parts[@"INTERVAL"] integerValue]);
        NSDate *recurrenceEnd = windowEnd;
        if ([parts[@"UNTIL"] length] > 0) {
            NSDate *until = [self calendarDateFromValue:parts[@"UNTIL"] property:@"UNTIL" allDay:NULL];
            if (until && [until compare:recurrenceEnd] == NSOrderedAscending) recurrenceEnd = until;
        }

        NSMutableSet<NSNumber *> *weekdays = [NSMutableSet set];
        for (NSString *code in [parts[@"BYDAY"] componentsSeparatedByString:@","]) {
            NSInteger weekday = [self calendarWeekdayForCode:code];
            if (weekday > 0) [weekdays addObject:@(weekday)];
        }
        if (weekdays.count == 0) {
            [weekdays addObject:@([calendar component:NSCalendarUnitWeekday fromDate:sourceStart])];
        }

        NSDate *sourceDay = [calendar startOfDayForDate:sourceStart];
        NSDate *sourceMonday = [self calendarMondayForDate:sourceStart];
        NSDateComponents *timeParts = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:sourceStart];
        NSDate *day = [calendar startOfDayForDate:windowStart];
        while ([day compare:recurrenceEnd] != NSOrderedDescending) {
            BOOL matches = NO;
            if ([frequency isEqualToString:@"DAILY"]) {
                NSInteger dayDifference = [[calendar components:NSCalendarUnitDay fromDate:sourceDay toDate:day options:0] day];
                matches = dayDifference >= 0 && dayDifference % interval == 0;
            } else {
                NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:day];
                NSDate *candidateMonday = [self calendarMondayForDate:day];
                NSInteger weekDifference = [[calendar components:NSCalendarUnitWeekOfYear fromDate:sourceMonday toDate:candidateMonday options:0] weekOfYear];
                matches = weekDifference >= 0 && weekDifference % interval == 0 && [weekdays containsObject:@(weekday)];
            }

            if (matches) {
                NSDateComponents *dateParts = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:day];
                if (![source[@"allDay"] boolValue]) {
                    dateParts.hour = timeParts.hour;
                    dateParts.minute = timeParts.minute;
                    dateParts.second = timeParts.second;
                }
                NSDate *occurrenceStart = [calendar dateFromComponents:dateParts];
                if ([occurrenceStart compare:sourceStart] != NSOrderedAscending && [occurrenceStart compare:recurrenceEnd] != NSOrderedDescending) {
                    NSMutableDictionary *occurrence = [source mutableCopy];
                    [occurrence removeObjectForKey:@"rrule"];
                    occurrence[@"start"] = occurrenceStart;
                    occurrence[@"end"] = [occurrenceStart dateByAddingTimeInterval:duration];
                    [expanded addObject:occurrence];
                }
            }
            day = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:day options:0];
        }
    }
    return expanded;
}

- (NSArray<NSDictionary *> *)parseCalendarData:(NSData *)data {
    NSString *calendarText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (calendarText.length == 0) return @[];
    calendarText = [calendarText stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    calendarText = [calendarText stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *line in [calendarText componentsSeparatedByString:@"\n"]) {
        if (([line hasPrefix:@" "] || [line hasPrefix:@"\t"]) && lines.count > 0) {
            lines[lines.count - 1] = [lines.lastObject stringByAppendingString:[line substringFromIndex:1]];
        } else [lines addObject:line];
    }

    NSMutableArray<NSDictionary *> *events = [NSMutableArray array];
    NSMutableDictionary *event = nil;
    for (NSString *line in lines) {
        if ([line isEqualToString:@"BEGIN:VEVENT"]) { event = [NSMutableDictionary dictionary]; continue; }
        if ([line isEqualToString:@"END:VEVENT"]) {
            if (event[@"start"] && event[@"title"]) [events addObject:[event copy]];
            event = nil;
            continue;
        }
        if (!event) continue;
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *property = [line substringToIndex:colon.location];
        NSString *key = [[property componentsSeparatedByString:@";"] firstObject];
        NSString *value = [line substringFromIndex:NSMaxRange(colon)];
        if ([key isEqualToString:@"SUMMARY"]) event[@"title"] = [self unescapedCalendarText:value];
        else if ([key isEqualToString:@"LOCATION"]) event[@"location"] = [self unescapedCalendarText:value];
        else if ([key isEqualToString:@"URL"]) event[@"url"] = [self unescapedCalendarText:value];
        else if ([key isEqualToString:@"DESCRIPTION"]) event[@"description"] = [self unescapedCalendarText:value];
        else if ([key isEqualToString:@"RRULE"]) event[@"rrule"] = value;
        else if ([key isEqualToString:@"UID"]) event[@"uid"] = value;
        else if ([key isEqualToString:@"STATUS"]) event[@"status"] = value;
        else if ([key isEqualToString:@"DTSTART"]) {
            BOOL allDay = NO;
            NSDate *date = [self calendarDateFromValue:value property:property allDay:&allDay];
            if (date) { event[@"start"] = date; event[@"allDay"] = @(allDay); }
        } else if ([key isEqualToString:@"DTEND"]) {
            NSDate *date = [self calendarDateFromValue:value property:property allDay:NULL];
            if (date) event[@"end"] = date;
        }
    }

    NSDate *now = NSDate.date;
    NSDate *windowStart = [self calendarMondayForDate:now];
    NSDate *cutoff = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:7 toDate:windowStart options:0];
    NSArray<NSDictionary *> *expandedEvents = [self expandedCalendarEvents:events windowStart:windowStart windowEnd:cutoff];
    NSMutableArray *upcoming = [NSMutableArray array];
    for (NSMutableDictionary *source in expandedEvents) {
        if ([source[@"status"] isEqualToString:@"CANCELLED"]) continue;
        NSDate *start = source[@"start"];
        NSDate *end = source[@"end"] ?: start;
        if ([end compare:windowStart] == NSOrderedAscending || [start compare:cutoff] == NSOrderedDescending) continue;
        NSMutableDictionary *item = [source mutableCopy];
        if (![item[@"url"] length] && [item[@"description"] length]) {
            NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
            NSTextCheckingResult *match = [detector firstMatchInString:item[@"description"] options:0 range:NSMakeRange(0, [item[@"description"] length])];
            if (match.URL.absoluteString.length > 0) item[@"url"] = match.URL.absoluteString;
        }
        [upcoming addObject:item];
    }
    [upcoming sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"start"] compare:b[@"start"]]; }];
    return upcoming;
}

- (BOOL)calendarLinkIsViewingPage:(NSString *)urlString {
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSString *path = components.path.lowercaseString;
    return [components.host.lowercaseString containsString:@"calendar.google.com"] &&
           ([path containsString:@"/calendar/embed"] || [path containsString:@"/calendar/u/"] || [path hasSuffix:@"/calendar/r"]);
}

- (NSURL *)calendarFeedURLForString:(NSString *)urlString {
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if ([components.scheme.lowercaseString isEqualToString:@"webcal"]) components.scheme = @"https";
    if ([components.host.lowercaseString containsString:@"calendar.google.com"] && [components.path.lowercaseString containsString:@"/calendar/embed"]) {
        NSString *calendarId = nil;
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name isEqualToString:@"src"]) { calendarId = item.value; break; }
        }
        if (calendarId.length > 0) {
            NSString *encodedId = [calendarId stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
            return [NSURL URLWithString:[NSString stringWithFormat:@"https://calendar.google.com/calendar/ical/%@/public/basic.ics", encodedId]];
        }
    }
    return components.URL;
}

- (NSString *)calendarCacheKeyForItem:(NSDictionary *)item {
    NSDate *start = item[@"start"];
    NSString *title = item[@"uid"] ?: item[@"title"] ?: @"";
    return [NSString stringWithFormat:@"%.0f|%@", start.timeIntervalSince1970, title];
}

- (NSArray<NSDictionary *> *)calendarItemsByMergingNewItems:(NSArray<NSDictionary *> *)newItems {
    NSArray *snapshot = [self calendarSnapshot:newItems weekOfDate:NSDate.date];
    [NSUserDefaults.standardUserDefaults setObject:snapshot forKey:@"cachedCalendarItems"];
    return snapshot;
}

- (NSArray<NSDictionary *> *)calendarSnapshot:(NSArray<NSDictionary *> *)newItems weekOfDate:(NSDate *)date {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *oldest = [self calendarMondayForDate:date];
    NSDate *newest = [calendar dateByAddingUnit:NSCalendarUnitDay value:7 toDate:oldest options:0];
    NSMutableDictionary<NSString *, NSDictionary *> *itemsByKey = [NSMutableDictionary dictionary];
    // A successful feed is authoritative: removed or rescheduled events must disappear.
    for (NSDictionary *item in newItems) {
        NSDate *start = item[@"start"];
        NSDate *end = item[@"end"] ?: start;
        if (![start isKindOfClass:NSDate.class] || ![end isKindOfClass:NSDate.class] || [end compare:oldest] == NSOrderedAscending || [start compare:newest] != NSOrderedAscending) continue;
        itemsByKey[[self calendarCacheKeyForItem:item]] = item;
    }
    NSArray *merged = [itemsByKey.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"start"] compare:b[@"start"]];
    }];
    return merged;
}

- (BOOL)rollCalendarWeekToDate:(NSDate *)date {
    NSArray *week = [self schoolWeekDatesAroundDate:date];
    if ([week.firstObject isEqual:self.calendarWeekDates.firstObject]) return NO;
    self.calendarWeekDates = week;
    self.selectedCalendarDayIndex = [self defaultCalendarDayIndex];
    self.calendarItems = [self calendarSnapshot:self.calendarItems weekOfDate:date];
    [NSUserDefaults.standardUserDefaults setObject:self.calendarItems forKey:@"cachedCalendarItems"];
    return YES;
}

- (void)refreshCalendar {
    NSString *urlString = [self calendarURLString];
    if (urlString.length == 0 || self.calendarRefreshInProgress) return;
    self.calendarRefreshInProgress = YES;
    self.calendarLoadError = nil;
    if (!self.hasFinishedInitialLoad || (self.loadingScreen && !self.loadingScreen.hidden)) [self showLoadingScreen:@"Loading calendar..."];
    self.calendarMessage = @"Refreshing Google Calendar...";
    if (self.tabs.selectedSegment == 2) [self showSelectedTab];
    BOOL viewingLink = [self calendarLinkIsViewingPage:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self calendarFeedURLForString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:25];
    [request setValue:@"text/calendar, text/plain;q=0.9, */*;q=0.5" forHTTPHeaderField:@"Accept"];
    [request setValue:@"Morning Canvas/3.1" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForResource = 25;
    NSURLSession *calendarSession = [NSURLSession sessionWithConfiguration:config];
    [[calendarSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [calendarSession finishTasksAndInvalidate];
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        NSArray *items = (!error && status >= 200 && status < 300) ? [self parseCalendarData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (items) {
                self.calendarItems = [self calendarItemsByMergingNewItems:items];
                self.calendarMessage = self.calendarItems.count > 0 ? @"" : (viewingLink ? @"This viewing link has no public events. Use the 'Secret address in iCal format' from Google Calendar settings." : @"No upcoming events found. Check that you used the iCal-format link.");
            } else {
                self.calendarMessage = viewingLink ? @"This is a Google Calendar viewing link. Use the 'Secret address in iCal format' from Google Calendar settings." : @"Google Calendar could not be reached. Check the saved calendar link.";
                self.calendarLoadError = self.calendarMessage;
            }
            if (self.tabs.selectedSegment == 2) [self showSelectedTab];
            self.calendarRefreshInProgress = NO;
            [self finishLoadingScreenIfReady];
        });
    }] resume];
}

- (void)autoRefresh:(NSTimer *)timer {
    if ([self canvasToken].length > 0) [self refresh:nil];
    else [self refreshCalendar];
}

- (void)setRefreshStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = status ?: @"Refreshing Canvas...";
        self.loadingStatusLabel.stringValue = self.statusLabel.stringValue;
    });
}

- (void)refresh:(id)sender {
    if (self.refreshInProgress) return;
    [self refreshCalendar];
    NSString *token = [self canvasToken];
    if (token.length == 0) {
        [self connectCanvas:nil];
        return;
    }
    self.refreshInProgress = YES;
    self.canvasLoadError = nil;
    SchoolLoadRun *run = [SchoolLoadRun new];
    self.activeLoadRun = run;
    [self.loadingWatchdog invalidate];
    __weak DashboardController *weakSelf = self;
    self.loadingWatchdog = [NSTimer scheduledTimerWithTimeInterval:65 repeats:NO block:^(NSTimer *timer) {
        [weakSelf expireLoadRun:run];
    }];
    self.statusLabel.stringValue = @"Refreshing Canvas...";
    if (!self.hasFinishedInitialLoad || sender) [self showLoadingScreen:@"Loading schoolwork: 0 of 7"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        NSDictionary *paths = @{
            @"classes": @"/api/v1/courses?enrollment_state=active&include%5B%5D=total_scores&per_page=100",
            @"grades": @"/api/v1/users/self/enrollments?type%5B%5D=StudentEnrollment&state%5B%5D=active&include%5B%5D=current_points&per_page=100",
            @"assignments": @"/api/v1/users/self/todo?include%5B%5D=ungraded_quizzes&per_page=100",
            @"missing work": @"/api/v1/users/self/missing_submissions?per_page=100",
            @"upcoming work": @"/api/v1/users/self/upcoming_events?per_page=100"
        };
        NSMutableDictionary *results = [NSMutableDictionary dictionary];
        NSMutableDictionary *failures = [NSMutableDictionary dictionary];
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 3;
        for (NSString *name in @[@"classes", @"assignments", @"grades", @"missing work", @"upcoming work"]) {
            [queue addOperationWithBlock:^{
                NSError *failure = nil;
                NSArray *items = [self fetchJSON:paths[name] token:token run:run error:&failure];
                @synchronized (results) {
                    if (items) results[name] = items;
                    else failures[name] = failure ?: [NSError errorWithDomain:@"MorningCanvas" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Canvas returned no response."}];
                    NSString *status = [NSString stringWithFormat:@"Loading schoolwork: %lu of 7", (unsigned long)results.count];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.activeLoadRun != run || run.cancelled) return;
                        self.statusLabel.stringValue = status;
                        self.loadingStatusLabel.stringValue = status;
                    });
                }
            }];
        }
        [queue waitUntilAllOperationsAreFinished];
        if (failures.count) {
            NSString *name = [failures.allKeys sortedArrayUsingSelector:@selector(compare:)].firstObject;
            error = [NSError errorWithDomain:@"MorningCanvas" code:1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Could not load %@. %@", name, [failures[name] localizedDescription]]}];
        }
        NSArray *courses = results[@"classes"] ?: @[];
        NSArray *enrollments = results[@"grades"] ?: @[];
        NSArray *todo = results[@"assignments"] ?: @[];
        NSArray *missing = results[@"missing work"] ?: @[];
        NSArray *upcoming = results[@"upcoming work"] ?: @[];
        NSArray *announcements = @[];
        NSMutableArray *submissions = [NSMutableArray array];
        if (!error) {
            __block NSUInteger finishedCourses = 0;
            for (NSDictionary *course in courses) {
                [queue addOperationWithBlock:^{
                    NSError *failure = nil;
                    NSString *path = [NSString stringWithFormat:@"/api/v1/courses/%@/assignments?include%%5B%%5D=submission&per_page=100", course[@"id"]];
                    NSArray *assignments = [self fetchJSON:path token:token run:run error:&failure];
                    @synchronized (submissions) {
                        if (failure) failures[[course[@"id"] description]] = failure;
                        for (NSDictionary *assignment in assignments) {
                            if (![assignment[@"submission"] isKindOfClass:NSDictionary.class]) continue;
                            NSMutableDictionary *submission = [assignment[@"submission"] mutableCopy];
                            submission[@"course_id"] = course[@"id"];
                            submission[@"assignment"] = assignment;
                            [submissions addObject:submission];
                        }
                        finishedCourses++;
                        NSString *status = [NSString stringWithFormat:@"Loading submissions: %lu of %lu classes", (unsigned long)finishedCourses, (unsigned long)courses.count];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (self.activeLoadRun != run || run.cancelled) return;
                            self.loadingStatusLabel.stringValue = status;
                            self.statusLabel.stringValue = status;
                        });
                    }
                }];
            }
            [queue waitUntilAllOperationsAreFinished];
            if (failures.count) error = failures.allValues.firstObject;
        }

        if (!error && courses.count > 0) {
            NSMutableArray *codes = [NSMutableArray array];
            for (NSDictionary *course in courses) {
                if (course[@"id"]) [codes addObject:[NSString stringWithFormat:@"context_codes%%5B%%5D=course_%@", course[@"id"]]];
            }
            NSString *path = [@"/api/v1/announcements?active_only=true&latest_only=true&per_page=100&" stringByAppendingString:[codes componentsJoinedByString:@"&"]];
            id result = [self fetchJSON:path token:token run:run error:&error];
            if ([result isKindOfClass:NSArray.class]) announcements = result;
        }

        [run.session finishTasksAndInvalidate];
        if (run.cancelled) return;

        if (!error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.activeLoadRun != run || run.cancelled) return;
                self.loadingStatusLabel.stringValue = @"Preparing dashboard...";
            });
            NSMutableArray *courseRows = [NSMutableArray array];
            for (NSDictionary *course in courses ?: @[]) {
                if (course[@"id"]) [courseRows addObject:@{@"id":course[@"id"], @"name":course[@"name"] ?: @"Course"}];
            }

            NSMutableArray *announcementRows = [NSMutableArray array];
            for (NSDictionary *announcement in announcements ?: @[]) {
                NSString *postedAt = announcement[@"posted_at"] ?: announcement[@"created_at"];
                if (postedAt.length > 0 && ![self timestampIsInCurrentWeek:postedAt]) continue;
                NSString *context = announcement[@"context_code"] ?: @"";
                NSNumber *courseId = nil;
                if ([context hasPrefix:@"course_"]) courseId = @([[context substringFromIndex:7] integerValue]);
                [announcementRows addObject:@{@"title":announcement[@"title"] ?: @"Announcement",
                                               @"courseId":courseId ?: [NSNull null],
                                               @"postedAt":postedAt ?: @"",
                                               @"url":announcement[@"html_url"] ?: @""}];
            }

            NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *enrollmentsByCourse = [NSMutableDictionary dictionary];
            for (NSDictionary *enrollment in enrollments ?: @[]) {
                id courseId = enrollment[@"course_id"];
                NSString *key = [self courseKeyForValue:courseId];
                if (key.length == 0) continue;
                if (!enrollmentsByCourse[key]) enrollmentsByCourse[key] = [NSMutableArray array];
                [enrollmentsByCourse[key] addObject:enrollment];
            }
            for (NSDictionary *course in courses ?: @[]) {
                id courseId = course[@"id"];
                NSString *key = [self courseKeyForValue:courseId];
                if (key.length == 0) continue;
                if (!enrollmentsByCourse[key]) enrollmentsByCourse[key] = [NSMutableArray array];
                NSArray *courseEnrollments = [course[@"enrollments"] isKindOfClass:NSArray.class] ? course[@"enrollments"] : @[];
                [enrollmentsByCourse[key] addObjectsFromArray:courseEnrollments];
            }

            NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSNumber *> *> *gradedPointsByCourse = [NSMutableDictionary dictionary];
            for (NSDictionary *submission in submissions ?: @[]) {
                if (![submission isKindOfClass:NSDictionary.class]) continue;
                NSDictionary *assignment = [submission[@"assignment"] isKindOfClass:NSDictionary.class] ? submission[@"assignment"] : @{};
                if ([self jsonBoolValue:submission[@"excused"]] || [self jsonBoolValue:assignment[@"omit_from_final_grade"]]) continue;
                id courseId = submission[@"course_id"] ?: assignment[@"course_id"];
                id scoreValue = submission[@"score"];
                id possibleValue = assignment[@"points_possible"];
                NSString *key = [self courseKeyForValue:courseId];
                if (key.length == 0 || ![scoreValue respondsToSelector:@selector(doubleValue)] || ![possibleValue respondsToSelector:@selector(doubleValue)]) continue;
                double possible = [possibleValue doubleValue];
                if (possible <= 0) continue;
                if (!gradedPointsByCourse[key]) gradedPointsByCourse[key] = [@{@"earned":@0.0, @"possible":@0.0} mutableCopy];
                NSMutableDictionary *totals = gradedPointsByCourse[key];
                totals[@"earned"] = @([totals[@"earned"] doubleValue] + [scoreValue doubleValue]);
                totals[@"possible"] = @([totals[@"possible"] doubleValue] + possible);
            }

            NSMutableArray *gradeRows = [NSMutableArray array];
            for (NSDictionary *course in courses ?: @[]) {
                id courseId = course[@"id"];
                NSString *courseKey = [self courseKeyForValue:courseId];
                NSArray<NSDictionary *> *courseEnrollments = courseKey.length > 0 ? enrollmentsByCourse[courseKey] : @[];
                NSNumber *score = nil;
                NSString *letter = @"";
                NSString *gradeURL = @"";
                BOOL calculated = NO;
                for (NSDictionary *enrollment in courseEnrollments) {
                    NSNumber *candidateScore = [self scoreFromEnrollment:enrollment];
                    NSString *candidateLetter = [self letterFromEnrollment:enrollment];
                    NSString *candidateURL = [self gradeURLFromEnrollment:enrollment];
                    if (gradeURL.length == 0 && candidateURL.length > 0) gradeURL = candidateURL;
                    if (candidateScore || candidateLetter.length > 0) {
                        score = candidateScore;
                        letter = candidateLetter;
                        if (candidateURL.length > 0) gradeURL = candidateURL;
                        break;
                    }
                }
                if (!score && courseKey.length > 0) {
                    NSDictionary *totals = gradedPointsByCourse[courseKey];
                    double possible = [totals[@"possible"] doubleValue];
                    if (possible > 0) {
                        score = @([totals[@"earned"] doubleValue] / possible * 100.0);
                        calculated = YES;
                    }
                }
                [gradeRows addObject:@{@"name":course[@"name"] ?: @"Course",
                                       @"courseId":courseId ?: NSNull.null,
                                       @"score":score ?: NSNull.null,
                                       @"letter":letter ?: @"",
                                       @"url":gradeURL ?: @"",
                                       @"calculated":@(calculated)}];
            }

            NSMutableDictionary *deduped = [NSMutableDictionary dictionary];
            for (NSDictionary *item in todo ?: @[]) {
                NSDictionary *assignment = item[@"assignment"] ?: item[@"quiz"];
                NSString *key = [NSString stringWithFormat:@"%@", assignment[@"id"] ?: item[@"html_url"] ?: NSUUID.UUID.UUIDString];
                NSString *name = assignment[@"name"] ?: item[@"type"] ?: @"Canvas item";
                deduped[key] = @{ @"id":assignment[@"id"] ?: key,
                                  @"name":name,
                                  @"courseId":assignment[@"course_id"] ?: item[@"course_id"] ?: [NSNull null],
                                  @"due":assignment[@"due_at"] ?: [NSNull null],
                                  @"url":assignment[@"html_url"] ?: item[@"html_url"] ?: @"",
                                  @"isTest":@([item[@"quiz"] isKindOfClass:NSDictionary.class] || [self isTestAssignment:assignment name:name]),
                                  @"missing":@NO };
            }
            for (NSDictionary *assignment in missing ?: @[]) {
                NSString *key = [NSString stringWithFormat:@"%@", assignment[@"id"] ?: NSUUID.UUID.UUIDString];
                NSString *name = assignment[@"name"] ?: @"Missing assignment";
                deduped[key] = @{ @"id":assignment[@"id"] ?: key,
                                  @"name":name,
                                  @"courseId":assignment[@"course_id"] ?: [NSNull null],
                                  @"due":assignment[@"due_at"] ?: [NSNull null],
                                  @"url":assignment[@"html_url"] ?: @"",
                                  @"isTest":@([self isTestAssignment:assignment name:name]),
                                  @"missing":@YES };
            }
            NSArray *sortedTodos = [[deduped allValues] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                id ad = a[@"due"], bd = b[@"due"];
                if (ad == NSNull.null) return NSOrderedDescending;
                if (bd == NSNull.null) return NSOrderedAscending;
                return [ad compare:bd];
            }];
            NSArray *homeworkTodos = [sortedTodos filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
                return [self belongsInTodo:item];
            }]];

            NSMutableDictionary *dedupedTests = [NSMutableDictionary dictionary];
            for (NSDictionary *item in sortedTodos) {
                if ([item[@"isTest"] boolValue]) dedupedTests[[self todoKeyForItem:item]] = item;
            }
            for (NSDictionary *event in upcoming ?: @[]) {
                NSDictionary *assignment = [event[@"assignment"] isKindOfClass:NSDictionary.class] ? event[@"assignment"] : @{};
                NSString *name = assignment[@"name"] ?: event[@"title"] ?: @"Upcoming test";
                if (![self isTestAssignment:assignment name:name]) continue;
                NSString *context = event[@"context_code"] ?: @"";
                NSNumber *courseId = assignment[@"course_id"];
                if (!courseId && [context hasPrefix:@"course_"]) courseId = @([[context substringFromIndex:7] integerValue]);
                id eventId = assignment[@"id"] ?: event[@"id"] ?: NSUUID.UUID.UUIDString;
                NSDictionary *test = @{ @"id":eventId,
                                        @"name":name,
                                        @"courseId":courseId ?: [NSNull null],
                                        @"due":assignment[@"due_at"] ?: event[@"start_at"] ?: [NSNull null],
                                        @"url":assignment[@"html_url"] ?: event[@"html_url"] ?: @"",
                                        @"isTest":@YES,
                                        @"missing":@NO };
                dedupedTests[[self todoKeyForItem:test]] = test;
            }
            NSArray *sortedTests = [[dedupedTests allValues] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                id ad = a[@"due"], bd = b[@"due"];
                if (ad == NSNull.null) return NSOrderedDescending;
                if (bd == NSNull.null) return NSOrderedAscending;
                return [ad compare:bd];
            }];

            NSMutableDictionary *dedupedSubmissions = [NSMutableDictionary dictionary];
            for (NSDictionary *submission in submissions) {
                id submittedAt = submission[@"submitted_at"];
                if (!submittedAt || submittedAt == NSNull.null) continue;
                if (![self timestampIsInCurrentWeek:submittedAt]) continue;
                NSDictionary *assignment = submission[@"assignment"];
                NSNumber *courseId = submission[@"course_id"] ?: assignment[@"course_id"];
                id assignmentId = submission[@"assignment_id"] ?: assignment[@"id"];
                NSString *key = [NSString stringWithFormat:@"%@-%@", courseId ?: @"course", assignmentId ?: NSUUID.UUID.UUIDString];
                dedupedSubmissions[key] = @{ @"id":assignmentId ?: key,
                                             @"name":assignment[@"name"] ?: @"Submitted assignment",
                                             @"courseId":courseId ?: [NSNull null],
                                             @"submittedAt":submittedAt,
                                             @"url":assignment[@"html_url"] ?: submission[@"html_url"] ?: @"" };
            }
            NSArray *sortedSubmissions = [[dedupedSubmissions allValues] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                return [b[@"submittedAt"] compare:a[@"submittedAt"]];
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.activeLoadRun != run || run.cancelled) return;
                [self.loadingWatchdog invalidate];
                self.activeLoadRun = nil;
                self.refreshInProgress = NO;
                self.courses = courseRows;
                self.announcements = announcementRows;
                self.grades = gradeRows;
                self.gradedAssignments = [self gradeDetailsFromSubmissions:submissions];
                self.overviewLoaded = NO;
                self.testItems = sortedTests;
                self.todoItems = homeworkTodos;
                self.submittedItems = sortedSubmissions;
                for (NSDictionary *item in homeworkTodos) {
                    NSString *key = [self todoKeyForItem:item];
                    if ([self.checkedTodoKeys containsObject:key]) [self scheduleMoveForItem:item key:key];
                }
                if (self.selectedCourseId) {
                    BOOL stillExists = [[courseRows valueForKey:@"id"] containsObject:self.selectedCourseId];
                    if (!stillExists) self.selectedCourseId = nil;
                }
                self.statusLabel.stringValue = [NSString stringWithFormat:@"Updated %@", [NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle]];
                [self renderClassList];
                [self showSelectedTab];
                [self finishLoadingScreenIfReady];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.activeLoadRun != run || run.cancelled) return;
                [self.loadingWatchdog invalidate];
                self.activeLoadRun = nil;
                self.refreshInProgress = NO;
                self.statusLabel.stringValue = error.localizedDescription ?: @"Canvas refresh failed.";
                self.canvasLoadError = self.statusLabel.stringValue;
                [self showSelectedTab];
                [self finishLoadingScreenIfReady];
            });
        }
    });
}

- (void)showSelectedTab {
    for (NSView *subview in [self.contentView.subviews copy]) [subview removeFromSuperview];
    self.contentView.frame = NSMakeRect(0, 0, 728, 374);
    if (self.tabs.selectedSegment == 0) [self showAnnouncements];
    else if (self.tabs.selectedSegment == 1) [self showGrades];
    else if (self.tabs.selectedSegment == 2) [self showCalendar];
    else if (self.tabs.selectedSegment == 3) [self showTests];
    else if (self.tabs.selectedSegment == 4) [self showTodo];
    else if (self.tabs.selectedSegment == 5) [self showSubmitted];
    else [self showWeeklyOverviews];
    [self applyWordColorsToView:self.view];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollContentToTop];
    });
}

- (CGFloat)prepareScrollableRows:(NSInteger)rowCount rowHeight:(CGFloat)rowHeight {
    CGFloat height = MAX(374, rowCount * rowHeight + 24);
    self.contentView.frame = NSMakeRect(0, 0, 728, height);
    return height - 36;
}

- (void)scrollContentToTop {
    NSClipView *clipView = self.contentScrollView.contentView;
    CGFloat top = MAX(0, NSHeight(self.contentView.frame) - NSHeight(clipView.bounds));
    [clipView scrollToPoint:NSMakePoint(0, top)];
    [self.contentScrollView reflectScrolledClipView:clipView];
}

- (NSString *)courseNameForId:(id)courseId {
    if (!courseId || courseId == NSNull.null) return @"Canvas";
    for (NSDictionary *course in self.courses) {
        if ([course[@"id"] isEqual:courseId]) return course[@"name"];
    }
    return @"Canvas";
}

- (NSArray<NSDictionary *> *)overviewLinksFromHTML:(NSString *)html course:(NSDictionary *)course {
    if (![html isKindOfClass:NSString.class] || html.length == 0) return @[];
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length > 5 * 1024 * 1024) return @[];
    htmlDocPtr doc = htmlReadMemory(data.bytes, (int)data.length, NULL, "UTF-8", HTML_PARSE_NONET | HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING);
    if (!doc) return @[];
    NSMutableArray *links = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    xmlXPathContextPtr context = xmlXPathNewContext(doc);
    xmlXPathObjectPtr anchors = context ? xmlXPathEvalExpression((const xmlChar *)"//a[@href]", context) : NULL;
    if (anchors && anchors->nodesetval) {
        for (int i = 0; i < anchors->nodesetval->nodeNr; i++) {
            xmlNodePtr node = anchors->nodesetval->nodeTab[i];
            xmlChar *rawText = xmlNodeGetContent(node);
            xmlChar *rawHref = xmlGetProp(node, (const xmlChar *)"href");
            NSString *text = rawText ? [NSString stringWithUTF8String:(const char *)rawText] : @"";
            NSString *href = rawHref ? [NSString stringWithUTF8String:(const char *)rawHref] : @"";
            xmlFree(rawText);
            xmlFree(rawHref);
            // Canvas homepages sometimes use an image rather than a text link.
            context->node = node;
            xmlXPathObjectPtr images = xmlXPathEvalExpression((const xmlChar *)".//img/@alt", context);
            if (images && images->nodesetval) for (int j = 0; j < images->nodesetval->nodeNr; j++) {
                xmlChar *alt = xmlNodeGetContent(images->nodesetval->nodeTab[j]);
                if (alt) text = [text stringByAppendingFormat:@" %@", [NSString stringWithUTF8String:(const char *)alt]];
                xmlFree(alt);
            }
            if (images) xmlXPathFreeObject(images);
            NSString *lower = text.lowercaseString;
            if (![lower containsString:@"weekly"] || ![lower containsString:@"overview"]) continue;
            NSURL *url = [NSURL URLWithString:href relativeToURL:[NSURL URLWithString:CanvasBaseURL]].absoluteURL;
            if (![@[@"https", @"http"] containsObject:url.scheme.lowercaseString] ||
                ![@[[NSURL URLWithString:CanvasBaseURL].host, @"docs.google.com", @"drive.google.com"] containsObject:url.host.lowercaseString]) continue;
            if ([seen containsObject:url.absoluteString]) continue;
            [seen addObject:url.absoluteString];
            [links addObject:@{@"title":@"Weekly Overview", @"courseId":course[@"id"] ?: @0,
                               @"courseName":course[@"name"] ?: @"Class", @"url":url.absoluteString}];
        }
    }
    if (anchors) xmlXPathFreeObject(anchors);
    if (context) xmlXPathFreeContext(context);
    xmlFreeDoc(doc);
    return links;
}

- (void)refreshWeeklyOverviews:(id)sender {
    if (self.overviewLoading) return;
    NSString *token = [self canvasToken];
    if (!token.length || self.courses.count == 0) {
        self.overviewError = @"Load your Canvas classes first.";
        self.overviewLoaded = YES;
        return;
    }
    self.overviewLoading = YES;
    self.overviewError = nil;
    NSArray *courses = self.courses;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 4;
        NSMutableArray *rows = [NSMutableArray array];
        __block NSUInteger failures = 0;
        for (NSDictionary *course in courses) [queue addOperationWithBlock:^{
            NSError *error = nil;
            SchoolLoadRun *run = [SchoolLoadRun new];
            NSURL *next = nil;
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/v1/courses/%@/front_page", CanvasBaseURL, course[@"id"]]];
            NSDictionary *page = [self fetchResponse:url token:token run:run nextURL:&next expectArray:NO error:&error];
            [run.session finishTasksAndInvalidate];
            NSArray *found = [page isKindOfClass:NSDictionary.class] ? [self overviewLinksFromHTML:page[@"body"] course:course] : @[];
            @synchronized (rows) {
                [rows addObjectsFromArray:found];
                if (error && error.code != 404) failures++;
            }
        }];
        [queue waitUntilAllOperationsAreFinished];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.weeklyOverviews = [rows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"courseName"] localizedStandardCompare:b[@"courseName"]]; }];
            self.overviewLoading = NO;
            self.overviewLoaded = YES;
            self.overviewError = failures ? @"Some class overviews could not be loaded. Try Refresh." : nil;
            if (self.tabs.selectedSegment == 6) [self showSelectedTab];
        });
    });
    if (self.tabs.selectedSegment == 6) [self showSelectedTab];
}

- (void)showWeeklyOverviews {
    if (!self.overviewLoaded && !self.overviewLoading) {
        [self refreshWeeklyOverviews:nil];
        if (self.overviewLoading) return;
    }
    NSArray *items = [self items:self.weeklyOverviews forSelectedClass:@"courseId"];
    self.displayedOverviews = items;
    CGFloat y = [self prepareScrollableRows:items.count + 2 rowHeight:62];
    [self.contentView addSubview:[self label:@"Weekly Overview" frame:NSMakeRect(8, y, 520, 28) size:19 weight:NSFontWeightSemibold color:NSColor.labelColor]];
    NSButton *refresh = [NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refreshWeeklyOverviews:)];
    refresh.frame = NSMakeRect(584, y, 100, 28);
    refresh.bezelStyle = NSBezelStyleRounded;
    refresh.enabled = !self.overviewLoading;
    [self.contentView addSubview:refresh];
    y -= 42;
    NSString *message = self.overviewLoading ? @"Loading weekly overviews..." : self.overviewError;
    if (!message.length && items.count == 0) message = @"None";
    if (message.length) {
        [self.contentView addSubview:[self label:message frame:NSMakeRect(8, y, 680, 28) size:13 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        y -= 36;
    }
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *item = items[i];
        NSButton *open = [NSButton buttonWithTitle:item[@"courseName"] target:self action:@selector(openOverview:)];
        open.tag = i;
        open.bordered = NO;
        open.alignment = NSTextAlignmentLeft;
        open.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
        open.contentTintColor = NSColor.controlAccentColor;
        open.frame = NSMakeRect(8, y, 680, 28);
        open.toolTip = @"Open this class's weekly overview";
        [self.contentView addSubview:open];
        NSString *source = [[NSURL URLWithString:item[@"url"]].host isEqualToString:@"docs.google.com"] ? @"Google Docs" : @"Canvas";
        [self.contentView addSubview:[self label:source frame:NSMakeRect(22, y - 22, 660, 20) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        y -= 62;
    }
}

- (void)openOverview:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedOverviews.count) return;
    [self openWebURLString:self.displayedOverviews[sender.tag][@"url"]];
}

- (void)showAnnouncements {
    NSArray *items = [self items:self.announcements forSelectedClass:@"courseId"];
    if (items.count == 0) { [self showNone:@"Announcements"]; return; }
    self.displayedAnnouncements = items;
    CGFloat y = [self prepareScrollableRows:self.displayedAnnouncements.count rowHeight:56];
    for (NSInteger index = 0; index < self.displayedAnnouncements.count; index++) {
        NSDictionary *item = self.displayedAnnouncements[index];
        NSString *url = item[@"url"] ?: @"";
        if (url.length > 0) {
            NSButton *button = [NSButton buttonWithTitle:item[@"title"] ?: @"Announcement" target:self action:@selector(openAnnouncement:)];
            button.frame = NSMakeRect(4, y, 692, 25);
            button.tag = index;
            button.bordered = NO;
            button.alignment = NSTextAlignmentLeft;
            button.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
            button.contentTintColor = NSColor.controlAccentColor;
            button.lineBreakMode = NSLineBreakByTruncatingTail;
            button.toolTip = @"Open this announcement in Canvas";
            [self.contentView addSubview:button];
        } else {
            [self.contentView addSubview:[self label:item[@"title"] ?: @"Announcement" frame:NSMakeRect(8, y, 688, 24) size:16 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        }
        y -= 22;
        [self.contentView addSubview:[self label:[self courseNameForId:item[@"courseId"]] frame:NSMakeRect(22, y, 674, 19) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        y -= 34;
    }
    [self scrollContentToTop];
}

- (void)openAnnouncement:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedAnnouncements.count) return;
    [self openWebURLString:self.displayedAnnouncements[sender.tag][@"url"]];
}

- (double)gpaForScore:(double)score {
    if (score >= 93) return 4.0;
    if (score >= 90) return 3.7;
    if (score >= 87) return 3.3;
    if (score >= 83) return 3.0;
    if (score >= 80) return 2.7;
    if (score >= 77) return 2.3;
    if (score >= 73) return 2.0;
    if (score >= 70) return 1.7;
    if (score >= 67) return 1.3;
    if (score >= 65) return 1.0;
    return 0.0;
}

- (double)gpaForLetter:(NSString *)letter {
    NSDictionary *points = @{@"A+":@4.0, @"A":@4.0, @"A-":@3.7, @"B+":@3.3, @"B":@3.0, @"B-":@2.7,
                             @"C+":@2.3, @"C":@2.0, @"C-":@1.7, @"D+":@1.3, @"D":@1.0, @"D-":@0.7, @"F":@0.0};
    NSNumber *value = points[letter.uppercaseString];
    return value ? value.doubleValue : -1.0;
}

- (void)showGrades {
    NSArray *items = [self items:self.grades forSelectedClass:@"courseId"];
    if (items.count == 0) { [self showNone:@"Grades"]; return; }
    double scoreTotal = 0;
    double gpaTotal = 0;
    NSInteger scoreCount = 0;
    NSInteger gpaCount = 0;
    for (NSDictionary *grade in items) {
        NSNumber *score = grade[@"score"] == NSNull.null ? nil : grade[@"score"];
        if (score) { scoreTotal += score.doubleValue; scoreCount++; gpaTotal += [self gpaForScore:score.doubleValue]; gpaCount++; }
        else {
            double points = [self gpaForLetter:grade[@"letter"] ?: @""];
            if (points >= 0) { gpaTotal += points; gpaCount++; }
        }
    }
    NSMutableArray *summaryParts = [NSMutableArray array];
    if (scoreCount > 0) [summaryParts addObject:[NSString stringWithFormat:@"Average %.1f%%", scoreTotal / scoreCount]];
    if (gpaCount > 0) [summaryParts addObject:[NSString stringWithFormat:@"Estimated GPA %.2f", gpaTotal / gpaCount]];
    if (summaryParts.count == 0) [summaryParts addObject:@"No posted grades yet"];
    NSArray *assignments = [self items:self.gradedAssignments forSelectedClass:@"courseId"];
    self.displayedGradedAssignments = assignments;
    NSUInteger expandedCount = 0;
    for (NSDictionary *assignment in assignments) if ([self.expandedGradeCourses containsObject:[self courseKeyForValue:assignment[@"courseId"]]]) expandedCount++;
    CGFloat height = MAX(374, items.count * 110 + expandedCount * 62 + 110);
    self.contentView.frame = NSMakeRect(0, 0, 728, height);
    [self.contentView addSubview:[self label:[summaryParts componentsJoinedByString:@"   |   "] frame:NSMakeRect(8, height - 40, 688, 28) size:19 weight:NSFontWeightSemibold color:NSColor.labelColor]];
    NSString *gradeNote = @"Personal averages use assignment weights. Canvas totals may use different rules. GPA is estimated.";
    [self.contentView addSubview:[self label:gradeNote frame:NSMakeRect(8, height - 63, 688, 18) size:11 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];

    CGFloat y = height - 104;
    NSArray *visibleGrades = items;
    for (NSDictionary *grade in visibleGrades) {
        NSNumber *score = grade[@"score"] == NSNull.null ? nil : grade[@"score"];
        double points = score ? [self gpaForScore:score.doubleValue] : [self gpaForLetter:grade[@"letter"] ?: @""];
        BOOL expanded = [self.expandedGradeCourses containsObject:[self courseKeyForValue:grade[@"courseId"]]];
        NSButton *disclosure = [NSButton buttonWithTitle:grade[@"name"] ?: @"Course" target:self action:@selector(toggleGradeCourse:)];
        disclosure.tag = [items indexOfObjectIdenticalTo:grade];
        disclosure.image = [NSImage imageWithSystemSymbolName:expanded ? @"chevron.down" : @"chevron.right" accessibilityDescription:expanded ? @"Collapse assignments" : @"Expand assignments"];
        disclosure.imagePosition = NSImageLeft;
        disclosure.bordered = NO;
        disclosure.alignment = NSTextAlignmentLeft;
        disclosure.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
        disclosure.frame = NSMakeRect(8, y, 688, 24);
        disclosure.toolTip = expanded ? @"Hide graded assignments" : @"Show graded assignments";
        [self.contentView addSubview:disclosure];
        y -= 21;
        NSString *average = score ? [NSString stringWithFormat:([grade[@"calculated"] boolValue] ? @"Calculated average %.1f%%" : @"Average %.1f%%"), score.doubleValue] : @"Average unavailable";
        NSString *gpa = points >= 0 ? [NSString stringWithFormat:@"Estimated GPA %.1f", points] : @"GPA unavailable";
        NSString *letter = [grade[@"letter"] length] ? [NSString stringWithFormat:@"   |   %@", grade[@"letter"]] : @"";
        [self.contentView addSubview:[self label:[NSString stringWithFormat:@"%@   |   %@%@", average, gpa, letter] frame:NSMakeRect(22, y, 674, 19) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        y -= 22;
        NSArray *courseAssignments = [assignments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, NSDictionary *bindings) {
            return [row[@"courseId"] isEqual:grade[@"courseId"]];
        }]];
        NSNumber *personal = [self personalAverageForAssignments:courseAssignments];
        NSString *personalText = personal ? [NSString stringWithFormat:@"Personal points-weighted average: %.1f%%", personal.doubleValue] : @"No graded points available";
        [self.contentView addSubview:[self label:personalText frame:NSMakeRect(22, y, 674, 20) size:12 weight:NSFontWeightMedium color:NSColor.labelColor]];
        y -= 32;
        for (NSDictionary *assignment in expanded ? courseAssignments : @[]) {
            NSInteger index = [assignments indexOfObjectIdenticalTo:assignment];
            NSButton *open = [NSButton buttonWithTitle:assignment[@"name"] target:self action:@selector(openGradedAssignment:)];
            open.tag = index;
            open.frame = NSMakeRect(22, y, 540, 24);
            open.bordered = NO;
            open.alignment = NSTextAlignmentLeft;
            open.lineBreakMode = NSLineBreakByTruncatingTail;
            open.contentTintColor = NSColor.controlAccentColor;
            open.toolTip = assignment[@"name"];
            [self.contentView addSubview:open];
            if (![assignment[@"excluded"] boolValue] && [assignment[@"possible"] doubleValue] > 0) {
                NSButton *weight = [NSButton buttonWithTitle:@"Weight..." target:self action:@selector(editGradeWeight:)];
                weight.tag = index;
                weight.frame = NSMakeRect(574, y - 2, 110, 28);
                weight.bezelStyle = NSBezelStyleRounded;
                [self.contentView addSubview:weight];
            }
            y -= 22;
            NSString *details = [assignment[@"excused"] boolValue] ? @"Excused" : [NSString stringWithFormat:@"%@ / %@ points", assignment[@"score"], assignment[@"possible"] == NSNull.null ? @"?" : assignment[@"possible"]];
            if ([assignment[@"excluded"] boolValue]) details = [details stringByAppendingString:@"  |  Excluded from personal average"];
            else if ([assignment[@"possible"] doubleValue] > 0) details = [details stringByAppendingFormat:@"  |  Weight %.2f", [self weightForAssignment:assignment]];
            [self.contentView addSubview:[self label:details frame:NSMakeRect(30, y, 650, 20) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
            y -= 40;
        }
        y -= 14;
    }
    [self scrollContentToTop];
}

- (void)toggleGradeCourse:(NSButton *)sender {
    NSArray *items = [self items:self.grades forSelectedClass:@"courseId"];
    if (sender.tag < 0 || sender.tag >= items.count) return;
    if (!self.expandedGradeCourses) self.expandedGradeCourses = [NSMutableSet set];
    NSString *key = [self courseKeyForValue:items[sender.tag][@"courseId"]];
    if ([self.expandedGradeCourses containsObject:key]) [self.expandedGradeCourses removeObject:key];
    else [self.expandedGradeCourses addObject:key];
    [self showSelectedTab];
}

- (NSArray<NSDictionary *> *)gradeDetailsFromSubmissions:(NSArray *)submissions {
    NSMutableDictionary *rows = [NSMutableDictionary dictionary];
    for (NSDictionary *submission in submissions) {
        if (![submission isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *assignment = [submission[@"assignment"] isKindOfClass:NSDictionary.class] ? submission[@"assignment"] : @{};
        NSNumber *score = [submission[@"score"] isKindOfClass:NSNumber.class] ? submission[@"score"] : nil;
        NSNumber *possible = [assignment[@"points_possible"] isKindOfClass:NSNumber.class] ? assignment[@"points_possible"] : nil;
        BOOL excused = [self jsonBoolValue:submission[@"excused"]];
        if (!score && !excused) continue;
        if ((score && !isfinite(score.doubleValue)) || (possible && !isfinite(possible.doubleValue))) continue;
        id courseId = submission[@"course_id"] ?: assignment[@"course_id"];
        id assignmentId = assignment[@"id"];
        if (![self courseKeyForValue:courseId].length || ![self courseKeyForValue:assignmentId].length) continue;
        NSDictionary *row = @{@"id":assignmentId, @"courseId":courseId,
                              @"name":[assignment[@"name"] isKindOfClass:NSString.class] ? assignment[@"name"] : @"Assignment",
                              @"score":score ?: NSNull.null, @"possible":possible ?: NSNull.null,
                              @"excused":@(excused),
                              @"excluded":@(excused || [self jsonBoolValue:assignment[@"omit_from_final_grade"]] || !possible || possible.doubleValue <= 0),
                              @"url":[assignment[@"html_url"] isKindOfClass:NSString.class] ? assignment[@"html_url"] : @""};
        rows[[self todoKeyForItem:row]] = row;
    }
    return [rows.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedStandardCompare:b[@"name"]];
    }];
}

- (double)weightForAssignment:(NSDictionary *)assignment {
    NSNumber *saved = self.gradeWeights[[self todoKeyForItem:assignment]];
    if ([saved isKindOfClass:NSNumber.class] && isfinite(saved.doubleValue) && saved.doubleValue > 0) return saved.doubleValue;
    return [assignment[@"possible"] isKindOfClass:NSNumber.class] ? [assignment[@"possible"] doubleValue] : 0;
}

- (NSNumber *)personalAverageForAssignments:(NSArray<NSDictionary *> *)assignments {
    double earned = 0, total = 0;
    for (NSDictionary *row in assignments) {
        if ([row[@"excluded"] boolValue] || ![row[@"score"] isKindOfClass:NSNumber.class] || ![row[@"possible"] isKindOfClass:NSNumber.class]) continue;
        double possible = [row[@"possible"] doubleValue], score = [row[@"score"] doubleValue], weight = [self weightForAssignment:row];
        if (!isfinite(possible) || !isfinite(score) || !isfinite(weight) || possible <= 0 || weight <= 0) continue;
        earned += score / possible * weight;
        total += weight;
    }
    return total > 0 ? @(100 * earned / total) : nil;
}

- (void)openGradedAssignment:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedGradedAssignments.count) return;
    [self openWebURLString:self.displayedGradedAssignments[sender.tag][@"url"]];
}

- (void)editGradeWeight:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedGradedAssignments.count) return;
    NSDictionary *row = self.displayedGradedAssignments[sender.tag];
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Assignment weight";
    alert.informativeText = [NSString stringWithFormat:@"%@\nDefault weight: %@ points. Changes affect only your personal average, not Canvas.", row[@"name"], row[@"possible"]];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 26)];
    field.stringValue = [NSString stringWithFormat:@"%g", [self weightForAssignment:row]];
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Use Points"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        NSString *key = [self todoKeyForItem:row];
        if (response == NSAlertSecondButtonReturn) [self.gradeWeights removeObjectForKey:key];
        else if (response == NSAlertFirstButtonReturn) {
            NSScanner *scanner = [NSScanner scannerWithString:[field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
            double weight = 0;
            if (![scanner scanDouble:&weight] || !scanner.isAtEnd || !isfinite(weight) || weight <= 0 || weight > 1000000) {
                NSAlert *error = [NSAlert new];
                error.messageText = @"Enter a weight greater than 0 and no more than 1,000,000.";
                [error runModal];
                return;
            }
            self.gradeWeights[key] = @(weight);
        } else return;
        [NSUserDefaults.standardUserDefaults setObject:self.gradeWeights forKey:@"gradeWeights"];
        [self showSelectedTab];
    }];
}

- (NSArray<NSDate *> *)schoolWeekDatesAroundDate:(NSDate *)date {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *center = [calendar startOfDayForDate:date];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:center];
    NSInteger daysSinceMonday = (weekday + 5) % 7;
    NSDate *monday = [calendar dateByAddingUnit:NSCalendarUnitDay value:-daysSinceMonday toDate:center options:0];
    NSMutableArray<NSDate *> *dates = [NSMutableArray array];
    for (NSInteger offset = 0; offset < 5; offset++) {
        [dates addObject:[calendar dateByAddingUnit:NSCalendarUnitDay value:offset toDate:monday options:0]];
    }
    return dates;
}

- (NSInteger)defaultCalendarDayIndex {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *today = [calendar startOfDayForDate:NSDate.date];
    for (NSInteger index = 0; index < self.calendarWeekDates.count; index++) {
        if ([calendar isDate:self.calendarWeekDates[index] inSameDayAsDate:today]) return index;
    }
    for (NSInteger index = 0; index < self.calendarWeekDates.count; index++) {
        if ([self.calendarWeekDates[index] compare:today] == NSOrderedDescending) return index;
    }
    return 0;
}

- (void)addCalendarDayTabsAtY:(CGFloat)y {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"EEE d";
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    for (NSDate *date in self.calendarWeekDates) [labels addObject:[formatter stringFromDate:date]];
    NSVisualEffectView *glass = [self glassViewWithFrame:NSMakeRect(8, y, 706, 32) radius:10];
    [self.contentView addSubview:glass];
    NSSegmentedControl *dayTabs = [NSSegmentedControl segmentedControlWithLabels:labels
                                                                    trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                          target:self
                                                                          action:@selector(calendarDayChanged:)];
    dayTabs.frame = NSMakeRect(12, y + 2, 698, 28);
    dayTabs.segmentStyle = NSSegmentStyleCapsule;
    dayTabs.selectedSegment = MIN(self.selectedCalendarDayIndex, (NSInteger)labels.count - 1);
    [self.contentView addSubview:dayTabs];
}

- (void)calendarDayChanged:(NSSegmentedControl *)sender {
    self.selectedCalendarDayIndex = sender.selectedSegment;
    [self showSelectedTab];
}

- (void)showCalendar {
    self.currentTimeLine = nil;
    self.currentTimeLabel = nil;
    self.calendarTimelineStart = nil;
    self.calendarTimelineDate = nil;
    NSString *savedURL = [self calendarURLString];
    if (savedURL.length == 0) {
        [self.contentView addSubview:[self label:@"Google Calendar" frame:NSMakeRect(8, 316, 500, 30) size:20 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        [self.contentView addSubview:[self label:@"Add your iCal-format Google Calendar link to see upcoming events." frame:NSMakeRect(8, 280, 650, 24) size:14 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        NSButton *button = [NSButton buttonWithTitle:@"Add Calendar URL" target:self action:@selector(connectCalendar:)];
        button.frame = NSMakeRect(8, 232, 140, 34);
        button.bezelStyle = NSBezelStyleRounded;
        [self.contentView addSubview:button];
        return;
    }
    if (self.calendarItems.count == 0) {
        [self.contentView addSubview:[self label:@"Calendar" frame:NSMakeRect(8, 316, 500, 30) size:20 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        [self.contentView addSubview:[self label:self.calendarMessage.length ? self.calendarMessage : @"None" frame:NSMakeRect(8, 270, 680, 42) size:15 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        NSButton *button = [NSButton buttonWithTitle:@"Change Calendar URL" target:self action:@selector(connectCalendar:)];
        button.frame = NSMakeRect(8, 220, 164, 34);
        button.bezelStyle = NSBezelStyleRounded;
        [self.contentView addSubview:button];
        return;
    }

    NSCalendar *calendar = NSCalendar.currentCalendar;
    if (self.calendarWeekDates.count == 0) self.calendarWeekDates = [self schoolWeekDatesAroundDate:NSDate.date];
    self.selectedCalendarDayIndex = MAX(0, MIN(self.selectedCalendarDayIndex, (NSInteger)self.calendarWeekDates.count - 1));
    NSDate *selectedDay = [calendar startOfDayForDate:self.calendarWeekDates[self.selectedCalendarDayIndex]];
    NSDate *dayEnd = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:selectedDay options:0];
    self.displayedCalendarItems = [self.calendarItems filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        NSDate *start = item[@"start"];
        NSDate *end = item[@"end"] ?: start;
        BOOL startsOnDay = [start compare:selectedDay] != NSOrderedAscending && [start compare:dayEnd] == NSOrderedAscending;
        BOOL overlapsDay = [start compare:dayEnd] == NSOrderedAscending && [end compare:selectedDay] == NSOrderedDescending;
        return startsOnDay || overlapsDay;
    }]];
    if (self.displayedCalendarItems.count == 0) {
        self.contentView.frame = NSMakeRect(0, 0, 728, 374);
        [self addCalendarDayTabsAtY:330];
        [self.contentView addSubview:[self label:@"None" frame:NSMakeRect(12, 274, 680, 30) size:17 weight:NSFontWeightSemibold color:NSColor.secondaryLabelColor]];
        return;
    }

    NSMutableArray<NSNumber *> *timedIndexes = [NSMutableArray array];
    NSMutableArray<NSNumber *> *allDayIndexes = [NSMutableArray array];
    NSDate *earliest = nil;
    NSDate *latest = nil;
    for (NSInteger index = 0; index < self.displayedCalendarItems.count; index++) {
        NSDictionary *item = self.displayedCalendarItems[index];
        if ([item[@"allDay"] boolValue]) {
            [allDayIndexes addObject:@(index)];
            continue;
        }
        [timedIndexes addObject:@(index)];
        NSDate *start = item[@"start"];
        NSDate *end = item[@"end"] ?: [start dateByAddingTimeInterval:45 * 60];
        if (!earliest || [start compare:earliest] == NSOrderedAscending) earliest = start;
        if (!latest || [end compare:latest] == NSOrderedDescending) latest = end;
    }

    CGFloat allDayHeight = allDayIndexes.count > 0 ? 28 + allDayIndexes.count * 38 : 0;
    if (timedIndexes.count == 0) {
        CGFloat height = MAX(374, 96 + allDayIndexes.count * 44);
        self.contentView.frame = NSMakeRect(0, 0, 728, height);
        [self addCalendarDayTabsAtY:height - 42];
        CGFloat y = height - 86;
        for (NSNumber *number in allDayIndexes) {
            NSInteger index = number.integerValue;
            NSDictionary *item = self.displayedCalendarItems[index];
            NSView *allDayView = [[NSView alloc] initWithFrame:NSMakeRect(84, y - 2, 630, 28)];
            allDayView.wantsLayer = YES;
            allDayView.layer.backgroundColor = [NSColor.systemOrangeColor colorWithAlphaComponent:0.28].CGColor;
            allDayView.layer.borderColor = [NSColor.systemOrangeColor colorWithAlphaComponent:0.65].CGColor;
            allDayView.layer.borderWidth = 1;
            allDayView.layer.cornerRadius = 5;
            [self.contentView addSubview:allDayView];
            [self addCalendarEventTitle:item index:index frame:NSMakeRect(8, 2, 610, 24) toView:allDayView];
            y -= 44;
        }
        [self scrollContentToTop];
        return;
    }

    NSDate *now = NSDate.date;
    BOOL selectedDayIsToday = [calendar isDate:selectedDay inSameDayAsDate:now];
    if (selectedDayIsToday && [now compare:latest] == NSOrderedDescending) latest = now;
    NSDateComponents *startParts = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour) fromDate:earliest];
    startParts.minute = 0;
    startParts.second = 0;
    self.calendarTimelineStart = [calendar dateFromComponents:startParts];
    self.calendarTimelineDate = selectedDay;
    NSDateComponents *endParts = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour) fromDate:latest];
    endParts.minute = 0;
    endParts.second = 0;
    NSDate *timelineEnd = [calendar dateByAddingUnit:NSCalendarUnitHour value:1 toDate:[calendar dateFromComponents:endParts] options:0];
    NSDate *minimumEnd = [self.calendarTimelineStart dateByAddingTimeInterval:6 * 60 * 60];
    if ([timelineEnd compare:minimumEnd] == NSOrderedAscending) timelineEnd = minimumEnd;

    self.calendarTimelineScale = 1.6;
    NSTimeInterval timelineMinutes = [timelineEnd timeIntervalSinceDate:self.calendarTimelineStart] / 60.0;
    self.calendarTimelineHeight = timelineMinutes * self.calendarTimelineScale;
    CGFloat height = MAX(374, 80 + allDayHeight + self.calendarTimelineHeight);
    self.contentView.frame = NSMakeRect(0, 0, 728, height);
    CGFloat top = height - 8;
    [self addCalendarDayTabsAtY:top - 32];
    top -= 52;

    if (allDayIndexes.count > 0) {
        [self.contentView addSubview:[self label:@"ALL DAY" frame:NSMakeRect(8, top - 13, 68, 18) size:10 weight:NSFontWeightBold color:NSColor.secondaryLabelColor]];
        CGFloat allDayY = top - 18;
        for (NSNumber *number in allDayIndexes) {
            NSInteger index = number.integerValue;
            NSDictionary *item = self.displayedCalendarItems[index];
            NSView *allDayView = [[NSView alloc] initWithFrame:NSMakeRect(84, allDayY - 9, 630, 28)];
            allDayView.wantsLayer = YES;
            allDayView.layer.backgroundColor = [NSColor.systemOrangeColor colorWithAlphaComponent:0.28].CGColor;
            allDayView.layer.borderColor = [NSColor.systemOrangeColor colorWithAlphaComponent:0.65].CGColor;
            allDayView.layer.borderWidth = 1;
            allDayView.layer.cornerRadius = 5;
            [self.contentView addSubview:allDayView];
            [self addCalendarEventTitle:item index:index frame:NSMakeRect(8, 2, 610, 24) toView:allDayView];
            allDayY -= 38;
        }
        top -= allDayHeight;
    }
    self.calendarTimelineTop = top;

    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.timeStyle = NSDateFormatterShortStyle;

    NSInteger hourCount = (NSInteger)ceil(timelineMinutes / 60.0);
    for (NSInteger hour = 0; hour <= hourCount; hour++) {
        NSDate *date = [self.calendarTimelineStart dateByAddingTimeInterval:hour * 60 * 60];
        CGFloat y = self.calendarTimelineTop - hour * 60 * self.calendarTimelineScale;
        [self.contentView addSubview:[self label:[timeFormatter stringFromDate:date] frame:NSMakeRect(4, y - 10, 68, 20) size:11 weight:NSFontWeightMedium color:NSColor.secondaryLabelColor]];
    }

    for (NSNumber *number in timedIndexes) {
        NSInteger index = number.integerValue;
        NSDictionary *item = self.displayedCalendarItems[index];
        NSDate *start = item[@"start"];
        NSDate *end = item[@"end"] ?: [start dateByAddingTimeInterval:45 * 60];
        CGFloat startOffset = [start timeIntervalSinceDate:self.calendarTimelineStart] / 60.0 * self.calendarTimelineScale;
        CGFloat duration = MAX(22, [end timeIntervalSinceDate:start] / 60.0 * self.calendarTimelineScale - 4);
        CGFloat eventY = self.calendarTimelineTop - startOffset - duration;
        NSView *eventView = [[NSView alloc] initWithFrame:NSMakeRect(84, eventY, 630, duration)];
        eventView.wantsLayer = YES;
        BOOL current = [now compare:start] != NSOrderedAscending && [now compare:end] == NSOrderedAscending;
        NSColor *eventColor = [self colorForCalendarItem:item];
        eventView.layer.backgroundColor = [eventColor colorWithAlphaComponent:(current ? 0.42 : 0.28)].CGColor;
        eventView.layer.borderColor = [eventColor colorWithAlphaComponent:0.72].CGColor;
        eventView.layer.borderWidth = 1;
        eventView.layer.cornerRadius = 6;
        [self.contentView addSubview:eventView];
        NSView *colorBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 4, duration)];
        colorBar.wantsLayer = YES;
        colorBar.layer.backgroundColor = eventColor.CGColor;
        colorBar.layer.cornerRadius = 2;
        [eventView addSubview:colorBar];

        NSString *range = [NSString stringWithFormat:@"%@ - %@", [timeFormatter stringFromDate:start], [timeFormatter stringFromDate:end]];
        NSString *title = [NSString stringWithFormat:@"%@   %@", item[@"title"] ?: @"Class", range];
        if (current) title = [@"NOW  " stringByAppendingString:title];
        NSMutableDictionary *displayItem = [item mutableCopy];
        displayItem[@"title"] = title;
        CGFloat controlY = MAX(0, (duration - 22) / 2.0);
        NSPopUpButton *colorMenu = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(392, controlY, 84, 22) pullsDown:NO];
        [colorMenu addItemWithTitle:@"Color"];
        NSString *savedHex = self.calendarColorAssignments[[self roomKeyForItem:item]];
        NSInteger selectedColorIndex = 0;
        NSInteger optionIndex = 1;
        for (NSDictionary *option in [self calendarColorOptions]) {
            [colorMenu addItemWithTitle:option[@"name"]];
            NSMenuItem *menuItem = colorMenu.lastItem;
            menuItem.representedObject = option[@"hex"];
            menuItem.image = [self swatchImageForColor:option[@"color"]];
            if ([savedHex isEqualToString:option[@"hex"]]) selectedColorIndex = optionIndex;
            optionIndex++;
        }
        [colorMenu selectItemAtIndex:selectedColorIndex];
        colorMenu.tag = index;
        colorMenu.target = self;
        colorMenu.action = @selector(calendarColorMenuChanged:);
        colorMenu.font = [NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
        colorMenu.toolTip = @"Change this class color";
        [eventView addSubview:colorMenu];
        [self addCalendarEventTitle:displayItem index:index frame:NSMakeRect(8, controlY, 376, 22) toView:eventView];
        [self addRoomButtonForItem:item index:index frame:NSMakeRect(482, controlY, 136, 22) toView:eventView];
    }

    self.currentTimeLine = [[NSView alloc] initWithFrame:NSMakeRect(76, 0, 640, 2)];
    self.currentTimeLine.wantsLayer = YES;
    self.currentTimeLine.layer.backgroundColor = NSColor.systemRedColor.CGColor;
    [self.contentView addSubview:self.currentTimeLine];
    self.currentTimeLabel = [self label:@"" frame:NSMakeRect(4, 0, 68, 20) size:11 weight:NSFontWeightBold color:NSColor.systemRedColor];
    [self.contentView addSubview:self.currentTimeLabel];
    [self updateCurrentTimeIndicator:nil];
    [self scrollContentToTop];
}

- (NSArray<NSDictionary *> *)calendarColorOptions {
    return @[
        @{@"name":@"Blue", @"hex":@"0A84FF", @"color":NSColor.systemBlueColor},
        @{@"name":@"Green", @"hex":@"30D158", @"color":NSColor.systemGreenColor},
        @{@"name":@"Orange", @"hex":@"FF9F0A", @"color":NSColor.systemOrangeColor},
        @{@"name":@"Purple", @"hex":@"BF5AF2", @"color":NSColor.systemPurpleColor},
        @{@"name":@"Teal", @"hex":@"64D2FF", @"color":NSColor.systemTealColor},
        @{@"name":@"Pink", @"hex":@"FF375F", @"color":NSColor.systemPinkColor},
        @{@"name":@"Red", @"hex":@"FF453A", @"color":NSColor.systemRedColor},
        @{@"name":@"Gray", @"hex":@"8E8E93", @"color":NSColor.systemGrayColor}
    ];
}

- (NSImage *)swatchImageForColor:(NSColor *)color {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(12, 12)];
    [image lockFocus];
    [color setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1, 1, 10, 10) xRadius:3 yRadius:3] fill];
    [image unlockFocus];
    return image;
}

- (void)calendarColorMenuChanged:(NSPopUpButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedCalendarItems.count) return;
    NSString *hex = sender.selectedItem.representedObject;
    if (hex.length != 6) return;
    NSDictionary *item = self.displayedCalendarItems[sender.tag];
    self.calendarColorAssignments[[self roomKeyForItem:item]] = hex;
    [NSUserDefaults.standardUserDefaults setObject:self.calendarColorAssignments forKey:@"calendarColorAssignments"];
    [self showSelectedTab];
}

- (NSColor *)colorForCalendarItem:(NSDictionary *)item {
    NSString *savedHex = self.calendarColorAssignments[[self roomKeyForItem:item]];
    if (savedHex.length == 6) {
        unsigned int value = 0;
        [[NSScanner scannerWithString:savedHex] scanHexInt:&value];
        return [NSColor colorWithSRGBRed:((value >> 16) & 0xFF) / 255.0
                                  green:((value >> 8) & 0xFF) / 255.0
                                   blue:(value & 0xFF) / 255.0
                                  alpha:1];
    }
    NSArray<NSColor *> *palette = @[
        NSColor.systemBlueColor,
        NSColor.systemGreenColor,
        NSColor.systemOrangeColor,
        NSColor.systemPurpleColor,
        NSColor.systemTealColor,
        NSColor.systemPinkColor
    ];
    return palette[[self roomKeyForItem:item].hash % palette.count];
}

- (NSString *)hexStringForColor:(NSColor *)color {
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: color;
    NSInteger red = lround(rgb.redComponent * 255);
    NSInteger green = lround(rgb.greenComponent * 255);
    NSInteger blue = lround(rgb.blueComponent * 255);
    return [NSString stringWithFormat:@"%02lX%02lX%02lX", (long)red, (long)green, (long)blue];
}

- (NSString *)roomKeyForItem:(NSDictionary *)item {
    NSString *title = [item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : @"class";
    return [title.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (NSString *)roomForItem:(NSDictionary *)item {
    NSString *saved = self.roomAssignments[[self roomKeyForItem:item]];
    if (saved.length > 0) return saved;
    NSString *location = [item[@"location"] isKindOfClass:NSString.class] ? item[@"location"] : @"";
    if (location.length > 0) return location;
    NSString *description = [item[@"description"] isKindOfClass:NSString.class] ? item[@"description"] : @"";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\b(?:room|rm\\.?)\\s*[:#-]?\\s*([A-Z0-9-]+)" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:description options:0 range:NSMakeRange(0, description.length)];
    if (match.numberOfRanges > 1) return [@"Room " stringByAppendingString:[description substringWithRange:[match rangeAtIndex:1]]];
    return @"";
}

- (void)addCalendarEventTitle:(NSDictionary *)item index:(NSInteger)index frame:(NSRect)frame {
    [self addCalendarEventTitle:item index:index frame:frame toView:self.contentView];
}

- (void)addCalendarEventTitle:(NSDictionary *)item index:(NSInteger)index frame:(NSRect)frame toView:(NSView *)parent {
    NSString *url = item[@"url"] ?: @"";
    if (url.length > 0) {
        NSButton *button = [NSButton buttonWithTitle:item[@"title"] ?: @"Calendar event" target:self action:@selector(openCalendarItem:)];
        button.frame = frame;
        button.tag = index;
        button.bordered = NO;
        button.alignment = NSTextAlignmentLeft;
        button.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        button.contentTintColor = NSColor.controlAccentColor;
        button.lineBreakMode = NSLineBreakByTruncatingTail;
        button.toolTip = @"Open this calendar event";
        [parent addSubview:button];
    } else {
        NSTextField *eventLabel = [self label:item[@"title"] ?: @"Calendar event" frame:frame size:13 weight:NSFontWeightSemibold color:NSColor.labelColor];
        eventLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        eventLabel.maximumNumberOfLines = 1;
        [parent addSubview:eventLabel];
    }
}

- (void)addRoomButtonForItem:(NSDictionary *)item index:(NSInteger)index frame:(NSRect)frame {
    [self addRoomButtonForItem:item index:index frame:frame toView:self.contentView];
}

- (void)addRoomButtonForItem:(NSDictionary *)item index:(NSInteger)index frame:(NSRect)frame toView:(NSView *)parent {
    NSString *room = [self roomForItem:item];
    NSButton *button = [NSButton buttonWithTitle:room.length > 0 ? room : @"Set room" target:self action:@selector(editRoom:)];
    button.frame = frame;
    button.tag = index;
    button.bezelStyle = NSBezelStyleRounded;
    button.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    button.toolTip = room.length > 0 ? @"Change this room" : @"Add this class room";
    [parent addSubview:button];
}

- (void)editRoom:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedCalendarItems.count) return;
    NSDictionary *item = self.displayedCalendarItems[sender.tag];
    NSString *key = [self roomKeyForItem:item];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Room for %@", item[@"title"] ?: @"class"];
    alert.informativeText = @"Enter a room number or location.";
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    field.stringValue = [self roomForItem:item];
    field.placeholderString = @"Example: Room 214";
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Clear"];
    [alert addButtonWithTitle:@"Cancel"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSString *value = [field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length > 0) self.roomAssignments[key] = value;
        else [self.roomAssignments removeObjectForKey:key];
    } else if (response == NSAlertSecondButtonReturn) {
        [self.roomAssignments removeObjectForKey:key];
    } else {
        return;
    }
    [NSUserDefaults.standardUserDefaults setObject:self.roomAssignments forKey:@"roomAssignments"];
    [self showSelectedTab];
}

- (void)updateCurrentTimeIndicator:(id)sender {
    if ([self rollCalendarWeekToDate:NSDate.date]) {
        [self showSelectedTab];
        [self refreshCalendar];
    }
    if (self.tabs.selectedSegment != 2 || !self.calendarTimelineStart || !self.currentTimeLine || !self.currentTimeLabel) return;
    NSDate *now = NSDate.date;
    NSCalendar *calendar = NSCalendar.currentCalendar;
    if (!self.calendarTimelineDate || ![calendar isDate:self.calendarTimelineDate inSameDayAsDate:now]) {
        self.currentTimeLine.hidden = YES;
        self.currentTimeLabel.hidden = YES;
        return;
    }
    CGFloat minutes = [now timeIntervalSinceDate:self.calendarTimelineStart] / 60.0;
    CGFloat y = self.calendarTimelineTop - minutes * self.calendarTimelineScale;
    BOOL visible = y >= self.calendarTimelineTop - self.calendarTimelineHeight && y <= self.calendarTimelineTop;
    self.currentTimeLine.hidden = !visible;
    self.currentTimeLabel.hidden = !visible;
    if (!visible) return;
    self.currentTimeLine.frame = NSMakeRect(76, y, 640, 2);
    self.currentTimeLabel.frame = NSMakeRect(4, y - 10, 68, 20);
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterShortStyle;
    self.currentTimeLabel.stringValue = [formatter stringFromDate:now];
}

- (void)openCalendarItem:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedCalendarItems.count) return;
    [self openWebURLString:self.displayedCalendarItems[sender.tag][@"url"]];
}

- (void)showTests {
    NSArray *items = [self items:self.testItems forSelectedClass:@"courseId"];
    NSSet *completed = [NSSet setWithArray:[self.localCompletedItems valueForKey:@"completionKey"] ?: @[]];
    items = [items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return ![completed containsObject:[self todoKeyForItem:item]];
    }]];
    self.displayedTestItems = items;
    if (items.count == 0) { [self showNone:@"Tests"]; return; }
    NSDateFormatter *display = [[NSDateFormatter alloc] init];
    display.dateStyle = NSDateFormatterMediumStyle;
    display.timeStyle = NSDateFormatterShortStyle;
    CGFloat y = [self prepareScrollableRows:items.count rowHeight:56];
    for (NSInteger index = 0; index < items.count; index++) {
        NSDictionary *item = items[index];
        NSString *url = item[@"url"] ?: @"";
        NSColor *color = [item[@"missing"] boolValue] ? NSColor.systemRedColor : (url.length > 0 ? NSColor.controlAccentColor : NSColor.labelColor);
        if (url.length > 0) {
            NSButton *button = [NSButton buttonWithTitle:item[@"name"] ?: @"Test" target:self action:@selector(openTestItem:)];
            button.frame = NSMakeRect(4, y, 692, 25);
            button.tag = index;
            button.bordered = NO;
            button.alignment = NSTextAlignmentLeft;
            button.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
            button.contentTintColor = color;
            button.lineBreakMode = NSLineBreakByTruncatingTail;
            button.toolTip = @"Open this test in Canvas";
            [self.contentView addSubview:button];
        } else {
            [self.contentView addSubview:[self label:item[@"name"] ?: @"Test" frame:NSMakeRect(8, y, 688, 24) size:16 weight:NSFontWeightSemibold color:color]];
        }
        y -= 22;
        NSString *dueText = @"No date";
        if (item[@"due"] != NSNull.null) {
            NSDate *due = [self canvasDateFromString:item[@"due"]];
            if (due) dueText = [NSString stringWithFormat:@"%@ %@", [item[@"missing"] boolValue] ? @"Was due" : @"Due", [display stringFromDate:due]];
        }
        NSString *details = [NSString stringWithFormat:@"%@  |  %@", [self courseNameForId:item[@"courseId"]], dueText];
        [self.contentView addSubview:[self label:details frame:NSMakeRect(22, y, 674, 19) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        y -= 34;
    }
    [self scrollContentToTop];
}

- (void)openTestItem:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedTestItems.count) return;
    [self openWebURLString:self.displayedTestItems[sender.tag][@"url"]];
}

- (BOOL)belongsInTodo:(NSDictionary *)item {
    return ![self jsonBoolValue:item[@"isTest"]] && ![self isTestAssignment:item name:item[@"name"]] && ![self isClassworkName:item[@"name"]];
}

- (void)showTodo {
    NSArray *classItems = [self items:self.todoItems forSelectedClass:@"courseId"];
    NSSet *completedKeys = [NSSet setWithArray:[self.localCompletedItems valueForKey:@"completionKey"]];
    NSArray *items = [classItems filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return [self belongsInTodo:item] && ![completedKeys containsObject:[self todoKeyForItem:item]];
    }]];
    self.displayedTodoItems = items;
    if (items.count == 0) { [self showNone:@"To-do"]; return; }
    CGFloat y = [self prepareScrollableRows:items.count rowHeight:59];
    NSDateFormatter *parser = [[NSDateFormatter alloc] init];
    parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    parser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    NSDateFormatter *display = [[NSDateFormatter alloc] init];
    display.dateStyle = NSDateFormatterMediumStyle;
    display.timeStyle = NSDateFormatterShortStyle;
    NSArray *visibleItems = items;
    for (NSInteger index = 0; index < visibleItems.count; index++) {
        NSDictionary *item = visibleItems[index];
        BOOL missing = [item[@"missing"] boolValue];
        BOOL checked = [self.checkedTodoKeys containsObject:[self todoKeyForItem:item]];
        NSString *url = item[@"url"] ?: @"";
        NSButton *checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(todoChecked:)];
        checkbox.frame = NSMakeRect(4, y + 1, 24, 24);
        checkbox.tag = index;
        checkbox.state = checked ? NSControlStateValueOn : NSControlStateValueOff;
        checkbox.toolTip = checked ? @"Mark as not done" : @"Mark as done";
        [self.contentView addSubview:checkbox];

        NSColor *color = checked ? NSColor.secondaryLabelColor : (missing ? NSColor.systemRedColor : (url.length > 0 ? NSColor.controlAccentColor : NSColor.labelColor));
        NSDictionary *titleAttributes = @{NSFontAttributeName:[NSFont systemFontOfSize:16 weight:NSFontWeightSemibold],
                                          NSForegroundColorAttributeName:color,
                                          NSStrikethroughStyleAttributeName:checked ? @(NSUnderlineStyleSingle) : @0};
        NSAttributedString *title = [[NSAttributedString alloc] initWithString:item[@"name"] attributes:titleAttributes];
        if (url.length > 0) {
            NSButton *assignmentButton = [NSButton buttonWithTitle:@"" target:self action:@selector(openTodoItem:)];
            assignmentButton.frame = NSMakeRect(30, y, 602, 25);
            assignmentButton.tag = index;
            assignmentButton.bordered = NO;
            assignmentButton.alignment = NSTextAlignmentLeft;
            assignmentButton.attributedTitle = title;
            assignmentButton.toolTip = @"Open this assignment in Canvas";
            assignmentButton.lineBreakMode = NSLineBreakByTruncatingTail;
            [self.contentView addSubview:assignmentButton];
        } else {
            NSTextField *titleLabel = [self label:@"" frame:NSMakeRect(34, y, 598, 25) size:16 weight:NSFontWeightSemibold color:color];
            titleLabel.attributedStringValue = title;
            [self.contentView addSubview:titleLabel];
        }
        y -= 23;
        NSString *dueText = @"No due date";
        if (item[@"due"] != NSNull.null) {
            NSDate *due = [parser dateFromString:item[@"due"]];
            if (due) dueText = [NSString stringWithFormat:@"Due %@", [display stringFromDate:due]];
        }
        NSString *details = [NSString stringWithFormat:@"%@  |  %@", [self courseNameForId:item[@"courseId"]], dueText];
        [self.contentView addSubview:[self label:details frame:NSMakeRect(48, y, 576, 20) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        y -= 36;
    }
    [self scrollContentToTop];
}

- (NSString *)todoKeyForItem:(NSDictionary *)item {
    return [NSString stringWithFormat:@"%@-%@", item[@"courseId"] ?: @"course", item[@"id"] ?: item[@"url"] ?: item[@"name"]];
}

- (void)scheduleMoveForItem:(NSDictionary *)item key:(NSString *)key {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (![self.checkedTodoKeys containsObject:key]) return;
        NSSet *completedKeys = [NSSet setWithArray:[self.localCompletedItems valueForKey:@"completionKey"]];
        if (![completedKeys containsObject:key]) {
            id courseId = item[@"courseId"];
            if (!courseId || courseId == NSNull.null) courseId = @0;
            NSDictionary *completedItem = @{ @"id":item[@"id"] ?: key,
                                              @"name":item[@"name"] ?: @"Completed assignment",
                                              @"courseId":courseId,
                                              @"submittedAt":[NSISO8601DateFormatter.new stringFromDate:NSDate.date],
                                              @"url":item[@"url"] ?: @"",
                                              @"completionKey":key,
                                              @"localCompletion":@YES };
            self.localCompletedItems = [self.localCompletedItems arrayByAddingObject:completedItem];
        }
        [self.checkedTodoKeys removeObject:key];
        [self saveCompletionState];
        [self renderClassList];
        [self showSelectedTab];
    });
}

- (void)todoChecked:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedTodoItems.count) return;
    NSDictionary *item = self.displayedTodoItems[sender.tag];
    NSString *key = [self todoKeyForItem:item];
    if (sender.state == NSControlStateValueOn) {
        NSPoint origin = [sender convertPoint:NSMakePoint(NSMidX(sender.bounds), NSMidY(sender.bounds)) toView:self.view];
        if (![self.checkedTodoKeys containsObject:key]) [self celebrateCompletionAtPoint:origin];
        [self.checkedTodoKeys addObject:key];
        [self scheduleMoveForItem:item key:key];
    } else {
        [self.checkedTodoKeys removeObject:key];
    }
    [self saveCompletionState];
    [self renderClassList];
    [self showSelectedTab];
}

- (void)saveCompletionState {
    [NSUserDefaults.standardUserDefaults setObject:self.checkedTodoKeys.allObjects forKey:@"checkedTodoKeys"];
    [NSUserDefaults.standardUserDefaults setObject:self.localCompletedItems forKey:@"localCompletedItems"];
}

- (void)openWebURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    if (url && ([url.scheme.lowercaseString isEqualToString:@"https"] || [url.scheme.lowercaseString isEqualToString:@"http"])) {
        [NSWorkspace.sharedWorkspace openURL:url];
    }
}

- (void)openTodoItem:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedTodoItems.count) return;
    [self openWebURLString:self.displayedTodoItems[sender.tag][@"url"]];
}

- (void)showSubmitted {
    NSArray *remoteItems = [self items:self.submittedItems forSelectedClass:@"courseId"];
    NSArray *localItems = [self items:self.localCompletedItems forSelectedClass:@"courseId"];
    NSMutableDictionary *mergedItems = [NSMutableDictionary dictionary];
    for (NSDictionary *item in localItems) if ([self timestampIsInCurrentWeek:item[@"submittedAt"]]) mergedItems[[self todoKeyForItem:item]] = item;
    for (NSDictionary *item in remoteItems) if ([self timestampIsInCurrentWeek:item[@"submittedAt"]]) mergedItems[[self todoKeyForItem:item]] = item;
    NSArray *items = [[mergedItems allValues] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"submittedAt"] compare:a[@"submittedAt"]];
    }];
    self.displayedSubmittedItems = items;
    if (items.count == 0) { [self showNone:@"Submitted"]; return; }

    NSDateFormatter *parser = [[NSDateFormatter alloc] init];
    parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    parser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    NSDateFormatter *display = [[NSDateFormatter alloc] init];
    display.dateStyle = NSDateFormatterMediumStyle;
    display.timeStyle = NSDateFormatterShortStyle;

    CGFloat y = [self prepareScrollableRows:items.count rowHeight:59];
    NSArray *visibleItems = items;
    for (NSInteger index = 0; index < visibleItems.count; index++) {
        NSDictionary *item = visibleItems[index];
        BOOL localCompletion = [item[@"localCompletion"] boolValue];
        CGFloat titleX = 4;
        CGFloat titleWidth = 628;
        if (localCompletion) {
            NSButton *checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(localSubmittedUnchecked:)];
            checkbox.frame = NSMakeRect(4, y + 1, 24, 24);
            checkbox.tag = index;
            checkbox.state = NSControlStateValueOn;
            checkbox.toolTip = @"Move back to To-do";
            [self.contentView addSubview:checkbox];
            titleX = 30;
            titleWidth = 602;
        }
        NSString *url = item[@"url"] ?: @"";
        if (url.length > 0) {
            NSButton *assignmentButton = [NSButton buttonWithTitle:item[@"name"] target:self action:@selector(openSubmittedItem:)];
            assignmentButton.frame = NSMakeRect(titleX, y, titleWidth, 25);
            assignmentButton.tag = index;
            assignmentButton.bordered = NO;
            assignmentButton.alignment = NSTextAlignmentLeft;
            assignmentButton.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
            assignmentButton.contentTintColor = NSColor.controlAccentColor;
            assignmentButton.toolTip = @"Open this assignment in Canvas";
            assignmentButton.lineBreakMode = NSLineBreakByTruncatingTail;
            [self.contentView addSubview:assignmentButton];
        } else {
            [self.contentView addSubview:[self label:item[@"name"] frame:NSMakeRect(titleX + 4, y, titleWidth - 8, 25) size:16 weight:NSFontWeightSemibold color:NSColor.labelColor]];
        }
        y -= 23;

        NSString *submittedText = localCompletion ? @"Checked off" : @"Submitted";
        NSDate *submittedAt = [parser dateFromString:item[@"submittedAt"]];
        if (submittedAt) submittedText = [NSString stringWithFormat:@"%@ %@", submittedText, [display stringFromDate:submittedAt]];
        NSString *details = [NSString stringWithFormat:@"%@  |  %@", [self courseNameForId:item[@"courseId"]], submittedText];
        [self.contentView addSubview:[self label:details frame:NSMakeRect(localCompletion ? 48 : 22, y, localCompletion ? 576 : 600, 20) size:12 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
        y -= 36;
    }
    [self scrollContentToTop];
}

- (void)localSubmittedUnchecked:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedSubmittedItems.count) return;
    NSDictionary *item = self.displayedSubmittedItems[sender.tag];
    if (![item[@"localCompletion"] boolValue]) return;
    NSString *key = item[@"completionKey"] ?: [self todoKeyForItem:item];
    self.localCompletedItems = [self.localCompletedItems filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *candidate, NSDictionary *bindings) {
        return ![[candidate objectForKey:@"completionKey"] isEqual:key];
    }]];
    [self.checkedTodoKeys removeObject:key];
    [self saveCompletionState];
    [self renderClassList];
    [self showSelectedTab];
}

- (void)openSubmittedItem:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.displayedSubmittedItems.count) return;
    [self openWebURLString:self.displayedSubmittedItems[sender.tag][@"url"]];
}

- (void)showNone:(NSString *)section {
    [self.contentView addSubview:[self label:section frame:NSMakeRect(8, 312, 400, 28) size:19 weight:NSFontWeightSemibold color:NSColor.labelColor]];
    [self.contentView addSubview:[self label:@"None" frame:NSMakeRect(8, 270, 400, 30) size:22 weight:NSFontWeightSemibold color:NSColor.secondaryLabelColor]];
}

- (void)openCanvas:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:CanvasBaseURL]];
}

- (void)checkForUpdates:(id)sender {
    [self.updaterController checkForUpdates:sender];
}

- (void)updateSettings:(id)sender {
    SPUUpdater *updater = self.updaterController.updater;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Software Updates";
    alert.informativeText = @"Verified updates install when Morning Canvas closes. Your school data and settings stay on this Mac.";
    NSView *options = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 370, 64)];
    NSButton *checks = [NSButton checkboxWithTitle:@"Automatically check for updates" target:nil action:nil];
    checks.frame = NSMakeRect(0, 36, 370, 24);
    checks.state = updater.automaticallyChecksForUpdates ? NSControlStateValueOn : NSControlStateValueOff;
    NSButton *installs = [NSButton checkboxWithTitle:@"Automatically download and install updates" target:nil action:nil];
    installs.frame = NSMakeRect(0, 4, 370, 24);
    installs.state = updater.automaticallyDownloadsUpdates ? NSControlStateValueOn : NSControlStateValueOff;
    [options addSubview:checks];
    [options addSubview:installs];
    alert.accessoryView = options;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn) return;
        updater.automaticallyChecksForUpdates = checks.state == NSControlStateValueOn;
        updater.automaticallyDownloadsUpdates = installs.state == NSControlStateValueOn;
    }];
}

- (void)shareApp:(NSButton *)sender {
    if (self.sharingAuthentication) return;
    [self authenticateSharingWithCompletion:^(BOOL success) {
        if (success) [self presentSharePicker:sender];
    }];
}

- (void)authenticateSharingWithCompletion:(void (^)(BOOL))completion {
    LAContext *context = [LAContext new];
    self.sharingAuthentication = context;
    NSError *error = nil;
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        self.sharingAuthentication = nil;
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Sharing is locked";
        alert.informativeText = @"Set up a Mac login password to authorize sharing this app.";
        [alert runModal];
        completion(NO);
        return;
    }
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:@"Authorize sharing Morning Canvas" reply:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sharingAuthentication = nil;
            [context invalidate];
            completion(success);
        });
    }];
}

- (void)presentSharePicker:(NSButton *)sender {
    NSURL *appURL = NSBundle.mainBundle.bundleURL;
    if (!appURL) return;
    self.sharingPicker = [[NSSharingServicePicker alloc] initWithItems:@[appURL]];
    [self.sharingPicker showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}

@end


@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    DashboardController *controller = [[DashboardController alloc] init];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1040, 660)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Morning Canvas";
    self.window.minSize = NSMakeSize(1040, 660);
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    self.window.contentViewController = controller;
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    NSMenu *menuBar = [[NSMenu alloc] init];
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [menuBar addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Morning Canvas"];
    appItem.submenu = appMenu;
    NSMenuItem *appearance = [appMenu addItemWithTitle:@"Appearance..." action:@selector(changeAppearance:) keyEquivalent:@","];
    appearance.target = controller;
    NSMenuItem *check = [appMenu addItemWithTitle:@"Check for Updates..." action:@selector(checkForUpdates:) keyEquivalent:@""];
    check.target = controller;
    NSMenuItem *settings = [appMenu addItemWithTitle:@"Software Update Settings..." action:@selector(updateSettings:) keyEquivalent:@""];
    settings.target = controller;
    [appMenu addItem:NSMenuItem.separatorItem];
    [appMenu addItemWithTitle:@"Quit Morning Canvas" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [menuBar addItem:editItem];
    NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
    editItem.submenu = edit;
    [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSApp.mainMenu = menuBar;
    [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
