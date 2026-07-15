# Licences and source availability

This repository mirrors unmodified vendor software, plus one modified build of Pentaho, for use in Deakin University's MIS774 unit. Nothing here is authored by the maintainer except `install.sh` and the documentation.

Files are mirrored rather than linked because vendor download URLs move when a version is superseded, which breaks setup instructions mid-trimester.

## Pentaho Data Integration 11.0.0.1-259 — **modified**

- **Licence:** Business Source License 1.1. Licensor: Hitachi Vantara, LLC. Change Date: four years from publication; Change Licence: Apache 2.0. Full text in `LICENSE.TXT` inside the distribution.
- **Permission relied on:** BSL 1.1 grants "the right to copy, modify, create derivative works, redistribute, and make non-production use of the Licensed Work." Classroom teaching is non-production use. The Additional Use Grant is "None", so **production use is not permitted** under this licence.
- **Modifications:** two, both documented in `MIS774-MODIFICATIONS.txt` inside the zip:
  1. `libswt/osx64_aarch/swt.jar` replaced (Eclipse SWT 3.122.0 → 3.134.0) so the interface renders on macOS 26.
  2. `lib/mysql-connector-j-8.0.33.jar` added, as the unit requires it and upstream ships no MySQL driver.
- **Upstream:** https://pentaho.com/pentaho-developer-edition/

## MySQL Community Server 9.7.1, MySQL Workbench 8.0.47, MySQL Connector/J 8.0.33 — unmodified

- **Licence:** GNU General Public License, version 2, as published by Oracle Corporation. Connector/J is GPLv2 with the Universal FOSS Exception. Licensing documents are included inside each distribution.
- **Copyright:** Oracle Corporation and/or its affiliates.
- **Trademarks:** MySQL is a trademark of Oracle Corporation. This mirror is not affiliated with, endorsed by, or sponsored by Oracle.
- **Corresponding source:** published by Oracle at
  - Server: https://dev.mysql.com/downloads/mysql/ (Source Code)
  - Workbench: https://dev.mysql.com/downloads/workbench/ (Source Code)
  - Connector/J: https://dev.mysql.com/downloads/connector/j/ (Source Code)
  - Archived versions: https://downloads.mysql.com/archives/

### Written offer of source

In accordance with GPLv2 section 3(b): for at least three years from the date of distribution, the maintainer of this repository will provide, to any third party who received these binaries from this repository, a complete machine-readable copy of the corresponding source code for the GPL-licensed works distributed here, on a medium customarily used for software interchange, for a charge no more than the cost of physically performing the distribution. Requests may be made by opening an issue on this repository.

The identical source is also available directly from Oracle at the links above.

## Eclipse SWT 3.134.0 — unmodified

- **Licence:** Eclipse Public License 2.0.
- **Copyright:** Eclipse Foundation and contributors.
- **Binary:** `org.eclipse.platform:org.eclipse.swt.cocoa.macosx.aarch64:3.134.0` from Maven Central.
- **Source:** https://github.com/eclipse-platform/eclipse.platform.swt

## Eclipse Temurin JDK 21 — not mirrored

`install.sh` downloads this directly from the Adoptium API. GPLv2 with Classpath Exception. https://adoptium.net

## Contact

To request source, raise a licensing concern, or ask for removal of any file, open an issue on this repository.
