# Streaming

## Overview

This guide covers the configuration and usage of a video streaming service that supports 16:9 aspect ratio, H.264 at 30Hz, floating point durations as separate segment files, and a CODECS attribute in the master playlist. It offers four video variants, with resolutions ranging from 416x234 at 265 kbps to 1920x1080 at 2 Mbps, and one audio-only variant, which provides stereo sound at 22.05 kHz and 40 kbps.

## Getting started with FFmpeg

### Install

To use this video streaming service, you must first install ffmpeg and v4l-utils. You can do so with the following commands:

```sh
sudo apt install ffmpeg
sudo apt install v4l-utils
sudo apt-get install vainfo
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

## Test hardware acceleration

The following command will display information about the VA-API (Video Acceleration API) driver and hardware acceleration support on your system. If the output shows `VAProfileH264` or `VAProfileMPEG4` (or any other supported video codec) and the `VAEntrypointEncSlice` entry point (or any other supported entry point), it means that hardware acceleration is available and working on your system.

```sh
vainfo
```

If you don't see any output or an error message saying "libva error: /dev/dri/renderD128: cannot open", it means that hardware acceleration is not available on your system, or you may need to install additional drivers or libraries.

Otherwise, if the execution of `vainfo` shows you a list as following:

```sh
libva info: VA-API version 1.14.0
libva info: Trying to open /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_14
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.14 (libva 2.12.0)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 22.3.1 ()
vainfo: Supported profile and entrypoints
      VAProfileMPEG2Simple            :	VAEntrypointVLD
      VAProfileMPEG2Main              :	VAEntrypointVLD
      VAProfileH264Main               :	VAEntrypointVLD
      VAProfileH264Main               :	VAEntrypointEncSliceLP
      VAProfileH264High               :	VAEntrypointVLD
      VAProfileH264High               :	VAEntrypointEncSliceLP
      VAProfileJPEGBaseline           :	VAEntrypointVLD
      VAProfileJPEGBaseline           :	VAEntrypointEncPicture
      VAProfileH264ConstrainedBaseline:	VAEntrypointVLD
      VAProfileH264ConstrainedBaseline:	VAEntrypointEncSliceLP
      VAProfileVP8Version0_3          :	VAEntrypointVLD
      VAProfileHEVCMain               :	VAEntrypointVLD
      VAProfileHEVCMain10             :	VAEntrypointVLD
      VAProfileVP9Profile0            :	VAEntrypointVLD
      VAProfileVP9Profile2            :	VAEntrypointVLD

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

This FFmpeg command captures video from a V4L2 device (/dev/video0), scales it to 1920x1080, converts it to the NV12 format, and uses the VA-API hardware encoder to encode it in the H.264 format with a constant quality factor of 20. The audio is copied unchanged, and the output is streamed to the console in FLV format. The piped output is then played by FFplay.

```sh
ffmpeg -y -hide_banner \
    -init_hw_device vaapi=foo:/dev/dri/renderD128 -hwaccel vaapi -hwaccel_output_format vaapi -hwaccel_device foo \
    -f v4l2 -i /dev/video0 \
    -f pulse -i alsa_input.usb-Elgato_Game_Capture_HD60_S__000615C683000-03.analog-stereo \
    -filter_hw_device foo \
    -vf 'scale=-1:720:force_original_aspect_ratio,fps=30,format=nv12|vaapi,hwupload' \
    -c:v h264_vaapi -profile:v high -rc_mode CQP -qp 20 -sc_threshold 0 -g 48 -keyint_min 48 \
    -c:a aac -b:a 128k \
    -f flv \
    - | ffplay -i -
```

- `ffmpeg`: This is the command to run the FFmpeg software.
- `-y`: This option will automatically overwrite any existing output file without asking for confirmation.
- `-hide_banner`: This option will hide the banner that is normally displayed when starting the FFmpeg software.
- `-init_hw_device vaapi=foo:/dev/dri/renderD128`: This option initializes the VA-API hardware device named "foo" with the device file "/dev/dri/renderD128".
- `-hwaccel vaapi`: This option enables hardware acceleration using the VA-API.
- `-hwaccel_output_format vaapi`: This option sets the output format for hardware-accelerated decoding to VA-API.
- `-hwaccel_device foo`: This option sets the hardware device to be used for hardware acceleration to "foo".
- `-f v4l2 -i /dev/video0`: This option specifies the input format as "v4l2" and the input file as "/dev/video0", which is a video capture device.
- `-f pulse -i alsa_input.usb-Elgato_Game_Capture_HD60_S__000615C683000-03.analog-stereo`: This option specifies the input format as "pulse" and the input file as "alsa_input.usb-Elgato_Game_Capture_HD60_S__000615C683000-03.analog-stereo", which is an audio capture device.
- `-filter_hw_device foo`: This option sets the filter hardware device to be used to "foo".
- `-vf 'scale=-1:720:force_original_aspect_ratio,fps=30,format=nv12|vaapi,hwupload'`: This option specifies the video filter to be applied. It scales the video to a height of 720 pixels while maintaining the original aspect ratio, sets the frame rate to 30 fps, sets the output format to NV12 or VA-API format, and performs hardware uploading.
- `-c:v h264_vaapi`: This option specifies the video codec to be used as H.264 with VA-API hardware acceleration.
- `-profile:v high`: This option sets the profile of the H.264 codec to "high".
- `-rc_mode CQP`: This option sets the rate control mode to "constant quantization parameter".
- `-qp 20`: This option sets the quantization parameter to 20.
- `-sc_threshold 0`: This option disables scene change detection.
- `-g 48`: This option sets the GOP size to 48.
- `-keyint_min 48`: This option sets the minimum keyframe interval to 48.
- `-c:a aac -b:a 128k`: This option specifies the audio codec to be used as AAC with a bitrate of 128 kbps.
- `-f flv`: This option sets the output format to FLV.
- `-`: This option sets the output to be sent to the standard output.
- `ffplay -i -`: This command pipes the output of FFmpeg to the input of ffplay, which is a media player that can play the output of FFmpeg.

## Streaming

To push the output to an endpoint using HLS format:

```sh
ffmpeg -y -hide_banner \
    -init_hw_device vaapi=foo:/dev/dri/renderD128 -hwaccel vaapi -hwaccel_output_format vaapi -hwaccel_device foo \
    -f v4l2 -i /dev/video0 \
    -f pulse -i alsa_input.usb-Elgato_Game_Capture_HD60_S__000615C683000-03.analog-stereo \
    -filter_hw_device foo \
    -vf 'scale=-1:1080:force_original_aspect_ratio,fps=30,format=nv12|vaapi,hwupload' \
    -c:v h264_vaapi -profile:v high -rc_mode CQP -qp 20 -sc_threshold 0 -g 48 -keyint_min 48 \
    -c:a copy \
    -f hls -hls_time 4 -hls_list_size 10 http://example.com/playlist.m3u8
```

This command is similar to the previous one, but with few changes:

- The `-c:a` option is set to `copy`, which means the audio will be copied as-is instead of being re-encoded as AAC.
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
