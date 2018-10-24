//
//  BBaseContactHandler.m
//  Pods
//
//  Created by Benjamin Smiley-andrews on 12/11/2016.
//
//

#import "BBaseContactHandler.h"

#import <ChatSDK/Core.h>

@implementation BBaseContactHandler

-(NSArray *) contacts {
    return [BChatSDK.currentUser connectionsWithType:bUserConnectionTypeContact];
}

-(NSArray *) contactsWithType: (bUserConnectionType) type {
    return [BChatSDK.currentUser contactsWithType: type];
}

-(NSArray *) connectionsWithType: (bUserConnectionType) type {
    return [BChatSDK.currentUser connectionsWithType:type];
}

-(RXPromise *) addContact: (id<PUser>) contact withType: (bUserConnectionType) type {
    id<PUserConnection> connection = [BChatSDK.db fetchOrCreateEntityWithID:contact.entityID withType:bUserConnectionEntity];
    [connection setType:@(bUserConnectionTypeContact)];
    [connection setEntityID:contact.entityID];
    [BChatSDK.currentUser addConnection:connection];
    return [RXPromise resolveWithResult:Nil];
}

/**
 * @brief Remove a contact locally and on the server if necessary
 */
-(RXPromise *) deleteContact: (id<PUser>) user {
    // Clear down the old blocking list
    id<PUser> currentUser = BChatSDK.currentUser;
    
    NSPredicate * predicate;
    if (user && user.entityID) {
        predicate = [NSPredicate predicateWithFormat:@"type = %@ AND owner = %@ AND entityID = %@", @(bUserConnectionTypeContact), currentUser, user.entityID];
    }
    else {
        predicate = [NSPredicate predicateWithFormat:@"type = %@ AND owner = %@", @(bUserConnectionTypeContact), currentUser];
    }
    
    NSArray * entities = [BChatSDK.db fetchEntitiesWithName:bUserConnectionEntity withPredicate:predicate];
    [BChatSDK.db deleteEntities:entities];
    
    return [RXPromise resolveWithResult:Nil];
}

@end
