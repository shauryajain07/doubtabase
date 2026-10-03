# Automatic Mac app updates

Pushing a commit to `main` runs the **Release macOS app** workflow. The workflow builds
the `.app`, signs its update archive with Sparkle, then publishes a GitHub Release with
the archive and appcast. The installed app checks for updates hourly, downloads them in
the background, and installs them when it can safely quit and relaunch.

## One-time signing setup

Sparkle uses an EdDSA key pair so the app can verify that an update came from this project.
Generate the pair once on a Mac:

```bash
./scripts/setup-auto-updates.sh
```

The script stores the private key in `.build/sparkle-private-key` with restricted
permissions and adds only the public key to `App/Info.plist`. Upload the private key as
the repository's Actions secret:

```bash
gh secret set SPARKLE_PRIVATE_ED_KEY < .build/sparkle-private-key
```

Alternatively, add the same secret under **GitHub repository Settings → Secrets and
variables → Actions**. Keep a secure backup of the private key; never commit it.

After the workflow has published its first release, install that build once. Builds
made before Sparkle was added do not contain an updater, so they cannot update
themselves. Later pushes to `main` are installed automatically. **Check for Updates…**
is also available in the app menu.

## Signing and distribution

The workflow's Sparkle EdDSA signature protects the update archive. Builds are
ad-hoc signed unless `CODESIGN_IDENTITY` is supplied to `scripts/build-app.sh`.
For distribution outside a personal/dev setup, configure Developer ID signing and
notarization before sharing releases broadly.
