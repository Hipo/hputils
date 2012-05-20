//
//  HPPhotoView.h
//  HPUtils
//
//  Created by Taylan Pince on 11-07-21.
//  Copyright 2011 Hippo Foundry Inc. All rights reserved.
//

@protocol HPPhotoViewDelegate;

@interface HPPhotoView : UIView {
@private
    UIImageView *_imageView;
    UIImageView *_errorIcon;
    UIActivityIndicatorView *_loadIndicator;
    
    id <HPPhotoViewDelegate> _delegate;
}

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, assign) id <HPPhotoViewDelegate> delegate;

- (void)prepareForReuse;
- (void)startLoadingAnimated:(BOOL)animated;
- (void)endLoadingAnimated:(BOOL)animated withSuccess:(BOOL)success;

@end


@protocol HPPhotoViewDelegate <NSObject>
@optional
- (void)photoViewDidTap:(HPPhotoView *)photoView;
- (void)photoViewDidDoubleTap:(HPPhotoView *)photoView;
@end
