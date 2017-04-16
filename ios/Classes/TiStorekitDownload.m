/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitDownload.h"
#import "TiStorekitModule.h"
#import "TiStorekitTransaction.h"

@implementation TiStorekitDownload

- (id)initWithDownload:(SKDownload *)download_ pageContext:(id<TiEvaluator>)context
{
    if (self = [super _initWithPageContext:context]) {
        download = download_;
    }
    return self;
}

- (SKDownload *)download
{
    return download;
}

#pragma mark Public APIs

- (id)contentIdentifier
{
    return [download contentIdentifier];
}

- (id)contentURL
{
    return [download contentURL];
}

- (id)contentVersion
{
    return [download contentVersion];
}

- (id)contentLength
{
    return NUMLONGLONG([download contentLength]);
}

- (id)downloadState
{
    return NUMINT([download downloadState]);
}

- (id)error
{
    NSError *error = [download error];
    if (!error) {
        return nil;
    }
    return [TiStorekitModule descriptionFromError:error];
}

- (id)progress
{
    return NUMFLOAT([download progress]);
}

- (id)timeRemaining
{
    return NUMDOUBLE([download timeRemaining] / 1000);
}

- (TiStorekitTransaction *)transaction
{
    return [[TiStorekitTransaction alloc] initWithTransaction:[download transaction] pageContext:[self pageContext]];
}

@end
