// -----------------------------------------------------------------------------
// Copyright 2011 Patrick Näf (herzbube@herzbube.ch)
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
#import "NewGameController.h"
#import "NewGameModel.h"
#import "../ui/TableViewCellFactory.h"
#import "../utility/NSStringAdditions.h"
#import "../utility/UIColorAdditions.h"
#import "../go/GoGame.h"
#import "../go/GoBoard.h"
#import "../ApplicationDelegate.h"
#import "../player/PlayerModel.h"
#import "../player/Player.h"


// -----------------------------------------------------------------------------
/// @brief Enumerates the sections presented in the "New Game" table view.
// -----------------------------------------------------------------------------
enum NewGameTableViewSection
{
  PlayersSection,
  MaxSectionLoadGame,
  // Sections from here on are not displayed in "load game" mode
  BoardSizeSection = MaxSectionLoadGame,
  HandicapSection,
  KomiSection,
  MaxSection
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the BoardSizeSection.
// -----------------------------------------------------------------------------
enum BoardSizeSectionItem
{
  BoardSizeItem,
  MaxBoardSizeSectionItem
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the PlayersSection.
// -----------------------------------------------------------------------------
enum PlayersSectionItem
{
  BlackPlayerItem,
  WhitePlayerItem,
  MaxPlayersSectionItem
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the HandicapSection.
// -----------------------------------------------------------------------------
enum HandicapSectionItem
{
  HandicapItem,
  MaxHandicapSectionItem
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the KomiSection.
// -----------------------------------------------------------------------------
enum KomiSectionItem
{
  KomiItem,
  MaxKomiSectionItem
};


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for NewGameController.
// -----------------------------------------------------------------------------
@interface NewGameController()
/// @name Initialization and deallocation
//@{
- (void) dealloc;
//@}
/// @name UIViewController methods
//@{
- (void) viewDidLoad;
- (void) viewDidUnload;
//@}
/// @name Action methods
//@{
- (void) done:(id)sender;
- (void) cancel:(id)sender;
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
/// @name BoardSizeSelectionDelegate protocol
//@{
- (void) boardSizeSelectionController:(BoardSizeSelectionController*)controller didMakeSelection:(bool)didMakeSelection;
//@}
/// @name PlayerSelectionDelegate protocol
//@{
- (void) playerSelectionController:(PlayerSelectionController*)controller didMakeSelection:(bool)didMakeSelection;
//@}
/// @name HandicapSelectionDelegate protocol
//@{
- (void) handicapSelectionController:(HandicapSelectionController*)controller didMakeSelection:(bool)didMakeSelection;
//@}
/// @name KomiSelectionDelegate protocol
//@{
- (void) komiSelectionController:(KomiSelectionController*)controller didMakeSelection:(bool)didMakeSelection;
//@}
/// @name UIAlertViewDelegate protocol
//@{
- (void) alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;
//@}
/// @name Helpers
//@{
- (void) updateCell:(UITableViewCell*)cell withPlayer:(Player*)player;
- (bool) isSelectionValid;
- (void) newGame;
//@}
@end


@implementation NewGameController

@synthesize delegate;
@synthesize boardSize;
@synthesize blackPlayer;
@synthesize whitePlayer;
@synthesize loadGame;
@synthesize handicap;
@synthesize komi;


// -----------------------------------------------------------------------------
/// @brief Convenience constructor. Creates a NewGameController instance of
/// grouped style.
///
/// @a loadGame is true to indicate that the intent of starting the new game is
/// to load an archived game. @a loadGame is false to indicate that the new game
/// should be started in the regular fashion. The two modes display different
/// UI elements and trigger different operations when the user finally confirms
/// starting the new game.
// -----------------------------------------------------------------------------
+ (NewGameController*) controllerWithDelegate:(id<NewGameDelegate>)delegate loadGame:(bool)loadGame
{
  NewGameController* controller = [[NewGameController alloc] initWithStyle:UITableViewStyleGrouped];
  if (controller)
  {
    [controller autorelease];
    controller.delegate = delegate;
    controller.loadGame = loadGame;
    NewGameModel* newGameModel = [ApplicationDelegate sharedDelegate].theNewGameModel;
    PlayerModel* playerModel = [ApplicationDelegate sharedDelegate].playerModel;
    controller.boardSize = newGameModel.boardSize;
    controller.blackPlayer = [playerModel playerWithUUID:newGameModel.blackPlayerUUID];
    controller.whitePlayer = [playerModel playerWithUUID:newGameModel.whitePlayerUUID];
    controller.handicap = newGameModel.handicap;
    controller.komi = newGameModel.komi;
  }
  return controller;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this NewGameController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.delegate = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Called after the controller’s view is loaded into memory, usually
/// to perform additional initialization steps.
// -----------------------------------------------------------------------------
- (void) viewDidLoad
{
  [super viewDidLoad];

  assert(self.delegate != nil);

  // Configure the navigation item representing this controller. This item will
  // be displayed by the navigation controller that wraps this controller in
  // its navigation bar.
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                        target:self
                                                                                        action:@selector(cancel:)];
  if (! self.loadGame)
    self.navigationItem.title = @"New Game";
  else
    self.navigationItem.title = @"Load Game";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                         target:self
                                                                                         action:@selector(done:)];
  self.navigationItem.rightBarButtonItem.enabled = [self isSelectionValid];
}

// -----------------------------------------------------------------------------
/// @brief Called when the controller’s view is released from memory, e.g.
/// during low-memory conditions.
///
/// Releases additional objects (e.g. by resetting references to retained
/// objects) that can be easily recreated when viewDidLoad() is invoked again
/// later.
// -----------------------------------------------------------------------------
- (void) viewDidUnload
{
  [super viewDidUnload];
}

// -----------------------------------------------------------------------------
/// @brief Invoked when the user has decided to start a new game.
// -----------------------------------------------------------------------------
- (void) done:(id)sender
{
  GoGame* game = [GoGame sharedGame];
  switch (game.state)
  {
    case GameHasStarted:
    case GameIsPaused:
    {
      UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"New game"
                                                      message:@"Are you sure you want to start a new game and discard the game in progress?"
                                                     delegate:self
                                            cancelButtonTitle:@"No"
                                            otherButtonTitles:@"Yes", nil];
      alert.tag = NewGameAlertView;
      [alert show];
      break;
    }
    default:
    {
      [self newGame];
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Invoked when the user has decided not to start a new game.
// -----------------------------------------------------------------------------
- (void) cancel:(id)sender
{
  [self.delegate newGameController:self didStartNewGame:false];
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView
{
  if (! self.loadGame)
    return MaxSection;
  else
    return MaxSectionLoadGame;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  switch (section)
  {
    case BoardSizeSection:
      return MaxBoardSizeSectionItem;
    case PlayersSection:
      return MaxPlayersSectionItem;
    case HandicapSection:
      return MaxHandicapSectionItem;
    case KomiSection:
      return MaxKomiSectionItem;
    default:
      assert(0);
      break;
  }
  return 0;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
  UITableViewCell* cell = [TableViewCellFactory cellWithType:Value1CellType tableView:tableView];
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  switch (indexPath.section)
  {
    case BoardSizeSection:
      switch (indexPath.row)
      {
        case BoardSizeItem:
          cell.textLabel.text = @"Board size";
          cell.detailTextLabel.text = [GoBoard stringForSize:self.boardSize];
          break;
        default:
          assert(0);
          break;
      }
      break;
    case PlayersSection:
      {
        switch (indexPath.row)
        {
          case BlackPlayerItem:
            cell.textLabel.text = @"Black";
            [self updateCell:cell withPlayer:self.blackPlayer];
            break;
          case WhitePlayerItem:
            cell.textLabel.text = @"White";
            [self updateCell:cell withPlayer:self.whitePlayer];
            break;
          default:
            assert(0);
            break;
        }
        break;
      }
    case HandicapSection:
      switch (indexPath.row)
      {
        case HandicapItem:
          cell.textLabel.text = @"Handicap";
          cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", self.handicap];
        default:
          assert(0);
          break;
      }
      break;
    case KomiSection:
      switch (indexPath.row)
      {
        case KomiItem:
          cell.textLabel.text = @"Komi";
          cell.detailTextLabel.text = [NSString stringWithKomi:self.komi];
        default:
          assert(0);
          break;
      }
      break;
    default:
      assert(0);
      break;
  }

  return cell;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:NO];

  UIViewController* modalController;
  switch (indexPath.section)
  {
    case BoardSizeSection:
      modalController = [[BoardSizeSelectionController controllerWithDelegate:self
                                                             defaultBoardSize:self.boardSize] retain];
      break;
    case PlayersSection:
      {
        Player* player;
        bool selectBlackPlayer;
        if (indexPath.row == BlackPlayerItem)
        {
          player = self.blackPlayer;
          selectBlackPlayer = true;
        }
        else
        {
          player = self.whitePlayer;
          selectBlackPlayer = false;
        }
        modalController = [[PlayerSelectionController controllerWithDelegate:self
                                                               defaultPlayer:player
                                                                 blackPlayer:selectBlackPlayer] retain];
        break;
      }
    case HandicapSection:
      modalController = [[HandicapSelectionController controllerWithDelegate:self
                                                             defaultHandicap:self.handicap] retain];
      break;
    case KomiSection:
      modalController = [[KomiSelectionController controllerWithDelegate:self
                                                             defaultKomi:self.komi] retain];
      break;
    default:
      assert(0);
      return;
  }
  UINavigationController* navigationController = [[UINavigationController alloc]
                                                  initWithRootViewController:modalController];
  navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  [self presentModalViewController:navigationController animated:YES];
  [navigationController release];
  [modalController release];
}

// -----------------------------------------------------------------------------
/// @brief BoardSizeSelectionDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) boardSizeSelectionController:(BoardSizeSelectionController*)controller didMakeSelection:(bool)didMakeSelection
{
  if (didMakeSelection)
  {
    if (self.boardSize != controller.boardSize)
    {
      self.boardSize = controller.boardSize;
      NSIndexPath* boardSizeIndexPath = [NSIndexPath indexPathForRow:0 inSection:BoardSizeSection];
      UITableViewCell* boardSizeCell = [self.tableView cellForRowAtIndexPath:boardSizeIndexPath];
      boardSizeCell.detailTextLabel.text = [GoBoard stringForSize:self.boardSize];
      self.navigationItem.rightBarButtonItem.enabled = [self isSelectionValid];
    }
  }
  [self dismissModalViewControllerAnimated:YES];
}

// -----------------------------------------------------------------------------
/// @brief PlayerSelectionDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) playerSelectionController:(PlayerSelectionController*)controller didMakeSelection:(bool)didMakeSelection
{
  if (didMakeSelection)
  {
    Player* previousPlayer = controller.blackPlayer ? self.blackPlayer : self.whitePlayer;
    if (previousPlayer != controller.player)
    {
      int playerRow;
      if (controller.blackPlayer)
      {
        self.blackPlayer = controller.player;
        playerRow = BlackPlayerItem;
      }
      else
      {
        self.whitePlayer = controller.player;
        playerRow = WhitePlayerItem;
      }
      NSIndexPath* playerIndexPath = [NSIndexPath indexPathForRow:playerRow inSection:PlayersSection];
      UITableViewCell* playerCell = [self.tableView cellForRowAtIndexPath:playerIndexPath];
      [self updateCell:playerCell withPlayer:controller.player];
      self.navigationItem.rightBarButtonItem.enabled = [self isSelectionValid];
    }
  }
  [self dismissModalViewControllerAnimated:YES];
}

// -----------------------------------------------------------------------------
/// @brief HandicapSelectionDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) handicapSelectionController:(HandicapSelectionController*)controller didMakeSelection:(bool)didMakeSelection
{
  if (didMakeSelection)
  {
    if (self.handicap != controller.handicap)
    {
      self.handicap = controller.handicap;
      NSIndexPath* handicapIndexPath = [NSIndexPath indexPathForRow:0 inSection:HandicapSection];
      UITableViewCell* handicapCell = [self.tableView cellForRowAtIndexPath:handicapIndexPath];
      handicapCell.detailTextLabel.text = [NSString stringWithFormat:@"%d", self.handicap];
      self.navigationItem.rightBarButtonItem.enabled = [self isSelectionValid];
    }
  }
  [self dismissModalViewControllerAnimated:YES];
}

// -----------------------------------------------------------------------------
/// @brief KomiSelectionDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) komiSelectionController:(KomiSelectionController*)controller didMakeSelection:(bool)didMakeSelection
{
  if (didMakeSelection)
  {
    if (self.komi != controller.komi)
    {
      self.komi = controller.komi;
      NSIndexPath* komiIndexPath = [NSIndexPath indexPathForRow:0 inSection:KomiSection];
      UITableViewCell* komiCell = [self.tableView cellForRowAtIndexPath:komiIndexPath];
      komiCell.detailTextLabel.text = [NSString stringWithKomi:self.komi];
      self.navigationItem.rightBarButtonItem.enabled = [self isSelectionValid];
    }
  }
  [self dismissModalViewControllerAnimated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Updates @a cell so that it represents @a player. Note that @a player
/// may be @e nil.
// -----------------------------------------------------------------------------
- (void) updateCell:(UITableViewCell*)cell withPlayer:(Player*)player
{
  if (player)
  {
    cell.detailTextLabel.text = player.name;
    cell.detailTextLabel.textColor = [UIColor slateBlueColor];
  }
  else
  {
    cell.detailTextLabel.text = @"No player selected";
    cell.detailTextLabel.textColor = [UIColor grayColor];
  }
}

// -----------------------------------------------------------------------------
/// @brief Returns true if the currently selected settings are valid so that a
/// new game can be started.
// -----------------------------------------------------------------------------
- (bool) isSelectionValid
{
  return (self.blackPlayer != nil && self.whitePlayer != nil);
}

// -----------------------------------------------------------------------------
/// @brief Reacts to the user dismissing an alert view for which this controller
/// is the delegate.
// -----------------------------------------------------------------------------
- (void) alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  switch (buttonIndex)
  {
    case NoAlertViewButton:
      break;
    case YesAlertViewButton:
      [self newGame];
      break;
    default:
      break;
  }
}

// -----------------------------------------------------------------------------
/// @brief Invoked when the user has finished selecting parameters for a new
/// game. Makes the collected information persistent, then informs the delegate
/// that a new game needs to be started.
// -----------------------------------------------------------------------------
- (void) newGame
{
  // Store the collected information in NewGameModel before informing the
  // delegate
  NewGameModel* model = [ApplicationDelegate sharedDelegate].theNewGameModel;
  assert(model);
  model.boardSize = self.boardSize;
  model.blackPlayerUUID = self.blackPlayer.uuid;
  model.whitePlayerUUID = self.whitePlayer.uuid;
  // If an archived game is loaded, handicap and komi are taken from the
  // archive; since the user did not make selections for those parameters, they
  // cannot be persisted.
  if (! self.loadGame)
  {
    model.handicap = self.handicap;
    model.komi = self.komi;
  }

  [self.delegate newGameController:self didStartNewGame:true];
}

@end
