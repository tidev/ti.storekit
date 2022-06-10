/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitDownload.h"
#import "TiStorekitModule.h"
#import "TiStorekitTransaction.h"

@implementation TiStorekitDownload

- (id)initWithDownload:(SKDownload *)download pageContext:(id<TiEvaluator>)context
{
  if (self = [super _initWithPageContext:context]) {
    _download = download;
  }
  return self;
}

- (SKDownload *)download
{
  return _download;
}

#pragma mark Public API's

- (id)contentIdentifier
{
  return [_download contentIdentifier];
}

- (id)contentURL
{
  return [_download contentURL];
}

- (id)contentVersion
{
  return [_download contentVersion];
}

- (id)contentLength
{
  return @([_download contentLength]);
}

- (id)downloadState
{
  return @([_download state]);
}

- (id)error
{
  NSError *error = [_download error];
  if (!error) {
    return nil;
  }
  return [TiStorekitModule descriptionFromError:error];
}

- (id)progress
{
  return @([_download progress]);
}

- (id)timeRemaining
{
  return @([_download timeRemaining] / 1000);
}

- (TiStorekitTransaction *)transaction
{
  return [[TiStorekitTransaction alloc] initWithTransaction:[_download transaction] pageContext:[self pageContext]];
}

@end
