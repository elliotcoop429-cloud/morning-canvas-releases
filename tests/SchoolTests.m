#define main MorningCanvasAppMain
#import "../MorningCanvas.m"
#undef main

@interface SchoolTestController : DashboardController
@property(nonatomic) NSUInteger scheduledMoves;
@end
@implementation SchoolTestController
- (void)renderClassList {}
- (void)showSelectedTab {}
- (void)scheduleMoveForItem:(NSDictionary *)item key:(NSString *)key { self.scheduledMoves++; }
@end

#define CHECK(condition, message) do { if (!(condition)) { NSLog(@"FAIL: %@", message); return 1; } } while (0)
static NSDictionary *Submission(NSNumber *identifier, id score, id possible, BOOL excused, BOOL omit) {
    return @{@"course_id":@1, @"score":score, @"excused":@(excused), @"assignment":@{
        @"id":identifier, @"name":@"Test assignment", @"points_possible":possible,
        @"omit_from_final_grade":@(omit), @"html_url":@"https://example.com/assignment"}};
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSString *domain = NSProcessInfo.processInfo.processName;
        CHECK([domain isEqualToString:@"MorningCanvasSchoolTests"], @"Test preferences are isolated");
        [defaults removePersistentDomainForName:domain];
        SchoolTestController *c = [SchoolTestController new];
        c.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 660)];
        c.contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 728, 374)];
        c.gradeWeights = [NSMutableDictionary dictionary];
        c.courses = @[];
        NSArray *rows = [c gradeDetailsFromSubmissions:@[Submission(@1,@10,@20,NO,NO), Submission(@2,@10,@10,NO,NO), Submission(@3,NSNull.null,@10,NO,NO), Submission(@4,NSNull.null,@10,YES,NO), Submission(@5,@0,NSNull.null,NO,NO), Submission(@6,@0,@10,NO,YES)]];
        CHECK(rows.count == 5, @"Posted and excused details included; ungraded excluded");
        CHECK(fabs([c personalAverageForAssignments:rows].doubleValue - 100.0 * 20 / 30) < 0.0001, @"20-point assignment counts twice as much as 10-point assignment");
        c.gradeWeights[@"1-1"] = @10;
        CHECK(fabs([c personalAverageForAssignments:rows].doubleValue - 75) < 0.0001, @"Custom equal weights use percentages");
        [c.gradeWeights removeAllObjects];
        NSArray *zeros = [c gradeDetailsFromSubmissions:@[Submission(@7,@0,@10,NO,NO)]];
        CHECK([c personalAverageForAssignments:zeros].doubleValue == 0, @"Zero scores count");
        CHECK([c personalAverageForAssignments:@[]] == nil, @"No grades is unavailable, not zero");
        c.grades = @[@{@"name":@"Test course", @"courseId":@1, @"score":@80, @"letter":@"B", @"calculated":@NO}];
        c.gradedAssignments = rows;
        [c showGrades];
        CHECK(c.displayedGradedAssignments.count == 5, @"Grade detail view safely handles null points and excused grades");
        CHECK([c.contentView.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSView *v, NSDictionary *b) { return [v isKindOfClass:NSButton.class] && [(NSButton *)v action] == @selector(openGradedAssignment:); }]].count == 0, @"Assignment dropdown starts collapsed");
        NSButton *disclosure = [NSButton new];
        disclosure.tag = 0;
        [c toggleGradeCourse:disclosure];
        CHECK([c.expandedGradeCourses containsObject:@"1"], @"Dropdown expands the selected class");
        for (NSView *v in c.contentView.subviews.copy) [v removeFromSuperview];
        [c showGrades];
        CHECK([c.contentView.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSView *v, NSDictionary *b) { return [v isKindOfClass:NSButton.class] && [(NSButton *)v action] == @selector(openGradedAssignment:); }]].count == 5, @"Expanded dropdown contains every graded assignment");
        [c toggleGradeCourse:disclosure];
        CHECK(c.expandedGradeCourses.count == 0, @"Dropdown collapses again");

        CHECK(![c belongsInTodo:@{@"name":@"Unit 2 Assessment"}], @"Tests are not homework");
        CHECK((![c belongsInTodo:@{@"name":@"Questions", @"isTest":@YES}]), @"Canvas test flag is honored");
        CHECK((![c belongsInTodo:@{@"name":@"Questions", @"quiz_id":@42}]), @"Canvas quizzes are excluded");
        CHECK([c belongsInTodo:@{@"name":@"HW: Latest chapter contest response"}], @"Test substring is not an assessment");
        CHECK(![c belongsInTodo:@{@"name":@"CW: Practice"}], @"Classwork remains excluded");
        NSArray *overviews = [c overviewLinksFromHTML:@"<a href='https://docs.google.com/document/d/example/edit'>Weekly <b>Overview</b></a><a href='https://docs.google.com/document/d/example/edit'>Weekly Overview</a><a href='/courses/1/modules/items/5'><img alt='Weekly Overview'></a><a href='javascript:alert(1)'>Weekly Overview</a><a href='https://elsewhere.example/doc'>Weekly Overview</a><a href='https://docs.google.com/document/d/unrelated'>Assignment</a>" course:@{@"id":@1,@"name":@"Course"}];
        CHECK(overviews.count == 2, @"Overview parser supports HTML and image labels, deduplicates, and rejects unrelated or unsafe links");
        CHECK([overviews[1][@"url"] isEqual:@"https://pinecrest.instructure.com/courses/1/modules/items/5"], @"Relative Canvas overview links resolve correctly");
        CHECK([c overviewLinksFromHTML:(id)NSNull.null course:@{}].count == 0, @"Missing overview HTML is safe");

        NSTextField *label = [c label:@"Example" frame:NSMakeRect(0,0,100,20) size:12 weight:NSFontWeightRegular color:NSColor.labelColor];
        [c.view addSubview:label];
        [c saveWordColor:NSColor.systemPinkColor key:@"wordColor"];
        [defaults setBool:YES forKey:@"customTextColors"];
        [c applyWordColorsToView:c.view];
        CHECK([label.textColor isEqual:[c wordColorForKey:@"wordColor" fallback:NSColor.labelColor]], @"Custom text color is applied");
        [defaults setBool:NO forKey:@"customTextColors"];
        [c applyWordColorsToView:c.view];
        CHECK([label.textColor isEqual:NSColor.labelColor], @"Turning custom colors off restores original colors");
        CHECK([c confettiEnabled], @"Confetti defaults on");
        [defaults setBool:NO forKey:@"completionConfetti"];
        NSUInteger before = c.view.subviews.count;
        [c celebrateCompletionAtPoint:NSMakePoint(100,100)];
        CHECK(c.view.subviews.count == before, @"Confetti can be disabled");
        [defaults setBool:YES forKey:@"completionConfetti"];
        [c celebrateCompletionAtPoint:NSMakePoint(100,100)];
        if (!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
            CHECK([c.view.subviews.lastObject isKindOfClass:ConfettiView.class], @"Confetti overlay is created");
            CHECK([c.view.subviews.lastObject hitTest:NSMakePoint(100,100)] == nil, @"Confetti never blocks clicks");
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.6]];
            CHECK(c.view.subviews.count == before, @"Confetti cleans up after the burst");
        }

        NSDate *monday = [c calendarMondayForDate:NSDate.date];
        NSDate *next = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:7 toDate:monday options:0];
        NSDictionary *event = @{@"uid":@"class-a", @"title":@"Class", @"start":[monday dateByAddingTimeInterval:36000]};
        NSDictionary *updated = @{@"uid":@"class-a", @"title":@"Updated class", @"start":[monday dateByAddingTimeInterval:39000]};
        NSDictionary *future = @{@"uid":@"class-a", @"title":@"Class", @"start":next};
        c.calendarItems = @[event];
        NSArray *snapshot = [c calendarItemsByMergingNewItems:@[updated, updated, future]];
        CHECK(snapshot.count == 1 && [snapshot[0][@"title"] isEqual:@"Updated class"], @"Snapshot replaces old times, deduplicates, and excludes next week");
        CHECK([c calendarItemsByMergingNewItems:@[]].count == 0, @"Deleted events do not linger");
        c.calendarItems = @[event, future];
        c.calendarWeekDates = [c schoolWeekDatesAroundDate:monday];
        CHECK([c rollCalendarWeekToDate:next], @"Calendar rolls over to new week");
        CHECK(c.calendarItems.count == 1 && [c.calendarItems[0][@"start"] isEqual:next], @"Previous week removed on rollover");
        CHECK(![c rollCalendarWeekToDate:next], @"Rollover does not repeatedly refresh same week");

        NSDictionary *done = @{@"id":@99, @"courseId":@1, @"name":@"Done", @"due":@"", @"url":@"", @"completionKey":@"1-99", @"submittedAt":@"2020-01-01T00:00:00Z", @"localCompletion":@YES};
        c.localCompletedItems = @[done];
        c.checkedTodoKeys = [NSMutableSet set];
        c.todoItems = @[done];
        c.submittedItems = @[];
        [c showTodo];
        CHECK(c.displayedTodoItems.count == 0, @"Old completed work remains hidden from To-do");
        [c showSubmitted];
        CHECK(c.displayedSubmittedItems.count == 0 && c.localCompletedItems.count == 1, @"Weekly Submitted display clears without forgetting completions");
        [c saveCompletionState];
        CHECK([defaults arrayForKey:@"localCompletedItems"].count == 1, @"Completion history survives restart");
        [defaults removePersistentDomainForName:domain];
        NSLog(@"PASS: grade detail/null safety, points weights, custom weights, zero scores, weekly snapshots, rollover, durable completion history");
    }
    return 0;
}
