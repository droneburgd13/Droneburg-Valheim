# Droneburg Valheim

Release and automation source for the Droneburg Valheim server and client modpack.

## Release Pipeline

Valheim update
→ mod update check
→ custom mod rebuild
→ server validation
→ client installer build
→ GitHub Release
→ Discord announcement

A release is not published unless validation succeeds.

## Distribution

Client installers are published through GitHub Releases.

## Security

Server credentials, Discord webhooks, world data, and private configuration are never stored in this repository.
