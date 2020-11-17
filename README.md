# macos-bootable-usb

[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE.md)

Combination of some codes and applications to create macOS installation media outside Mac app store.\
Thanks me later :3

## How to Use

it's still in beta. Simply, just edit `MACOS_VERSION` and `TARGET_DISK` variables and run the script.

`TARGET_DISK` information can be found in `diskutil` > `table` > `Device`. In this example `disk3`. So, `TARGET_DISK` become `/dev/disk3`.

![diskutil](screenshots/diskutil.png)

```shell script
$ git clone https://github.com/heinthanth/macos-bootable-usb
$ cd macos-bootable-usb
$ ./creator.sh
```

## License

This work is licensed under GPLv3. See [License](LICENSE.md) for more information.
