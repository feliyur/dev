#! /usr/bin/env bash

ACCESS_TOKEN="$1"
FILE_ID="$2"


echo ${ACCESS_TOKEN}
echo ${FILE_ID}

curl -H "Authorization: Bearer ${ACCESS_TOKEN}" https://www.googleapis.com/drive/v3/files/${FILE_ID}?alt=media 
