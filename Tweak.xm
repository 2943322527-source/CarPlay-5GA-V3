#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// CarPlay 5Gᴀ rendering tweak: ONLY apply a narrower font to characters 0..1
// ("5G"); the small-cap A (U+1D00) retains its existing appearance.
// This is a new iOS 16.5 CarPlay experiment, not a verified final solution.

static const CGFloat kWidthTrait = -0.55f;
static const CGFloat kFiveGKerning = -0.20f;
static BOOL cp5ga_settingStyledText = NO;

static BOOL cp5ga_matches(NSString *s) {
    return [s isKindOfClass:[NSString class]] &&
           ([s isEqualToString:@"5G\u1D00"] || [s isEqualToString:@"5G\u1D2C"]);
}

static UIFont *cp5ga_narrowFont(UIFont *font) {
    if (!font) return nil;
    UIFontDescriptor *base = font.fontDescriptor;
    NSMutableDictionary *traits = [[base objectForKey:UIFontDescriptorTraitsAttribute] mutableCopy];
    if (!traits) traits = [NSMutableDictionary dictionary];
    traits[UIFontDescriptorTraitWidth] = @(kWidthTrait);
    UIFontDescriptor *target = [base fontDescriptorByAddingAttributes:@{UIFontDescriptorTraitsAttribute: traits}];
    return [UIFont fontWithDescriptor:target size:font.pointSize];
}

static void cp5ga_styleLabel(UILabel *label) {
    if (!label || cp5ga_settingStyledText || !cp5ga_matches(label.text)) return;
    UIFont *narrow = cp5ga_narrowFont(label.font);
    if (!narrow) return;
    NSAttributedString *oldValue = label.attributedText;
    NSMutableAttributedString *styled = nil;
    if (oldValue && [oldValue.string isEqualToString:label.text]) {
        styled = [oldValue mutableCopy];
    } else {
        styled = [[NSMutableAttributedString alloc] initWithString:label.text];
    }
    if (styled.length < 3) return;
    // Style only 5G; do NOT set a font on index 2 (small-cap A).
    [styled addAttribute:NSFontAttributeName value:narrow range:NSMakeRange(0, 2)];
    [styled addAttribute:NSKernAttributeName value:@(kFiveGKerning) range:NSMakeRange(0, 1)];
    cp5ga_settingStyledText = YES;
    label.attributedText = styled;
    cp5ga_settingStyledText = NO;
}

static void cp5ga_visit(UIView *v, NSUInteger depth) {
    if (!v || depth > 7) return;
    if ([v isKindOfClass:[UILabel class]]) cp5ga_styleLabel((UILabel *)v);
    for (UIView *child in v.subviews) cp5ga_visit(child, depth + 1);
}

%hook UILabel
- (void)setText:(NSString *)text {
    %orig;
    if (cp5ga_matches(text)) cp5ga_styleLabel(self);
}
%end

// Some status-bar views own a nested UILabel rather than inheriting UILabel.
// After the original and V1 hooks run, inspect nested labels for 5Gᴀ.
%hook _UIStatusBarStringView
- (void)setText:(NSString *)text {
    %orig;
    if ([self isKindOfClass:[UIView class]]) cp5ga_visit((UIView *)self, 0);
}
%end
