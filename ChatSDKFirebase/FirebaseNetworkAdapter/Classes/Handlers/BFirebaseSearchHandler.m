//
//  BFirebaseSearchHandler.m
//  Pods
//
//  Created by Benjamin Smiley-andrews on 12/11/2016.
//
//

#import "BFirebaseSearchHandler.h"

#import <ChatSDKFirebase/FirebaseAdapter.h>

@implementation BFirebaseSearchHandler

-(RXPromise *) usersForIndex: (NSString *) index withValue: (id) value limit: (int) limit userAdded: (void(^)(id<PUser> user)) userAdded {
    RXPromise * promise = [RXPromise new];
    
    if ([index isEqual:bUserNameLowercase]) {
        value = [value lowercaseString];
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if(!index || !index.length || !value) {
            // TODO: Localise this
            [promise rejectWithReason:[NSError errorWithDomain:@"" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Index or value is blank"}]];
        }
        else {
            NSString * childPath = [NSString stringWithFormat:@"%@/%@", bMetaPath, index];
            FIRDatabaseQuery * query = [[FIRDatabaseReference usersRef] queryOrderedByChild: childPath];
            query = [query queryStartingAtValue:value];
            query = [query queryLimitedToFirst:limit];
            
            [query observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * snapshot) {
                if(snapshot.value != [NSNull null]) {
                    for(NSString * key in [snapshot.value allKeys]) {
                        NSDictionary * meta = snapshot.value[key][bMetaPath];
                        if(meta && [meta[index] isEqual:value]) {
                            CCUserWrapper * wrapper = [CCUserWrapper userWithSnapshot:[snapshot childSnapshotForPath:key]];
                            if(![wrapper.model isEqual:BChatSDK.currentUser]) {
                                userAdded(wrapper.model);
                            }
                        }
                    }
                }
                [promise resolveWithResult:Nil];
            }];
        }
    });
    
    return promise;
}

-(RXPromise *) usersForIndexes: (NSArray *) indexes withValue: (id) value limit: (int) limit userAdded: (void(^)(id<PUser> user)) userAdded {
    
    if(!indexes) {
        indexes = @[bUserNameKey, bUserEmailKey, bUserPhoneKey, bUserNameLowercase];
    }
    
    NSMutableArray * promises = [NSMutableArray new];
    for (NSString * index in indexes) {
        [promises addObject:[self usersForIndex:index withValue:value limit: limit userAdded:userAdded]];
    }
    
    // Return null when all the promises finish
    return [RXPromise all:promises].thenOnMain(^id(id success) {
        return Nil;
    }, Nil);
}

// TODO: add the user index to user/index
#pragma Depricated
-(RXPromise *) updateIndexForUser: (id<PUser>) userModel  {
    
    RXPromise * promise = [RXPromise new];
    
    FIRDatabaseReference * ref = [[FIRDatabaseReference searchIndexRef] child:BChatSDK.auth.currentUserEntityID];
    
    NSString * email = [userModel.meta metaStringForKey:bUserEmailKey];
    NSString * phone = [userModel.meta metaStringForKey:bUserPhoneKey];
    
    NSDictionary * value = @{bUserNameKey: userModel.name ? [self processForQuery:userModel.name] : @"",
                             bUserEmailKey: email ? [self processForQuery:email] : @"",
                             bUserPhoneKey: phone ? [self processForQuery:phone] : @""};
    
    // The search index works like: /searchIndex/[user entity id]/user details
    [ref setValue:value withCompletionBlock:^(NSError * error, FIRDatabaseReference * firebase) {
        if (!error) {
            [promise resolveWithResult:Nil];
        }
        else {
            [promise rejectWithReason:error];
        }
    }];
    
    return promise;
}

-(NSString *) processForQuery: (NSString *) string {
    return [[string stringByReplacingOccurrencesOfString:@" " withString:@""] lowercaseString];
}

-(RXPromise *) availableIndexes {
    return [RXPromise resolveWithResult:Nil];
}


@end
