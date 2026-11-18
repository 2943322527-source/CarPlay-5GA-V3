#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// V4: fix the V3 re-entrant update crash.
// This tweak is injected ONLY into com.apple.CarPlayApp (see the existing plist).
// V1 (FakeSignalBar bridge) must remain installed.
// Never hook setText: or attributedText:; never walk a live view hierarchy.
// Touch only the leading "5G"; preserve the original small-cap A (U+1D00).

static char kCP5GAStyledKey;
static const CGFloat kCP5GAWidthTrait = -0.50f;
static const CGFloat kCP5GKerning = -0.15f;

static BOOL CP5GAIsTarget(NSString *string) {
    return [string isKindOfClass:[NSString class]] &&
           [string isEqualToString:@"5G\u1D00"];
}

static UIFont *CP5GANarrowFont(UIFont *original) {
    if (!original) return nil;
    UIFontDescriptor *descriptor = original.fontDescriptor;
    if (!descriptor) return nil;
    NSDictionary *existing = [descriptor objectForKey:UIFontDescriptorTraitsAttribute];
    NSMutableDictionary *traits = existing ? [existing mutableCopy] : [NSMutableDictionary dictionary];
    traits[UIFontWidthTrait] = @(kCP5GAWidthTrait);
    UIFontDescriptor *newDescriptor = [descriptor fontDescriptorByAddingAttributes:
        @{ UIFontDescriptorTraitsAttribute: traits }];
    return [UIFont fontWithDescriptor:newDescriptor size:original.pointSize];
}

static void CP5GAStyleOnce(UILabel *label) {
    if (!label) return;
    NSString *string = label.text;
    if (!CP5GAIsTarget(string)) {
        // Allow restyling if this view is later reused for a different network type.
        if (objc_getAssociatedObject(label, &kCP5GAStyledKey)) {
            objc_setAssociatedObject(label, &kCP5GAStyledKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
        return;
    }
    // Set this marker BEFORE modifying attributedText. It prevents re-entrancy
    // if UIKit triggers a nested layout while updating its text storage.
    if (objc_getAssociatedObject(label, &kCP5GAStyledKey)) return;

    UIFont *originalFont = label.font;
    UIFont *narrowFont = CP5GANarrowFont(originalFont);
    if (!originalFont || !narrowFont) return;

    NSAttributedString *current = label.attributedText;
    NSMutableAttributedString *edited = nil;
    if (current && [current.string isEqualToString:string]) {
        edited = [current mutableCopy];
    } else {
        edited = [[NSMutableAttributedString alloc] initWithString:string];
    }
    if (edited.length != 3) return;

    // Explicitly preserve the A's original font: when the first character's
    // attributed font changes, UILabel may update its default font too.
    UIFont *originalAFont = nil;
    if (current && current.length == 3) {
        id attributedAFont = [current attribute:NSFontAttributeName atIndex:2 effectiveRange:NULL];
        if ([attributedAFont isKindOfClass:[UIFont class]]) {
            originalAFont = (UIFont *)attributedAFont;
        }
    }
    if (!originalAFont) originalAFont = originalFont;

    [edited addAttribute:NSFontAttributeName value:narrowFont range:NSMakeRange(0, 2)];
    [edited addAttribute:NSKernAttributeName value:@(kCP5GKerning) range:NSMakeRange(0, 1)];
    [edited addAttribute:NSFontAttributeName value:originalAFont range:NSMakeRange(2, 1)];

    objc_setAssociatedObject(label, &kCP5GAStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    label.attributedText = edited;
}

// On iOS 16.x, _UIStatusBarStringView is a UILabel subtype.
// Deliberately do NOT hook setText: -- FakeSignalBar V1 already hooks it.
%hook _UIStatusBarStringView
- (void)layoutSubviews {
    %orig;
    if ([(id)self isKindOfClass:[UILabel class]]) {
        CP5GAStyleOnce((UILabel *)(id)self);
    }
}
%end
