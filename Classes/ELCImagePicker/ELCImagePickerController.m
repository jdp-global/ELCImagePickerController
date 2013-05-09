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

@interface ELCImagePickerController (){
    
}

@property (nonatomic, retain) NSMutableArray *imageQueue;
@property (nonatomic, retain) NSMutableArray *videoQueue;
@property (nonatomic, retain) NSMutableArray *processedAssets;
@property (nonatomic, assign) NSInteger processCount;
@end
@implementation ELCImagePickerController

#pragma mark - Properties 
@synthesize delegate = _myDelegate;
@synthesize
imageQueue = _imageQueue,
videoQueue = _videoQueue,
processedAssets = _processedAssets;

- (void)cancelImagePicker
{
	if([_myDelegate respondsToSelector:@selector(elcImagePickerControllerDidCancel:)]) {
		[_myDelegate performSelector:@selector(elcImagePickerControllerDidCancel:) withObject:self];
	}
}

#pragma mark - Accept asset dictionaries

//called from album picker. assets holds dictionaries for all assets picked from the photo album
- (void)selectedAssets:(NSArray *)assets
{
	
    //pull out video files and process separately
    //queue completed assets in array
    //once all are processed, send the dictionary array to the delegate
	for(ALAsset *asset in assets) {
        
        NSString *assetType = [asset valueForProperty:ALAssetPropertyType];

        
        //move video to tmp file
        if ([assetType isEqualToString:ALAssetTypeVideo]) {
            if (!self.videoQueue) {
                self.videoQueue = [NSMutableArray array];
            }
            
            [self.videoQueue addObject:asset];
        }else{
            if (!self.imageQueue) {
                self.imageQueue = [NSMutableArray array];
            }
            
            [self.imageQueue addObject:asset];
        }
    }
    self.processCount =  self.imageQueue.count + self.videoQueue.count;
    self.processedAssets = [NSMutableArray arrayWithCapacity:self.processCount];
    [self startProcessing];
    
//    NSURL *refUrl = [[asset valueForProperty:ALAssetPropertyURLs] valueForKey:[[[asset valueForProperty:ALAssetPropertyURLs] allKeys] objectAtIndex:0]];
//    refUrl = [self videoAssetURLToTempFile:refUrl];
    
}

#pragma mark - handle processing events
//checks if all assets have been processed and notifies delegate if everything is done
-(void)assetProcessed{
    if (self.processCount > 0)
        return;
    
    if(_myDelegate != nil && [_myDelegate respondsToSelector:@selector(elcImagePickerController:didFinishPickingMediaWithInfo:)]) {
		[_myDelegate performSelector:@selector(elcImagePickerController:didFinishPickingMediaWithInfo:) withObject:self withObject:[NSArray arrayWithArray:self.processedAssets]];
	} else {
        [self popToRootViewControllerAnimated:NO];
    }
}

//starts processing on queues once the assets have been sorted
-(void)startProcessing{
    for (ALAsset *asset in self.imageQueue) {
        NSURL *url = [[asset valueForProperty:ALAssetPropertyURLs] valueForKey:[[[asset valueForProperty:ALAssetPropertyURLs] allKeys] objectAtIndex:0]];
        url = [NSURL fileURLWithPath:[self tmpPathForAssetURL:url]];
        [self processAsset:asset withURL:url];
    }
    
    for (ALAsset *asset in self.videoQueue) {
        [self videoAssetToTempFile:asset];
    }
}



//pulls out relevant info from the asset object
-(void)processAsset:(ALAsset*)asset withURL:(NSURL*)fileURL{
    
    //initialize asset dictionary
    NSMutableDictionary *workingDictionary = [[NSMutableDictionary alloc] init];

    //pull out type
    NSString *assetType = [asset valueForProperty:ALAssetPropertyType];
    [workingDictionary setObject:assetType forKey:@"UIImagePickerControllerMediaType"];

    //pull out image
    ALAssetRepresentation *assetRep = [asset defaultRepresentation];
    CGImageRef imgRef = [assetRep fullScreenImage];
    UIImage *img = [UIImage imageWithCGImage:imgRef
                                       scale:[UIScreen mainScreen].scale
                                 orientation:UIImageOrientationUp];
    [workingDictionary setObject:img forKey:@"UIImagePickerControllerOriginalImage"];
    
    //pull out reference URL: this property is a file url for videos; for images it's used as the file name since the full image is returned;
//    NSURL *refUrl = [[asset valueForProperty:ALAssetPropertyURLs] valueForKey:[[[asset valueForProperty:ALAssetPropertyURLs] allKeys] objectAtIndex:0]];
    [workingDictionary setObject:fileURL forKey:@"UIImagePickerControllerReferenceURL"];
    
//    if ([assetType isEqualToString:ALAssetTypeVideo]) {
//        [self.videoQueue removeObject:asset];
//    }else{
//        [self.imageQueue removeObject:asset];
//    }
    self.processCount--;
    [self.processedAssets addObject:workingDictionary];
    [workingDictionary release];
    [self assetProcessed];
}

#pragma mark - helper functions
-(NSString *)tmpPathForAssetURL:(NSURL*) assetUrl{
    NSString * surl = [assetUrl absoluteString];
    NSString * ext = [surl substringFromIndex:[surl rangeOfString:@"ext="].location + 4];
    NSTimeInterval ti = [[NSDate date]timeIntervalSinceReferenceDate];
    NSString * filename = [NSString stringWithFormat: @"%f.%@",ti,ext];
    NSString * tmpfile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    return tmpfile;
}

#pragma mark - copy video data out of photo album
//notified when the videoAssetToTempFile success block is run
-(void)finishedMovingVideoForAsset:(ALAsset*)asset withURL:(NSURL*)fileURL{
    //    [self.videoQueue removeObject:asset];
    [self processAsset:asset withURL:fileURL];
}

//notified when the videoAssetToTempFile failure block is run
-(void)failedMovingVideoForAsset:(ALAsset*)asset{
    NSLog(@"<ELCImagePickerController> Failed to move video file to tmp; removing from queue ");
//    [self.videoQueue removeObject:asset];
    self.processCount--;
    [self assetProcessed];
}

//caches the video file data to the tmp directory then calls the next step when processed
-(void) videoAssetToTempFile:(ALAsset*)asset
{    
    NSURL *url = [[asset valueForProperty:ALAssetPropertyURLs] valueForKey:[[[asset valueForProperty:ALAssetPropertyURLs] allKeys] objectAtIndex:0]];
//    NSString * surl = [url absoluteString];
//    NSString * ext = [surl substringFromIndex:[surl rangeOfString:@"ext="].location + 4];
//    NSTimeInterval ti = [[NSDate date]timeIntervalSinceReferenceDate];
//    NSString * filename = [NSString stringWithFormat: @"%f.%@",ti,ext];
    NSString * tmpfile = [self tmpPathForAssetURL:url];
    //[NSTemporaryDirectory() stringByAppendingPathComponent:filename];

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
        [self finishedMovingVideoForAsset:asset withURL:[NSURL fileURLWithPath:tmpfile]];
    };
    
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"Can not get asset - %@",[myerror localizedDescription]);
        [self failedMovingVideoForAsset:asset];
    };
    
    if(url)
    {
        ALAssetsLibrary* assetslibrary = [[[ALAssetsLibrary alloc] init] autorelease];
        [assetslibrary assetForURL:url
                       resultBlock:resultblock
                      failureBlock:failureblock];
    }
    
//    return [NSURL fileURLWithPath:tmpfile];
}



#pragma mark - rotation
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
    [_videoQueue release];
    [_processedAssets release];
    [_imageQueue release];
    [_myDelegate release];
    
    _videoQueue = nil;
    _processedAssets = nil;
    _imageQueue = nil;
    _myDelegate = nil;
    
    [super dealloc];
}

@end
