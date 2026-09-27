#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
static char OriginalTextStyleKey;
#import "../GuiLayout.h"
#define CHECK(c,m) do { if (!(c)) { NSLog(@"FAIL: %@",m); return 1; } } while(0)
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSData *data=[NSData dataWithContentsOfFile:@"Resources/gui-layout.json"];
        NSMutableDictionary *layout=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        CHECK(MCValidLayout(layout),@"Default layout validates");
        NSView *root=[[NSView alloc] initWithFrame:NSMakeRect(0,0,1040,660)];
        NSTextField *title=[NSTextField labelWithString:@"Original"];
        NSButton *button=[NSButton buttonWithTitle:@"Refresh" target:root action:@selector(display)];
        NSView *glass=[[NSView alloc] initWithFrame:NSMakeRect(864,590,72,34)];
        NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(278,82,746,374)];
        NSView *doc=[[NSView alloc] initWithFrame:NSMakeRect(0,0,728,900)];scroll.documentView=doc;
        [root addSubview:title];[root addSubview:glass];[root addSubview:button];[root addSubview:scroll];
        for (NSMutableDictionary *item in layout[@"items"]) {
            if ([item[@"id"] isEqual:@"title"]) [item addEntriesFromDictionary:@{@"x":@60,@"y":@80,@"width":@350,@"height":@50,@"text":@"Studio title",@"color":@"#123456",@"fontSize":@24}];
            if ([item[@"id"] isEqual:@"content"]) [item addEntriesFromDictionary:@{@"x":@300,@"y":@220,@"width":@373,@"height":@187}];
        }
        NSMutableDictionary *extra=[layout[@"items"][0] mutableCopy];extra[@"id"]=@"custom_test";extra[@"text"]=@"New label";[layout[@"items"] addObject:extra];
        CHECK(MCApplyLayout(layout,root,@{@"title":@[title],@"refresh":@[glass,button],@"content":@[scroll]}),@"Valid layout applied");
        CHECK(NSEqualRects(title.frame,NSMakeRect(60,530,350,50)) && [title.stringValue isEqual:@"Studio title"],@"Top-left coordinates converted to native bottom-left");
        CHECK(title.font.pointSize==24,@"Text style applies");
        CHECK(button.target==root && button.action==@selector(display),@"Original button behavior preserved");
        CHECK(NSEqualRects(scroll.superview.frame,NSMakeRect(300,253,373,187)),@"Panel moved and resized");
        CHECK(NSEqualSizes(scroll.superview.bounds.size,NSMakeSize(746,374)) && scroll.documentView==doc,@"Existing content/scroll coordinates preserved");
        CHECK(root.subviews.count==5,@"Custom label inserted with panel wrapper");
        NSRect prior=title.frame;layout[@"items"][0][@"width"]=@9999;
        CHECK(!MCApplyLayout(layout,root,@{@"title":@[title]}) && NSEqualRects(prior,title.frame),@"Malformed layouts leave native UI untouched");
        NSLog(@"PASS: layout validation, native coordinates, styles, actions, scaling, custom labels, safe fallback");
    }return 0;
}
