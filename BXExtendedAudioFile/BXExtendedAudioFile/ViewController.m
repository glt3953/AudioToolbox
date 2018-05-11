//
//  ViewController.m
//  BXExtendedAudioFile
//
//  Created by baxiang on 2017/7/14.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "lame.h"
@interface ViewController ()
{
    ExtAudioFileRef _audioFileRef;
    AudioStreamBasicDescription   _outputFormat;
    AudioStreamBasicDescription   _inputFormat;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
   NSString *path =  [[NSBundle mainBundle] pathForResource:@"VoiceOriginFile" ofType:@"wav"];
  // 读取音频文件
   OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef _Nonnull)([NSURL fileURLWithPath:path]), &_audioFileRef);
    if (status!= noErr) {
        NSLog(@"数据读取错误 %d",status);
    }
    
    _outputFormat.mSampleRate = 44100;
    _outputFormat.mBitsPerChannel = 16;
    _outputFormat.mChannelsPerFrame = 2;
    _outputFormat.mFormatID = kAudioFormatMPEGLayer3;
    
    //获得属性内容，kExtAudioFileProperty_Xxxx : 源文件的相关属性，也就是原来什么格式的数据（MP3/AAC），他的基本属性。
    UInt32 descSize = sizeof(AudioStreamBasicDescription);
    ExtAudioFileGetProperty(_audioFileRef, kExtAudioFileProperty_FileDataFormat, &descSize, &_inputFormat);
    
    
    _inputFormat.mSampleRate = _outputFormat.mSampleRate;
    _inputFormat.mChannelsPerFrame = _outputFormat.mChannelsPerFrame;
    _inputFormat.mBytesPerFrame = _inputFormat.mChannelsPerFrame* _inputFormat.mBytesPerFrame;
    _inputFormat.mBytesPerPacket =  _inputFormat.mFramesPerPacket*_inputFormat.mBytesPerFrame;
    
    //设置属性内容，kExtAudioFileProperty_ClientXxx: 读出时的数据格式，Ext在读出时会自动帮我们做编解码操作，这个是处理后的结果
    ExtAudioFileSetProperty(_audioFileRef,
                            kExtAudioFileProperty_ClientDataFormat,
                            sizeof(AudioStreamBasicDescription),
                            &_inputFormat),

    [self startConvertMP3:_inputFormat];
    
    //回收音频资源
    status = ExtAudioFileDispose(_audioFileRef);
    if (status!= noErr) {
        NSLog(@"回收资源错误 %d",status);
    }
    
    // Do any additional setup after loading the view, typically from a nib.
}
-(void)startConvertMP3:(AudioStreamBasicDescription) inputFormat{
    
    lame_t lame = lame_init();
    lame_set_in_samplerate(lame, inputFormat.mSampleRate);
    lame_set_num_channels(lame, inputFormat.mChannelsPerFrame);
    lame_set_VBR(lame, vbr_default);
    lame_init_params(lame);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* outputFilePath = [[paths lastObject] stringByAppendingPathComponent:@"music.mp3"];
    FILE* outputFile = fopen([outputFilePath cStringUsingEncoding:1], "wb");
    UInt32 sizePerBuffer = 32*1024;
    UInt32 framesPerBuffer = sizePerBuffer/sizeof(SInt16);
    
    int write;
    
    // allocate destination buffer
    SInt16 *outputBuffer = (SInt16 *)malloc(sizeof(SInt16) * sizePerBuffer);
    
    while (1) {
        AudioBufferList outputBufferList;
        outputBufferList.mNumberBuffers              = 1;
        outputBufferList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
        outputBufferList.mBuffers[0].mDataByteSize   = sizePerBuffer;
        outputBufferList.mBuffers[0].mData           = outputBuffer;
        
        UInt32 framesCount = framesPerBuffer;
        
        ExtAudioFileRead(_audioFileRef,&framesCount,&outputBufferList);
        
        SInt16 pcm_buffer[framesCount];
        unsigned char mp3_buffer[framesCount];
        memcpy(pcm_buffer,
               outputBufferList.mBuffers[0].mData,
               framesCount);
        if (framesCount==0) {
            NSLog(@"outputFile---- %@\n",outputFilePath);
            free(outputBuffer);
            outputBuffer = NULL;
            break;
        }
        write = lame_encode_buffer_interleaved(lame,
                                               outputBufferList.mBuffers[0].mData,
                                               framesCount,
                                               mp3_buffer,
                                               0);
         fwrite(mp3_buffer,1,write,outputFile);
    }
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
