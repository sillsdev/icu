#  International Components for Unicode with SIL Modifications

This is the SIL fork of the repository for the [International Components for Unicode](https://icu.unicode.org/).

### Long term branches

## fw

The fw branch is a full build of icu with SIL modifications patched in to allow adding and modifying character data.

### Build Status (`fw` branch)

Build | Status
------|-------
GitHub Actions | [![FW Branch CI](https://github.com/sillsdev/icu/actions/workflows/fw_icu4c_ci.yml/badge.svg?branch=fw)](https://github.com/sillsdev/icu/actions/workflows/fw_icu4c_ci.yml)

### NuGet packages (`fw` branch)

Package | Version
--------|--------
[Icu4c.Win.Fw.Lib](https://www.nuget.org/packages/Icu4c.Win.Fw.Lib/) | [![NuGet version](https://img.shields.io/nuget/v/Icu4c.Win.Fw.Lib.svg?style=flat-square)](https://www.nuget.org/packages/Icu4c.Win.Fw.Lib/)
[Icu4c.Win.Fw.Bin](https://www.nuget.org/packages/Icu4c.Win.Fw.Bin/) | [![NuGet version](https://img.shields.io/nuget/v/Icu4c.Win.Fw.Bin.svg?style=flat-square)](https://www.nuget.org/packages/Icu4c.Win.Fw.Bin/)
[Icu4c.Android.Fw.Lib](https://www.nuget.org/packages/Icu4c.Android.Fw.Lib/) | [![NuGet version](https://img.shields.io/nuget/v/Icu4c.Android.Fw.Lib.svg?style=flat-square)](https://www.nuget.org/packages/Icu4c.Android.Fw.Lib/)

# ICU Project info

The ICU project is under the stewardship of [The Unicode Consortium](https://www.unicode.org).

- Source: https://github.com/unicode-org/icu
- Bugs: https://unicode-org.atlassian.net/projects/ICU
- API Docs: https://unicode-org.github.io/icu-docs/
- User Guide: https://unicode-org.github.io/icu/

![ICU Logo](./tools/images/iculogo_64.png)


### Subdirectories and Information

#### Subdirectories that we modify and package
- [`icu4c/`](./icu4c/) [ICU for C/C++](./icu4c/readme.html)
  - [Android native build guide](./icu4c/packaging/README.android.md)
#### Subdirectories that we don't care about
- [`icu4j/`](./icu4j/) [ICU for Java](./icu4j/readme.html)
- [`tools/`](./tools/) Tools
- [`vendor/`](./vendor/) Vendor dependencies

### License

Please see [./icu4c/LICENSE](./icu4c/LICENSE) (C and J are under an identical license file.)

> Copyright © 2016 and later Unicode, Inc. and others. All Rights Reserved.
Unicode and the Unicode Logo are registered trademarks 
of Unicode, Inc. in the U.S. and other countries.
[Terms of Use and License](http://www.unicode.org/copyright.html)
