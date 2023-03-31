# Streaming With FFmpeg

## Overview

This guide covers the configuration and usage of a video streaming service that supports 16:9 aspect ratio, H.264 at 30Hz, floating point durations as separate segment files, and a CODECS attribute in the master playlist. It offers four video variants, with resolutions ranging from 416x234 at 265 kbps to 1920x1080 at 2 Mbps, and one audio-only variant, which provides stereo sound at 22.05 kHz and 40 kbps.

## Getting started with FFmpeg

### Install

To use this video streaming service, you must first install `ffmpeg`, `v4l-utils`. You can do so with the following commands:

```sh
sudo apt install ffmpeg
sudo apt install v4l-utils
```

List devices:

To list video devices, run the following command:

```sh
v4l2-ctl --list-devices
```

To list audio devices, run the following command:

```sh
arecord -L
```

List formats for a device
To list the formats supported by a device, run the following command:

```sh
ffmpeg -hide_banner -f video4linux2 -list_formats all -i /dev/video0
```

Test the input source with ffplay

```sh
ffplay -f v4l2 -i /dev/video0
```

## Hardware acceleration

### Getting started with VA-API

VA-API (Video Acceleration API) is a video acceleration API for Linux that allows video decoding, encoding, and processing to be offloaded to specialized hardware video decoding/encoding processors. It is typically installed by default on most modern Linux distributions.

To check if VA-API is installed on your system, open a terminal and run the following command:ecialized hardware video decoding/encoding processors (such as Intel Quick Sync Video).

```sh
vainfo
```

This command displays information about the VA-API driver and hardware acceleration support on your system. If the output shows VAProfileH264 or VAProfileMPEG4 (or any other supported video codec) and the VAEntrypointEncSlice entry point (or any other supported entry point), it means that hardware acceleration is available and working on your system.

If you don't see any output or an error message saying "libva error: /dev/dri/renderD128: cannot open", it means that hardware acceleration is not available on your system, or you may need to install additional drivers or libraries.

```sh
sudo apt-get install vainfo
```

Otherwise, if the execution of `vainfo` shows you a list as following:

```sh
libva info: VA-API version 1.14.0
libva info: Trying to open /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_14
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.14 (libva 2.12.0)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 22.3.1 ()
vainfo: Supported profile and entrypoints
      VAProfileMPEG2Simple            : VAEntrypointVLD
      VAProfileMPEG2Main              : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSliceLP
      VAProfileH264High               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointEncSliceLP
      VAProfileJPEGBaseline           : VAEntrypointVLD
      VAProfileJPEGBaseline           : VAEntrypointEncPicture
      VAProfileH264ConstrainedBaseline: VAEntrypointVLD
      VAProfileH264ConstrainedBaseline: VAEntrypointEncSliceLP
      VAProfileVP8Version0_3          : VAEntrypointVLD
      VAProfileHEVCMain               : VAEntrypointVLD
      VAProfileHEVCMain10             : VAEntrypointVLD
      VAProfileVP9Profile0            : VAEntrypointVLD
      VAProfileVP9Profile2            : VAEntrypointVLD

```

It means, that based on your `vainfo` output, your graphics card supports hardware acceleration for the following codecs and entry points:

- MPEG2 (Simple and Main) with VLD entry point
- H.264 (Main and High) with VLD and EncSliceLP entry points
- JPEG Baseline with VLD and EncPicture entry points
- H.264 Constrained Baseline with VLD and EncSliceLP entry points
- VP8 (Version0_3) with VLD entry point
- HEVC (Main and Main10) with VLD entry point
- VP9 (Profile0 and Profile2) with VLD entry point

You can use the appropriate codec and entry point for your use case to utilize hardware acceleration.

### Capturing video using FFmpeg with VA-API hardware acceleration

This command is using FFmpeg to capture video from a video4linux2 device (/dev/video0) and audio from an ALSA device (hw:CARD=S,DEV=0), and then encoding them into an FLV container format for output to a pipe.

```sh
ffmpeg -y -hide_banner \
    -init_hw_device vaapi=foo:/dev/dri/renderD128 \
    -hwaccel vaapi \
    -hwaccel_output_format vaapi \
    -hwaccel_device foo \
    -f v4l2 -i /dev/video0 \
    -f alsa -i hw:CARD=S,DEV=0 \
    -filter_hw_device foo \
    -vf 'scale=-1:720:force_original_aspect_ratio,fps=30,format=nv12|vaapi,hwupload' \
    -c:v h264_vaapi -profile:v main -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 \
    -c:a aac -b:a 128k \
    -f flv \
    - \
    | ffplay -i -
```

The command includes several FFmpeg options and filters that are used for hardware acceleration, scaling, and encoding:

- `-init_hw_device vaapi=foo:/dev/dri/renderD128`: Initializes the VAAPI (Video Acceleration API) hardware device named "foo" with the specified DRM (Direct Rendering Manager) device file.
- `-hwaccel vaapi`: Enables VAAPI hardware acceleration for decoding video frames.
- `-hwaccel_output_format vaapi`: Specifies the output format for hardware accelerated decoding.
- `-hwaccel_device foo`: Specifies the hardware acceleration device to use for decoding and encoding.
- `-f v4l2 -i /dev/video0`: Specifies the input format as video4linux2 and the input device as /dev/video0.
- `-f alsa -i hw:CARD=S,DEV=0`: Specifies the input format as ALSA (Advanced Linux Sound Architecture) and the input device as hw:CARD=S,DEV=0, which represents the sound card with ID "S" and device ID "0".
- `-filter_hw_device foo:` Specifies the hardware acceleration device to use for filtering.
- `-vf 'scale=-1:720:force_original_aspect_ratio,fps=30,format=nv12|vaapi,hwupload'`: Applies a video filter to scale the input video to a height of 720 pixels, while preserving the original aspect ratio, and set the output frame rate to 30 fps. The filter also converts the pixel format to nv12 or vaapi and uses the "hwupload" option to upload the filtered frames to the hardware device.
- `-c:v h264_vaapi -profile:v main -crf 20 -sc_threshold 0 -g 48 -keyint_min 48`: Specifies the video encoder to use as h264_vaapi and sets the H.264 profile to main. The "-crf 20" option sets the constant rate factor, which determines the video quality and file size. The "-sc_threshold 0" option disables scene detection, and the "-g 48" and "-keyint_min 48" options set the GOP (Group of Pictures) size to 48 frames and the minimum keyframe interval to 48 frames, respectively.
- `-c:a aac -b:a 128k`: Specifies the audio encoder to use as AAC and sets the audio bitrate to 128 kbps.
- `-f flv`: Specifies the output container format as FLV (Flash Video).
- `-`: Writes the output to a pipe.
- `| ffplay -i -`: Reads the output from the pipe and plays it with FFplay.

## Streaming

To push the output to an endpoint using HLS format:

```sh
ffmpeg -y -hide_banner \
    -init_hw_device vaapi=foo:/dev/dri/renderD128 \
    -hwaccel vaapi \
    -hwaccel_output_format vaapi \
    -hwaccel_device foo \
    -f v4l2 -i /dev/video0 \
    -f alsa -i hw:CARD=S,DEV=0 \
    -filter_hw_device foo \
    -vf 'scale=-1:720:force_original_aspect_ratio,fps=30,format=nv12|vaapi,hwupload' \
    -c:v h264_vaapi -profile:v main -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 \
    -c:a aac -b:a 128k \
    -f hls \ 
    -hls_time 4 \
    -hls_list_size 10 \
    http://example.com/playlist.m3u8
```

This command is similar to the previous one, but with few changes:

- `-f hls` specifies the output format to be HLS.
- `-hls_time 4` sets the target duration of each segment to 4 seconds.
- `-hls_list_size 10` sets the maximum number of segments in the playlist to 10.
- `http://example.com/playlist.m3u8` is the URL of the HLS playlist file that will be generated by FFmpeg.

### Preview HLS

To play a video from an HLS, run the following command:

```sh
ffplay hls+http://example.com/playlist.m3u8/master.m3u8
```

## Conclusion

Streaming videos with FFmpeg on Ubuntu is a powerful way to share content with a large audience. Utilizing hardware acceleration can significantly improve the streaming experience. With the steps provided in this guide, you can easily stream videos using FFmpeg and hardware acceleration on Ubuntu.
