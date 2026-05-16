---
sidebar_position: 2
title: Desktop Sync
---

# Desktop Sync

The Nextcloud desktop app creates a folder on your computer that automatically
stays in sync with your file storage. Files you add to the folder appear in
Nextcloud, and files added in Nextcloud appear in the folder.

---

## Install the Nextcloud desktop app

Download from: **nextcloud.com/install** → click "Desktop client"

Available for Windows, Mac, and Linux.

---

## Connect to your ShopStack

1. Open the Nextcloud app after installing
2. Click **Log in** → **Log in with your browser**
3. A browser window will open — enter your ShopStack file storage URL:
   `https://files.YOUR_DOMAIN.woodhead.tech`
4. Log in with your Nextcloud username and password
5. Click **Grant access** to let the desktop app connect
6. Back in the desktop app, choose which folders to sync:
   - **Sync everything** — recommended for most users
   - Or pick specific folders to save disk space
7. Choose where the local folder should live on your computer (e.g., `~/Nextcloud`)
8. Click **Connect** — the initial sync will begin

---

## Using the sync folder

After setup, a **Nextcloud** folder appears on your computer (in the sidebar on Mac,
or in File Explorer on Windows).

- **Add a file** — drag it into the folder. It uploads automatically.
- **Delete a file** — it's removed from Nextcloud and other synced devices.
- **Sync status** — small icons on files show if they're synced (green checkmark),
  syncing (circular arrows), or have an error (red X).

Changes sync in the background. Large files may take a few minutes.

---

## Multiple computers

You can install the app on multiple computers and they'll all stay in sync.
Each computer logs in with the same (or different) Nextcloud accounts.

---

## Pause or stop syncing

Right-click the Nextcloud icon in the system tray (Windows) or menu bar (Mac):
- **Pause sync** — temporarily stops syncing (useful on metered connections)
- **Quit** — stops the app (files on your computer stay, but won't sync until you reopen it)

---

## Troubleshooting

**Files aren't syncing:**
1. Check the Nextcloud icon — is it showing an error?
2. Click the icon → **Open Nextcloud** to see detailed sync status
3. Make sure you have a working internet connection
4. If a specific file has a red X, it may have a filename with special characters — rename it

**"Connection error" or can't log in:**
Email brandon@woodhead.tech with a screenshot of the error message.
