#!/bin/bash

# facebook-dl [input_file] [output_file]

# Download the best quality video from a Facebook HTML file
# Ensure that the page only has one video, otherwise the wrong video will be selected
# Select "Copy URL" in the three dots menu to get the /videos/ link from a /watch/ page
# The user must download the HTML file themselves
# because Facebook checks for more than user agent to determine real users

# Good URL: https://www.facebook.com/123456789/videos/123456789/
# Bad URL: https://www.facebook.com/watch/?v=123456789

# input_file: path to the HTML file [Default: index.html]
# output_file: path to the output MP4 file [Default: output.mp4]

# Example: facebook-dl index.html output.mp4

QUALITY_PATTERN='(?<=FBQualityLabel=\\")(\d+)(?=p\\")'

# Argument cleaning

if [ -z "$1" ]; then
    html_path='index.html'
else
    html_path=$1
fi


if [ -z "$2" ]; then
    output_path='output'
else
    output_path=$2
    if [[ $output_path == *.mp4 ]]; then
        # Remove .mp4
        output_path=${output_path::-4}
    fi
fi

# Get highest video quality
highest_quality=$(grep -oP $QUALITY_PATTERN $html_path | sort -nr | head -1)
echo Best quality: ${highest_quality}p

clean_url() {
    # Clean escaped URL retrieved from Facebook's HTML script tag
    url=${1//\\\//\/} # Replace \/ with /
    url=${url//&amp;/&} # Replace &amp; with &
    echo -e $url # Resolve all unicode escape sequences (\u0025 -> %)
}

# Get video URL
video_url_pattern="(?<=FBQualityLabel=\\\\\"${highest_quality}p\\\\\">\\\\u003CBaseURL>)(.+?)(?=\\\\u003C\\\\\/BaseURL>)"
video_url=$(grep -oP $video_url_pattern $html_path)
video_url=$(clean_url $video_url)
echo ""
echo Video URL: $video_url

# Get the substring from FBQualityLabel to <BaseURL> right before the audio URL
audio_url_prefix_pattern="FBQualityLabel=\\\\\"${highest_quality}p\\\\\">\\\\u003CBaseURL>.+?\\\\u003C\\\\\/BaseURL>.+?\\/>\\\\u003CBaseURL>"
audio_url_prefix=$(grep -oP $audio_url_prefix_pattern $html_path)

# The following replacements are performed to use it as part of a regex pattern
audio_url_prefix=${audio_url_prefix//\\/\\\\} # \ -> \\ (escape backslashes)
audio_url_prefix=${audio_url_prefix//\\\\\//\\\\\\\/} # \\/ -> \\\/ (escape the forward slash)
audio_url_prefix=${audio_url_prefix//\?/\\?} # ? -> \? 
audio_url_prefix=${audio_url_prefix// /\\s} # (space) -> \s

# Get audio url
audio_url_pattern="(?<=${audio_url_prefix}).+?(?=\\\\u003C\\\\\/BaseURL>)"
audio_url=$(grep -oP $audio_url_pattern $html_path)
audio_url=$(clean_url $audio_url)
echo ""
echo Audio URL: $audio_url

echo ""
printf "=%.0s" {1..70}
echo ""

wget $video_url -O ._temp_video_stream
wget $audio_url -O ._temp_audio_stream

ffmpeg -hide_banner -loglevel warning \
    -i ._temp_video_stream -i ._temp_audio_stream \
    -acodec copy -vcodec copy $output_path.mp4

rm ._temp_video_stream ._temp_audio_stream
