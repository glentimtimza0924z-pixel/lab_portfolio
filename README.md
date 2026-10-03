# Mobile Computing Master Compilation App (Activities 1 – 4)

A unified, multi-screen Flutter application serving as the master compilation client for all 4 Mobile Computing laboratory activities. Designed with a clean, calm, professional aesthetic (non-vibrant, high legibility slate/charcoal palette) and strict declarative architecture (`UI = f(state)`).

---

## 📱 Module Architecture & Activity Breakdown

### 🔹 Activity 1: Flutter Portfolio & State Management
- **Dashboard Menu Navigation**: Responsive Home Dashboard built with native layout widgets (`Column`, `Row`, `Expanded`, `Flexible`) that adapts seamlessly across phone and tablet screens without overflows.
- **Widget Architecture**: Strict separation of concerns using reusable `StatelessWidget` components (`ActivityCard`, `StatusBadge`, `MetricTile`, `SectionHeader`) for static rendering and `StatefulWidget` for localized user input forms.
- **Global State Management (Provider)**: Dedicated Settings & Portfolio screen with a live **Dark/Light Theme toggle** and student pair profile parameters (`studentName`, `partnerName`, `courseSection`, `studentId`). Changing any value instantly propagates and re-renders across the Home Dashboard and all module screens.

### 🔹 Activity 2: Active Network Monitor & Handover Handling
- **Real-Time Stream Listener**: Leverages `connectivity_plus` to listen to hardware network state changes in real time.
- **Dynamic Interface Indicator**: Real-time visual dashboard indicating whether the device is on **Wi-Fi**, **Cellular**, **Ethernet**, or **Offline**.
- **Handover Transition Audit Log**: Records every network migration event (e.g., `Wi-Fi ➜ Cellular`, `Cellular ➜ Offline`) with timestamps.
- **Resilient Request Queuing System**: Long-running telemetry requests catch network dropouts and IP migrations. Instead of failing or crashing, requests are buffered in a persistent queue (`QueuedRequest`).
- **Graceful Recovery**: Automatically drains and retries queued requests as soon as a stable connection (Cellular or Wi-Fi) is re-established.
- **Testing Simulator**: Includes a Handover Simulator toggle to test offline drops and Wi-Fi/Cellular switching even on a single device or emulator without physical SIMs.

### 🔹 Activity 3: Dynamic Performance Throttle App
- **Multi-Step Diagnostic Sequence**:
  1. Measures baseline **idle ping** (round-trip latency via HTTP HEAD ping).
  2. Computes **download bandwidth** (Mbps) while concurrently tracking loaded download ping.
  3. Measures **upload bandwidth** (Mbps) while concurrently tracking loaded upload ping.
- **Threshold Health Categorization**:
  - `Excellent`: > 10 Mbps (and low latency < 100ms)
  - `Fair`: 2 – 10 Mbps
  - `Poor`: < 2 Mbps
  - `Degraded`: Heavy packet loss or extreme latency (> 300ms)
- **Global Health Broadcast**: Injected globally via `DiagnosticProvider` to make real-time network health status available across the entire app.
- **Dynamic Adaptive UI Showcase**: The UI dynamically adapts from high-resolution multimedia (4K assets, uncompressed LIDAR/satellite feeds) down to compressed assets, lightweight vector placeholders, or minimal text-only emergency mode based on connection health.
- **Instant Preset Controls**: Includes one-tap tier presets (`Excellent`, `Fair`, `Poor`, `Degraded`) for seamless laboratory presentation.

### 🔹 Activity 4: Serverless Local Chat App
- **Zero-Server P2P Mesh Architecture**: Serverless peer discovery and messaging that operates completely without internet connectivity or central cloud servers.
- **Local Discovery via UDP Beacon**: Devices broadcast discovery beacons on UDP port `8888` every 2 seconds and listen for neighboring peers on the local Wi-Fi or Mobile Hotspot subnet.
- **Pairing Handshake Socket**: Tapping "Pair" on a discovered peer establishes a dedicated TCP socket connection on port `8889` with a bidirectional handshake sequence (`HANDSHAKE_INIT` ➜ `HANDSHAKE_ACK`).
- **Declarative Payload Routing**: Sends and receives JSON text payloads in real time across the mesh sockets, updating declarative chat bubble states (`sent`, `delivered`, `received`).
- **Solo Evaluation Node**: Includes a "Test Node" simulator button allowing students to demonstrate peer pairing and chat delivery even when presenting on a single device.

---

## 🛠️ Tech Stack & Dependencies
- **Flutter SDK**: 3.41+
- **Dart SDK**: 3.11+
- **State Management**: `provider: ^6.1.5`
- **Network Monitoring**: `connectivity_plus: ^7.3.2`
- **Networking & Diagnostics**: `http: ^1.6.0`
- **Formatting**: `intl: ^0.20.3`
- **Permissions**: `permission_handler: ^13.0.2`

---

## 🚀 Running the Project

1. Verify dependencies:
   ```bash
   flutter pub get
   ```

2. Run test suite:
   ```bash
   flutter test
   ```

3. Run code analysis (passes with 0 issues):
   ```bash
   flutter analyze
   ```

4. Launch the application:
   ```bash
   flutter run
   ```
