// Dashboard layout shared with the browser designer. No credentials or app actions are serialized.
static NSDictionary<NSString *, NSString *> *MCLayoutKinds(void) {
    return @{@"title":@"text", @"date":@"dynamic", @"share":@"button", @"update":@"button",
             @"connect":@"button", @"calendar":@"button", @"appearance":@"button", @"refresh":@"button",
             @"open":@"button", @"status":@"dynamic", @"classes-title":@"text", @"classes":@"classes",
             @"vertical-rule":@"rule", @"tabs":@"tabs", @"horizontal-rule":@"rule", @"content":@"content",
             @"footer":@"text", @"quit":@"button"};
}

static BOOL MCValidLayout(id layout) {
    if (![layout isKindOfClass:NSDictionary.class]) return NO;
    if (![layout[@"version"] isEqual:@1] || ![layout[@"width"] isEqual:@1040] || ![layout[@"height"] isEqual:@660]) return NO;
    NSArray *items = layout[@"items"];
    if (![items isKindOfClass:NSArray.class] || items.count < MCLayoutKinds().count || items.count > 100) return NO;
    NSMutableSet *seen = [NSMutableSet set];
    NSRegularExpression *custom = [NSRegularExpression regularExpressionWithPattern:@"^custom_[a-zA-Z0-9_-]{1,64}$" options:0 error:nil];
    NSRegularExpression *hex = [NSRegularExpression regularExpressionWithPattern:@"^#[a-fA-F0-9]{6}$" options:0 error:nil];
    for (id item in items) {
        if (![item isKindOfClass:NSDictionary.class]) return NO;
        NSString *key = item[@"id"], *kind = item[@"kind"];
        if (![key isKindOfClass:NSString.class] || ![kind isKindOfClass:NSString.class] || [seen containsObject:key]) return NO;
        [seen addObject:key];
        NSString *expected = MCLayoutKinds()[key];
        if (expected ? ![expected isEqual:kind] : (![kind isEqual:@"text"] || ![custom numberOfMatchesInString:key options:0 range:NSMakeRange(0,key.length)])) return NO;
        for (NSString *field in @[@"name", @"text", @"color"]) {
            if (![item[field] isKindOfClass:NSString.class] || [item[field] length] > ([field isEqual:@"name"] ? 80 : [field isEqual:@"color"] ? 7 : 500)) return NO;
        }
        NSString *color = item[@"color"];
        if (color.length && ![hex numberOfMatchesInString:color options:0 range:NSMakeRange(0,color.length)]) return NO;
        if (![item[@"visible"] isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)item[@"visible"]) != CFBooleanGetTypeID()) return NO;
        for (NSString *field in @[@"x",@"y",@"width",@"height",@"fontSize"]) {
            id value = item[field];
            if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() || !isfinite([value doubleValue])) return NO;
        }
        double x=[item[@"x"] doubleValue], y=[item[@"y"] doubleValue], w=[item[@"width"] doubleValue], h=[item[@"height"] doubleValue], font=[item[@"fontSize"] doubleValue];
        if (x<0 || y<0 || w<1 || h<1 || x+w>1040 || y+h>660 || font<8 || font>72) return NO;
    }
    return [[NSSet setWithArray:MCLayoutKinds().allKeys] isSubsetOfSet:seen];
}

static BOOL MCApplyLayout(NSDictionary *layout, NSView *root, NSDictionary<NSString *, NSArray<NSView *> *> *bindings) {
    if (!MCValidLayout(layout)) return NO; // Invalid files preserve the original app layout in full.
    for (NSDictionary *item in layout[@"items"]) {
        NSString *key=item[@"id"], *kind=item[@"kind"];
        NSArray<NSView *> *views=bindings[key];
        if (!views && [key hasPrefix:@"custom_"]) {
            NSTextField *label = [NSTextField labelWithString:item[@"text"]];
            label.maximumNumberOfLines=0;
            [root addSubview:label];
            views=@[label];
        }
        if (!views.count) continue;
        NSRect frame=NSMakeRect([item[@"x"] doubleValue], 660-[item[@"y"] doubleValue]-[item[@"height"] doubleValue], [item[@"width"] doubleValue], [item[@"height"] doubleValue]);
        if ([@[@"classes",@"content",@"tabs"] containsObject:kind]) {
            // Preserve existing rendering/scrolling in its original coordinate space.
            NSRect original=views.firstObject.frame;
            for (NSView *view in views) original=NSUnionRect(original,view.frame);
            NSView *group=[[NSView alloc] initWithFrame:frame];
            group.bounds=NSMakeRect(0,0,original.size.width,original.size.height);
            group.identifier=key;
            group.hidden=![item[@"visible"] boolValue];
            for (NSView *view in views) {
                NSRect local=NSOffsetRect(view.frame,-original.origin.x,-original.origin.y);
                [view removeFromSuperview];[group addSubview:view];view.frame=local;
            }
            [root addSubview:group];
        } else {
            for (NSView *view in views) {
                view.frame=([kind isEqual:@"button"] && views.count>1 && [view isKindOfClass:NSButton.class]) ? NSInsetRect(frame,MIN(4,frame.size.width/4),MIN(3,frame.size.height/4)) : frame;
                view.identifier=key;view.hidden=![item[@"visible"] boolValue];
            }
        }
        for (NSView *view in views) {
            if ([view isKindOfClass:NSTextField.class]) {
                NSTextField *field=(NSTextField *)view;
                if ([kind isEqual:@"text"]) field.stringValue=item[@"text"];
                field.font=[[NSFontManager sharedFontManager] convertFont:field.font ?: [NSFont systemFontOfSize:13] toSize:[item[@"fontSize"] doubleValue]];
                NSString *color=item[@"color"];
                if (color.length) {
                    unsigned int rgb=0;[[NSScanner scannerWithString:[color substringFromIndex:1]] scanHexInt:&rgb];
                    field.textColor=[NSColor colorWithSRGBRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:1];
                    objc_setAssociatedObject(field,&OriginalTextStyleKey,field.textColor,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            } else if ([view isKindOfClass:NSButton.class]) {
                NSButton *button=(NSButton *)view;
                button.title=item[@"text"];
                button.font=[NSFont systemFontOfSize:[item[@"fontSize"] doubleValue]];
                objc_setAssociatedObject(button,&OriginalTextStyleKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
    return YES;
}
