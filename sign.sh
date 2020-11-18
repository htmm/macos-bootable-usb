#!/usr/bin/env bash

shasum creator.sh > SHASUM
gpg --detach-sig --sign --output ./SHASUM.gpg ./SHASUM