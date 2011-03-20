//
//  HPEditableTableViewCell.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-20.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPEditableTableViewCell.h"


@implementation HPEditableTableViewCell

@synthesize delegate;
@synthesize textField = _textField;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        _textField = [[UITextField alloc] initWithFrame:CGRectInset(self.contentView.bounds, 10.0, 4.0)];
		
		[_textField setDelegate:self];
		[_textField setFont:[UIFont systemFontOfSize:16.0]];
		[_textField setTextColor:[UIColor blackColor]];
		[_textField setAutocorrectionType:UITextAutocorrectionTypeNo];
		[_textField setEnablesReturnKeyAutomatically:YES];
		[_textField setBackgroundColor:self.contentView.backgroundColor];
		[_textField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
		[_textField setClearButtonMode:UITextFieldViewModeWhileEditing];
		[_textField setReturnKeyType:UIReturnKeyNext];
		[_textField setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
		
        [self.contentView addSubview:_textField];
    }
	
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	if (selected) {
		[_textField becomeFirstResponder];
	}
}

- (void)textFieldDidBeginEditing:(UITextField *)field {
	if ([delegate respondsToSelector:@selector(editableTableViewCellDidBeginEditing:)]) {
		[delegate editableTableViewCellDidBeginEditing:self];
	}
}

- (void)textFieldDidEndEditing:(UITextField *)field {
	if ([delegate respondsToSelector:@selector(editableTableViewCellDidEndEditing:)]) {
		[delegate editableTableViewCellDidEndEditing:self];
	}
}

- (BOOL)textFieldShouldClear:(UITextField *)field {
	if ([delegate respondsToSelector:@selector(editableTableViewCellDidClear:)]) {
		[delegate editableTableViewCellDidClear:self];
	}
    
	return YES;
}

- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	NSMutableString *replacedString = [NSMutableString stringWithString:field.text];
	
	[replacedString replaceCharactersInRange:range withString:string];
	
	if ([delegate respondsToSelector:@selector(editableTableViewCell:didChangeValue:)]) {
		[delegate editableTableViewCell:self didChangeValue:replacedString];
	}
	
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	if ([delegate respondsToSelector:@selector(editableTableViewCellDidReturn:)]) {
		[delegate editableTableViewCellDidReturn:self];
	}
	
	return YES;
}

- (void)dealloc {
	[_textField release], _textField = nil;
    
    [super dealloc];
}

@end
