// -----------------------------------------------------------------------------
// Copyright 2011-2012 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Project includes
#import "GtpLogViewController.h"
#import "GtpLogItem.h"
#import "GtpLogItemViewController.h"
#import "GtpLogModel.h"
#import "SubmitGtpCommandViewController.h"
#import "../main/ApplicationDelegate.h"
#import "../ui/TableViewCellFactory.h"
#import "../ui/UiElementMetrics.h"
#import "../ui/UiUtilities.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for GtpLogViewController.
// -----------------------------------------------------------------------------
@interface GtpLogViewController()
/// @name Initialization and deallocation
//@{
- (void) dealloc;
//@}
/// @name UIViewController methods
//@{
- (void) loadView;
- (void) viewDidLoad;
- (void) viewDidUnload;
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;
//@}
/// @name UITableViewDataSource protocol
//@{
- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView;
- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath;
//@}
/// @name UITableViewDelegate protocol
//@{
- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath;
//@}
/// @name Action methods
//@{
- (void) flipView:(id)sender;
- (void) composeCommand:(id)sender;
- (void) viewLogItem:(GtpLogItem*)logItem;
//@}
/// @name Notification responders
//@{
- (void) gtpLogContentChanged:(NSNotification*)notification;
- (void) gtpLogItemChanged:(NSNotification*)notification;
//@}
/// @name Private helpers
//@{
- (CGRect) mainViewFrame;
- (void) setupNavigationItem;
- (void) setupFrontSideView;
- (void) setupBackSideView;
- (void) reloadBackSideView;
- (void) appendToBackSideView:(GtpLogItem*)logItem;
- (void) updateBackSideView:(NSString*)newText;
- (NSString*) rawLogStringForItem:(GtpLogItem*)logItem;
- (void) scrollToBottomOfFrontSideView;
- (void) scrollToBottomOfBackSideView;
//@}
/// @name Privately declared properties
//@{
/// @brief The frontside view. Log items are represented by table view cells.
@property(nonatomic, retain) UITableView* frontSideView;
/// @brief The backside view. Log items are represented by raw text.
@property(nonatomic, retain) UITextView* backSideView;
@property(nonatomic, assign) bool lastRowIsVisible;
@property(nonatomic, assign) bool updateScheduledByGtpLogItemChanged;
/// TODO This flag exists because we "know" that, if both gtpLogContentChanged
/// and gtpLogItemChanged are sent shortly after each other,
/// gtpLogContentChanged will always be sent first. This is deep knowledge of
/// how GtpLogModel sends its notifications, and we should find a better way
/// for handling update conflicts.
@property(nonatomic, assign) bool updateScheduledByGtpLogContentChanged;
//@}
@end


@implementation GtpLogViewController

// -----------------------------------------------------------------------------
/// @brief Convenience constructor. Creates a GtpLogViewController instance
/// that loads its frontside and backside view from a .nib file.
// -----------------------------------------------------------------------------
+ (GtpLogViewController*) controller
{
  GtpLogViewController* controller = [[GtpLogViewController alloc] init];
  if (controller)
    [controller autorelease];
  return controller;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this GtpLogViewController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.model = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Creates the view that this controller manages.
// -----------------------------------------------------------------------------
- (void) loadView
{
  // Setup view hierarchy
  CGRect mainViewFrame = [self mainViewFrame];
  self.view = [[[UIView alloc] initWithFrame:mainViewFrame] autorelease];
  self.frontSideView = [[[UITableView alloc] initWithFrame:mainViewFrame
                                                     style:UITableViewStylePlain] autorelease];
  self.backSideView = [[[UITextView alloc] initWithFrame:mainViewFrame] autorelease];

  // Configure autoresizingMask properties for proper autorotation
  UIViewAutoresizing autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  self.view.autoresizingMask = autoresizingMask;
  self.frontSideView.autoresizingMask = autoresizingMask;
  self.backSideView.autoresizingMask = autoresizingMask;

  // Other configuration
  self.backSideView.editable = false;
}

// -----------------------------------------------------------------------------
/// @brief Called after the controller’s view is loaded into memory, usually
/// to perform additional initialization steps.
// -----------------------------------------------------------------------------
- (void) viewDidLoad
{
  [super viewDidLoad];

  ApplicationDelegate* delegate = [ApplicationDelegate sharedDelegate];
  self.model = delegate.gtpLogModel;

  [self setupNavigationItem];
  [self setupFrontSideView];
  [self setupBackSideView];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(gtpLogContentChanged:)
                                               name:gtpLogContentChanged
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(gtpLogItemChanged:)
                                               name:gtpLogItemChanged
                                             object:nil];

  if (self.model.gtpLogViewFrontSideIsVisible)
  {
    [self.view addSubview:self.frontSideView];
    [self.frontSideView reloadData];
  }
  else
  {
    [self.view addSubview:self.backSideView];
    [self reloadBackSideView];
  }
}

// -----------------------------------------------------------------------------
/// @brief Exists for compatibility with iOS 5. Is not invoked in iOS 6 and can
/// be removed if deployment target is set to iOS 6.
// -----------------------------------------------------------------------------
- (void) viewDidUnload
{
  [super viewDidUnload];

  // Super's viewDidUnload does not release self.view/self.tableView for us,
  // possibly because we override loadView and create the view ourselves
  self.view = nil;

  // Undo all of the stuff that is happening in viewDidLoad
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.model = nil;
  self.navigationItem.rightBarButtonItem = nil;
}

// -----------------------------------------------------------------------------
/// @brief Called by UIKit at various times to determine whether this controller
/// supports the given orientation @a interfaceOrientation.
// -----------------------------------------------------------------------------
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return [UiUtilities shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

// -----------------------------------------------------------------------------
/// @brief Called by UIKit after the user interface has rotated.
// -----------------------------------------------------------------------------
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  // Adjust the frame of the view that is currently NOT visible. The main view
  // has already been resized by the auto-rotation process, so we can take its
  // frame as the reference.
  if (self.model.gtpLogViewFrontSideIsVisible)
    self.backSideView.frame = self.view.frame;
  else
    self.frontSideView.frame = self.view.frame;
}

// -----------------------------------------------------------------------------
/// @brief Calculates the frame of this controller's main view, taking into
/// account the current interface orientation. Assumes that super views have
/// the correct bounds.
// -----------------------------------------------------------------------------
- (CGRect) mainViewFrame
{
  int mainViewX = 0;
  int mainViewY = 0;
  int mainViewWidth = [UiElementMetrics screenWidth];
  int mainViewHeight = ([UiElementMetrics screenHeight]
                        - [UiElementMetrics tabBarHeight]
                        - [UiElementMetrics navigationBarHeight]
                        - [UiElementMetrics statusBarHeight]);
  return CGRectMake(mainViewX, mainViewY, mainViewWidth, mainViewHeight);
}

// -----------------------------------------------------------------------------
/// @brief Sets up the navigation item of this view controller.
// -----------------------------------------------------------------------------
- (void) setupNavigationItem
{
  // 105.0 determined experimentally in IB
  // 44.01 taken from examples on the Internet; this values seems to shift the
  // toolbar up 1px for some reason
  UIToolbar* toolbar = [[UIToolbar alloc]
                        initWithFrame:CGRectMake(0.0f, 0.0f, 105.0f, 44.01f)];
  NSMutableArray* buttons = [[NSMutableArray alloc] initWithCapacity:2];
  UIBarButtonItem* compose = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                           target:self
                                                                           action:@selector(composeCommand:)];
  compose.style = UIBarButtonItemStyleBordered;
  [buttons addObject:compose];
  [compose release];
  UIBarButtonItem* flip = [[UIBarButtonItem alloc] initWithTitle:@"Flip"
                                                           style:UIBarButtonItemStyleBordered
                                                          target:self
                                                          action:@selector(flipView:)];
  [buttons addObject:flip];
  [flip release];
  [toolbar setItems:buttons animated:NO];
  [buttons release];
  self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:toolbar] autorelease];

  self.navigationItem.title = @"GTP Log";
}

// -----------------------------------------------------------------------------
/// @brief Sets up the frontside view of this controller.
// -----------------------------------------------------------------------------
- (void) setupFrontSideView
{
  self.frontSideView.delegate = self;
  self.frontSideView.dataSource = self;

  self.lastRowIsVisible = false;
  self.updateScheduledByGtpLogItemChanged = false;
  self.updateScheduledByGtpLogContentChanged = false;
}

// -----------------------------------------------------------------------------
/// @brief Sets up the backside view of this controller.
// -----------------------------------------------------------------------------
- (void) setupBackSideView
{
  UIFont* oldFont = self.backSideView.font;
  UIFont* newFont = [oldFont fontWithSize:oldFont.pointSize * 0.75];
  self.backSideView.text = nil;
  self.backSideView.font = newFont;
}

// -----------------------------------------------------------------------------
/// @brief Reloads the content of the backside view of this controller.
// -----------------------------------------------------------------------------
- (void) reloadBackSideView
{
  NSString* contentString = @"";
  for (GtpLogItem* logItem in self.model.itemList)
  {
    // Ignore items with outstanding responses. This should happen only for the
    // last item in the list. Information for that item will be appended to the
    // backside view when the response comes in.
    if (logItem.hasResponse)
    {
      NSString* rawLogString = [self rawLogStringForItem:logItem];
      contentString = [contentString stringByAppendingString:rawLogString];
    }
  }
  [self updateBackSideView:contentString];
}

// -----------------------------------------------------------------------------
/// @brief Appends the information in @a logItem to the current content of the
/// backside view of this controller.
// -----------------------------------------------------------------------------
- (void) appendToBackSideView:(GtpLogItem*)logItem
{
  // UIKit does not like being executed in a secondary thread
  if ([NSThread currentThread] != [NSThread mainThread])
    return;

  NSString* rawLogString = [self rawLogStringForItem:logItem];
  NSString* contentString = [self.backSideView.text stringByAppendingString:rawLogString];
  [self updateBackSideView:contentString];
}

// -----------------------------------------------------------------------------
/// @brief Displays @a newText in the backside view of this controller.
///
/// Automatically scrolls to the bottom of the view if the view already was at
/// the bottom before the update.
// -----------------------------------------------------------------------------
- (void) updateBackSideView:(NSString*)newText
{
  // UIKit does not like being executed in a secondary thread
  if ([NSThread currentThread] != [NSThread mainThread])
    return;

  bool scrollToBottom = false;
  UIScrollView* scrollView = self.backSideView;
  if (scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height)
    scrollToBottom = true;

  self.backSideView.text = newText;

  if (scrollToBottom)
    [self scrollToBottomOfBackSideView];
}

// -----------------------------------------------------------------------------
/// @brief Returns a single string that represents the GTP command/response pair
/// encapsulated by @a logItem.
///
/// The string is formatted with newlines in a fashion that makes it suitable
/// for display in the raw log on the backside view of this controller.
// -----------------------------------------------------------------------------
- (NSString*) rawLogStringForItem:(GtpLogItem*)logItem
{
  return [NSString stringWithFormat:@"%@\n%@\n\n", logItem.commandString, logItem.rawResponseString];
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView
{
  // We assume that this method is invoked only for a complete rebuild of the
  // view (e.g. when the view is displayed for the first time, or for
  // reloadData()). We can clear the flag here, and it will be set again in
  // tableView:cellForRowAtIndexPath:() as soon as the cell for the last row
  // is requested.
  self.lastRowIsVisible = false;

  return 1;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.model.itemCount;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
  // If updateScheduledByGtpLogItemChanged is true we must *NOT* clear
  // lastRowIsVisible. See class documentation for an extensive discussion of
  // how the lastRowIsVisible flag is managed.
  if (self.updateScheduledByGtpLogItemChanged)
  {
    self.updateScheduledByGtpLogItemChanged = false;
    assert(! self.updateScheduledByGtpLogContentChanged);
  }
  else
  {
    if (self.lastRowIsVisible)
      self.lastRowIsVisible = false;
    // updateScheduledByGtpLogContentChanged and updateScheduledByGtpLogItemChanged
    // are not expected to be set at the same time.
    if (self.updateScheduledByGtpLogContentChanged)
      self.updateScheduledByGtpLogContentChanged = false;
  }

  int lastRow = self.model.itemCount - 1;  // -1 because table view rows are zero-based
  int row = indexPath.row;
  if (lastRow == row)
    self.lastRowIsVisible = true;

  UITableViewCell* cell = [TableViewCellFactory cellWithType:SubtitleCellType tableView:tableView];
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  GtpLogItem* logItem = [self.model itemAtIndex:row];
  cell.textLabel.text = logItem.commandString;
  cell.detailTextLabel.text = logItem.timeStamp;
  cell.imageView.image = [logItem imageRepresentingResponseStatus];

  return cell;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
  [self viewLogItem:[self.model itemAtIndex:indexPath.row]];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #gtpLogContentChanged notification.
// -----------------------------------------------------------------------------
- (void) gtpLogContentChanged:(NSNotification*)notification
{
  if (self.lastRowIsVisible)
  {
    // The delay value must be in the range of
    // - "not too short" (so that reloadData() has time to do its work), and
    // - "not too long" (so that the delay does not get noticed by the user)
    NSTimeInterval delay = 0.1;
    [self performSelector:@selector(scrollToBottomOfFrontSideView) withObject:nil afterDelay:delay];
  }

  // Inform gtpLogItemChanged:() that an update has been scheduled by this
  // method.
  self.updateScheduledByGtpLogContentChanged = true;

  [self.frontSideView reloadData];

  if (! self.model.gtpLogViewFrontSideIsVisible)
    [self reloadBackSideView];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #gtpLogItemChanged notification.
// -----------------------------------------------------------------------------
- (void) gtpLogItemChanged:(NSNotification*)notification
{
  GtpLogItem* logItem = [notification object];

  // Ignore updateScheduledByGtpLogContentChanged for backside view updating
  if (! self.model.gtpLogViewFrontSideIsVisible)
    [self appendToBackSideView:logItem];

  // If an update has already been scheduled by gtpLogContentChanged:() we don't
  // have to do anything - in fact the number of cells in self.tableView at this
  // time has already been reset, so we can't invoke
  // reloadRowsAtIndexPaths:withRowAnimation:() anyway
  if (self.updateScheduledByGtpLogContentChanged)
    return;

  // Inform tableView:cellForRowAtIndexPath:() that the update is only for a
  // single item (not for scrolling).
  self.updateScheduledByGtpLogItemChanged = true;

  NSUInteger sectionIndex = 0;
  NSUInteger indexOfItem = [self.model.itemList indexOfObject:logItem];
  NSIndexPath* indexPath = [NSIndexPath indexPathForRow:indexOfItem inSection:sectionIndex];
  NSArray* indexPaths = [NSArray arrayWithObject:indexPath];
  [self.frontSideView reloadRowsAtIndexPaths:indexPaths
                            withRowAnimation:UITableViewRowAnimationNone];
}

// -----------------------------------------------------------------------------
/// @brief Scrolls to the bottom of the frontside view.
// -----------------------------------------------------------------------------
- (void) scrollToBottomOfFrontSideView
{
  NSUInteger lastRowSection = 0;
  NSUInteger lastRow = self.model.itemCount - 1;  // -1 because table view rows are zero-based
  NSIndexPath* lastRowIndexPath = [NSIndexPath indexPathForRow:lastRow
                                                     inSection:lastRowSection];
  [self.frontSideView scrollToRowAtIndexPath:lastRowIndexPath
                            atScrollPosition:UITableViewScrollPositionBottom
                                    animated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Scrolls to the bottom of the backside view.
// -----------------------------------------------------------------------------
- (void) scrollToBottomOfBackSideView
{
  // TODO This UITextView specific code does not work for unknown reasons. It
  // did work in the past, though, when the Diagnostics view consisted only of a
  // UITextView.
  NSRange endOfTextRange = NSMakeRange([self.backSideView.text length], 0);
  [self.backSideView scrollRangeToVisible:endOfTextRange];

  // The following general-purpose approach for scrolling in a UIScrollView
  // does not work either
//  CGPoint contentOffset = CGPointMake(0, 0);
//  UIScrollView* scrollView = self.backSideView;
//  contentOffset.y = scrollView.contentSize.height - scrollView.frame.size.height;
//  if (contentOffset.y < 0)
//    contentOffset.y = 0;
//  [scrollView setContentOffset:contentOffset animated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Flips the main table view over to the raw log view, and vice versa.
// -----------------------------------------------------------------------------
- (void) flipView:(id)sender
{
  [UIView beginAnimations:nil context:nil];
  [UIView setAnimationDuration:0.75];

  bool flipToFrontSideView = ! self.model.gtpLogViewFrontSideIsVisible;
  if (flipToFrontSideView)
  {
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:self.view cache:YES];
    [self.backSideView removeFromSuperview];
    [self.view addSubview:self.frontSideView];
  }
  else
  {
    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.view cache:YES];
    [self.frontSideView removeFromSuperview];
    [self.view addSubview:self.backSideView];
    // Content must be reloaded in
    [self reloadBackSideView];
  }
  [UIView commitAnimations];

  // Remember which view is visible
  self.model.gtpLogViewFrontSideIsVisible = flipToFrontSideView;
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "compose" button in the navigation
/// item. Displays a view that allows the user to compose and submit a GTP
/// command.
// -----------------------------------------------------------------------------
- (void) composeCommand:(id)sender
{
  SubmitGtpCommandViewController* controller = [SubmitGtpCommandViewController controller];
  [self.navigationController pushViewController:controller animated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Displays GtpLogItemViewController to allow the user to view the
/// details of item @a logItem.
// -----------------------------------------------------------------------------
- (void) viewLogItem:(GtpLogItem*)logItem
{
  GtpLogItemViewController* controller = [GtpLogItemViewController controllerWithLogItem:logItem];
  [self.navigationController pushViewController:controller animated:YES];
}

@end
