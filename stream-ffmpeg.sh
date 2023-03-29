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