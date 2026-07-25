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
| WhatsApp UI/UX | ⏳ Not Started | Next up. |
| Group Chat Support | ⏳ Not Started | |
| Media / File Transfer with Chunking | ⏳ Not Started | |
| QR Pairing & Trust System | ⏳ Not Started | |
| Diagnostics Mesh Canvas Graph | ⏳ Not Started | |
| Local Notifications | ⏳ Not Started | |
| Unit & Widget Tests | ⏳ Not Started | |

---

## Current Step

1. **Build WhatsApp-like UI/UX**:
   - Establish Theme & Dark/Light custom styles with Material 3 and green accents.
   - Profile Setup Screen: Profile setup for first launch (generates cryptographic profile).
   - Home Screen: Bottom navigation containing Chats tab, Neighbors (discovered devices) tab, and Settings tab.
   - Chat Screen: WhatsApp-like chat bubbles, swipe replies, long-press reactions, status indicators, and E2EE verification indicator.
   - Settings Screen: Edit profile, developer settings to toggle simulation mode.

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
