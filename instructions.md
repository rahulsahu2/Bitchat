# BitChat Mesh - Development Status

This document tracks the features implemented in the Bluetooth Mesh Chat App and documents the setup, testing, and operation instructions.

## Progress Overview

| Feature | Status | Notes |
|---------|--------|-------|
| Project Setup & Git Init | ✅ Completed | Flutter 3.38.5, Dart 3.10.4, dependencies updated. |
| Cryptography (P-256, AES-GCM, ECDSA) | ✅ Completed | ECDH key agreement, AES-256-GCM, and signatures using PointyCastle. |
| Database (Isar & Schemas) | ✅ Completed | Isar database with schemas, queries, and transactions. |
| BLE / Mock BLE Simulation Layer | ⏳ Not Started | Next up. |
| Mesh Routing (AODV + Flood) | ⏳ Not Started | |
| State Management (Riverpod Providers) | ⏳ Not Started | |
| WhatsApp UI/UX | ⏳ Not Started | |
| Group Chat Support | ⏳ Not Started | |
| Media / File Transfer with Chunking | ⏳ Not Started | |
| QR Pairing & Trust System | ⏳ Not Started | |
| Diagnostics Mesh Canvas Graph | ⏳ Not Started | |
| Local Notifications | ⏳ Not Started | |
| Unit & Widget Tests | ⏳ Not Started | |

---

## Current Step

1. **Implement BLE and Mock BLE Simulation Layer**:
   - Define the `BleService` interface representing Bluetooth discovery and data transmission.
   - Implement `RealBleService` using `flutter_blue_plus` and `flutter_ble_peripheral`.
   - Implement `MockBleService` to manage simulated nodes in memory for rapid local testing without physical devices.
   - Set up automatic scanning and background advertising toggle.

---

## How to Run & Test

1. Run dependencies installation:
   ```bash
   flutter pub get
   ```
2. Build code generation models:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
3. Run automated unit tests:
   ```bash
   flutter test
   ```
4. Start application locally:
   ```bash
   flutter run
   ```
