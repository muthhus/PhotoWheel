//
//  PhotoBrowserViewController.m
//  PhotoWheel
//
//  Created by Kirby Turner on 6/21/11.
//  Copyright 2011 White Peak Software Inc. All rights reserved.
//

#import "PhotoBrowserViewController.h"
#import "ClearToolbar.h"

@interface PhotoBrowserViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIBarButtonItem *actionButton;
@property (nonatomic, strong) NSMutableArray *photoViewCache;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign, getter = isChromeHidden) BOOL chromeHidden;
@property (nonatomic, strong) NSTimer *chromeHideTimer;

- (void)addButtonsToNavigationBar;
- (void)initPhotoViewCache;
- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (void)scrollToIndex:(NSInteger)index;
- (void)setScrollViewContentSize;
- (NSInteger)numberOfPhotos;
- (UIImage*)imageAtIndex:(NSInteger)index;

- (void)toggleChromeDisplay;
- (void)toggleChrome:(BOOL)hide;
- (void)hideChrome;
- (void)showChrome;
- (void)startChromeDisplayTimer;
- (void)cancelChromeDisplayTimer; 

@end


@implementation PhotoBrowserViewController

@synthesize delegate = delegate_;
@synthesize startAtIndex = startAtIndex_;
@synthesize pushFromFrame = pushFromFrame;
@synthesize scrollView = scrollView_;
@synthesize actionButton = actionButton_;
@synthesize photoViewCache = photoViewCache_;
@synthesize currentIndex = currentIndex_;
@synthesize chromeHidden = chromeHidden_;
@synthesize chromeHideTimer = chromeHideTimer_;

- (void)loadView
{
   [super loadView];
   
   UIScrollView *newScrollView = [[UIScrollView alloc] initWithFrame:[self frameForPagingScrollView]];
   [newScrollView setDelegate:self];
   [newScrollView setBackgroundColor:[UIColor blackColor]];
   [newScrollView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
   [newScrollView setAutoresizesSubviews:YES];
   [newScrollView setPagingEnabled:YES];
   [newScrollView setShowsVerticalScrollIndicator:NO];
   [newScrollView setShowsHorizontalScrollIndicator:NO];
   
   [self.view addSubview:newScrollView];
   [self setScrollView:newScrollView];
}

- (void)viewDidLoad
{
   [super viewDidLoad];
   
   [self addButtonsToNavigationBar];
   [self initPhotoViewCache];
}

- (void)viewWillAppear:(BOOL)animated
{
   [super viewWillAppear:animated];
   
   UINavigationBar *navBar = [[self navigationController] navigationBar];
   [navBar setBarStyle:UIBarStyleBlack];
   [navBar setTranslucent:YES];
   
   [[self navigationController] setNavigationBarHidden:NO animated:YES];
   
   [self setScrollViewContentSize];
   [self setCurrentIndex:[self startAtIndex]];
   [self scrollToIndex:[self startAtIndex]];
   [self startChromeDisplayTimer];
}

- (void)viewWillDisappear:(BOOL)animated
{
   [self cancelChromeDisplayTimer];
   [[self navigationController] setNavigationBarHidden:YES animated:YES];
   [super viewWillDisappear:animated];
}

#pragma mark - Helper Methods

- (void)addButtonsToNavigationBar
{
   // Add buttons to the navigation bar. The nav bar allows
   // one button on the left and one on the right. Optionally
   // a custom view can be used instead of a button. To get
   // multiple buttons we must create a short toolbar containing
   // the buttons we want.
   
   UIBarButtonItem *trashButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deletePhoto:)];
   [trashButton setStyle:UIBarButtonItemStyleBordered];
   
   UIBarButtonItem *actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(showActionMenu:)];
   [actionButton setStyle:UIBarButtonItemStyleBordered];
   [self setActionButton:actionButton];
   
   UIBarButtonItem *slideshowButton = [[UIBarButtonItem alloc] initWithTitle:@"Slideshow" style:UIBarButtonItemStyleBordered target:self action:@selector(slideshow:)];
   
   UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
   
   
   NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithCapacity:3];
   [toolbarItems addObject:flexibleSpace];
   [toolbarItems addObject:slideshowButton];
   [toolbarItems addObject:actionButton];
   [toolbarItems addObject:trashButton];
   
   UIToolbar *toolbar = [[ClearToolbar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
   [toolbar setBackgroundColor:[UIColor clearColor]];
   [toolbar setBarStyle:UIBarStyleBlack];
   [toolbar setTranslucent:YES];
   
   [toolbar setItems:toolbarItems];
   
   UIBarButtonItem *customBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:toolbar];
   [[self navigationItem] setRightBarButtonItem:customBarButtonItem animated:YES];
}

- (void)initPhotoViewCache
{
   // Setup our photo view cache. We only keep 3 views in
   // memory. NSNull is used as a placeholder for the other
   // elements in the view cache array.
   
   NSInteger numberOfPhotos = [self numberOfPhotos];;
   self.photoViewCache = [[NSMutableArray alloc] initWithCapacity:numberOfPhotos];
   for (int i=0; i < numberOfPhotos; i++) {
      [self.photoViewCache addObject:[NSNull null]];
   }
}

- (void)scrollToIndex:(NSInteger)index 
{
   CGRect frame = [self scrollView].frame;
   frame.origin.x = frame.size.width * index;
   frame.origin.y = 0;
   [[self scrollView] scrollRectToVisible:frame animated:NO];
}

- (void)setScrollViewContentSize
{
   NSInteger pageCount = [self numberOfPhotos];
   if (pageCount == 0) {
      pageCount = 1;
   }
   
   CGSize size = CGSizeMake([self scrollView].frame.size.width * pageCount, 
                            [self scrollView].frame.size.height / 2);   // Cut in half to prevent horizontal scrolling.
   [[self scrollView] setContentSize:size];
}

#pragma mark - Frame calculations
#define PADDING  20

- (CGRect)frameForPagingScrollView 
{
   CGRect frame = [[UIScreen mainScreen] bounds];
   frame.origin.x -= PADDING;
   frame.size.width += (2 * PADDING);
   return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index 
{
   // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
   // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
   // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
   // because it has a rotation transform applied.
   CGRect bounds = [scrollView_ bounds];
   CGRect pageFrame = bounds;
   pageFrame.size.width -= (2 * PADDING);
   pageFrame.origin.x = (bounds.size.width * index) + PADDING;
   return pageFrame;
}

#pragma mark - Delegate Callback Helpers

- (NSInteger)numberOfPhotos
{
   NSInteger numberOfPhotos = 0;
   id<PhotoBrowserViewControllerDelegate> delegate = [self delegate];
   if (delegate && [delegate respondsToSelector:@selector(photoBrowserViewControllerNumberOfPhotos:)]) {
      numberOfPhotos = [delegate photoBrowserViewControllerNumberOfPhotos:self];
   }
   return numberOfPhotos;
}

- (UIImage*)imageAtIndex:(NSInteger)index
{
   UIImage *image = nil;
   id<PhotoBrowserViewControllerDelegate> delegate = [self delegate];
   if (delegate && [delegate respondsToSelector:@selector(photoBrowserViewController:imageAtIndex:)]) {
      image = [delegate photoBrowserViewController:self imageAtIndex:index];
   }
   return image;
}

#pragma mark - Actions

- (void)deletePhoto:(id)sender
{
   NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)showActionMenu:(id)sender
{
   NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)slideshow:(id)sender
{
   NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)photoTapped:(id)sender
{
   [self toggleChromeDisplay];
}

#pragma mark - Page Management

- (void)loadPage:(NSInteger)index
{
   if (index < 0 || index >= [self numberOfPhotos]) {
      return;
   }
   
   id currentView = [[self photoViewCache] objectAtIndex:index];
   if ([currentView isKindOfClass:[UIImageView class]] == NO) {
      // Load the photo view.
      CGRect frame = [self frameForPageAtIndex:index];
      UIImageView *newView = [[UIImageView alloc] initWithFrame:frame];
      [newView setBackgroundColor:[UIColor clearColor]];
      [newView setImage:[self imageAtIndex:index]];
      
      UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoTapped:)];
      [newView addGestureRecognizer:tap];
      [newView setUserInteractionEnabled:YES];
      
      [[self scrollView] addSubview:newView];
      [[self photoViewCache] replaceObjectAtIndex:index withObject:newView];
   }
}

- (void)unloadPage:(NSInteger)index
{
   if (index < 0 || index >= [self numberOfPhotos]) {
      return;
   }
   
   id currentView = [[self photoViewCache] objectAtIndex:index];
   if ([currentView isKindOfClass:[UIImageView class]]) {
      [currentView removeFromSuperview];
      [[self photoViewCache] replaceObjectAtIndex:index withObject:[NSNull null]];
   }
}

- (void)setCurrentIndex:(NSInteger)newIndex
{
   currentIndex_ = newIndex;
   
   [self loadPage:currentIndex_];
   [self loadPage:currentIndex_ + 1];
   [self loadPage:currentIndex_ - 1];
   [self unloadPage:currentIndex_ + 2];
   [self unloadPage:currentIndex_ - 2];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView 
{
   CGFloat pageWidth = scrollView.frame.size.width;
   float fractionalPage = scrollView.contentOffset.x / pageWidth;
   NSInteger page = floor(fractionalPage);
	if (page != currentIndex_) {
		[self setCurrentIndex:page];
	}
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView 
{
   [self hideChrome];
}

#pragma mark - Chrome Helpers

- (void)toggleChromeDisplay 
{
   [self toggleChrome:![self isChromeHidden]];
}

- (void)toggleChrome:(BOOL)hide 
{
   [self setChromeHidden:hide];
   if (hide) {
      [UIView beginAnimations:nil context:nil];
      [UIView setAnimationDuration:0.4];
   }
   
   CGFloat alpha = hide ? 0.0 : 1.0;
   
   // Must set the navigation bar's alpha, otherwise the photo
   // view will be pushed until the navigation bar.
   UINavigationBar *navbar = [[self navigationController] navigationBar];
   [navbar setAlpha:alpha];
   
   if (hide) {
      [UIView commitAnimations];
   }
   
   if ( ! [self isChromeHidden] ) {
      [self startChromeDisplayTimer];
   }
}

- (void)hideChrome 
{
   NSTimer *timer = [self chromeHideTimer];
   if (timer && [timer isValid]) {
      [timer invalidate];
      [self setChromeHideTimer:nil];
   }
   [self toggleChrome:YES];
}

- (void)showChrome 
{
   [self toggleChrome:NO];
}

- (void)startChromeDisplayTimer 
{
   [self cancelChromeDisplayTimer];
   NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(hideChrome) userInfo:nil repeats:NO];
   [self setChromeHideTimer:timer];
}

- (void)cancelChromeDisplayTimer 
{
   if ([self chromeHideTimer]) {
      [[self chromeHideTimer] invalidate];
      [self setChromeHideTimer:nil];
   }
}

@end