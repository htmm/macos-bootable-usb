#!/usr/bin/env bash

echo "$(shasum creator.sh | awk '{ print $1 }')  creator.sh" > SHASUM
gpg --detach-sig --sign --output ./SHASUM.gpg ./SHASUM
