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

-(RXPromise *) usersForIndex: (NSString *) index withValue: (NSString *) value limit: (int) limit userAdded: (void(^)(id<PUser> user)) userAdded {
    RXPromise * promise = [RXPromise new];
    
    if ([index isEqual:bUserNameLowercase]) {
        value = [value lowercaseString];
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if(!index || !index.length || !value || !value.length) {
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
                        if(meta && [meta[index] containsString:value]) {
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

//-(RXPromise *) usersForIndex2: (NSString *) index withValue: (NSString *) value limit: (int) limit userAdded: (void(^)(id<PUser> user)) userAdded {
//
//    RXPromise * promise = [RXPromise new];
//
//
//    // Make the query lower case and bunch it up
//    value = [self processForQuery:value];
//
//    if (!value.length) {
//        [promise rejectWithReason:Nil];
//        return promise;
//    }
//
//    // Make the query
//    FIRDatabaseQuery * query = [[[[FIRDatabaseReference searchIndexRef] queryOrderedByChild:index] queryStartingAtValue:value] queryLimitedToFirst:limit];
//
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
//
//        // Execute the query
//        [query observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * snapshot) {
//
//            if(snapshot.value != [NSNull null]) {
//
//                // Get the keys of the dictionary
//                NSDictionary * dict = snapshot.value;
//
//                // Only add users that match the original query
//                NSArray * keys = dict.allKeys;
//                NSString * resultValue;
//
//                NSMutableArray * validUIDs = [NSMutableArray new];
//
//                // Loop over the dictionary keys
//                for (NSString * key in keys) {
//
//                    // Don't return the current user!
//                    NSString * currentUserID = BChatSDK.auth.currentUserEntityID;
//
//                    if ([key isEqualToString:currentUserID]) {
//                        continue;
//                    }
//
//                    resultValue = dict[key][index];
//                    if(resultValue) {
//                        // Transform the result value to lower case / no spaces
//                        resultValue = [self processForQuery:resultValue];
//
//                        // If the query is longer than the result then it's obviously not a match
//                        if (resultValue.length < value.length) {
//                            continue;
//                        }
//
//                        // Trim it to the length of the input query
//                        resultValue = [resultValue substringToIndex:value.length];
//
//                        // If they match add it to the result
//                        if ([value isEqualToString:resultValue]) {
//                            [validUIDs addObject:key];
//                        }
//                    }
//                }
//
//                if(validUIDs.count) {
//
//                    NSMutableArray * userPromises = [NSMutableArray new];
//
//                    // Loop over the IDs and get the users
//                    for(NSString * entityID in validUIDs) {
//
//                        CCUserWrapper * user = [CCUserWrapper userWithEntityID:entityID];
//                        [userPromises addObject:[user once].thenOnMain(^id(id<PUserWrapper> u) {
//
//                            // Call add user again to udpate the list with the
//                            // correct image - only add users who have names
//                            if (u.model.name.length) {
//                                userAdded(user.model);
//                            }
//                            return Nil;
//                        }, Nil)];
//                    }
//
//                    [RXPromise all: userPromises].then(^id(id success) {
//                        [promise resolveWithResult:success];
//                        return Nil;
//                    }, Nil);
//                }
//                else {
//                    [promise resolveWithResult:Nil];
//                }
//            }
//            else {
//                [promise resolveWithResult:Nil];
//            }
//        }];
//
//    });
//
//    return promise;
//}

-(RXPromise *) usersForIndexes: (NSArray *) indexes withValue: (NSString *) value limit: (int) limit userAdded: (void(^)(id<PUser> user)) userAdded {
    
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


@end
