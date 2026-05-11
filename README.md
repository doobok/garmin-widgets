# Garmin Connect IQ — Monorepo

Monkey C widgets for Garmin Instinct 2 Solar.

## Widgets

| Directory | Description | Devices |
|---|---|---|
| [`shiftsun/`](shiftsun/) | Maritime/shift-work duty rotation tracker | Instinct 2 / 2S / 2X / Solar |

## Setup

### Developer key (required by Garmin for any build)

```bash
openssl req -newkey rsa:4096 -x509 -nodes \
  -keyout developer_key.pem -out developer_key.pem \
  -days 3650 -subj "/CN=garmin-dev"

openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in developer_key.pem -nocrypt -out developer_key.der
```

Place both files in the repo root (they are gitignored).

### SDK

- Install [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/)
- Download SDK + device `instinct2`
- VS Code extension: **Monkey C** by Garmin

## Build

```bash
SDK=/home/yura/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b

# ShiftSun
$SDK/bin/monkeyc -d instinct2 -f shiftsun/monkey.jungle -o shiftsun/bin/ShiftSun.prg -y developer_key.der
```

VS Code: open the repo root, then **F5** to build + run in simulator.
