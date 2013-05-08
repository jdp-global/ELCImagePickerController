//
//  ELCImagePickerController.m
//  ELCImagePickerDemo
//
//  Created by ELC on 9/9/10.
//  Copyright 2010 ELC Technologies. All rights reserved.
//

#import "ELCImagePickerController.h"
#import "ELCAsset.h"
#import "ELCAssetCell.h"
#import "ELCAssetTablePicker.h"
#import "ELCAlbumPickerController.h"

@implementation ELCImagePickerController

@synthesize delegate = _myDelegate;

- (void)cancelImagePicker
{
	if([_myDelegate respondsToSelector:@selector(elcImagePickerControllerDidCancel:)]) {
		[_myDelegate performSelector:@selector(elcImagePickerControllerDidCancel:) withObject:self];
	}
}

- (void)selectedAssets:(NSArray *)assets
{
	NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
	
    
	for(ALAsset *asset in assets) {
        
        NSString *assetType = [asset valueForProperty:ALAssetPropertyType];
        
		NSMutableDictionary *workingDictionary = [[NSMutableDictionary alloc] init];
		[workingDictionary setObject:assetType forKey:@"UIImagePickerControllerMediaType"];
        ALAssetRepresentation *assetRep = [asset defaultRepresentation];
        
        CGImageRef imgRef = [assetRep fullScreenImage];
        UIImage *img = [UIImage imageWithCGImage:imgRef
                                           scale:[UIScreen mainScreen].scale
                                     orientation:UIImageOrientationUp];
        [workingDictionary setObject:img forKey:@"UIImagePickerControllerOriginalImage"];
		
        NSURL *refUrl = [[asset valueForProperty:ALAssetPropertyURLs] valueForKey:[[[asset valueForProperty:ALAssetPropertyURLs] allKeys] objectAtIndex:0]];
        
        if ([assetType isEqualToString:ALAssetTypeVideo]) {
            refUrl = [self videoAssetURLToTempFile:refUrl];
        }
        
        [workingDictionary setObject:refUrl forKey:@"UIImagePickerControllerReferenceURL"];
		
		[returnArray addObject:workingDictionary];
		
		[workingDictionary release];	
	}    
	if(_myDelegate != nil && [_myDelegate respondsToSelector:@selector(elcImagePickerController:didFinishPickingMediaWithInfo:)]) {
		[_myDelegate performSelector:@selector(elcImagePickerController:didFinishPickingMediaWithInfo:) withObject:self withObject:[NSArray arrayWithArray:returnArray]];
	} else {
        [self popToRootViewControllerAnimated:NO];
    }
}

-(NSURL*) videoAssetURLToTempFile:(NSURL*)url
{
    
    NSString * surl = [url absoluteString];
    NSString * ext = [surl substringFromIndex:[surl rangeOfString:@"ext="].location + 4];
    NSTimeInterval ti = [[NSDate date]timeIntervalSinceReferenceDate];
    NSString * filename = [NSString stringWithFormat: @"%f.%@",ti,ext];
    NSString * tmpfile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];

    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        
        ALAssetRepresentation * rep = [myasset defaultRepresentation];
        
        NSUInteger size = [rep size];
        const int bufferSize = 8192;
        
        NSLog(@"Writing to %@",tmpfile);
        FILE* f = fopen([tmpfile cStringUsingEncoding:1], "wb+");
        if (f == NULL) {
            NSLog(@"Can not create tmp file.");
            return;
        }
        
        Byte * buffer = (Byte*)malloc(bufferSize);
        int read = 0, offset = 0, written = 0;
        NSError* err;
        if (size != 0) {
            do {
                read = [rep getBytes:buffer
                          fromOffset:offset
                              length:bufferSize
                               error:&err];
                written = fwrite(buffer, sizeof(char), read, f);
                offset += read;
            } while (read != 0);
            
            
        }
        fclose(f);                
    };
    
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"Can not get asset - %@",[myerror localizedDescription]);
        
    };
    
    if(url)
    {
        ALAssetsLibrary* assetslibrary = [[[ALAssetsLibrary alloc] init] autorelease];
        [assetslibrary assetForURL:url
                       resultBlock:resultblock
                      failureBlock:failureblock];
    }
    
    return [NSURL fileURLWithPath:tmpfile];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
    }
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning
{
    NSLog(@"ELC Image Picker received memory warning.");
    
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}


- (void)dealloc
{
    NSLog(@"deallocing ELCImagePickerController");
    [super dealloc];
}

@end
