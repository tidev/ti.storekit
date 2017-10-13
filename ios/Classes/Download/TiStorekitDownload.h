/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiProxy.h"
#import "TiStorekitTransaction.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitDownload : TiProxy {
  @private
  SKDownload *_download;
}

- (id)initWithDownload:(SKDownload *)download pageContext:(id<TiEvaluator>)context;

#pragma mark Public API's

- (SKDownload *)download;

- (id)contentIdentifier;

- (id)contentURL;

- (id)contentVersion;

- (id)contentLength;

- (id)downloadState;

- (id)error;

- (id)progress;

- (id)timeRemaining;

- (TiStorekitTransaction *)transaction;

@end
