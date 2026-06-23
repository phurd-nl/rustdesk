# NextSession macOS — MDM PPPC Profile (required for unattended access)

This is the **load-bearing** companion to `deploy/provision-macos.sh`.

macOS TCC (Transparency, Consent, and Control) blocks screen capture and input
control behind user-granted permissions. **No script, installer, `tccutil`, or
root process can grant them** — the TCC database is SIP-protected. `tccutil` can
only *reset/revoke*, never grant. The **only** unattended grant mechanism is an
**MDM-delivered PPPC configuration profile** applied to a **supervised /
MDM-enrolled** Mac (ideally via DEP / Automated Device Enrollment).

> The RMM/MDM **MUST** deploy this PPPC profile **before or together with** the
> NextSession agent. Without it the agent will **not** work unattended.

---

## 1. TCC services that must be pre-granted

The agent calls exactly these TCC-gated APIs (`src/platform/macos.rs`:
`AXIsProcessTrustedWithOptions`, `InputMonitoringAuthStatus`,
`IsCanScreenRecording`):

| Capability | PPPC service key | TCC service | Silent via PPPC? |
|---|---|---|---|
| View the screen | `ScreenCapture` | `kTCCServiceScreenCapture` | **Partial — see §4** |
| Control keyboard & mouse | `Accessibility` | Accessibility / `kTCCServicePostEvent` | **Yes** |
| Read local HID input | `ListenEvent` | `kTCCServiceListenEvent` (Input Monitoring) | **Yes** |

- **Accessibility** is the load-bearing one for *control*. Grant it.
- **ListenEvent (Input Monitoring)** is probed by the app; grant it.
- **ScreenCapture (Screen Recording)** is required for *viewing* — but Apple
  treats it specially in PPPC (see §4).
- **Full Disk Access** (`SystemPolicyAllFiles`) is **NOT required** for view +
  control. Skip unless a future feature needs protected user data.

---

## 2. App identity to bind the grants to

Each PPPC service entry must identify the app so a look-alike can't inherit the
grant:

- **Identifier:** `com.nxlink.nextsession`
- **IdentifierType:** `bundleID`
- **CodeRequirement:** the app's signed **Designated Requirement (DR)**.

Get the exact DR from your signed, notarized build (do **not** hand-type it):

```sh
codesign --display -r - /Applications/NextSession.app
```

It will look like:

```
identifier "com.nxlink.nextsession" and anchor apple generic and certificate leaf[subject.OU] = "TEAMID1234"
```

> **TODO (fill in before rollout):** paste the real DR string and the real
> `<YOUR_TEAM_ID>` from `codesign --display -r -` of the production-signed bundle.
> The placeholder below must be replaced.

### Daemon binary caveat

The grants must apply to the **signed process that actually captures the screen
and posts events** — i.e. the binary the LaunchAgent launches
(`/Applications/NextSession.app/Contents/MacOS/nextsession --server`). A
**bundleID**-based entry for `com.nxlink.nextsession` covers the in-bundle binary.

> **TODO (verify):** confirm the LaunchDaemon's root `service` binary is also
> inside the bundle (and thus covered by the bundleID entry). If the daemon runs
> a binary **outside** the bundle, add a second PPPC entry with
> `IdentifierType = path` pointing at that binary plus its own code requirement.

---

## 3. Profile payload (template)

`PayloadType = com.apple.TCC.configuration-profile-policy`. Replace the
`CodeRequirement` placeholder with the real DR from §2.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadType</key>        <string>Configuration</string>
  <key>PayloadVersion</key>     <integer>1</integer>
  <key>PayloadIdentifier</key>  <string>team.nxlink.nextsession.pppc</string>
  <key>PayloadUUID</key>        <string>REPLACE-WITH-UUID</string>
  <key>PayloadDisplayName</key> <string>NextSession PPPC</string>
  <key>PayloadScope</key>       <string>System</string>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>       <string>com.apple.TCC.configuration-profile-policy</string>
      <key>PayloadVersion</key>    <integer>1</integer>
      <key>PayloadIdentifier</key> <string>team.nxlink.nextsession.pppc.tcc</string>
      <key>PayloadUUID</key>       <string>REPLACE-WITH-UUID</string>
      <key>Services</key>
      <dict>

        <key>Accessibility</key>
        <array>
          <dict>
            <key>Identifier</key>     <string>com.nxlink.nextsession</string>
            <key>IdentifierType</key> <string>bundleID</string>
            <key>CodeRequirement</key>
            <string>identifier "com.nxlink.nextsession" and anchor apple generic and certificate leaf[subject.OU] = "REPLACE_TEAM_ID"</string>
            <key>Allowed</key>        <true/>
          </dict>
        </array>

        <key>ListenEvent</key>
        <array>
          <dict>
            <key>Identifier</key>     <string>com.nxlink.nextsession</string>
            <key>IdentifierType</key> <string>bundleID</string>
            <key>CodeRequirement</key>
            <string>identifier "com.nxlink.nextsession" and anchor apple generic and certificate leaf[subject.OU] = "REPLACE_TEAM_ID"</string>
            <key>Allowed</key>        <true/>
          </dict>
        </array>

        <key>ScreenCapture</key>
        <array>
          <dict>
            <key>Identifier</key>     <string>com.nxlink.nextsession</string>
            <key>IdentifierType</key> <string>bundleID</string>
            <key>CodeRequirement</key>
            <string>identifier "com.nxlink.nextsession" and anchor apple generic and certificate leaf[subject.OU] = "REPLACE_TEAM_ID"</string>
            <key>Allowed</key>        <true/>
          </dict>
        </array>

      </dict>
    </dict>
  </array>
</dict>
</plist>
```

> **TODO (verify per MDM):** some MDMs (Jamf, Kandji, Mosyle, Intune) build PPPC
> payloads through a GUI rather than raw XML, and a few do not yet expose the
> `Allowed`-vs-`AllowStandardUserToSetSystemService` distinction the same way.
> Use your MDM's PPPC editor with the §2 identity if available; the XML above is
> the canonical fallback.

---

## 4. Screen Recording caveat — read this before promising "zero touch"

Apple deliberately does **not** let PPPC silently flip Screen Recording the way
it does Accessibility/Input Monitoring:

- **Through Big Sur / Monterey:** PPPC could *pre-list* the app, but Screen
  Recording still required a **one-time user click** in
  System Settings → Privacy & Security.
- **Ventura / Sonoma+:** MDM can manage `ScreenCapture` more fully on
  **supervised** devices, but it remains the most fragile of the four.

> **TODO (validate on target OS):** wipe a representative Mac at your fleet's
> exact macOS version + supervision state (DEP), push this PPPC profile + the
> agent pkg, reboot to the login window, and confirm a remote operator gets a
> live (non-black) screen with working keyboard/mouse — **with zero human
> interaction**. If Screen Recording still needs a click, your OS/supervision
> combo does not support silent `ScreenCapture`, and a one-time approval is
> unavoidable.

---

## 5. Deployment order (what the MDM/RMM must do)

For a freshly-imaged, supervised Mac to be reachable unattended:

1. **Push the PPPC profile** from §3 (with the real DR) — **first, or in the same
   batch** as the agent. PPPC applied before the binary runs avoids first-run
   prompts.
2. **Push the signed + notarized NextSession `.pkg`** to `/Applications`. Its
   postinstall installs:
   - `/Library/LaunchDaemons/com.nxlink.nextsession_service.plist`
     (root, `KeepAlive`, `RunAtLoad`)
   - `/Library/LaunchAgents/com.nxlink.nextsession_server.plist`
     (`LimitLoadToSessionType = [LoginWindow, Aqua]`, `RunAtLoad`) — the
     `LoginWindow` session type is what enables capture/control **at the login
     window with nobody logged in**.
3. **Run `deploy/provision-macos.sh`** (as root, via the RMM) to set the unique
   permanent password, force `approve-mode=password`, read the device ID, and
   register into the shared address book.

Servers + key are baked into the signed `custom.txt` — **do not** set servers in
any profile or script.

### Net minimum
| Item | Delivered by | Silent? |
|---|---|---|
| Signed `.pkg` + LaunchDaemon/LaunchAgent | MDM pkg push | yes |
| Accessibility grant | PPPC profile | yes |
| Input Monitoring grant | PPPC profile | yes |
| Screen Recording grant | PPPC profile | **OS/supervision-dependent (§4)** |
| Unique password + approve-mode + ID + AB registration | `provision-macos.sh` | yes |
