# BitChat Mesh - Development Status

This document tracks the features implemented in the Bluetooth Mesh Chat App and documents the setup, testing, and operation instructions.

## Progress Overview

| Feature | Status | Notes |
|---------|--------|-------|
| Project Setup & Git Init | ✅ Completed | Flutter 3.38.5, Dart 3.10.4, dependencies updated. |
| Cryptography (P-256, AES-GCM, ECDSA) | ✅ Completed | ECDH key agreement, AES-256-GCM, and signatures using PointyCastle. |
| Database (Isar & Schemas) | ✅ Completed | Isar database with schemas, queries, and transactions. |
| BLE / Mock BLE Simulation Layer | ✅ Completed | Interfaces, RealBleService, and coordinate-based MockBleService. |
| Mesh Routing (AODV + Flood) | ✅ Completed | AODV path discovery, flood protection, routing tables, and file chunking. |
| State Management (Riverpod Providers) | ✅ Completed | Provider infrastructure for state, identities, neighbors, and messages. |
| WhatsApp UI/UX | ✅ Completed | Custom light/dark themes, active chats, bubbles, swipe replies, and emoji reactions. |
| Group Chat Support | ✅ Completed | Broadcast-flooded channels for encrypted multi-node group chats. |
| Media / File Transfer with Chunking | ✅ Completed | File picking, chunk splitting, fragment routing, progress tracking, and reassembly. |
| QR Pairing & Trust System | ✅ Completed | QR code generator for public keys, verification scanner, and manual entry forms. |
| Diagnostics Mesh Canvas Graph | ✅ Completed | CustomPainter force-directed canvas graph representing nodes and packet travels. |
| Local Notifications | ✅ Completed | Mock and system notifications for newly routed offline messages. |
| Unit & Widget Tests | ✅ Completed | 100% passing tests for crypto, Isar db, BLE simulation, and Riverpod providers. |

---

## Current Step

1. **Development & Verification Complete**:
   - All modules (cryptography, local storage database, mock BLE adapter, AODV routing, state management, and WhatsApp-like presentation layer) are fully built and tested.
   - Run command `flutter test` to verify code consistency.

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
