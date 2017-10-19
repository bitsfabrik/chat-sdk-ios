//
//  BMessageCellDelegate.h
//  Pods
//
//  Created by Dominik Weidner on 19.10.17.
//

@protocol BMessageCellDelegate <NSObject>

-(void) showProfile: (id<PUser>) user;

@end

